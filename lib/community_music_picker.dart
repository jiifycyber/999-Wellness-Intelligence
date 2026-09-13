import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommunityMusicPicker extends StatefulWidget {
  const CommunityMusicPicker({super.key});

  @override
  State<CommunityMusicPicker> createState() => _CommunityMusicPickerState();
}

class _CommunityMusicPickerState extends State<CommunityMusicPicker> {
  final TextEditingController searchController = TextEditingController();
  final AudioPlayer player = AudioPlayer();

  bool loading = true;
  String playingId = '';
  String query = '';

  List<Map<String, dynamic>> tracks = [];

  @override
  void initState() {
    super.initState();

    _loadTracks();

    player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() => playingId = '');
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    player.dispose();
    super.dispose();
  }

  Future<void> _loadTracks() async {
    try {
      final rows = await Supabase.instance.client
          .from('music_tracks')
          .select(
            'id, artist_name, title, featured_artist, album_name, '
            'release_type, duration_seconds, audio_path, artwork_path, '
            'spotify_url, distrokid_url, explicit, featured',
          )
          .eq('active', true)
          .order('featured', ascending: false)
          .order('created_at');

      if (!mounted) return;

      setState(() {
        tracks = (rows as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();

        loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() => loading = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to load music: $error')));
    }
  }

  String _artworkUrl(Map<String, dynamic> track) {
    final path = track['artwork_path']?.toString().trim() ?? '';

    if (path.isEmpty) return '';

    return Supabase.instance.client.storage
        .from('music-artwork')
        .getPublicUrl(path);
  }

  String _audioUrl(Map<String, dynamic> track) {
    final path = track['audio_path']?.toString().trim() ?? '';

    if (path.isEmpty) return '';

    return Supabase.instance.client.storage
        .from('music-audio')
        .getPublicUrl(path);
  }

  String _title(Map<String, dynamic> track) {
    final title = track['title']?.toString() ?? '';
    final feature = track['featured_artist']?.toString().trim() ?? '';

    if (feature.isEmpty) return title;

    return '$title (feat. $feature)';
  }

  Future<void> _togglePreview(Map<String, dynamic> track) async {
    final id = track['id']?.toString() ?? '';
    final url = _audioUrl(track);

    if (id.isEmpty || url.isEmpty) return;

    if (playingId == id) {
      await player.pause();

      if (mounted) {
        setState(() => playingId = '');
      }

      return;
    }

    await player.stop();
    await player.play(UrlSource(url));

    if (mounted) {
      setState(() => playingId = id);
    }
  }

  List<Map<String, dynamic>> get visibleTracks {
    final needle = query.trim().toLowerCase();

    if (needle.isEmpty) return tracks;

    return tracks.where((track) {
      final artist = track['artist_name']?.toString().toLowerCase() ?? '';

      final title = track['title']?.toString().toLowerCase() ?? '';

      final feature = track['featured_artist']?.toString().toLowerCase() ?? '';

      final album = track['album_name']?.toString().toLowerCase() ?? '';

      return artist.contains(needle) ||
          title.contains(needle) ||
          feature.contains(needle) ||
          album.contains(needle);
    }).toList();
  }

  Widget _glowCloseButton() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFF153466), Color(0xFF07162D)],
        ),
        border: Border.all(
          color: const Color(0xFF1B9BFF).withValues(alpha: .7),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF167DFF).withValues(alpha: .25),
            blurRadius: 18,
          ),
        ],
      ),
      child: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 29),
      ),
    );
  }

  Widget _searchField() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF20E7FF), Color(0xFF3E87FF), Color(0xFF7F42FF)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16E1FF).withValues(alpha: .22),
            blurRadius: 24,
          ),
        ],
      ),
      padding: const EdgeInsets.all(1.4),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF081934),
          borderRadius: BorderRadius.circular(23),
        ),
        child: TextField(
          controller: searchController,
          onChanged: (value) {
            setState(() => query = value);
          },
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
          decoration: const InputDecoration(
            hintText: 'Search songs, artists or albums',
            hintStyle: TextStyle(
              color: Color(0xFF9AA8C5),
              fontWeight: FontWeight.w600,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: Color(0xFF41EBFF),
              size: 27,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 17, vertical: 19),
          ),
        ),
      ),
    );
  }

  Widget _trackCard(Map<String, dynamic> track) {
    final artwork = _artworkUrl(track);
    final id = track['id']?.toString() ?? '';
    final playing = playingId == id;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF16E2FF), Color(0xFF395BFF), Color(0xFF963CFF)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF20DBFF).withValues(alpha: .18),
            blurRadius: 28,
          ),
          BoxShadow(
            color: const Color(0xFF8A3CFF).withValues(alpha: .16),
            blurRadius: 28,
          ),
        ],
      ),
      padding: const EdgeInsets.all(1.2),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF082142), Color(0xFF101A4B), Color(0xFF251353)],
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(19),
                border: Border.all(
                  color: const Color(0xFF3CE6FF).withValues(alpha: .55),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF06D7FF).withValues(alpha: .20),
                    blurRadius: 18,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: artwork.isEmpty
                    ? const ColoredBox(
                        color: Color(0xFF111A32),
                        child: Icon(
                          Icons.music_note_rounded,
                          color: Color(0xFFFF55D5),
                          size: 34,
                        ),
                      )
                    : Image.network(
                        artwork,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                          return const ColoredBox(
                            color: Color(0xFF111A32),
                            child: Icon(
                              Icons.music_note_rounded,
                              color: Color(0xFFFF55D5),
                              size: 34,
                            ),
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _title(track),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15.5,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    track['artist_name']?.toString() ?? '',
                    style: const TextStyle(
                      color: Color(0xFF24E8FF),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 11),
                  Wrap(
                    spacing: 9,
                    runSpacing: 8,
                    children: [
                      InkWell(
                        onTap: () => _togglePreview(track),
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF07162F),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFF1DEAFF)),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF20E8FF)
                                    .withValues(alpha: .16),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 23,
                                height: 23,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFFFF38C8),
                                      Color(0xFF7C3EFF),
                                    ],
                                  ),
                                ),
                                child: Icon(
                                  playing
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 7),
                              Text(
                                playing ? 'Pause' : 'Preview',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          player.stop();
                          Navigator.of(context).pop(track);
                        },
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6849FF), Color(0xFFB52AFF)],
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: .25),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFAB28FF)
                                    .withValues(alpha: .35),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                          child: const Text(
                            'Add',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF010611),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-.75, -.55),
                  radius: 1.25,
                  colors: [
                    Color(0xFF073463),
                    Color(0xFF07132A),
                    Color(0xFF05091A),
                    Color(0xFF100626),
                  ],
                  stops: [0, .35, .72, 1],
                ),
              ),
            ),
          ),
          Positioned(
            right: -120,
            bottom: -70,
            child: IgnorePointer(
              child: Container(
                width: 340,
                height: 340,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF7628FF).withValues(alpha: .32),
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
                      _glowCloseButton(),
                      const Expanded(
                        child: Column(
                          children: [
                            Text(
                              'Music',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -.5,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              '999 WELLNESS SOUND',
                              style: TextStyle(
                                color: Color(0xFF2BE8FF),
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
                  color: const Color(0xFF2B5D9D).withValues(alpha: .30),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 11),
                  child: _searchField(),
                ),
                Expanded(
                  child: loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF39E9FF),
                          ),
                        )
                      : visibleTracks.isEmpty
                      ? const Center(
                          child: Text(
                            'No music available yet.',
                            style: TextStyle(
                              color: Color(0xFF8F9DBA),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(18, 10, 18, 34),
                          itemCount: visibleTracks.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 13),
                          itemBuilder: (context, index) {
                            return _trackCard(visibleTracks[index]);
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
