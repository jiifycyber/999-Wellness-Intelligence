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

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF010611);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 68,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: const BoxDecoration(
                color: Color(0xFF020816),
                border: Border(bottom: BorderSide(color: Color(0x3325EDFF))),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF52EAFF),
                      size: 29,
                    ),
                  ),
                  const Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Music',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '999 WELLNESS SOUND',
                          style: TextStyle(
                            color: Color(0xFFFF55D5),
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: TextField(
                controller: searchController,
                onChanged: (value) {
                  setState(() => query = value);
                },
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search songs, artists or albums',
                  hintStyle: const TextStyle(color: Color(0xFF8693AD)),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Color(0xFF4BEAFF),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF07152B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: Color(0xFF294D79)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: Color(0xFF294D79)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: Color(0xFF32E8FF)),
                  ),
                ),
              ),
            ),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : visibleTracks.isEmpty
                  ? const Center(
                      child: Text(
                        'No music available yet.',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                      itemCount: visibleTracks.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final track = visibleTracks[index];
                        final artwork = _artworkUrl(track);
                        final id = track['id']?.toString() ?? '';

                        final playing = playingId == id;

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF07172F), Color(0xFF101039)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF425E92)),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF713EFF)
                                    .withValues(alpha: .12),
                                blurRadius: 18,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  width: 76,
                                  height: 76,
                                  color: const Color(0xFF111A32),
                                  child: artwork.isEmpty
                                      ? const Icon(
                                          Icons.music_note_rounded,
                                          color: Color(0xFFFF55D5),
                                          size: 32,
                                        )
                                      : Image.network(
                                          artwork,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) {
                                            return const Icon(
                                              Icons.music_note_rounded,
                                              color: Color(0xFFFF55D5),
                                              size: 32,
                                            );
                                          },
                                        ),
                                ),
                              ),
                              const SizedBox(width: 13),
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
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      track['artist_name']?.toString() ?? '',
                                      style: const TextStyle(
                                        color: Color(0xFF55E9FF),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 7),
                                    Row(
                                      children: [
                                        InkWell(
                                          onTap: () {
                                            _togglePreview(track);
                                          },
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 11,
                                              vertical: 7,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF0B2548),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  playing
                                                      ? Icons.pause_rounded
                                                      : Icons
                                                            .play_arrow_rounded,
                                                  color: const Color(
                                                    0xFFFF5DD7,
                                                  ),
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  playing ? 'Pause' : 'Preview',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        FilledButton(
                                          onPressed: () {
                                            player.stop();
                                            Navigator.of(context).pop(track);
                                          },
                                          style: FilledButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF7148FF,
                                            ),
                                            foregroundColor: Colors.white,
                                          ),
                                          child: const Text(
                                            'Add',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
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
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
