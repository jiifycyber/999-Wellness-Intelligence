import 'community_post_options.dart';
import 'community_music_picker.dart';
import 'community_location_picker.dart';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'community_member_profile.dart';
import 'premium_share_sheet.dart';

class CommunityFeedScreen extends StatefulWidget {
  const CommunityFeedScreen({
    super.key,
    this.onSearch,
    this.onNotifications,
    this.onMessages,
    this.onProfile,
    this.embedded = false,
    this.openComposerOnStart = false,
  });

  final VoidCallback? onSearch;
  final VoidCallback? onNotifications;
  final VoidCallback? onMessages;
  final VoidCallback? onProfile;
  final bool embedded;
  final bool openComposerOnStart;

  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen> {
  final TextEditingController postController = TextEditingController();

  bool loading = true;
  bool posting = false;
  int selectedTab = 0;

  String currentName = '999 Member';
  String currentRole = 'customer';
  String currentPhoto = '';

  PlatformFile? pendingImage;

  Map<String, dynamic>? selectedMusicTrack;

  List<Map<String, dynamic>> selectedTaggedPeople = [];
  String? selectedLocationName;
  String? selectedFeelingActivity;

  final AudioPlayer feedMusicPlayer = AudioPlayer();
  String playingMusicPostId = '';

  final Map<String, Map<String, String>> linkPreviewCache = {};

  List<Map<String, dynamic>> posts = [];
  List<Map<String, dynamic>> liveSessions = [];
  List<Map<String, dynamic>> communityMembers = [];

  Set<String> followingIds = {};
  Set<String> likedPostIds = {};

  Map<String, int> likeCounts = {};
  Map<String, int> commentCounts = {};
  Map<String, int> followerCounts = {};

  static const Color bg = Color(0xFF01050F);
  static const Color panel = Color(0xFF071D42);
  static const Color panel2 = Color(0xFF092149);
  static const Color purple = Color(0xFFA23CFF);
  static const Color purple2 = Color(0xFFD43CFF);
  static const Color cyan = Color(0xFF25EDFF);
  static const Color pink = Color(0xFFFF4D87);

  @override
  void initState() {
    super.initState();

    feedMusicPlayer.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() => playingMusicPostId = '');
    });

    _initialize().then((_) {
      if (!mounted || !widget.openComposerOnStart) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _openMobileComposer();
        }
      });
    });
  }

  @override
  void dispose() {
    postController.dispose();
    feedMusicPlayer.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    await _loadIdentity();
    await _syncCommunityProfile();
    await _loadFeed();
  }

  Future<void> _syncCommunityProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      await Supabase.instance.client.from('community_member_profiles').upsert({
        'user_id': user.id,
        'display_name': currentName.trim().isEmpty
            ? '999 Member'
            : currentName.trim(),
        'role': currentRole == 'provider' ? 'provider' : 'customer',
        'photo_url': currentPhoto.trim().isEmpty ? null : currentPhoto.trim(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id');
    } catch (_) {}
  }

  Future<void> _loadIdentity() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('full_name, role')
          .eq('id', user.id)
          .maybeSingle();

      final role = profile?['role']?.toString() ?? 'customer';
      var name = profile?['full_name']?.toString().trim() ?? '';
      var photo = '';

      if (role == 'provider') {
        final provider = await Supabase.instance.client
            .from('provider_profiles')
            .select('full_name, professional_name, profile_photo_url')
            .eq('id', user.id)
            .maybeSingle();

        final professional =
            provider?['professional_name']?.toString().trim() ?? '';

        final full = provider?['full_name']?.toString().trim() ?? '';

        if (professional.isNotEmpty) {
          name = professional;
        } else if (full.isNotEmpty) {
          name = full;
        }

        photo = provider?['profile_photo_url']?.toString() ?? '';
      }

      if (role != 'provider') {
        try {
          final customer = await Supabase.instance.client
              .from('community_member_profiles')
              .select('display_name, photo_url, photo_path')
              .eq('user_id', user.id)
              .maybeSingle();

          final customerName =
              customer?['display_name']?.toString().trim() ?? '';

          if (customerName.isNotEmpty) {
            name = customerName;
          }

          photo = customer?['photo_url']?.toString().trim() ?? '';

          final photoPath = customer?['photo_path']?.toString().trim() ?? '';

          if (photoPath.isNotEmpty) {
            try {
              photo = await Supabase.instance.client.storage
                  .from('community-profile-media')
                  .createSignedUrl(photoPath, 3600);
            } catch (_) {}
          }
        } catch (_) {}
      }

      if (name.isEmpty) {
        name = user.userMetadata?['full_name']?.toString() ?? '999 Member';
      }

      if (!mounted) return;

      setState(() {
        currentName = name;
        currentRole = role == 'provider' ? 'provider' : 'customer';
        currentPhoto = photo;
      });
    } catch (_) {}
  }

  Future<void> _loadFeed() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    if (mounted) {
      setState(() => loading = true);
    }

    try {
      final postRows = await Supabase.instance.client
          .from('community_posts')
          .select(
            'id, author_id, author_name, author_role, author_photo_url, '
            'body, media_path, media_type, '
            'music_track_id, music_title, music_artist, '
            'music_featured_artist, music_album, '
            'music_artwork_path, music_audio_path, music_spotify_url, '
            'tagged_people, location_name, feeling_activity, '
            'created_at',
          )
          .order('created_at', ascending: false);

      final likeRows = await Supabase.instance.client
          .from('community_likes')
          .select('post_id, user_id');

      final commentRows = await Supabase.instance.client
          .from('community_comments')
          .select('post_id');

      final followRows = await Supabase.instance.client
          .from('community_follows')
          .select('follower_id, following_id');

      final liveRows = await Supabase.instance.client
          .from('community_live_sessions')
          .select(
            'id, host_id, host_name, host_role, host_photo_url, '
            'title, status, viewer_count, started_at, created_at',
          )
          .eq('status', 'live')
          .order('created_at', ascending: false);

      final memberRows = await Supabase.instance.client
          .from('community_member_profiles')
          .select(
            'user_id, display_name, role, photo_url, photo_path, bio, created_at',
          )
          .order('created_at', ascending: false);

      final latestMemberPhotos = <String, String>{};

      for (final raw in memberRows as List) {
        final member = Map<String, dynamic>.from(raw as Map);

        final memberId = member['user_id']?.toString() ?? '';
        if (memberId.isEmpty) {
          continue;
        }

        var photo = member['photo_url']?.toString().trim() ?? '';
        final path = member['photo_path']?.toString().trim() ?? '';

        if (path.isNotEmpty) {
          try {
            photo = await Supabase.instance.client.storage
                .from('community-profile-media')
                .createSignedUrl(path, 3600);
          } catch (_) {}
        }

        if (photo.isNotEmpty) {
          latestMemberPhotos[memberId] = photo;
        }
      }

      final mappedPosts = (postRows as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();

      for (final post in mappedPosts) {
        final authorId = post['author_id']?.toString() ?? '';
        final latestPhoto = latestMemberPhotos[authorId] ?? '';

        if (latestPhoto.isNotEmpty) {
          post['author_photo_url'] = latestPhoto;
        }
      }

      for (final post in mappedPosts) {
        final mediaPath = post['media_path']?.toString().trim() ?? '';

        if (mediaPath.isNotEmpty) {
          try {
            post['_media_url'] = await Supabase.instance.client.storage
                .from('feed-media')
                .createSignedUrl(mediaPath, 3600);
          } catch (_) {
            post['_media_url'] = '';
          }
        }

        final artworkPath = post['music_artwork_path']?.toString().trim() ?? '';
        final audioPath = post['music_audio_path']?.toString().trim() ?? '';

        if (artworkPath.isNotEmpty) {
          post['_music_artwork_url'] = Supabase.instance.client.storage
              .from('music-artwork')
              .getPublicUrl(artworkPath);
        }

        if (audioPath.isNotEmpty) {
          post['_music_audio_url'] = Supabase.instance.client.storage
              .from('music-audio')
              .getPublicUrl(audioPath);
        }
      }

      final likes = <String, int>{};
      final mine = <String>{};

      for (final raw in likeRows as List) {
        final row = Map<String, dynamic>.from(raw as Map);
        final postId = row['post_id']?.toString() ?? '';

        likes[postId] = (likes[postId] ?? 0) + 1;

        if (row['user_id']?.toString() == user.id) {
          mine.add(postId);
        }
      }

      final comments = <String, int>{};

      for (final raw in commentRows as List) {
        final row = Map<String, dynamic>.from(raw as Map);
        final postId = row['post_id']?.toString() ?? '';

        comments[postId] = (comments[postId] ?? 0) + 1;
      }

      final following = <String>{};
      final followers = <String, int>{};

      for (final raw in followRows as List) {
        final row = Map<String, dynamic>.from(raw as Map);

        final followerId = row['follower_id']?.toString() ?? '';

        final followingId = row['following_id']?.toString() ?? '';

        followers[followingId] = (followers[followingId] ?? 0) + 1;

        if (followerId == user.id) {
          following.add(followingId);
        }
      }

      if (!mounted) return;

      setState(() {
        posts = mappedPosts;

        liveSessions = (liveRows as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();

        communityMembers = (memberRows as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();

        likeCounts = likes;
        commentCounts = comments;
        likedPostIds = mine;
        followingIds = following;
        followerCounts = followers;
        loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() => loading = false);

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Unable to load Feed: $error')));
    }
  }

  Future<void> _pickPhoto() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'jpg',
        'jpeg',
        'png',
        'webp',
        'gif',
        'heic',
        'heif',
      ],
      allowMultiple: false,
    );

    if (files.isEmpty) return;

    setState(() {
      pendingImage = files.first;
    });
  }

  String _safeName(String value) {
    final safe = value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

    return safe.isEmpty ? 'feed_image.jpg' : safe;
  }

  Future<List<Map<String, dynamic>>?> _pickTaggedPeople(
    BuildContext parentContext,
  ) async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';

    final available = communityMembers.where((person) {
      final id = person['user_id']?.toString() ?? '';
      return id.isNotEmpty && id != currentUserId;
    }).toList();

    final selectedIds = selectedTaggedPeople
        .map((person) => person['user_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    final searchController = TextEditingController();

    final result = await showModalBottomSheet<List<Map<String, dynamic>>>(
      context: parentContext,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: .72),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final query = searchController.text.trim().toLowerCase();

            final visible = available.where((person) {
              if (query.isEmpty) return true;

              final name =
                  person['display_name']?.toString().toLowerCase() ??
                  person['full_name']?.toString().toLowerCase() ??
                  '';

              final role = person['role']?.toString().toLowerCase() ?? '';

              return name.contains(query) || role.contains(query);
            }).toList();

            return FractionallySizedBox(
              heightFactor: .76,
              child: Container(
                margin: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF19E4FF),
                      Color(0xFF5263FF),
                      Color(0xFFB237FF),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF22DFFF).withValues(alpha: .25),
                      blurRadius: 32,
                    ),
                    BoxShadow(
                      color: const Color(0xFFA83CFF).withValues(alpha: .22),
                      blurRadius: 32,
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(1.3, 1.3, 1.3, 0),
                child: Container(
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(29),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF071A38),
                        Color(0xFF07142D),
                        Color(0xFF13092F),
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFF6D70DA),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 15, 14, 10),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'TAG PEOPLE',
                                    style: TextStyle(
                                      color: Color(0xFF3CEAFF),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.8,
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'Add people to this post',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 21,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 45,
                              height: 45,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF0C1B3B),
                                border: Border.all(
                                  color: const Color(0xFF3C6FFF)
                                      .withValues(alpha: .65),
                                ),
                              ),
                              child: IconButton(
                                onPressed: () =>
                                    Navigator.of(sheetContext).pop(),
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 4, 18, 13),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF20E5FF),
                                Color(0xFF5369FF),
                                Color(0xFF8D3EFF),
                              ],
                            ),
                          ),
                          padding: const EdgeInsets.all(1.2),
                          child: TextField(
                            controller: searchController,
                            onChanged: (_) => setSheetState(() {}),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFF091A37),
                              hintText: 'Search people...',
                              hintStyle: const TextStyle(
                                color: Color(0xFF9DAAC6),
                              ),
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                color: Color(0xFF44EAFF),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(21),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(21),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(21),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: visible.isEmpty
                            ? const Center(
                                child: Text(
                                  'No community members found.',
                                  style: TextStyle(
                                    color: Color(0xFF8D9BB8),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  4,
                                  18,
                                  16,
                                ),
                                itemCount: visible.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final person = visible[index];

                                  final id =
                                      person['user_id']?.toString() ?? '';

                                  final name =
                                      person['display_name']
                                          ?.toString()
                                          .trim() ??
                                      person['full_name']?.toString().trim() ??
                                      '999 Member';

                                  final role =
                                      person['role']?.toString() ??
                                      'Community member';

                                  final checked = selectedIds.contains(id);

                                  return InkWell(
                                    onTap: () {
                                      setSheetState(() {
                                        if (checked) {
                                          selectedIds.remove(id);
                                        } else {
                                          selectedIds.add(id);
                                        }
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF0A2548),
                                            Color(0xFF121B47),
                                            Color(0xFF21124E),
                                          ],
                                        ),
                                        border: Border.all(
                                          color: checked
                                              ? const Color(0xFF40E9FF)
                                              : const Color(0xFF485CC1)
                                                    .withValues(alpha: .55),
                                        ),
                                        boxShadow: checked
                                            ? [
                                                BoxShadow(
                                                  color: const Color(0xFF31DEFF)
                                                      .withValues(alpha: .18),
                                                  blurRadius: 20,
                                                ),
                                              ]
                                            : null,
                                      ),
                                      padding: const EdgeInsets.all(13),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 50,
                                            height: 50,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFF694CFF),
                                                  Color(0xFFAF3DFF),
                                                  Color(0xFF20CFFF),
                                                ],
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(0xFF6A47FF)
                                                      .withValues(alpha: .28),
                                                  blurRadius: 16,
                                                ),
                                              ],
                                            ),
                                            child: Center(
                                              child: Text(
                                                name.isEmpty
                                                    ? '?'
                                                    : name
                                                          .substring(0, 1)
                                                          .toUpperCase(),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 13),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  name,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  role,
                                                  style: const TextStyle(
                                                    color: Color(0xFFA8B4CE),
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 180,
                                            ),
                                            width: 29,
                                            height: 29,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(7),
                                              gradient: checked
                                                  ? const LinearGradient(
                                                      colors: [
                                                        Color(0xFF23E5FF),
                                                        Color(0xFF7257FF),
                                                      ],
                                                    )
                                                  : null,
                                              border: Border.all(
                                                color: checked
                                                    ? Colors.white
                                                    : const Color(0xFF9DB7E5),
                                                width: 1.6,
                                              ),
                                            ),
                                            child: checked
                                                ? const Icon(
                                                    Icons.check_rounded,
                                                    color: Colors.white,
                                                    size: 20,
                                                  )
                                                : null,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
                        child: InkWell(
                          onTap: () {
                            final selected = available.where((person) {
                              final id = person['user_id']?.toString() ?? '';

                              return selectedIds.contains(id);
                            }).toList();

                            Navigator.of(sheetContext).pop(selected);
                          },
                          borderRadius: BorderRadius.circular(28),
                          child: Container(
                            width: double.infinity,
                            height: 56,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFFF31C5),
                                  Color(0xFF8B39FF),
                                  Color(0xFF514EFF),
                                ],
                              ),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: .45),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFB830FF)
                                      .withValues(alpha: .35),
                                  blurRadius: 24,
                                ),
                              ],
                            ),
                            child: Text(
                              selectedIds.isEmpty
                                  ? 'Done'
                                  : 'Done (${selectedIds.length})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    searchController.dispose();

    return result;
  }

  Future<String?> _pickPostLocation(BuildContext parentContext) async {
    FocusScope.of(parentContext).unfocus();

    final place = await Navigator.of(parentContext).push<Map<String, dynamic>>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const CommunityLocationPicker(),
      ),
    );

    if (place == null) {
      return null;
    }

    String valueFor(List<String> keys) {
      for (final key in keys) {
        final value = place[key]?.toString().trim() ?? '';
        if (value.isNotEmpty) {
          return value;
        }
      }
      return '';
    }

    final displayName = valueFor([
      'display_name',
      'displayName',
      'formatted_address',
      'formattedAddress',
    ]);

    final name = valueFor([
      'name',
      'title',
      'place_name',
      'placeName',
      'label',
    ]);

    final city = valueFor(['city', 'locality', 'town', 'village']);

    final state = valueFor(['state', 'region', 'state_code', 'stateCode']);

    if (name.isNotEmpty) {
      final pieces = <String>[name];

      if (city.isNotEmpty && !name.toLowerCase().contains(city.toLowerCase())) {
        pieces.add(city);
      }

      if (state.isNotEmpty &&
          !name.toLowerCase().contains(state.toLowerCase()) &&
          !city.toLowerCase().contains(state.toLowerCase())) {
        pieces.add(state);
      }

      return pieces.join(', ');
    }

    if (displayName.isNotEmpty) {
      return displayName;
    }

    if (city.isNotEmpty && state.isNotEmpty) {
      return '$city, $state';
    }

    if (city.isNotEmpty) {
      return city;
    }

    if (state.isNotEmpty) {
      return state;
    }

    return null;
  }

  Future<String?> _pickFeelingActivity(BuildContext parentContext) async {
    const options = [
      ('Blessed', Icons.auto_awesome_rounded, Color(0xFF44E8FF)),
      ('Happy', Icons.sentiment_very_satisfied_rounded, Color(0xFFFFD84D)),
      ('Grateful', Icons.eco_rounded, Color(0xFF32E891)),
      ('Excited', Icons.bolt_rounded, Color(0xFFB05CFF)),
      ('Loved', Icons.favorite_rounded, Color(0xFFFF4F8E)),
      ('Motivated', Icons.bar_chart_rounded, Color(0xFF32DFFF)),
      ('Relaxed', Icons.spa_rounded, Color(0xFF9F65FF)),
      ('Celebrating', Icons.celebration_rounded, Color(0xFFFF7ECF)),
      ('Working out', Icons.fitness_center_rounded, Color(0xFF4FE7D6)),
      ('Traveling', Icons.flight_takeoff_rounded, Color(0xFF68A8FF)),
      ('Listening to music', Icons.headphones_rounded, Color(0xFFFF52D0)),
      ('Enjoying life', Icons.wb_sunny_rounded, Color(0xFFFFC44D)),
      ('Focused', Icons.center_focus_strong_rounded, Color(0xFF46E8FF)),
      ('Inspired', Icons.lightbulb_rounded, Color(0xFFA95AFF)),
      ('Thankful', Icons.volunteer_activism_rounded, Color(0xFFFF6E9C)),
    ];

    return showModalBottomSheet<String>(
      context: parentContext,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: .72),
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: .90,
          child: Container(
            margin: const EdgeInsets.fromLTRB(8, 0, 8, 6),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF18E3FF),
                  Color(0xFF5261FF),
                  Color(0xFFAA38FF),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1BE1FF).withValues(alpha: .20),
                  blurRadius: 30,
                ),
                BoxShadow(
                  color: const Color(0xFFA63CFF).withValues(alpha: .20),
                  blurRadius: 30,
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(1.3, 1.3, 1.3, 0),
            child: Container(
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(29)),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF071C3C),
                    Color(0xFF07142F),
                    Color(0xFF140930),
                  ],
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFF646DD0),
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 11),
                    child: Row(
                      children: [
                        Icon(
                          Icons.sentiment_satisfied_alt_rounded,
                          color: Color(0xFF42EFE8),
                          size: 31,
                        ),
                        SizedBox(width: 11),
                        Text(
                          'FEELING / ACTIVITY',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 18),
                    color: const Color(0xFF2FE5FF).withValues(alpha: .20),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 11, 18, 12),
                      itemCount: options.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 7),
                      itemBuilder: (context, index) {
                        final option = options[index];

                        final value = option.$1;
                        final icon = option.$2;
                        final color = option.$3;

                        final selected = selectedFeelingActivity == value;

                        return InkWell(
                          onTap: () => Navigator.of(sheetContext).pop(value),
                          borderRadius: BorderRadius.circular(19),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(11, 8, 13, 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(19),
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF0A2850),
                                  Color(0xFF111D49),
                                  Color(0xFF241354),
                                ],
                              ),
                              border: Border.all(
                                color: selected
                                    ? const Color(0xFF4CEBFF)
                                    : const Color(0xFF425ED1)
                                          .withValues(alpha: .65),
                              ),
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF3DE6FF)
                                            .withValues(alpha: .18),
                                        blurRadius: 20,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: color.withValues(alpha: .16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: color.withValues(alpha: .20),
                                        blurRadius: 16,
                                      ),
                                    ],
                                  ),
                                  child: Icon(icon, color: color, size: 25),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    value,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                Icon(
                                  selected
                                      ? Icons.check_circle_rounded
                                      : Icons.chevron_right_rounded,
                                  color: selected
                                      ? const Color(0xFF52F0DF)
                                      : const Color(0xFF7CBFFF),
                                  size: 26,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 18),
                    color: Colors.white.withValues(alpha: .08),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.of(sheetContext).pop(''),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFFF59D1),
                    ),
                    label: const Text(
                      'Remove feeling / activity',
                      style: TextStyle(
                        color: Color(0xFFFF59D1),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _createPost() async {
    final user = Supabase.instance.client.auth.currentUser;
    final body = postController.text.trim();

    if (user == null || posting) return;

    if (body.isEmpty && pendingImage == null && selectedMusicTrack == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Write something, select a photo, or add music first.'),
        ),
      );
      return;
    }

    setState(() => posting = true);

    String? mediaPath;

    try {
      if (pendingImage != null) {
        final file = pendingImage!;
        final bytes = await file.readAsBytes();

        if (bytes.length > 15728640) {
          throw Exception('Feed photos must be 15 MB or smaller.');
        }

        final stamp = DateTime.now().microsecondsSinceEpoch;

        mediaPath = '${user.id}/posts/${stamp}_${_safeName(file.name)}';

        await Supabase.instance.client.storage
            .from('feed-media')
            .uploadBinary(
              mediaPath,
              bytes,
              fileOptions: const FileOptions(upsert: false),
            );
      }

      final music = selectedMusicTrack;

      await Supabase.instance.client.from('community_posts').insert({
        'author_id': user.id,
        'author_name': currentName,
        'author_role': currentRole,
        'author_photo_url': currentPhoto.trim().isEmpty ? null : currentPhoto,
        'body': body,
        'media_path': mediaPath,
        'media_type': mediaPath == null ? null : 'image',
        'music_track_id': music?['id'],
        'music_title': music?['title'],
        'music_artist': music?['artist_name'],
        'music_featured_artist': music?['featured_artist'],
        'music_album': music?['album_name'],
        'music_artwork_path': music?['artwork_path'],
        'music_audio_path': music?['audio_path'],
        'music_spotify_url': music?['spotify_url'],
        'tagged_people': selectedTaggedPeople.map((person) {
          final name =
              person['display_name']?.toString().trim() ??
              person['full_name']?.toString().trim() ??
              '999 Member';

          return <String, dynamic>{
            'user_id': person['user_id']?.toString() ?? '',
            'name': name,
          };
        }).toList(),
        'location_name': selectedLocationName?.trim().isEmpty == true
            ? null
            : selectedLocationName?.trim(),
        'feeling_activity': selectedFeelingActivity?.trim().isEmpty == true
            ? null
            : selectedFeelingActivity?.trim(),
      });

      postController.clear();

      if (mounted) {
        setState(() {
          pendingImage = null;
          selectedMusicTrack = null;
          selectedTaggedPeople = [];
          selectedLocationName = null;
          selectedFeelingActivity = null;
        });
      }

      await _loadFeed();
    } catch (error) {
      if (mediaPath != null) {
        try {
          await Supabase.instance.client.storage.from('feed-media').remove([
            mediaPath,
          ]);
        } catch (_) {}
      }

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to create post: $error')));
    } finally {
      if (mounted) {
        setState(() => posting = false);
      }
    }
  }

  Future<void> _toggleLike(String postId) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final wasLiked = likedPostIds.contains(postId);
    final previousCount = likeCounts[postId] ?? 0;

    setState(() {
      if (wasLiked) {
        likedPostIds.remove(postId);
        likeCounts[postId] = previousCount > 0 ? previousCount - 1 : 0;
      } else {
        likedPostIds.add(postId);
        likeCounts[postId] = previousCount + 1;
      }
    });

    try {
      if (wasLiked) {
        await Supabase.instance.client
            .from('community_likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', user.id);
      } else {
        await Supabase.instance.client.from('community_likes').insert({
          'post_id': postId,
          'user_id': user.id,
        });
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        if (wasLiked) {
          likedPostIds.add(postId);
        } else {
          likedPostIds.remove(postId);
        }

        likeCounts[postId] = previousCount;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to update like. Please try again.'),
        ),
      );
    }
  }

  Future<void> _toggleFollow(String accountId) async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null || accountId == user.id) return;

    try {
      if (followingIds.contains(accountId)) {
        await Supabase.instance.client
            .from('community_follows')
            .delete()
            .eq('follower_id', user.id)
            .eq('following_id', accountId);
      } else {
        await Supabase.instance.client.from('community_follows').insert({
          'follower_id': user.id,
          'following_id': accountId,
        });
      }

      await _loadFeed();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update follow: $error')),
      );
    }
  }

  Future<void> _openComments(Map<String, dynamic> post) async {
    final postId = post['id']?.toString() ?? '';

    if (postId.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF090E1B),
      builder: (_) {
        return _FeedCommentsSheet(
          postId: postId,
          authorName: currentName,
          authorRole: currentRole,
        );
      },
    );

    await _loadFeed();
  }

  Future<void> _goLiveSetup() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final titleController = TextEditingController(text: '$currentName is live');

    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0C1426),
          title: const Row(
            children: [
              Icon(Icons.sensors_rounded, color: pink),
              SizedBox(width: 10),
              Text(
                'Go Live',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          content: TextField(
            controller: titleController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Live title',
              hintText: 'What are you going live about?',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop(titleController.text.trim());
              },
              icon: const Icon(Icons.videocam_rounded),
              label: const Text('Continue'),
            ),
          ],
        );
      },
    );

    titleController.dispose();

    if (title == null || title.isEmpty) return;

    try {
      await Supabase.instance.client.from('community_live_sessions').insert({
        'host_id': user.id,
        'host_name': currentName,
        'host_role': currentRole,
        'host_photo_url': currentPhoto.trim().isEmpty ? null : currentPhoto,
        'title': title,
        'room_name':
            'wellness_${user.id}_${DateTime.now().millisecondsSinceEpoch}',
        'status': 'setup',
        'stream_provider': 'unconfigured',
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Live room ready. Camera broadcasting will be connected next.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to prepare live room: $error')),
      );
    }
  }

  List<Map<String, dynamic>> get visiblePosts {
    if (selectedTab == 1) {
      return posts.where((post) {
        final author = post['author_id']?.toString() ?? '';

        return followingIds.contains(author);
      }).toList();
    }

    return posts;
  }

  String _timeAgo(dynamic value) {
    if (value == null) return '';

    final date = DateTime.tryParse(value.toString());
    if (date == null) return '';

    final difference = DateTime.now().difference(date.toLocal());

    if (difference.inMinutes < 1) {
      return 'Now';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours}h';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays}d';
    }

    return '${date.month}/${date.day}/${date.year}';
  }

  Widget _avatar(
    String photo,
    String name, {
    double size = 46,
    VoidCallback? onTap,
  }) {
    final initial = name.trim().isEmpty ? '9' : name.trim()[0].toUpperCase();

    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFD12CFF), Color(0xFF5A55FF), Color(0xFF18E6FF)],
        ),
        border: Border.all(color: const Color(0xFF48F0FF), width: 1.8),
        boxShadow: [
          BoxShadow(color: purple.withValues(alpha: .42), blurRadius: 22),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: photo.trim().isNotEmpty
          ? Image.network(
              photo,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                );
              },
            )
          : Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
    );

    if (onTap == null) {
      return avatar;
    }

    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(cursor: SystemMouseCursors.click, child: avatar),
    );
  }

  void _openMemberProfile({
    required String userId,
    required String name,
    required String role,
    required String photo,
  }) {
    if (userId.isEmpty) return;

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => CommunityMemberProfileScreen(
              userId: userId,
              fallbackName: name,
              fallbackRole: role,
              fallbackPhoto: photo,
            ),
          ),
        )
        .then((_) {
          _loadFeed();
        });
  }

  Widget _glassPanel({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0A2A61).withValues(alpha: .97),
            const Color(0xFF040914).withValues(alpha: .99),
          ],
        ),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(
          color: const Color(0xFF32D7FF).withValues(alpha: .60),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF132C66).withValues(alpha: .24),
            blurRadius: 50,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sidebarItem({
    required IconData icon,
    required String label,
    bool selected = false,
    VoidCallback? onTap,
    String? badge,
    bool dot = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFF17235A).withValues(alpha: .68)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: selected
                  ? Border.all(
                      color: const Color(0xFF655EFF).withValues(alpha: .72),
                    )
                  : null,
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: purple.withValues(alpha: .18),
                        blurRadius: 16,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                if (selected)
                  Container(
                    width: 3,
                    height: 25,
                    margin: const EdgeInsets.only(right: 11),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF58DFFF), Color(0xFF925CFF)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                Icon(
                  icon,
                  size: 20,
                  color: selected
                      ? const Color(0xFF72E3FF)
                      : const Color(0xFFC3CAE0),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFFC3CAE0),
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 11.5,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7137FF), Color(0xFF9E4CFF)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 7,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                if (dot)
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF8C49FF),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 232,
      decoration: BoxDecoration(
        color: const Color(0xFF030918).withValues(alpha: .99),
        border: Border(
          right: BorderSide(
            color: const Color(0xFF29436D).withValues(alpha: .45),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [
                        Color(0xFF8E59FF),
                        Color(0xFF5139EF),
                        Color(0xFF102A62),
                      ],
                    ),
                    border: Border.all(
                      color: const Color(0xFF70BFFF).withValues(alpha: .55),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: purple.withValues(alpha: .28),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.spa_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '999 WELLNESS',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .5,
                          fontSize: 12.5,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Heal - Connect - Evolve',
                        style: TextStyle(
                          color: Color(0xFF8E9FCA),
                          fontSize: 8.2,
                          letterSpacing: .3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 29),
          _sidebarItem(
            icon: Icons.home_outlined,
            label: 'Home',
            onTap: () => Navigator.of(context).pop(),
          ),
          _sidebarItem(
            icon: Icons.dynamic_feed_outlined,
            label: 'Feed',
            selected: true,
            onTap: () {},
          ),
          _sidebarItem(
            icon: Icons.search_rounded,
            label: 'Search',
            onTap: () => Navigator.of(context).pop(),
          ),
          _sidebarItem(
            icon: Icons.calendar_month_outlined,
            label: 'Bookings',
            onTap: () => Navigator.of(context).pop(),
          ),
          _sidebarItem(
            icon: Icons.favorite_border_rounded,
            label: 'Favorites',
            onTap: () => Navigator.of(context).pop(),
          ),
          _sidebarItem(
            icon: Icons.person_outline_rounded,
            label: 'Profile',
            onTap: () => Navigator.of(context).pop(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            child: Container(
              height: 1,
              color: Colors.white.withValues(alpha: .07),
            ),
          ),
          _sidebarItem(
            icon: Icons.auto_awesome_outlined,
            label: 'AI Assistant',
            badge: 'BETA',
            onTap: () => Navigator.of(context).pop(),
          ),
          _sidebarItem(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Messages',
            dot: true,
            onTap: () => Navigator.of(context).pop(),
          ),
          _sidebarItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            onTap: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF21145D), Color(0xFF0C1836)],
                ),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(
                  color: const Color(0xFF5141C9).withValues(alpha: .55),
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFF8C72FF),
                    size: 16,
                  ),
                  SizedBox(height: 13),
                  Text(
                    'A healthier,\nhappier you\n- together.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _communityQuickComposer() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF071B39), Color(0xFF0B1835), Color(0xFF130D31)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF2B6FA8).withValues(alpha: .65),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF19DFFF).withValues(alpha: .08),
            blurRadius: 22,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2.4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF22E9FF),
                  Color(0xFF6754FF),
                  Color(0xFFE348FF),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF644DFF).withValues(alpha: .28),
                  blurRadius: 18,
                ),
              ],
            ),
            child: _avatar(currentPhoto, currentName, size: 42),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: InkWell(
              onTap: _openMobileComposer,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                height: 45,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 15),
                decoration: BoxDecoration(
                  color: const Color(0xFF101D39),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFF3B5487).withValues(alpha: .50),
                  ),
                ),
                child: const Text(
                  "What's on your mind?",
                  style: TextStyle(
                    color: Color(0xFF9CA9C4),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _communityComposerIcon(
            Icons.image_outlined,
            const Color(0xFF36E8FF),
            () {},
          ),
          _communityComposerIcon(
            Icons.music_note_rounded,
            const Color(0xFFFF4CCE),
            () async {
              final track = await Navigator.of(context)
                  .push<Map<String, dynamic>>(
                    MaterialPageRoute(
                      fullscreenDialog: true,
                      builder: (_) => const CommunityMusicPicker(),
                    ),
                  );

              if (track == null || !mounted) return;

              setState(() {
                selectedMusicTrack = Map<String, dynamic>.from(track);
              });

              _openMobileComposer();
            },
          ),
        ],
      ),
    );
  }

  Widget _communityComposerIcon(
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 38,
        height: 38,
        margin: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: .10),
          border: Border.all(color: color.withValues(alpha: .32)),
        ),
        child: Icon(icon, color: color, size: 21),
      ),
    );
  }

  Widget _storiesAndReelsSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 2, 12, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0xFF050C1B),
        border: Border.all(
          color: const Color(0xFF173E68).withValues(alpha: .70),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 11, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: _storiesReelsTab(
                    label: 'Stories',
                    selected: true,
                    color: const Color(0xFF27E9FF),
                    onTap: () {},
                  ),
                ),
                Expanded(
                  child: _storiesReelsTab(
                    label: 'Reels',
                    selected: false,
                    color: const Color(0xFFFF4DD3),
                    onTap: () {},
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          SizedBox(
            height: 205,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              children: [
                _createStoryCard(),
                _storyPreviewCard(
                  name: 'Your Story',
                  subtitle: '999 WELLNESS',
                  imageUrl: currentPhoto,
                  ringColor: const Color(0xFF28E9FF),
                  isOwn: true,
                ),
                _storyPreviewCard(
                  name: 'Wellness',
                  subtitle: 'HEALTHY',
                  imageUrl: '',
                  ringColor: const Color(0xFFFF4BCF),
                  icon: Icons.spa_rounded,
                ),
                _storyPreviewCard(
                  name: 'Mindset',
                  subtitle: 'INSPIRE',
                  imageUrl: '',
                  ringColor: const Color(0xFF7459FF),
                  icon: Icons.auto_awesome_rounded,
                ),
                _storyPreviewCard(
                  name: 'Fitness',
                  subtitle: 'MOVE',
                  imageUrl: '',
                  ringColor: const Color(0xFF31E6BF),
                  icon: Icons.fitness_center_rounded,
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(19),
              gradient: const LinearGradient(
                colors: [Color(0xFF071A37), Color(0xFF101642)],
              ),
              border: Border.all(
                color: const Color(0xFF334D85).withValues(alpha: .58),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFFFF47D0), Color(0xFF7155FF)],
                        ),
                      ),
                      child: const Icon(
                        Icons.video_collection_rounded,
                        color: Colors.white,
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 9),
                    const Text(
                      'Reels',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'SHORT VIDEOS • WELLNESS • COMMUNITY',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFF7D8EAF),
                          fontSize: 7.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .9,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text(
                        'See all',
                        style: TextStyle(
                          color: Color(0xFF9AB5FF),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 132,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _reelPreviewCard(
                        icon: Icons.fitness_center_rounded,
                        title: 'Consistency',
                        views: '12.4K',
                        color: const Color(0xFF26E6FF),
                      ),
                      _reelPreviewCard(
                        icon: Icons.wb_sunny_rounded,
                        title: 'Motivation',
                        views: '8.7K',
                        color: const Color(0xFFFFB541),
                      ),
                      _reelPreviewCard(
                        icon: Icons.local_drink_rounded,
                        title: 'Fuel Your Purpose',
                        views: '15.2K',
                        color: const Color(0xFFFF4FA3),
                      ),
                      _reelPreviewCard(
                        icon: Icons.music_note_rounded,
                        title: 'Studio Vibes',
                        views: '9.1K',
                        color: const Color(0xFF9E4EFF),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _storiesReelsTab({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
    bool showAdd = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? color : const Color(0xFF9DA9C2),
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (showAdd) ...[
                  const SizedBox(width: 7),
                  Container(
                    width: 21,
                    height: 21,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: .12),
                      border: Border.all(color: color.withValues(alpha: .65)),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: .18),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Icon(Icons.add_rounded, color: color, size: 16),
                  ),
                ],
              ],
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: selected
                  ? LinearGradient(
                      colors: [
                        color,
                        const Color(0xFF754EFF),
                        const Color(0xFFFF4DD1),
                      ],
                    )
                  : null,
              color: selected ? null : const Color(0xFF20334F),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: .38),
                        blurRadius: 10,
                      ),
                    ]
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _createStoryCard() {
    return Container(
      width: 82,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF19E9FF), Color(0xFF5B59FF), Color(0xFFFF43D1)],
        ),
      ),
      padding: const EdgeInsets.all(1.3),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(21),
          gradient: const LinearGradient(
            colors: [Color(0xFF081A38), Color(0xFF151034)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF26E8FF),
                    Color(0xFF7454FF),
                    Color(0xFFFF4DD2),
                  ],
                ),
              ),
              child: _avatar(currentPhoto, currentName, size: 52),
            ),
            const SizedBox(height: 13),
            const Text(
              'Create Story',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'SHARE YOUR\nJOURNEY',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFB28CFF),
                fontSize: 6.2,
                height: 1.25,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.7,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _storyPreviewCard({
    required String name,
    required String subtitle,
    required String imageUrl,
    required Color ringColor,
    bool isOwn = false,
    IconData icon = Icons.spa_rounded,
  }) {
    return Container(
      width: 82,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ringColor, const Color(0xFF5F53FF), const Color(0xFFFF47CA)],
        ),
      ),
      padding: const EdgeInsets.all(1.3),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(21),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF11244A), Color(0xFF151033)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ringColor, width: 2),
              ),
              child: imageUrl.trim().isNotEmpty
                  ? _avatar(imageUrl, name, size: 30)
                  : CircleAvatar(
                      radius: 15,
                      backgroundColor: ringColor.withValues(alpha: .18),
                      child: Icon(icon, color: ringColor, size: 15),
                    ),
            ),
            const Spacer(),
            Icon(
              isOwn ? Icons.auto_awesome_rounded : icon,
              color: ringColor.withValues(alpha: .88),
              size: 21,
            ),
            const Spacer(),
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: ringColor,
                fontSize: 6.2,
                fontWeight: FontWeight.w900,
                letterSpacing: .8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reelPreviewCard({
    required IconData icon,
    required String title,
    required String views,
    required Color color,
  }) {
    return Container(
      width: 82,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: .85),
            const Color(0xFF5E4BFF),
            const Color(0xFF1A123C),
          ],
        ),
      ),
      padding: const EdgeInsets.all(1),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF142A50), Color(0xFF0C1028)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Center(
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: .14),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: .20),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
              ),
            ),
            Row(
              children: [
                const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 17,
                ),
                const SizedBox(width: 3),
                Text(
                  views,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8.5,
                height: 1.05,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: const Color(0xFF071126).withValues(alpha: .97),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFF284A7A).withValues(alpha: .42),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onSearch,
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 590),
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B1831),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFF4268A3).withValues(alpha: .82),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.search_rounded,
                            color: Color(0xFFCBD8F3),
                            size: 20,
                          ),
                          SizedBox(width: 11),
                          Expanded(
                            child: Text(
                              'Search people, topics, or wellness content...',
                              style: TextStyle(
                                color: Color(0xFF8F9CBC),
                                fontSize: 11,
                              ),
                            ),
                          ),
                          Text(
                            'SEARCH',
                            style: TextStyle(
                              color: Color(0xFF7C8AA9),
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 18),
          _topIcon(
            Icons.notifications_none_rounded,
            onTap: widget.onNotifications,
          ),
          const SizedBox(width: 8),
          _topIcon(Icons.chat_bubble_outline_rounded, onTap: widget.onMessages),
          const SizedBox(width: 10),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onProfile,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  height: 45,
                  padding: const EdgeInsets.fromLTRB(6, 4, 11, 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFF2F4F7D).withValues(alpha: .75),
                    ),
                    color: const Color(0xFF0A152B),
                  ),
                  child: Row(
                    children: [
                      _avatar(currentPhoto, currentName, size: 34),
                      const SizedBox(width: 9),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            currentRole == 'provider'
                                ? 'Wellness Provider'
                                : 'Stay Well',
                            style: const TextStyle(
                              color: Color(0xFF8391AF),
                              fontSize: 7.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 9),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF8897B9),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topIcon(IconData icon, {VoidCallback? onTap}) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 40,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0B1730),
              border: Border.all(
                color: const Color(0xFF34517F).withValues(alpha: .72),
              ),
            ),
            child: Icon(icon, color: const Color(0xFFD4DDF0), size: 19),
          ),
        ),
      ),
    );
  }

  Future<void> _openMobileComposer() async {
    FocusScope.of(context).unfocus();

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (composerContext) {
          return StatefulBuilder(
            builder: (composerContext, setComposerState) {
              final hasContent =
                  postController.text.trim().isNotEmpty ||
                  pendingImage != null ||
                  selectedMusicTrack != null;

              Future<void> choosePhoto() async {
                await _pickPhoto();

                if (composerContext.mounted) {
                  setComposerState(() {});
                }
              }

              Future<void> publishPost() async {
                if (posting) return;

                final ready =
                    postController.text.trim().isNotEmpty ||
                    pendingImage != null ||
                    selectedMusicTrack != null;

                if (!ready) return;

                FocusScope.of(composerContext).unfocus();

                setComposerState(() {});

                await _createPost();

                if (!composerContext.mounted) return;

                setComposerState(() {});

                if (!posting &&
                    postController.text.trim().isEmpty &&
                    pendingImage == null &&
                    selectedMusicTrack == null) {
                  Navigator.of(composerContext).pop();
                }
              }

              Widget quickChip({
                required IconData icon,
                required String label,
                required Color color,
                VoidCallback? onTap,
              }) {
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(25),
                    child: Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF07162F),
                            color.withValues(alpha: .10),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: color.withValues(alpha: .70),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: .15),
                            blurRadius: 18,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color.withValues(alpha: .12),
                            ),
                            child: Icon(icon, color: color, size: 18),
                          ),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              Widget mediaButton({
                required IconData icon,
                required String label,
                required Color color,
                required VoidCallback? onTap,
              }) {
                return Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(19),
                      child: Container(
                        height: 78,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF07172F),
                              color.withValues(alpha: .07),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(19),
                          border: Border.all(
                            color: color.withValues(alpha: .55),
                            width: 1.15,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: .12),
                              blurRadius: 18,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: color.withValues(alpha: .11),
                              ),
                              child: Icon(icon, color: color, size: 23),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }

              return Scaffold(
                backgroundColor: const Color(0xFF010611),
                resizeToAvoidBottomInset: true,
                body: Stack(
                  children: [
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment(.85, -.65),
                            radius: 1.35,
                            colors: [
                              Color(0x221D7BFF),
                              Color(0x110F2B75),
                              Color(0x00010611),
                            ],
                          ),
                        ),
                      ),
                    ),

                    Positioned(
                      left: -120,
                      top: 160,
                      child: IgnorePointer(
                        child: Container(
                          width: 300,
                          height: 300,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00DFFF)
                                    .withValues(alpha: .09),
                                blurRadius: 130,
                                spreadRadius: 40,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    Positioned(
                      right: -90,
                      bottom: 175,
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: .18,
                          child: Icon(
                            Icons.spa_rounded,
                            size: 230,
                            color: Color(0xFF8251FF),
                          ),
                        ),
                      ),
                    ),

                    Positioned(
                      right: -80,
                      bottom: 330,
                      child: IgnorePointer(
                        child: Transform.rotate(
                          angle: -.32,
                          child: Container(
                            width: 430,
                            height: 2,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0x00000000),
                                  Color(0xFF18E6FF),
                                  Color(0xFF6856FF),
                                  Color(0x00000000),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0xFF297EFF),
                                  blurRadius: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    Positioned(
                      right: -100,
                      bottom: 160,
                      child: Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6C2BFF)
                                  .withValues(alpha: .10),
                              blurRadius: 120,
                              spreadRadius: 35,
                            ),
                          ],
                        ),
                      ),
                    ),

                    SafeArea(
                      child: Column(
                        children: [
                          Container(
                            height: 66,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF020816)
                                  .withValues(alpha: .92),
                              border: Border(
                                bottom: BorderSide(
                                  color: const Color(0xFF21538A)
                                      .withValues(alpha: .32),
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF07152D),
                                    border: Border.all(
                                      color: const Color(0xFF294D79),
                                    ),
                                  ),
                                  child: IconButton(
                                    onPressed: posting
                                        ? null
                                        : () {
                                            Navigator.of(composerContext).pop();
                                          },
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                ),

                                const Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Create Post',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -.4,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        '999 WELLNESS',
                                        style: TextStyle(
                                          color: Color(0xFF45DEFF),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 3.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF07152D),
                                    border: Border.all(
                                      color: const Color(0xFF294D79),
                                    ),
                                  ),
                                  child: IconButton(
                                    onPressed: () {},
                                    icon: const Icon(
                                      Icons.more_horiz_rounded,
                                      color: Color(0xFF74EDFF),
                                      size: 27,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Expanded(
                            child: SingleChildScrollView(
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: const EdgeInsets.fromLTRB(
                                18,
                                18,
                                18,
                                20,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF18E6FF),
                                              Color(0xFF6B56FF),
                                              Color(0xFFD64BFF),
                                            ],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF6B56FF)
                                                  .withValues(alpha: .28),
                                              blurRadius: 22,
                                            ),
                                          ],
                                        ),
                                        child: _avatar(
                                          currentPhoto,
                                          currentName,
                                          size: 68,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              currentName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 22,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: -.4,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 8,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF07152A),
                                                borderRadius:
                                                    BorderRadius.circular(22),
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFF24DFFF,
                                                  ),
                                                ),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.public_rounded,
                                                    color: Color(0xFF51EFFF),
                                                    size: 18,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    'Public',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                  SizedBox(width: 5),
                                                  Icon(
                                                    Icons
                                                        .keyboard_arrow_down_rounded,
                                                    color: Color(0xFF65B7FF),
                                                    size: 18,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 30),

                                  Row(
                                    children: [
                                      Expanded(
                                        child: quickChip(
                                          icon: Icons.group_rounded,
                                          label: selectedTaggedPeople.isEmpty
                                              ? 'People'
                                              : 'People (${selectedTaggedPeople.length})',
                                          color: const Color(0xFF21DFFF),
                                          onTap: () async {
                                            final people =
                                                await _pickTaggedPeople(
                                                  composerContext,
                                                );

                                            if (people != null) {
                                              setComposerState(() {
                                                selectedTaggedPeople = people;
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: quickChip(
                                          icon: Icons.location_on_rounded,
                                          label:
                                              selectedLocationName == null ||
                                                  selectedLocationName!.isEmpty
                                              ? 'Location'
                                              : 'Location added',
                                          color: const Color(0xFF725CFF),
                                          onTap: () async {
                                            final location =
                                                await _pickPostLocation(
                                                  composerContext,
                                                );

                                            if (location != null) {
                                              setComposerState(() {
                                                selectedLocationName =
                                                    location.isEmpty
                                                    ? null
                                                    : location;
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: quickChip(
                                          icon: Icons.music_note_rounded,
                                          label: 'Music',
                                          color: const Color(0xFFFF4ACF),
                                          onTap: () async {
                                            FocusScope.of(composerContext)
                                                .unfocus();

                                            final track =
                                                await Navigator.of(
                                                  composerContext,
                                                ).push<Map<String, dynamic>>(
                                                  MaterialPageRoute(
                                                    fullscreenDialog: true,
                                                    builder: (_) =>
                                                        const CommunityMusicPicker(),
                                                  ),
                                                );

                                            if (track != null) {
                                              setComposerState(() {
                                                selectedMusicTrack =
                                                    Map<String, dynamic>.from(
                                                      track,
                                                    );
                                              });

                                              debugPrint(
                                                'MUSIC SELECTED: ${track['title']}',
                                              );
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: quickChip(
                                          icon: Icons
                                              .sentiment_satisfied_alt_rounded,
                                          label:
                                              selectedFeelingActivity == null ||
                                                  selectedFeelingActivity!
                                                      .isEmpty
                                              ? 'Feeling / Activity'
                                              : 'Feeling added',
                                          color: const Color(0xFF36E8FF),
                                          onTap: () async {
                                            final feeling =
                                                await _pickFeelingActivity(
                                                  composerContext,
                                                );

                                            if (feeling != null) {
                                              setComposerState(() {
                                                selectedFeelingActivity =
                                                    feeling.isEmpty
                                                    ? null
                                                    : feeling;
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),

                                  if (selectedMusicTrack != null) ...[
                                    const SizedBox(height: 14),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF07152B),
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: const Color(0x66FF4ACF),
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x2200E5FF),
                                            blurRadius: 18,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 52,
                                            height: 52,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              gradient: const LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  Color(0xFFFF4ACF),
                                                  Color(0xFF7148FF),
                                                  Color(0xFF16DFFF),
                                                ],
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.music_note_rounded,
                                              color: Colors.white,
                                              size: 28,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'MUSIC ADDED',
                                                  style: TextStyle(
                                                    color: Color(0xFFFF55D5),
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: 1.5,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  () {
                                                    final title =
                                                        selectedMusicTrack?['title']
                                                            ?.toString() ??
                                                        'Selected song';
                                                    final feature =
                                                        selectedMusicTrack?['featured_artist']
                                                            ?.toString()
                                                            .trim() ??
                                                        '';

                                                    if (feature.isEmpty) {
                                                      return title;
                                                    }

                                                    return '$title (feat. $feature)';
                                                  }(),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  selectedMusicTrack?['artist_name']
                                                          ?.toString() ??
                                                      '',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Color(0xFFA8B6D0),
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            tooltip: 'Remove music',
                                            onPressed: () {
                                              setComposerState(() {
                                                selectedMusicTrack = null;
                                              });
                                            },
                                            icon: const Icon(
                                              Icons.close_rounded,
                                              color: Color(0xFF8FEFFF),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 24),

                                  Stack(
                                    children: [
                                      TextField(
                                        controller: postController,
                                        autofocus: true,
                                        minLines: 14,
                                        maxLines: null,
                                        textCapitalization:
                                            TextCapitalization.sentences,
                                        keyboardType: TextInputType.multiline,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          height: 1.45,
                                        ),
                                        onChanged: (_) {
                                          setComposerState(() {});
                                        },
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          hintText: "What's on your mind?",
                                          hintStyle: TextStyle(
                                            color: Color(0xFF8390A8),
                                            fontSize: 22,
                                            fontWeight: FontWeight.w400,
                                          ),
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),

                                      Positioned(
                                        right: 2,
                                        top: 3,
                                        child: Text(
                                          '${postController.text.length}/5000',
                                          style: const TextStyle(
                                            color: Color(0xFF70809B),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  if (pendingImage != null) ...[
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF07152C),
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: const Color(0xFF4F73FF)
                                              .withValues(alpha: .65),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.image_rounded,
                                            color: Color(0xFF42EFFF),
                                            size: 30,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              pendingImage!.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: posting
                                                ? null
                                                : () {
                                                    pendingImage = null;

                                                    setComposerState(() {});

                                                    if (mounted) {
                                                      setState(() {});
                                                    }
                                                  },
                                            icon: const Icon(
                                              Icons.close_rounded,
                                              color: Color(0xFFFF6697),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),

                          Container(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF020816)
                                  .withValues(alpha: .97),
                              border: Border(
                                top: BorderSide(
                                  color: const Color(0xFF1E4B7D)
                                      .withValues(alpha: .45),
                                ),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    mediaButton(
                                      icon: Icons.photo_library_rounded,
                                      label: 'Gallery',
                                      color: const Color(0xFF24E5FF),
                                      onTap: posting ? null : choosePhoto,
                                    ),
                                    const SizedBox(width: 8),
                                    mediaButton(
                                      icon: Icons.videocam_rounded,
                                      label: 'Live',
                                      color: const Color(0xFFFF4CCF),
                                      onTap: posting
                                          ? null
                                          : () {
                                              _goLiveSetup();
                                            },
                                    ),
                                    const SizedBox(width: 8),
                                    mediaButton(
                                      icon: Icons.gif_box_rounded,
                                      label: 'GIF',
                                      color: const Color(0xFFA95DFF),
                                      onTap: () {},
                                    ),
                                    const SizedBox(width: 8),
                                    mediaButton(
                                      icon: Icons.call_rounded,
                                      label: 'Calls',
                                      color: const Color(0xFF2EEAFF),
                                      onTap: () {
                                        ScaffoldMessenger.of(composerContext)
                                            .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Calls sharing will connect to the wellness calling system.',
                                                ),
                                              ),
                                            );
                                      },
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 13),

                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 11,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF07152A),
                                        borderRadius: BorderRadius.circular(23),
                                        border: Border.all(
                                          color: const Color(0xFF22DFFF),
                                        ),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(
                                            Icons.public_rounded,
                                            color: Color(0xFF4DEFFF),
                                            size: 18,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Public',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          SizedBox(width: 4),
                                          Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                            color: Color(0xFF68B4FF),
                                            size: 18,
                                          ),
                                        ],
                                      ),
                                    ),

                                    const Spacer(),

                                    Container(
                                      width: 178,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        gradient: hasContent
                                            ? const LinearGradient(
                                                colors: [
                                                  Color(0xFF1BDFFF),
                                                  Color(0xFF5C59FF),
                                                  Color(0xFFD32FFF),
                                                ],
                                              )
                                            : const LinearGradient(
                                                colors: [
                                                  Color(0xFF303746),
                                                  Color(0xFF3D4352),
                                                ],
                                              ),
                                        borderRadius: BorderRadius.circular(18),
                                        boxShadow: hasContent
                                            ? [
                                                BoxShadow(
                                                  color: const Color(0xFF5B57FF)
                                                      .withValues(alpha: .30),
                                                  blurRadius: 22,
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: hasContent && !posting
                                              ? publishPost
                                              : null,
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          child: Center(
                                            child: posting
                                                ? const SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Colors.white,
                                                        ),
                                                  )
                                                : const Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.send_rounded,
                                                        color: Colors.white,
                                                        size: 20,
                                                      ),
                                                      SizedBox(width: 9),
                                                      Text(
                                                        'Post',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 18,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
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
                  ],
                ),
              );
            },
          );
        },
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  Widget _buildComposer() {
    return LayoutBuilder(
      builder: (context, box) {
        final compact = box.maxWidth < 430;
        final mobile = box.maxWidth < 600;

        final panelPadding = compact
            ? 12.0
            : mobile
            ? 14.0
            : 18.0;
        final avatarSize = compact
            ? 44.0
            : mobile
            ? 48.0
            : 56.0;
        final fieldHeight = compact
            ? 52.0
            : mobile
            ? 60.0
            : 68.0;
        final actionGap = compact ? 6.0 : 9.0;

        return _glassPanel(
          padding: EdgeInsets.all(panelPadding),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _avatar(currentPhoto, currentName, size: avatarSize),
                  SizedBox(width: compact ? 9 : 13),
                  Expanded(
                    child: mobile
                        ? Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _openMobileComposer,
                              borderRadius: BorderRadius.circular(
                                compact ? 15 : 18,
                              ),
                              child: Container(
                                constraints: BoxConstraints(
                                  minHeight: fieldHeight,
                                ),
                                padding: EdgeInsets.symmetric(
                                  horizontal: compact ? 13 : 17,
                                  vertical: compact ? 17 : 21,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF103873),
                                  borderRadius: BorderRadius.circular(
                                    compact ? 15 : 18,
                                  ),
                                  border: Border.all(
                                    color: const Color(0xFF36E6FF)
                                        .withValues(alpha: .82),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        postController.text.trim().isEmpty
                                            ? "What's on your mind?"
                                            : postController.text.trim(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color:
                                              postController.text.trim().isEmpty
                                              ? const Color(0xFFA8B3CC)
                                              : Colors.white,
                                          fontSize: compact ? 11 : 12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      color: Color(0xFF71EFFF),
                                      size: 22,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : Container(
                            constraints: BoxConstraints(minHeight: fieldHeight),
                            decoration: BoxDecoration(
                              color: const Color(0xFF103873),
                              borderRadius: BorderRadius.circular(
                                compact ? 15 : 18,
                              ),
                              border: Border.all(
                                color: const Color(0xFF36E6FF)
                                    .withValues(alpha: .82),
                              ),
                            ),
                            child: TextField(
                              controller: postController,
                              minLines: 1,
                              maxLines: 6,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: compact ? 11 : 12,
                              ),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: "Transmit a wellness signal to the neural network...",
                                hintStyle: TextStyle(
                                  color: const Color(0xFFA8B3CC),
                                  fontSize: compact ? 11 : 12,
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: compact ? 13 : 17,
                                  vertical: compact ? 18 : 24,
                                ),
                              ),
                            ),
                          ),
                  ),
                ],
              ),

              if (pendingImage != null) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: EdgeInsets.only(left: compact ? 0 : avatarSize + 7),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B1730),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: const Color(0xFF314A78)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.image_outlined, color: cyan, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            pendingImage!.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            setState(() {
                              pendingImage = null;
                            });
                          },
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white54,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              SizedBox(height: compact ? 8 : 14),

              Row(
                children: [
                  Expanded(
                    child: _composerButton(
                      icon: Icons.photo_camera_outlined,
                      label: "Photo",
                      onTap: _pickPhoto,
                    ),
                  ),
                  SizedBox(width: actionGap),
                  Expanded(
                    child: _composerButton(
                      icon: Icons.videocam_outlined,
                      label: "Go Live",
                      onTap: _goLiveSetup,
                    ),
                  ),
                  SizedBox(width: actionGap),
                  Expanded(
                    child: InkWell(
                      onTap: posting ? null : _createPost,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 44,
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 6 : 9,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFC326FF),
                              Color(0xFF6056FF),
                              Color(0xFF14E3FF),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: purple.withValues(alpha: .22),
                              blurRadius: 15,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: posting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.send_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  SizedBox(width: compact ? 4 : 7),
                                  Flexible(
                                    child: Text(
                                      compact ? "Post" : "Transmit Post",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: compact ? 10 : 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _composerButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF3F79C7)),
          color: const Color(0xFF091A38),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: label == 'Go Live'
                  ? const Color(0xFFFF4D87)
                  : const Color(0xFFD8E3F8),
              size: 20,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFFE6ECF8),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    final compact = MediaQuery.sizeOf(context).width < 430;

    return Container(
      height: compact ? 44 : 48,
      padding: EdgeInsets.all(compact ? 3 : 4),
      decoration: BoxDecoration(
        color: const Color(0xFF071D42),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF35B9FF)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _tabButton(
              index: 0,
              label: 'Neural For You',
              icon: Icons.auto_awesome_rounded,
            ),
          ),
          Expanded(
            child: _tabButton(
              index: 1,
              label: 'Network',
              icon: Icons.people_alt_outlined,
            ),
          ),
          Expanded(
            child: _tabButton(index: 2, label: 'Live', icon: Icons.circle),
          ),
        ],
      ),
    );
  }

  Widget _tabButton({
    required int index,
    required String label,
    required IconData icon,
  }) {
    final selected = selectedTab == index;

    return InkWell(
      onTap: () {
        setState(() {
          selectedTab = index;
        });
      },
      borderRadius: BorderRadius.circular(11),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: MediaQuery.sizeOf(context).width < 430 ? 36 : 40,
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [
                    Color(0xFF9B30FF),
                    Color(0xFF5B49FF),
                    Color(0xFF1BAFFF),
                  ],
                )
              : null,
          borderRadius: BorderRadius.circular(11),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: purple.withValues(alpha: .42),
                    blurRadius: 18,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (label == 'Live')
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 7),
                decoration: const BoxDecoration(
                  color: Color(0xFFFF4D87),
                  shape: BoxShape.circle,
                ),
              )
            else
              Icon(
                icon,
                color: selected ? Colors.white : const Color(0xFF8F9BB7),
                size: 14,
              ),
            if (label != 'Live') const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFFA6B0C7),
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                fontSize: MediaQuery.sizeOf(context).width < 430 ? 9.6 : 10.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _feedMusicDisplayTitle(Map<String, dynamic> post) {
    final title = post['music_title']?.toString().trim() ?? '';
    final feature = post['music_featured_artist']?.toString().trim() ?? '';

    if (feature.isEmpty) return title;
    return '$title (feat. $feature)';
  }

  Future<void> _toggleFeedMusic(Map<String, dynamic> post) async {
    final postId = post['id']?.toString() ?? '';
    final audioUrl = post['_music_audio_url']?.toString().trim() ?? '';

    if (postId.isEmpty || audioUrl.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio is not available for this track.')),
      );
      return;
    }

    try {
      if (playingMusicPostId == postId) {
        await feedMusicPlayer.pause();
        if (!mounted) return;
        setState(() => playingMusicPostId = '');
        return;
      }

      await feedMusicPlayer.stop();
      await feedMusicPlayer.play(UrlSource(audioUrl));

      if (!mounted) return;
      setState(() => playingMusicPostId = postId);
    } catch (error) {
      if (!mounted) return;
      setState(() => playingMusicPostId = '');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to play music: $error')));
    }
  }

  Widget _compactPostMusicLine(Map<String, dynamic> post) {
    final postId = post['id']?.toString() ?? '';
    final title = _feedMusicDisplayTitle(post);
    final artist = post['music_artist']?.toString().trim() ?? '';
    final audio = post['_music_audio_url']?.toString().trim() ?? '';
    final playing = playingMusicPostId == postId;

    final display = artist.isEmpty ? title : '$title - $artist';

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 1, 18, 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: audio.isEmpty ? null : () => _toggleFeedMusic(post),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Container(
                  width: 27,
                  height: 27,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFF3DB8),
                        Color(0xFF7A4DFF),
                        Color(0xFF20DCFF),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: const [
                      BoxShadow(color: Color(0x335E7BFF), blurRadius: 10),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    playing ? Icons.pause_rounded : Icons.music_note_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    display,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFE9ECF7),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (audio.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Icon(
                    playing
                        ? Icons.graphic_eq_rounded
                        : Icons.play_circle_outline_rounded,
                    color: playing
                        ? const Color(0xFF48F6C8)
                        : const Color(0xFF91A2C8),
                    size: 18,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _musicFeedCard(Map<String, dynamic> post) {
    final postId = post['id']?.toString() ?? '';
    final title = _feedMusicDisplayTitle(post);
    final artist = post['music_artist']?.toString().trim() ?? '';
    final artwork = post['_music_artwork_url']?.toString().trim() ?? '';
    final audio = post['_music_audio_url']?.toString().trim() ?? '';
    final playing = playingMusicPostId == postId;

    Widget fallbackArtwork() {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF28104E), Color(0xFF0B1D48), Color(0xFF06111F)],
          ),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.music_note_rounded,
          color: Colors.white,
          size: 84,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(18, 2, 18, 11)),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: const Color(0xFFFF4FCB).withValues(alpha: .74),
                width: 1.3,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFB42EFF).withValues(alpha: .20),
                  blurRadius: 26,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: const Color(0xFF22DFFF).withValues(alpha: .10),
                  blurRadius: 34,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(21),
              child: AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (artwork.isNotEmpty)
                      Image.network(
                        artwork,
                        fit: BoxFit.cover,
                        errorBuilder: (_, error, stackTrace) {
                          return fallbackArtwork();
                        },
                      )
                    else
                      fallbackArtwork(),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: IgnorePointer(
                        child: Container(
                          height: 150,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                const Color(0xFF020713).withValues(alpha: .92),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 17,
                      right: 90,
                      bottom: 17,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '999 WELLNESS SOUND',
                            style: TextStyle(
                              color: Color(0xFFFF55D5),
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.4,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            title.isEmpty ? 'Music' : title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              height: 1.05,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (artist.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFD7DDEA),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: audio.isEmpty
                              ? null
                              : () => _toggleFeedMusic(post),
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 62,
                            height: 62,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF26E9FF),
                                  Color(0xFF704CFF),
                                  Color(0xFFFF3FC5),
                                ],
                              ),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: .82),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF7B46FF)
                                      .withValues(alpha: .50),
                                  blurRadius: 22,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Icon(
                              playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 37,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 14,
                      right: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF030914).withValues(alpha: .75),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .12),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              playing
                                  ? Icons.graphic_eq_rounded
                                  : Icons.music_note_rounded,
                              color: playing
                                  ? const Color(0xFF52F1FF)
                                  : Colors.white70,
                              size: 14,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              playing ? 'PLAYING' : 'MUSIC',
                              style: TextStyle(
                                color: playing
                                    ? const Color(0xFF52F1FF)
                                    : Colors.white70,
                                fontSize: 7.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: .8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _firstPostUrl(String body) {
    final match = RegExp(
      r'https?://[^\s]+',
      caseSensitive: false,
    ).firstMatch(body);

    if (match == null) {
      return null;
    }

    var url = match.group(0) ?? '';

    while (url.isNotEmpty &&
        (url.endsWith('.') ||
            url.endsWith(',') ||
            url.endsWith(')') ||
            url.endsWith(']'))) {
      url = url.substring(0, url.length - 1);
    }

    return url.isEmpty ? null : url;
  }

  Future<void> _openPostUrl(String url) async {
    final uri = Uri.tryParse(url);

    if (uri == null) {
      return;
    }

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open this link.')),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Unable to open link: $error')));
    }
  }

  Widget _linkedPostBody(String body) {
    final pattern = RegExp(r'https?://[^\s]+', caseSensitive: false);

    final spans = <InlineSpan>[];
    var cursor = 0;

    for (final match in pattern.allMatches(body)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: body.substring(cursor, match.start)));
      }

      var url = match.group(0) ?? '';

      while (url.isNotEmpty &&
          (url.endsWith('.') ||
              url.endsWith(',') ||
              url.endsWith(')') ||
              url.endsWith(']'))) {
        url = url.substring(0, url.length - 1);
      }

      final clickableUrl = url;

      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: InkWell(
            onTap: clickableUrl.isEmpty
                ? null
                : () => _openPostUrl(clickableUrl),
            borderRadius: BorderRadius.circular(4),
            child: Text(
              clickableUrl,
              style: const TextStyle(
                color: Color(0xFF3DA9FF),
                fontSize: 13,
                height: 1.5,
                fontWeight: FontWeight.w800,
                decoration: TextDecoration.underline,
                decorationColor: Color(0xFF3DA9FF),
              ),
            ),
          ),
        ),
      );

      cursor = match.end;
    }

    if (cursor < body.length) {
      spans.add(TextSpan(text: body.substring(cursor)));
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          color: Color(0xFFE8EDF7),
          fontSize: 13,
          height: 1.5,
          fontWeight: FontWeight.w400,
        ),
        children: spans,
      ),
    );
  }

  Future<Map<String, String>> _loadLinkPreview(String url) async {
    final cached = linkPreviewCache[url];

    if (cached != null) {
      return cached;
    }

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'link-preview',
        body: {'url': url},
      );

      final raw = response.data;

      if (raw is! Map) {
        return const <String, String>{};
      }

      final result = <String, String>{
        'url': raw['url']?.toString() ?? url,
        'title': raw['title']?.toString() ?? '',
        'description': raw['description']?.toString() ?? '',
        'image': raw['image']?.toString() ?? '',
        'siteName': raw['siteName']?.toString() ?? '',
      };

      linkPreviewCache[url] = result;

      return result;
    } catch (error) {
      debugPrint('LINK PREVIEW ERROR: $error');
      return const <String, String>{};
    }
  }

  Widget _linkPreviewFallback({
    required String host,
    required String headline,
  }) {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF173E7B), Color(0xFF412461), Color(0xFF071526)],
        ),
      ),
      child: Stack(
        children: [
          const Center(
            child: Icon(
              Icons.language_rounded,
              color: Color(0xFF5EEBFF),
              size: 62,
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 12,
            child: Text(
              headline.isNotEmpty ? headline : host,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _postLinkPreview(String body) {
    final url = _firstPostUrl(body);

    if (url == null) {
      return const SizedBox.shrink();
    }

    final uri = Uri.tryParse(url);

    if (uri == null) {
      return const SizedBox.shrink();
    }

    final host = uri.host.replaceFirst(RegExp(r'^www\.'), '');

    final textLines = body
        .split('\n')
        .map((value) => value.trim())
        .where(
          (value) =>
              value.isNotEmpty &&
              !value.startsWith('http://') &&
              !value.startsWith('https://'),
        )
        .toList();

    final fallbackHeadline = textLines.isEmpty ? host : textLines.join(' ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: FutureBuilder<Map<String, String>>(
        future: _loadLinkPreview(url),
        builder: (context, snapshot) {
          final metadata = snapshot.data ?? const <String, String>{};

          final metadataUrl = metadata['url']?.trim() ?? '';
          final metadataTitle = metadata['title']?.trim() ?? '';
          final metadataDescription = metadata['description']?.trim() ?? '';
          final metadataImage = metadata['image']?.trim() ?? '';
          final metadataSite = metadata['siteName']?.trim() ?? '';

          final previewUrl = metadataUrl.isNotEmpty ? metadataUrl : url;

          final title = metadataTitle.isNotEmpty
              ? metadataTitle
              : fallbackHeadline;

          final site = metadataSite.isNotEmpty ? metadataSite : host;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openPostUrl(previewUrl),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFF071120),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF566FFF)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7747FF).withValues(alpha: .20),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Stack(
                      children: [
                        if (metadataImage.isNotEmpty)
                          AspectRatio(
                            aspectRatio: 1.75,
                            child: Image.network(
                              metadataImage,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) {
                                return _linkPreviewFallback(
                                  host: host,
                                  headline: fallbackHeadline,
                                );
                              },
                            ),
                          )
                        else
                          _linkPreviewFallback(
                            host: host,
                            headline: fallbackHeadline,
                          ),
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFF07101E)
                                  .withValues(alpha: .88),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Icon(
                              Icons.open_in_new_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(15, 13, 15, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            site.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF8DBDFF),
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              height: 1.3,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (metadataDescription.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              metadataDescription,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFADB7CB),
                                fontSize: 10.5,
                                height: 1.35,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          const SizedBox(height: 9),
                          Row(
                            children: [
                              const Icon(
                                Icons.link_rounded,
                                color: Color(0xFF3DA9FF),
                                size: 15,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  previewUrl,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF3DA9FF),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: Color(0xFF91A7CA),
                                size: 12,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _postCard(Map<String, dynamic> post) {
    final user = Supabase.instance.client.auth.currentUser;

    final postId = post['id']?.toString() ?? '';
    final authorId = post['author_id']?.toString() ?? '';
    final name = post['author_name']?.toString() ?? '999 Member';
    final role = post['author_role']?.toString() ?? 'customer';
    final postAuthorId = post['author_id']?.toString() ?? '';
    final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';
    final savedPhoto = post['author_photo_url']?.toString().trim() ?? '';
    final photo =
        postAuthorId == currentUserId && currentPhoto.trim().isNotEmpty
        ? currentPhoto.trim()
        : savedPhoto;
    final body = post['body']?.toString().trim() ?? '';
    final media = post['_media_url']?.toString().trim() ?? '';

    final hasMusic =
        (post['music_track_id']?.toString().trim() ?? '').isNotEmpty ||
        (post['music_title']?.toString().trim() ?? '').isNotEmpty;

    final hasPhoto = media.isNotEmpty;

    final locationName = post['location_name']?.toString().trim() ?? '';
    final feelingActivity = post['feeling_activity']?.toString().trim() ?? '';

    final taggedNames = <String>[];
    final taggedRaw = post['tagged_people'];

    if (taggedRaw is List) {
      for (final item in taggedRaw) {
        if (item is Map) {
          final nameValue = item['name']?.toString().trim() ?? '';

          if (nameValue.isNotEmpty) {
            taggedNames.add(nameValue);
          }
        }
      }
    }

    final ownPost = user?.id == authorId;
    final following = followingIds.contains(authorId);
    final liked = likedPostIds.contains(postId);

    return Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.sizeOf(context).width < 430 ? 11 : 14,
      ),
      child: _glassPanel(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 15, 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _avatar(
                    photo,
                    name,
                    size: 48,
                    onTap: () => _openMemberProfile(
                      userId: authorId,
                      name: name,
                      role: role,
                      photo: photo,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 7,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: role == 'provider'
                                    ? const Color(0xFF0D5164)
                                    : const Color(0xFF1A3779),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: role == 'provider'
                                      ? const Color(0xFF32FFE0)
                                            .withValues(alpha: .7)
                                      : const Color(0xFF7084FF)
                                            .withValues(alpha: .6),
                                ),
                              ),
                              child: Text(
                                role == 'provider'
                                    ? 'Wellness Provider'
                                    : 'Customer',
                                style: TextStyle(
                                  color: role == 'provider'
                                      ? const Color(0xFF6BFFE1)
                                      : const Color(0xFF9DAAFF),
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _timeAgo(post['created_at']),
                          style: const TextStyle(
                            color: Color(0xFF7886A4),
                            fontSize: 9,
                          ),
                        ),
                        if (taggedNames.isNotEmpty ||
                            locationName.isNotEmpty ||
                            feelingActivity.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 5,
                            runSpacing: 3,
                            children: [
                              if (taggedNames.isNotEmpty)
                                Text(
                                  'with ${taggedNames.take(2).join(', ')}${taggedNames.length > 2 ? ' +${taggedNames.length - 2}' : ''}',
                                  style: const TextStyle(
                                    color: Color(0xFF61E8FF),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              if (locationName.isNotEmpty)
                                Text(
                                  'at $locationName',
                                  style: const TextStyle(
                                    color: Color(0xFFAA8FFF),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              if (feelingActivity.isNotEmpty)
                                Text(
                                  '- feeling $feelingActivity',
                                  style: const TextStyle(
                                    color: Color(0xFF64E9D6),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                            ],
                          ),
                        ],
                        if (hasMusic) ...[
                          const SizedBox(height: 5),
                          InkWell(
                            onTap:
                                (post['_music_audio_url']?.toString().trim() ??
                                        '')
                                    .isEmpty
                                ? null
                                : () => _toggleFeedMusic(post),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    playingMusicPostId == postId
                                        ? Icons.pause_rounded
                                        : Icons.music_note_rounded,
                                    color: const Color(0xFFFF5BD7),
                                    size: 15,
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      () {
                                        final title =
                                            post['music_title']
                                                ?.toString()
                                                .trim() ??
                                            '';
                                        final feature =
                                            post['music_featured_artist']
                                                ?.toString()
                                                .trim() ??
                                            '';
                                        final artist =
                                            post['music_artist']
                                                ?.toString()
                                                .trim() ??
                                            '';

                                        var song = title;

                                        if (feature.isNotEmpty) {
                                          song = '$song (feat. $feature)';
                                        }

                                        if (artist.isNotEmpty) {
                                          song = '$song - $artist';
                                        }

                                        return song;
                                      }(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFFD8DCEA),
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!ownPost)
                    TextButton(
                      onPressed: () {
                        _toggleFollow(authorId);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: following
                            ? const Color(0xFF8190AF)
                            : const Color(0xFF75DFFF),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        minimumSize: Size.zero,
                      ),
                      child: Text(
                        following ? 'Network' : 'Follow',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  IconButton(
                    onPressed: ownPost
                        ? () => showCommunityPostOptions(
                            context: context,
                            post: post,
                            onChanged: _loadFeed,
                          )
                        : null,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.more_horiz_rounded,
                      color: Color(0xFF9BA6BF),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            if (body.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                child: _linkedPostBody(body),
              ),
            if (_firstPostUrl(body) != null && !hasPhoto)
              _postLinkPreview(body),
            if (hasMusic && !hasPhoto && body.isEmpty) _musicFeedCard(post),
            if (media.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 7, 16, 13),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.network(
                    media,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) {
                      return Container(
                        height: 260,
                        color: const Color(0xFF091327),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white38,
                          size: 36,
                        ),
                      );
                    },
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 2, 15, 10),
              child: Row(
                children: [
                  InkWell(
                    onTap: () {
                      _toggleLike(postId);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 5,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            liked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: liked
                                ? const Color(0xFFFF4D78)
                                : const Color(0xFF98A5C1),
                            size: 20,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${likeCounts[postId] ?? 0}',
                            style: const TextStyle(
                              color: Color(0xFFC9D1E2),
                              fontSize: 9.2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      _openComments(post);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 7,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: Color(0xFF98A5C1),
                            size: 20,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${commentCounts[postId] ?? 0}',
                            style: const TextStyle(
                              color: Color(0xFFC9D1E2),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => showPremiumWellnessShareSheet(context, post),
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                      child: Row(
                        children: [
                          Icon(
                            Icons.ios_share_outlined,
                            color: Color(0xFF98A5C1),
                            size: 20,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Share',
                            style: TextStyle(
                              color: Color(0xFFC9D1E2),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.bookmark_border_rounded,
                    color: Color(0xFF98A5C1),
                    size: 20,
                  ),
                  const SizedBox(width: 5),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveFeed() {
    if (liveSessions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: _glassPanel(
          child: Column(
            children: [
              const SizedBox(height: 18),
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: pink.withValues(alpha: .12),
                  border: Border.all(color: pink.withValues(alpha: .45)),
                ),
                child: const Icon(Icons.sensors_rounded, color: pink, size: 34),
              ),
              const SizedBox(height: 14),
              const Text(
                'No one is live right now',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Start a live room and connect with the 999 Wellness community.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _goLiveSetup,
                icon: const Icon(Icons.videocam_rounded),
                label: const Text('Go Live'),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final session in liveSessions)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _liveSessionCard(session),
          ),
      ],
    );
  }

  Widget _liveSessionCard(Map<String, dynamic> session) {
    final name = session['host_name']?.toString() ?? '999 Member';

    final photo = session['host_photo_url']?.toString() ?? '';

    final title = session['title']?.toString() ?? 'Live on 999 Wellness';

    final viewers = session['viewer_count'] ?? 0;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B102B), Color(0xFF10152B)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: pink.withValues(alpha: .45)),
        boxShadow: [
          BoxShadow(color: pink.withValues(alpha: .13), blurRadius: 25),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          _avatar(photo, name, size: 54),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: pink,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Text(
                    'LIVE NOW',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'with $name',
                  style: const TextStyle(color: Colors.white60, fontSize: 10),
                ),
              ],
            ),
          ),
          Column(
            children: [
              const Icon(
                Icons.visibility_outlined,
                color: Colors.white70,
                size: 20,
              ),
              const SizedBox(height: 3),
              Text(
                '$viewers',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader({
    required IconData icon,
    required String title,
    String action = 'View all',
  }) {
    return Row(
      children: [
        Container(
          width: 29,
          height: 29,
          decoration: BoxDecoration(
            color: purple.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: const Color(0xFF9B73FF), size: 16),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
        Text(
          '$action  >',
          style: const TextStyle(
            color: Color(0xFF9A79FF),
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  List<List<String>> get _trendingTopics {
    final counts = <String, int>{};
    final names = <String, String>{};
    final pattern = RegExp(r'#[A-Za-z0-9_]+');

    for (final post in posts) {
      final body = post['body']?.toString() ?? '';
      final seen = <String>{};

      for (final match in pattern.allMatches(body)) {
        final tag = match.group(0);

        if (tag == null || tag.length < 2) {
          continue;
        }

        final key = tag.toLowerCase();

        if (!seen.add(key)) {
          continue;
        }

        counts[key] = (counts[key] ?? 0) + 1;
        names.putIfAbsent(key, () => tag);
      }
    }

    final ranked = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return a.key.compareTo(b.key);
      });

    return ranked.take(5).map((entry) {
      final count = entry.value;

      return <String>[
        names[entry.key] ?? entry.key,
        count == 1 ? '1 post' : '$count posts',
      ];
    }).toList();
  }

  Widget _trendingPanel() {
    final trends = _trendingTopics;

    return _glassPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          _sectionHeader(
            icon: Icons.local_fire_department_rounded,
            title: 'Trending Topics',
          ),
          const SizedBox(height: 13),
          if (trends.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Topics appear as members use hashtags.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF7785A4),
                  fontSize: 8.5,
                  height: 1.3,
                ),
              ),
            ),
          for (int i = 0; i < trends.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: i == 0
                          ? const LinearGradient(
                              colors: [Color(0xFF7743FF), Color(0xFF412FD0)],
                            )
                          : null,
                      color: i == 0 ? null : const Color(0xFF172848),
                    ),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trends[i][0],
                          style: const TextStyle(
                            color: Color(0xFFE9EDF7),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          trends[i][1],
                          style: const TextStyle(
                            color: Color(0xFF74829E),
                            fontSize: 8.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.trending_up_rounded,
                    color: Color(0xFF48E3A7),
                    size: 15,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> get _suggestedMembers {
    final user = Supabase.instance.client.auth.currentUser;
    final suggestions = <Map<String, dynamic>>[];

    for (final profile in communityMembers) {
      final id = profile['user_id']?.toString() ?? '';

      if (id.isEmpty || id == user?.id || followingIds.contains(id)) {
        continue;
      }

      final name = profile['display_name']?.toString().trim() ?? '';

      suggestions.add({
        'author_id': id,
        'author_name': name.isEmpty ? '999 Member' : name,
        'author_role': profile['role']?.toString() == 'provider'
            ? 'provider'
            : 'customer',
        'author_photo_url': profile['photo_url']?.toString() ?? '',
        'bio': profile['bio']?.toString() ?? '',
      });
    }

    suggestions.sort((a, b) {
      final aId = a['author_id']?.toString() ?? '';
      final bId = b['author_id']?.toString() ?? '';
      final aRole = a['author_role']?.toString() ?? '';
      final bRole = b['author_role']?.toString() ?? '';

      if (aRole != bRole) {
        if (aRole == 'provider') return -1;
        if (bRole == 'provider') return 1;
      }

      final byFollowers = (followerCounts[bId] ?? 0).compareTo(
        followerCounts[aId] ?? 0,
      );

      if (byFollowers != 0) {
        return byFollowers;
      }

      return (a['author_name']?.toString() ?? '').compareTo(
        b['author_name']?.toString() ?? '',
      );
    });

    return suggestions.take(3).toList();
  }

  Widget _suggestedPanel() {
    final suggestions = _suggestedMembers;

    return _glassPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          _sectionHeader(
            icon: Icons.people_alt_outlined,
            title: 'Suggested Connections',
          ),
          const SizedBox(height: 13),
          if (suggestions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 13),
              child: Text(
                'More community connections will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF7785A4), fontSize: 9),
              ),
            ),
          for (final member in suggestions)
            Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: Row(
                children: [
                  _avatar(
                    member['author_photo_url']?.toString() ?? '',
                    member['author_name']?.toString() ?? '999 Member',
                    size: 36,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member['author_name']?.toString() ?? '999 Member',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.2,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          member['author_role']?.toString() == 'provider'
                              ? 'Wellness Provider'
                              : 'Customer',
                          style: const TextStyle(
                            color: Color(0xFF4BCFEA),
                            fontSize: 7.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 7),
                  InkWell(
                    onTap: () {
                      final id = member['author_id']?.toString() ?? '';

                      if (id.isNotEmpty) {
                        _toggleFollow(id);
                      }
                    },
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF783EFF), Color(0xFF5B36ED)],
                        ),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Text(
                        'Follow',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _rightLivePanel() {
    return _glassPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader(icon: Icons.sensors_rounded, title: 'Live Sessions'),
          const SizedBox(height: 12),
          if (liveSessions.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF341831), Color(0xFF171B46)],
                ),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: const Color(0xFF9B4B86).withValues(alpha: .5),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: pink.withValues(alpha: .14),
                    ),
                    child: const Icon(
                      Icons.videocam_rounded,
                      color: pink,
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 9),
                  const Text(
                    'Start the conversation',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 10.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Be the first member to create a live room.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF8D96AE),
                      fontSize: 8,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: _goLiveSetup,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE34E87), Color(0xFF8750E8)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Go Live',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            _liveSessionCard(liveSessions.first),
        ],
      ),
    );
  }

  Widget _desktopContent() {
    final feedPosts = visiblePosts;

    return Column(
      children: [
        _buildTopBar(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadFeed,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 54),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1320),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '999 WELLNESS COMMUNITY',
                                  style: TextStyle(
                                    color: Color(0xFFA07AFF),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Feed',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 33,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Real people. Real progress. A healthier, happier you - together.',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: .68),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'PEOPLE',
                                style: TextStyle(
                                  color: Color(0xFF9D6FFF),
                                  letterSpacing: 5,
                                  fontSize: 9,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'WELLNESS',
                                style: TextStyle(
                                  color: Color(0xFF9D6FFF),
                                  letterSpacing: 5,
                                  fontSize: 9,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'PROGRESS',
                                style: TextStyle(
                                  color: Color(0xFF9D6FFF),
                                  letterSpacing: 5,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 18,
                            child: Column(
                              children: [
                                _buildComposer(),
                                const SizedBox(height: 13),
                                _buildTabs(),
                                if (loading)
                                  const Padding(
                                    padding: EdgeInsets.all(70),
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  )
                                else if (selectedTab == 2)
                                  _buildLiveFeed()
                                else if (feedPosts.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: _glassPanel(
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 32,
                                        ),
                                        child: Center(
                                          child: Text(
                                            'No posts here yet.',
                                            style: TextStyle(
                                              color: Colors.white54,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  for (final post in feedPosts) _postCard(post),
                              ],
                            ),
                          ),
                          const SizedBox(width: 18),
                          SizedBox(
                            width: 326,
                            child: Column(
                              children: [
                                _trendingPanel(),
                                const SizedBox(height: 16),
                                _suggestedPanel(),
                                const SizedBox(height: 16),
                                _rightLivePanel(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _embeddedContent() {
    final feedPosts = visiblePosts;

    return LayoutBuilder(
      builder: (context, box) {
        final compact = box.maxWidth < 430;
        final mobile = box.maxWidth < 600;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!mobile)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: compact ? 2 : 1),
                    child: Icon(
                      Icons.groups_2_rounded,
                      color: const Color(0xFF55DFFF),
                      size: compact ? 21 : 25,
                    ),
                  ),
                  SizedBox(width: compact ? 7 : 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          compact
                              ? 'Neural Community Feed - LIVE NETWORK'
                              : 'Neural Community Feed  -  LIVE NETWORK',
                          maxLines: compact ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: compact
                                ? 16.5
                                : mobile
                                ? 18
                                : 20,
                            height: compact ? 1.12 : 1.2,
                            fontWeight: FontWeight.w900,
                            letterSpacing: compact ? -.35 : 0,
                          ),
                        ),
                        SizedBox(height: compact ? 4 : 2),
                        Text(
                          compact
                              ? 'Real people. Real journeys. LIVE INTELLIGENCE - NEURAL LINK STABLE'
                              : 'Real people. Real journeys. LIVE INTELLIGENCE - COMMUNITY SIGNAL - QUANTUM SYNC ACTIVE - NEURAL LINK STABLE',
                          maxLines: compact ? 2 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: const Color(0xFF8793AD),
                            fontSize: compact ? 8.2 : 9,
                            height: compact ? 1.35 : 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: compact ? 1 : 4),
                  IconButton(
                    onPressed: _loadFeed,
                    tooltip: 'Refresh Feed',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.all(compact ? 5 : 8),
                    constraints: BoxConstraints(
                      minWidth: compact ? 34 : 40,
                      minHeight: compact ? 34 : 40,
                    ),
                    icon: Icon(
                      Icons.refresh_rounded,
                      color: const Color(0xFF6DBBFF),
                      size: compact ? 21 : 24,
                    ),
                  ),
                ],
              ),
            SizedBox(height: compact ? 10 : 13),

            if (mobile) ...[
              _communityQuickComposer(),
              const SizedBox(height: 6),
              _storiesAndReelsSection(),
              const SizedBox(height: 10),
            ] else ...[
              _buildComposer(),
              const SizedBox(height: 13),
              _buildTabs(),
            ],

            if (loading)
              Padding(
                padding: EdgeInsets.all(compact ? 48 : 70),
                child: const Center(child: CircularProgressIndicator()),
              )
            else if (selectedTab == 2)
              _buildLiveFeed()
            else if (feedPosts.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _glassPanel(
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'No posts here yet.',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                  ),
                ),
              )
            else
              for (final post in feedPosts) _postCard(post),
          ],
        );
      },
    );
  }

  Widget _mobileContent() {
    final feedPosts = visiblePosts;

    Widget topAction({
      required IconData icon,
      VoidCallback? onTap,
      Color glow = const Color(0xFF32E9FF),
    }) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF07142B),
              border: Border.all(color: glow.withValues(alpha: .72)),
              boxShadow: [
                BoxShadow(color: glow.withValues(alpha: .18), blurRadius: 16),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 23),
          ),
        ),
      );
    }

    Widget navItem({
      required IconData icon,
      required String label,
      VoidCallback? onTap,
      bool active = false,
      Color accent = const Color(0xFF28E9FF),
    }) {
      return Expanded(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 39,
                    height: 39,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      gradient: active
                          ? LinearGradient(
                              colors: [
                                accent,
                                const Color(0xFF6854FF),
                                const Color(0xFFE044FF),
                              ],
                            )
                          : null,
                      color: active ? null : const Color(0xFF07142A),
                      border: Border.all(
                        color: active
                            ? Colors.white.withValues(alpha: .56)
                            : const Color(0xFF304461),
                      ),
                      boxShadow: active
                          ? [
                              BoxShadow(
                                color: accent.withValues(alpha: .28),
                                blurRadius: 17,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      icon,
                      color: active ? Colors.white : const Color(0xFFB8C5DF),
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: active ? accent : const Color(0xFFA8B4CC),
                      fontSize: 8,
                      fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Container(
          height: 76,
          padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
          decoration: BoxDecoration(
            color: const Color(0xFF020817),
            border: Border(
              bottom: BorderSide(
                color: const Color(0xFF28E7FF).withValues(alpha: .22),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF542CFF).withValues(alpha: .10),
                blurRadius: 24,
              ),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () {},
                icon: const Icon(
                  Icons.menu_rounded,
                  color: Colors.white,
                  size: 31,
                ),
              ),
              ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [
                    Color(0xFF22EAFF),
                    Color(0xFF6559FF),
                    Color(0xFFE044FF),
                  ],
                ).createShader(bounds),
                child: const Text(
                  '999',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 31,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -2,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WELLNESS',
                    style: TextStyle(
                      color: Color(0xFF4CEBFF),
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.1,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'MIND  BODY  SPIRIT',
                    style: TextStyle(
                      color: Color(0xFF8996B8),
                      fontSize: 5.5,
                      letterSpacing: 1.4,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              topAction(
                icon: Icons.add_rounded,
                onTap: _openMobileComposer,
                glow: const Color(0xFFFF42D1),
              ),
              const SizedBox(width: 7),
              topAction(icon: Icons.search_rounded, onTap: widget.onSearch),
              const SizedBox(width: 7),
              topAction(
                icon: Icons.notifications_none_rounded,
                onTap: widget.onNotifications,
                glow: const Color(0xFF8F72FF),
              ),
            ],
          ),
        ),

        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadFeed,
            color: const Color(0xFF3CEAFF),
            backgroundColor: const Color(0xFF07142B),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _communityQuickComposer(),

                  const SizedBox(height: 4),

                  _storiesAndReelsSection(),

                  const SizedBox(height: 3),

                  if (loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 70),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF35E8FF),
                        ),
                      ),
                    )
                  else if (feedPosts.isEmpty)
                    Container(
                      margin: const EdgeInsets.fromLTRB(12, 5, 12, 20),
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF071B38),
                            Color(0xFF0C1531),
                            Color(0xFF160B32),
                          ],
                        ),
                        border: Border.all(
                          color: const Color(0xFF526CFF).withValues(alpha: .42),
                        ),
                      ),
                      child: const Column(
                        children: [
                          Icon(
                            Icons.dynamic_feed_rounded,
                            color: Color(0xFF55E9FF),
                            size: 40,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Your community feed is ready.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Create the first post and start the conversation.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF8E9DBA),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    for (final post in feedPosts) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: _postCard(post),
                      ),
                      const SizedBox(height: 13),
                    ],
                  ],

                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ),

        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF020817),
            border: Border(
              top: BorderSide(
                color: const Color(0xFF526CFF).withValues(alpha: .38),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .55),
                blurRadius: 24,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                navItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  active: true,
                  onTap: () {},
                ),
                navItem(
                  icon: Icons.groups_2_outlined,
                  label: 'Community',
                  onTap: () {},
                ),
                navItem(
                  icon: Icons.video_library_rounded,
                  label: 'Reels',
                  accent: const Color(0xFFFF4DD2),
                  onTap: () {},
                ),
                navItem(
                  icon: Icons.notifications_none_rounded,
                  label: 'Notifications',
                  accent: const Color(0xFF9D76FF),
                  onTap: widget.onNotifications,
                ),
                navItem(
                  icon: Icons.person_rounded,
                  label: 'Profile',
                  accent: const Color(0xFF62C8FF),
                  onTap: widget.onProfile,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return _embeddedContent();
    }

    final desktop = MediaQuery.sizeOf(context).width >= 1050;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(.55, -.7),
                  radius: 1.5,
                  colors: [
                    const Color(0xFF153F7F).withValues(alpha: .22),
                    const Color(0xFF090D20).withValues(alpha: .25),
                    bg,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: desktop
                ? Row(
                    children: [
                      _buildSidebar(),
                      Expanded(child: _desktopContent()),
                    ],
                  )
                : _mobileContent(),
          ),
        ],
      ),
    );
  }
}

class _FeedCommentsSheet extends StatefulWidget {
  const _FeedCommentsSheet({
    required this.postId,
    required this.authorName,
    required this.authorRole,
  });

  final String postId;
  final String authorName;
  final String authorRole;

  @override
  State<_FeedCommentsSheet> createState() => _FeedCommentsSheetState();
}

class _FeedCommentsSheetState extends State<_FeedCommentsSheet> {
  final TextEditingController controller = TextEditingController();

  bool loading = true;
  bool sending = false;

  List<Map<String, dynamic>> comments = [];

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final rows = await Supabase.instance.client
          .from('community_comments')
          .select('id, author_id, author_name, author_role, body, created_at')
          .eq('post_id', widget.postId)
          .order('created_at');

      if (!mounted) return;

      setState(() {
        comments = (rows as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();

        loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _sendComment() async {
    final user = Supabase.instance.client.auth.currentUser;

    final message = controller.text.trim();

    if (user == null || message.isEmpty || sending) {
      return;
    }

    setState(() => sending = true);

    try {
      await Supabase.instance.client.from('community_comments').insert({
        'post_id': widget.postId,
        'author_id': user.id,
        'author_name': widget.authorName,
        'author_role': widget.authorRole,
        'body': message,
      });

      controller.clear();
      await _loadComments();
    } finally {
      if (mounted) {
        setState(() => sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .72,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white12)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: Color(0xFFA679FF),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Comments',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : comments.isEmpty
                  ? const Center(
                      child: Text(
                        'No comments yet.',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(14),
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final comment = comments[index];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 9),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111828),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                comment['author_name']?.toString() ??
                                    '999 Member',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                comment['body']?.toString() ?? '',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Write a comment...',
                        ),
                        onSubmitted: (_) {
                          _sendComment();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: sending ? null : _sendComment,
                      icon: const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
