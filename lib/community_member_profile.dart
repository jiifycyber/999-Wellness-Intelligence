import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommunityMemberProfileScreen extends StatefulWidget {
  const CommunityMemberProfileScreen({
    super.key,
    required this.userId,
    required this.fallbackName,
    required this.fallbackRole,
    required this.fallbackPhoto,
  });

  final String userId;
  final String fallbackName;
  final String fallbackRole;
  final String fallbackPhoto;

  @override
  State<CommunityMemberProfileScreen> createState() =>
      _CommunityMemberProfileScreenState();
}

class _CommunityMemberProfileScreenState
    extends State<CommunityMemberProfileScreen> {
  bool loading = true;
  bool uploading = false;
  bool following = false;

  String name = '999 Member';
  String role = 'customer';
  String photo = '';
  String photoPath = '';
  String cover = '';
  String coverPath = '';
  String bio = '';

  int followers = 0;
  int followingCount = 0;

  List<Map<String, dynamic>> posts = [];

  final Set<String> likedPostIds = {};
  final Map<String, int> likeCounts = {};
  final Map<String, int> commentCounts = {};

  bool get isMine {
    return Supabase.instance.client.auth.currentUser?.id == widget.userId;
  }

  @override
  void initState() {
    super.initState();

    name = widget.fallbackName;
    role = widget.fallbackRole;
    photo = widget.fallbackPhoto;

    _load();
  }

  Future<void> _load() async {
    final current = Supabase.instance.client.auth.currentUser;

    if (current == null) {
      return;
    }

    if (mounted) {
      setState(() {
        loading = true;
      });
    }

    try {
      final social = await Supabase.instance.client
          .from('community_member_profiles')
          .select(
            'display_name, role, photo_url, photo_path, '
            'cover_url, cover_path, bio',
          )
          .eq('user_id', widget.userId)
          .maybeSingle();

      var resolvedPhoto =
          social?['photo_url']?.toString().trim() ?? widget.fallbackPhoto;

      final resolvedPhotoPath = social?['photo_path']?.toString().trim() ?? '';

      if (resolvedPhotoPath.isNotEmpty) {
        try {
          resolvedPhoto = await Supabase.instance.client.storage
              .from('community-profile-media')
              .createSignedUrl(resolvedPhotoPath, 3600);
        } catch (_) {}
      }

      var resolvedCover = social?['cover_url']?.toString().trim() ?? '';

      final resolvedCoverPath = social?['cover_path']?.toString().trim() ?? '';

      if (resolvedCoverPath.isNotEmpty) {
        try {
          resolvedCover = await Supabase.instance.client.storage
              .from('community-profile-media')
              .createSignedUrl(resolvedCoverPath, 3600);
        } catch (_) {}
      }

      final postRows = await Supabase.instance.client
          .from('community_posts')
          .select(
            'id, author_id, author_name, author_role, author_photo_url, '
            'body, media_path, media_type, created_at',
          )
          .eq('author_id', widget.userId)
          .order('created_at', ascending: false);

      final followerRows = await Supabase.instance.client
          .from('community_follows')
          .select('follower_id')
          .eq('following_id', widget.userId);

      final followingRows = await Supabase.instance.client
          .from('community_follows')
          .select('following_id')
          .eq('follower_id', widget.userId);

      final currentFollow = isMine
          ? null
          : await Supabase.instance.client
                .from('community_follows')
                .select('following_id')
                .eq('follower_id', current.id)
                .eq('following_id', widget.userId)
                .maybeSingle();

      final likeRows = await Supabase.instance.client
          .from('community_likes')
          .select('post_id, user_id');

      final commentRows = await Supabase.instance.client
          .from('community_comments')
          .select('post_id');

      final loadedPosts = (postRows as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();

      for (final post in loadedPosts) {
        final mediaPath = post['media_path']?.toString().trim() ?? '';

        if (mediaPath.isEmpty) {
          continue;
        }

        try {
          post['_media_url'] = await Supabase.instance.client.storage
              .from('feed-media')
              .createSignedUrl(mediaPath, 3600);
        } catch (_) {
          post['_media_url'] = '';
        }
      }

      final loadedLikes = <String, int>{};
      final mine = <String>{};

      for (final raw in likeRows as List) {
        final row = Map<String, dynamic>.from(raw as Map);
        final postId = row['post_id']?.toString() ?? '';

        if (postId.isEmpty) {
          continue;
        }

        loadedLikes[postId] = (loadedLikes[postId] ?? 0) + 1;

        if (row['user_id']?.toString() == current.id) {
          mine.add(postId);
        }
      }

      final loadedComments = <String, int>{};

      for (final raw in commentRows as List) {
        final row = Map<String, dynamic>.from(raw as Map);
        final postId = row['post_id']?.toString() ?? '';

        if (postId.isEmpty) {
          continue;
        }

        loadedComments[postId] = (loadedComments[postId] ?? 0) + 1;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        final socialName = social?['display_name']?.toString().trim() ?? '';
        final socialRole = social?['role']?.toString().trim() ?? '';

        if (socialName.isNotEmpty) {
          name = socialName;
        }

        if (socialRole.isNotEmpty) {
          role = socialRole;
        }

        photo = resolvedPhoto;
        photoPath = resolvedPhotoPath;

        cover = resolvedCover;
        coverPath = resolvedCoverPath;

        bio = social?['bio']?.toString() ?? '';

        followers = (followerRows as List).length;
        followingCount = (followingRows as List).length;
        following = currentFollow != null;

        posts = loadedPosts;

        likedPostIds
          ..clear()
          ..addAll(mine);

        likeCounts
          ..clear()
          ..addAll(loadedLikes);

        commentCounts
          ..clear()
          ..addAll(loadedComments);

        loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        loading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to load profile: $error')));
    }
  }

  Future<void> _toggleFollow() async {
    final current = Supabase.instance.client.auth.currentUser;

    if (current == null || isMine) {
      return;
    }

    try {
      if (following) {
        await Supabase.instance.client
            .from('community_follows')
            .delete()
            .eq('follower_id', current.id)
            .eq('following_id', widget.userId);
      } else {
        await Supabase.instance.client.from('community_follows').insert({
          'follower_id': current.id,
          'following_id': widget.userId,
        });
      }

      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update follow: $error')),
      );
    }
  }

  String _safeName(String value) {
    final safe = value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return safe.isEmpty ? 'image.jpg' : safe;
  }

  Future<void> _changeImage(String type) async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null || !isMine || uploading) {
      return;
    }

    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'],
    );

    if (files.isEmpty) {
      return;
    }

    final file = files.first;

    setState(() {
      uploading = true;
    });

    try {
      final bytes = await file.readAsBytes();

      if (bytes.length > 10485760) {
        throw Exception('Image must be 10 MB or smaller.');
      }

      final stamp = DateTime.now().microsecondsSinceEpoch;

      final folder = type == 'cover' ? 'cover' : 'profile';

      final storagePath = '${user.id}/$folder/${stamp}_${_safeName(file.name)}';

      await Supabase.instance.client.storage
          .from('community-profile-media')
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(upsert: false),
          );

      final signedUrl = await Supabase.instance.client.storage
          .from('community-profile-media')
          .createSignedUrl(storagePath, 3600);

      final payload = <String, dynamic>{
        'user_id': user.id,
        'display_name': name,
        'role': role,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      if (type == 'cover') {
        payload['cover_path'] = storagePath;
        payload['cover_url'] = signedUrl;
      } else {
        payload['photo_path'] = storagePath;
        payload['photo_url'] = signedUrl;
      }

      await Supabase.instance.client
          .from('community_member_profiles')
          .upsert(payload, onConflict: 'user_id');

      if (type != 'cover') {
        await Supabase.instance.client
            .from('community_posts')
            .update({'author_photo_url': signedUrl})
            .eq('author_id', user.id);
      }

      await _load();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            type == 'cover' ? 'Cover photo updated.' : 'Profile photo updated.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to update image: $error')));
    } finally {
      if (mounted) {
        setState(() {
          uploading = false;
        });
      }
    }
  }

  Future<void> _toggleLike(String postId) async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null || postId.isEmpty) {
      return;
    }

    final wasLiked = likedPostIds.contains(postId);
    final oldCount = likeCounts[postId] ?? 0;

    setState(() {
      if (wasLiked) {
        likedPostIds.remove(postId);
        likeCounts[postId] = oldCount > 0 ? oldCount - 1 : 0;
      } else {
        likedPostIds.add(postId);
        likeCounts[postId] = oldCount + 1;
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
      if (!mounted) {
        return;
      }

      setState(() {
        if (wasLiked) {
          likedPostIds.add(postId);
        } else {
          likedPostIds.remove(postId);
        }

        likeCounts[postId] = oldCount;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to update like: $error')));
    }
  }

  Future<Map<String, String>> _currentIdentity() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      return {'name': '999 Member', 'role': 'customer'};
    }

    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('full_name, role')
          .eq('id', user.id)
          .maybeSingle();

      final resolvedName =
          profile?['full_name']?.toString().trim() ??
          user.userMetadata?['full_name']?.toString().trim() ??
          '999 Member';

      final resolvedRole = profile?['role']?.toString() == 'provider'
          ? 'provider'
          : 'customer';

      return {
        'name': resolvedName.isEmpty ? '999 Member' : resolvedName,
        'role': resolvedRole,
      };
    } catch (_) {
      return {
        'name': user.userMetadata?['full_name']?.toString() ?? '999 Member',
        'role': 'customer',
      };
    }
  }

  Future<void> _openComments(Map<String, dynamic> post) async {
    final postId = post['id']?.toString() ?? '';

    if (postId.isEmpty) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF070D19),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        return _ProfileCommentsSheet(
          postId: postId,
          identityLoader: _currentIdentity,
        );
      },
    );

    await _load();
  }

  String _timeAgo(dynamic value) {
    if (value == null) {
      return '';
    }

    final date = DateTime.tryParse(value.toString());

    if (date == null) {
      return '';
    }

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

  Widget _avatar({double size = 112}) {
    final initial = name.trim().isEmpty ? '9' : name.trim()[0].toUpperCase();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFA449FF), Color(0xFF525EFF), Color(0xFF35D7FF)],
        ),
        border: Border.all(color: const Color(0xFF73E5FF), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7137FF).withValues(alpha: .38),
            blurRadius: 30,
          ),
        ],
      ),
      padding: const EdgeInsets.all(3),
      child: ClipOval(
        child: Container(
          color: const Color(0xFF111A31),
          child: photo.trim().isNotEmpty
              ? Image.network(
                  photo,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    return Center(
                      child: Text(
                        initial,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: size * .32,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    );
                  },
                )
              : Center(
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: size * .32,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _stat(int value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF09152A),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: const Color(0xFF43628C).withValues(alpha: .35),
          ),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF8290AC),
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: .7,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF763FFF), Color(0xFF2958AF)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 19),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF75849F),
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .7,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _panel({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(17),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D1B35), Color(0xFF081225), Color(0xFF060B16)],
        ),
        borderRadius: BorderRadius.circular(21),
        border: Border.all(
          color: const Color(0xFF426391).withValues(alpha: .38),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _profileHeader() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF07101F),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0xFF5B6FC4).withValues(alpha: .42),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 245,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (cover.trim().isNotEmpty)
                  Image.network(
                    cover,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) {
                      return _defaultCover();
                    },
                  )
                else
                  _defaultCover(),

                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        const Color(0xFF050B17).withValues(alpha: .88),
                      ],
                    ),
                  ),
                ),

                if (isMine)
                  Positioned(
                    right: 18,
                    bottom: 18,
                    child: FilledButton.icon(
                      onPressed: uploading ? null : () => _changeImage('cover'),
                      icon: const Icon(Icons.photo_camera_outlined, size: 17),
                      label: const Text('EDIT COVER'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xD9161E34),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Transform.translate(
              offset: const Offset(0, -44),
              child: Column(
                children: [
                  LayoutBuilder(
                    builder: (context, box) {
                      final wide = box.maxWidth >= 700;

                      final identity = Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              _avatar(size: 118),
                              if (isMine)
                                Positioned(
                                  right: -2,
                                  bottom: 2,
                                  child: InkWell(
                                    onTap: uploading
                                        ? null
                                        : () => _changeImage('profile'),
                                    borderRadius: BorderRadius.circular(30),
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFFA44DFF),
                                            Color(0xFF4568FF),
                                          ],
                                        ),
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt_rounded,
                                        color: Colors.white,
                                        size: 17,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 7,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 25,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const Icon(
                                        Icons.verified_rounded,
                                        color: Color(0xFF45B7FF),
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    role == 'provider'
                                        ? 'Wellness Provider'
                                        : '999 Wellness Community Member',
                                    style: const TextStyle(
                                      color: Color(0xFF8EA1C2),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );

                      if (!wide) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            identity,
                            const SizedBox(height: 14),
                            _relationshipButton(),
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(child: identity),
                          const SizedBox(width: 18),
                          SizedBox(width: 190, child: _relationshipButton()),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 18),

                  Row(
                    children: [
                      _stat(followers, 'Followers'),
                      const SizedBox(width: 9),
                      _stat(followingCount, 'Following'),
                      const SizedBox(width: 9),
                      _stat(posts.length, 'Posts'),
                    ],
                  ),

                  if (bio.trim().isNotEmpty) ...[
                    const SizedBox(height: 17),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        bio,
                        style: const TextStyle(
                          color: Color(0xFFC7D0E1),
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _defaultCover() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF35146D),
            Color(0xFF182E75),
            Color(0xFF07506B),
            Color(0xFF080C1A),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 80,
            top: 25,
            child: Icon(
              Icons.blur_circular_rounded,
              size: 170,
              color: Colors.white10,
            ),
          ),
          const Positioned(
            left: 24,
            top: 22,
            child: Text(
              '999 WELLNESS COMMUNITY',
              style: TextStyle(
                color: Color(0xFFAF9BFF),
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.7,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _relationshipButton() {
    if (isMine) {
      return OutlinedButton.icon(
        onPressed: uploading
            ? null
            : () {
                showModalBottomSheet<void>(
                  context: context,
                  backgroundColor: const Color(0xFF0A1121),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  builder: (_) {
                    return SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              onTap: () {
                                Navigator.of(context).pop();
                                _changeImage('profile');
                              },
                              leading: const Icon(
                                Icons.account_circle_outlined,
                                color: Color(0xFFB379FF),
                              ),
                              title: const Text(
                                'Change Profile Photo',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            ListTile(
                              onTap: () {
                                Navigator.of(context).pop();
                                _changeImage('cover');
                              },
                              leading: const Icon(
                                Icons.panorama_outlined,
                                color: Color(0xFF4BD8FF),
                              ),
                              title: const Text(
                                'Change Cover Photo',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
        icon: const Icon(Icons.edit_rounded),
        label: const Text('EDIT PROFILE'),
      );
    }

    return FilledButton.icon(
      onPressed: _toggleFollow,
      icon: Icon(
        following ? Icons.check_rounded : Icons.person_add_alt_1_rounded,
      ),
      label: Text(following ? 'FOLLOWING' : 'FOLLOW'),
    );
  }

  Widget _post(Map<String, dynamic> post) {
    final postId = post['id']?.toString() ?? '';
    final body = post['body']?.toString().trim() ?? '';
    final media = post['_media_url']?.toString().trim() ?? '';
    final postPhoto = post['author_photo_url']?.toString().trim() ?? photo;
    final postName = post['author_name']?.toString().trim() ?? name;
    final postRole = post['author_role']?.toString().trim() ?? role;

    final liked = likedPostIds.contains(postId);

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0E1B34), Color(0xFF081224)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF456392).withValues(alpha: .43),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 7),
              child: Row(
                children: [
                  _smallAvatar(postPhoto, postName, size: 43),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 7,
                          children: [
                            Text(
                              postName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: postRole == 'provider'
                                    ? const Color(0xFF123E4A)
                                    : const Color(0xFF172E55),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                postRole == 'provider'
                                    ? 'Wellness Provider'
                                    : 'Customer',
                                style: TextStyle(
                                  color: postRole == 'provider'
                                      ? const Color(0xFF64E7F4)
                                      : const Color(0xFF80B8FF),
                                  fontSize: 7.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _timeAgo(post['created_at']),
                          style: const TextStyle(
                            color: Color(0xFF7484A1),
                            fontSize: 8.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            InkWell(
              onTap: () => _openComments(post),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (body.isNotEmpty)
                      Text(
                        body,
                        style: const TextStyle(
                          color: Color(0xFFE8EDF7),
                          fontSize: 13,
                          height: 1.48,
                        ),
                      ),
                    if (body.isNotEmpty && media.isNotEmpty)
                      const SizedBox(height: 13),
                    if (media.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          media,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) {
                            return Container(
                              height: 220,
                              alignment: Alignment.center,
                              color: const Color(0xFF091326),
                              child: const Icon(
                                Icons.broken_image_outlined,
                                color: Colors.white38,
                                size: 34,
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),

            Divider(height: 1, color: Colors.white.withValues(alpha: .07)),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () => _toggleLike(postId),
                    icon: Icon(
                      liked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 18,
                      color: liked
                          ? const Color(0xFFFF557E)
                          : const Color(0xFF96A5BF),
                    ),
                    label: Text(
                      '${likeCounts[postId] ?? 0}',
                      style: const TextStyle(color: Color(0xFFC5CEDE)),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _openComments(post),
                    icon: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 17,
                    ),
                    label: Text('${commentCounts[postId] ?? 0} Comments'),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _openComments(post),
                    icon: const Icon(Icons.reply_rounded, size: 17),
                    label: const Text('Respond'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallAvatar(String image, String displayName, {double size = 42}) {
    final initial = displayName.trim().isEmpty
        ? '9'
        : displayName.trim()[0].toUpperCase();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF65CFFF), width: 1.4),
      ),
      clipBehavior: Clip.antiAlias,
      child: image.trim().isNotEmpty
          ? Image.network(
              image,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return Container(
                  color: const Color(0xFF192446),
                  alignment: Alignment.center,
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
          : Container(
              color: const Color(0xFF192446),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
    );
  }

  Widget _aboutPanel() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle(
            icon: Icons.person_outline_rounded,
            title: 'About',
            subtitle: 'MEMBER PROFILE',
          ),
          const SizedBox(height: 15),
          Text(
            bio.trim().isNotEmpty
                ? bio
                : role == 'provider'
                ? 'Wellness provider on the 999 Wellness network.'
                : 'Member of the 999 Wellness community.',
            style: const TextStyle(
              color: Color(0xFFBBC5D8),
              fontSize: 11,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              const Icon(
                Icons.people_alt_outlined,
                color: Color(0xFF5EDCFF),
                size: 18,
              ),
              const SizedBox(width: 9),
              Text(
                '$followers followers',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.dynamic_feed_outlined,
                color: Color(0xFFB36CFF),
                size: 18,
              ),
              const SizedBox(width: 9),
              Text(
                '${posts.length} community posts',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _activityPanel() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle(
            icon: Icons.bolt_rounded,
            title: 'Community Activity',
            subtitle: '999 WELLNESS NETWORK',
          ),
          const SizedBox(height: 14),
          _activityLine(Icons.article_outlined, '${posts.length} Posts'),
          _activityLine(Icons.people_outline_rounded, '$followers Followers'),
          _activityLine(
            Icons.person_add_alt_rounded,
            '$followingCount Following',
          ),
          if (!isMine) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _toggleFollow,
              icon: Icon(
                following
                    ? Icons.check_rounded
                    : Icons.person_add_alt_1_rounded,
              ),
              label: Text(following ? 'Following' : 'Follow Member'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _activityLine(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF8295BC), size: 17),
          const SizedBox(width: 9),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFFC6CFDF),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _postsColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _panel(
          child: _sectionTitle(
            icon: Icons.dynamic_feed_rounded,
            title: '$name Posts',
            subtitle: 'COMMUNITY CONVERSATIONS',
          ),
        ),
        const SizedBox(height: 12),
        if (posts.isEmpty)
          _panel(
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(
                    Icons.forum_outlined,
                    color: Color(0xFF7183A5),
                    size: 34,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'No posts yet.',
                    style: TextStyle(
                      color: Colors.white54,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          for (final post in posts) _post(post),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020611),
      appBar: AppBar(
        backgroundColor: const Color(0xFF060C19),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            onPressed: _load,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final desktop = constraints.maxWidth >= 1100;

                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    desktop ? 28 : 14,
                    22,
                    desktop ? 28 : 14,
                    80,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1450),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _profileHeader(),
                          const SizedBox(height: 18),

                          if (desktop)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 285,
                                  child: Column(
                                    children: [
                                      _aboutPanel(),
                                      const SizedBox(height: 13),
                                      _activityPanel(),
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 16),

                                Expanded(flex: 5, child: _postsColumn()),

                                const SizedBox(width: 16),

                                SizedBox(
                                  width: 260,
                                  child: _panel(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        _sectionTitle(
                                          icon: Icons.hub_outlined,
                                          title: '999 Wellness Network',
                                          subtitle: 'CONNECTED COMMUNITY',
                                        ),
                                        const SizedBox(height: 15),
                                        const Text(
                                          'Posts on this profile are live community posts. You can like them, open the conversation, and respond directly.',
                                          style: TextStyle(
                                            color: Color(0xFF9EABC2),
                                            fontSize: 10.5,
                                            height: 1.55,
                                          ),
                                        ),
                                        const SizedBox(height: 15),
                                        Container(
                                          padding: const EdgeInsets.all(13),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF09182A),
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            border: Border.all(
                                              color: const Color(0xFF5FE3A7)
                                                  .withValues(alpha: .20),
                                            ),
                                          ),
                                          child: const Row(
                                            children: [
                                              Icon(
                                                Icons.verified_user_outlined,
                                                color: Color(0xFF5FE3A7),
                                                size: 20,
                                              ),
                                              SizedBox(width: 9),
                                              Expanded(
                                                child: Text(
                                                  'REAL-TIME SOCIAL PROFILE',
                                                  style: TextStyle(
                                                    color: Color(0xFF5FE3A7),
                                                    fontSize: 8,
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: .8,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else ...[
                            _aboutPanel(),
                            const SizedBox(height: 13),
                            _activityPanel(),
                            const SizedBox(height: 16),
                            _postsColumn(),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _ProfileCommentsSheet extends StatefulWidget {
  const _ProfileCommentsSheet({
    required this.postId,
    required this.identityLoader,
  });

  final String postId;
  final Future<Map<String, String>> Function() identityLoader;

  @override
  State<_ProfileCommentsSheet> createState() => _ProfileCommentsSheetState();
}

class _ProfileCommentsSheetState extends State<_ProfileCommentsSheet> {
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
          .select(
            'id, post_id, author_id, author_name, '
            'author_role, body, created_at',
          )
          .eq('post_id', widget.postId)
          .order('created_at');

      if (!mounted) {
        return;
      }

      setState(() {
        comments = (rows as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();

        loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load comments: $error')),
      );
    }
  }

  Future<void> _sendComment() async {
    final user = Supabase.instance.client.auth.currentUser;
    final body = controller.text.trim();

    if (user == null || body.isEmpty || sending) {
      return;
    }

    setState(() {
      sending = true;
    });

    try {
      final identity = await widget.identityLoader();

      await Supabase.instance.client.from('community_comments').insert({
        'post_id': widget.postId,
        'author_id': user.id,
        'author_name': identity['name'] ?? '999 Member',
        'author_role': identity['role'] == 'provider' ? 'provider' : 'customer',
        'body': body,
      });

      controller.clear();

      await _loadComments();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to post response: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          sending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * .72,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 46,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 16, 18, 12),
                child: Row(
                  children: [
                    Icon(Icons.forum_outlined, color: Color(0xFF70DFFF)),
                    SizedBox(width: 10),
                    Text(
                      'Post Conversation',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.white.withValues(alpha: .08)),
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : comments.isEmpty
                    ? const Center(
                        child: Text(
                          'No responses yet. Start the conversation.',
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: comments.length,
                        itemBuilder: (context, index) {
                          final comment = comments[index];

                          final commentName =
                              comment['author_name']?.toString() ??
                              '999 Member';

                          final commentRole =
                              comment['author_role']?.toString() ?? 'customer';

                          final commentBody = comment['body']?.toString() ?? '';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D172A),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: const Color(0xFF3E5C85)
                                    .withValues(alpha: .32),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        commentName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      commentRole == 'provider'
                                          ? 'Wellness Provider'
                                          : 'Customer',
                                      style: TextStyle(
                                        color: commentRole == 'provider'
                                            ? const Color(0xFF5FE5F4)
                                            : const Color(0xFF78B7FF),
                                        fontSize: 8,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  commentBody,
                                  style: const TextStyle(
                                    color: Color(0xFFDCE3F0),
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 11, 14, 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF07101F),
                  border: Border(
                    top: BorderSide(color: Colors.white.withValues(alpha: .08)),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        minLines: 1,
                        maxLines: 4,
                        style: const TextStyle(color: Colors.white),
                        onSubmitted: (_) => _sendComment(),
                        decoration: const InputDecoration(
                          hintText: 'Write a response...',
                          prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: FilledButton(
                        onPressed: sending ? null : _sendComment,
                        style: FilledButton.styleFrom(
                          padding: EdgeInsets.zero,
                          backgroundColor: const Color(0xFF754AFF),
                        ),
                        child: sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
