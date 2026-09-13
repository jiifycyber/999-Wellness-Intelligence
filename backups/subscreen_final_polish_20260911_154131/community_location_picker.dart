import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommunityLocationPicker extends StatefulWidget {
  const CommunityLocationPicker({super.key});

  @override
  State<CommunityLocationPicker> createState() =>
      _CommunityLocationPickerState();
}

class _CommunityLocationPickerState extends State<CommunityLocationPicker> {
  final TextEditingController searchController = TextEditingController();

  Timer? debounce;
  bool searching = false;
  bool locating = false;
  String? error;

  List<Map<String, dynamic>> results = [];

  @override
  void dispose() {
    debounce?.cancel();
    searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    debounce?.cancel();

    final query = value.trim();

    if (query.length < 2) {
      setState(() {
        results = [];
        searching = false;
        error = null;
      });
      return;
    }

    debounce = Timer(const Duration(milliseconds: 350), () {
      _searchPlaces(query);
    });
  }

  Future<void> _searchPlaces(String query) async {
    if (!mounted) return;

    setState(() {
      searching = true;
      error = null;
    });

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'place-search',
        body: {'action': 'search', 'query': query},
      );

      final data = response.data;

      if (data is! Map) {
        throw Exception('Invalid place search response.');
      }

      final raw = data['results'];

      final mapped = raw is List
          ? raw
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
          : <Map<String, dynamic>>[];

      if (!mounted) return;

      setState(() {
        results = mapped;
        searching = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        searching = false;
        error = 'Search error: ' + e.toString();
      });
    }
  }

  Future<void> _useCurrentLocation() async {
    if (locating) return;

    setState(() {
      locating = true;
      error = null;
    });

    try {
      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied.');
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permission is disabled in device settings.');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );

      final response = await Supabase.instance.client.functions.invoke(
        'place-search',
        body: {
          'action': 'reverse',
          'lat': position.latitude,
          'lng': position.longitude,
        },
      );

      final data = response.data;

      if (data is! Map || data['place'] is! Map) {
        throw Exception('Unable to identify this location.');
      }

      final place = Map<String, dynamic>.from(data['place'] as Map);

      if (!mounted) return;

      Navigator.of(context).pop(place);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        locating = false;
        error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _selectPlace(Map<String, dynamic> place) {
    Navigator.of(context).pop(place);
  }

  Widget _premiumLocationButton() {
    return InkWell(
      onTap: locating ? null : _useCurrentLocation,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xFF18E6FF), Color(0xFF525EFF), Color(0xFFFF45D0)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF22E3FF).withValues(alpha: .18),
              blurRadius: 24,
            ),
          ],
        ),
        padding: const EdgeInsets.all(1.3),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(23),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0B2852), Color(0xFF19245B), Color(0xFF34125E)],
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFF477F),
                      Color(0xFFE82BCC),
                      Color(0xFF8C42FF),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF42B3).withValues(alpha: .35),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: locating
                    ? const Padding(
                        padding: EdgeInsets.all(15),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.my_location_rounded,
                        color: Colors.white,
                        size: 27,
                      ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Use my current location',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Find nearby cities and places',
                      style: TextStyle(color: Color(0xFFB2BFDB), fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF8BEFFF),
                size: 29,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _premiumResultTile(Map<String, dynamic> place) {
    final name = place['name']?.toString().trim() ?? 'Unknown place';

    final state = place['state']?.toString().trim() ?? '';

    final stateCode = place['state_code']?.toString().trim() ?? '';

    var subtitle = state;

    if (subtitle.isEmpty) {
      subtitle = place['subtitle']?.toString().trim() ?? '';
    }

    if (stateCode.isNotEmpty &&
        subtitle.toLowerCase().endsWith(', ${stateCode.toLowerCase()}')) {
      subtitle = subtitle.substring(0, subtitle.length - stateCode.length - 2);
    }

    return InkWell(
      onTap: () => _selectPlace(place),
      borderRadius: BorderRadius.circular(21),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(21),
          gradient: const LinearGradient(
            colors: [Color(0xFF19DFFF), Color(0xFF5860FF), Color(0xFF8D39FF)],
          ),
        ),
        padding: const EdgeInsets.all(1),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [Color(0xFF0A2142), Color(0xFF121C47)],
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF624EFF), Color(0xFF9B43FF)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF774DFF).withValues(alpha: .32),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: Color(0xFFDAD0FF),
                  size: 23,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFA8B6D2),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF70DFFF)),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _rankedLocationResults() {
    final query = searchController.text.trim().toLowerCase();
    final ranked = List<Map<String, dynamic>>.from(results);

    String value(Map<String, dynamic> place, String key) {
      return place[key]?.toString().trim().toLowerCase() ?? '';
    }

    bool isCityType(Map<String, dynamic> place) {
      final type = value(place, 'type');
      final addressType = value(place, 'addresstype');

      const cityTypes = {
        'city',
        'town',
        'village',
        'municipality',
        'borough',
        'hamlet',
      };

      return cityTypes.contains(type) || cityTypes.contains(addressType);
    }

    int score(Map<String, dynamic> place) {
      final name = value(place, 'name');
      final city = value(place, 'city');
      final fullName = value(place, 'full_name');
      final countryCode = value(place, 'country_code');

      var points = 0;

      if (countryCode == 'us') {
        points += 10000;
      }

      if (isCityType(place)) {
        points += 7000;
      }

      if (query.isNotEmpty) {
        if (name == query) {
          points += 7000;
        } else if (name.startsWith(query)) {
          points += 6000;
        } else if (name.contains(query)) {
          points += 2500;
        }

        if (city == query) {
          points += 6500;
        } else if (city.startsWith(query)) {
          points += 5500;
        } else if (city.contains(query)) {
          points += 2200;
        }

        if (fullName.startsWith(query)) {
          points += 1800;
        } else if (fullName.contains(query)) {
          points += 800;
        }
      }

      final importanceRaw = place['importance'];

      if (importanceRaw is num) {
        points += (importanceRaw.toDouble() * 1000).round();
      } else {
        final importance =
            double.tryParse(importanceRaw?.toString() ?? '') ?? 0;
        points += (importance * 1000).round();
      }

      return points;
    }

    ranked.sort((a, b) {
      final scoreCompare = score(b).compareTo(score(a));

      if (scoreCompare != 0) {
        return scoreCompare;
      }

      return value(a, 'name').compareTo(value(b, 'name'));
    });

    return ranked;
  }

  @override
  Widget build(BuildContext context) {
    final rankedResults = _rankedLocationResults();

    return Scaffold(
      backgroundColor: const Color(0xFF020712),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-.72, -.52),
                  radius: 1.25,
                  colors: [
                    Color(0xFF083566),
                    Color(0xFF07142D),
                    Color(0xFF050918),
                    Color(0xFF13072D),
                  ],
                  stops: [0, .34, .70, 1],
                ),
              ),
            ),
          ),
          Positioned(
            right: -135,
            bottom: -80,
            child: IgnorePointer(
              child: Container(
                width: 360,
                height: 360,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF7A2EFF).withValues(alpha: .34),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 13, 18, 15),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF081831),
                          border: Border.all(
                            color: const Color(0xFF248BFF)
                                .withValues(alpha: .68),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1F7DFF)
                                  .withValues(alpha: .24),
                              blurRadius: 18,
                            ),
                          ],
                        ),
                        child: IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 29,
                          ),
                        ),
                      ),
                      const Expanded(
                        child: Column(
                          children: [
                            Text(
                              'Add Location',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -.4,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              '999 WELLNESS',
                              style: TextStyle(
                                color: Color(0xFF35E9FF),
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Container(
                  height: 1,
                  color: const Color(0xFF38629E).withValues(alpha: .28),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF23E8FF),
                          Color(0xFF58A1FF),
                          Color(0xFF824DFF),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF20E8FF).withValues(alpha: .18),
                          blurRadius: 24,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(1.3),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF091A37),
                        borderRadius: BorderRadius.circular(23),
                      ),
                      child: TextField(
                        controller: searchController,
                        autofocus: true,
                        onChanged: _onSearchChanged,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search cities and places',
                          hintStyle: const TextStyle(color: Color(0xFF9AA8C4)),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Color(0xFF45EBFF),
                            size: 27,
                          ),
                          suffixIcon: searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    searchController.clear();

                                    setState(() {
                                      results = [];
                                      error = null;
                                    });
                                  },
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: Color(0xFFB0BCD3),
                                  ),
                                ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 11),
                  child: _premiumLocationButton(),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                    child: Text(
                      error!,
                      style: const TextStyle(
                        color: Color(0xFFFF7891),
                        fontSize: 11,
                      ),
                    ),
                  ),
                Expanded(
                  child: searching
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF48EFFF),
                          ),
                        )
                      : results.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 96,
                                  height: 96,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const RadialGradient(
                                      colors: [
                                        Color(0xFF153B82),
                                        Color(0xFF101638),
                                      ],
                                    ),
                                    border: Border.all(
                                      color: const Color(0xFF456DFF)
                                          .withValues(alpha: .30),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF435CFF)
                                            .withValues(alpha: .25),
                                        blurRadius: 30,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.location_searching_rounded,
                                    size: 49,
                                    color: Color(0xFF6EB9FF),
                                  ),
                                ),
                                const SizedBox(height: 22),
                                const Text(
                                  'Type a few letters',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 20,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                const Text(
                                  'Example: Lou for Louisville',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFF8796B6),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.fromLTRB(18, 8, 18, 34),
                          itemCount: rankedResults.length,
                          itemBuilder: (context, index) {
                            return _premiumResultTile(rankedResults[index]);
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
