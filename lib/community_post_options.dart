import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _PostEditResult {
  const _PostEditResult({
    required this.body,
    required this.removePhoto,
    this.newPhoto,
    this.newPhotoBytes,
  });

  final String body;
  final bool removePhoto;
  final PlatformFile? newPhoto;
  final Uint8List? newPhotoBytes;
}

Future<void> showCommunityPostOptions({
  required BuildContext context,
  required Map<String, dynamic> post,
  required Future<void> Function() onChanged,
}) async {
  final user = Supabase.instance.client.auth.currentUser;
  final postId = post['id']?.toString() ?? '';
  final authorId = post['author_id']?.toString() ?? '';

  if (user == null || postId.isEmpty || authorId != user.id) {
    return;
  }

  final action = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return SimpleDialog(
        backgroundColor: const Color(0xFF0C1426),
        title: const Text(
          'Post Options',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        children: [
          SimpleDialogOption(
            onPressed: () {
              Navigator.of(dialogContext).pop('edit');
            },
            child: const Row(
              children: [
                Icon(Icons.edit_outlined, color: Color(0xFF75DFFF)),
                SizedBox(width: 12),
                Text('Edit Post', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.of(dialogContext).pop('delete');
            },
            child: const Row(
              children: [
                Icon(Icons.delete_outline_rounded, color: Color(0xFFFF6D8F)),
                SizedBox(width: 12),
                Text('Delete Post', style: TextStyle(color: Color(0xFFFF8AA5))),
              ],
            ),
          ),
        ],
      );
    },
  );

  if (!context.mounted || action == null) {
    return;
  }

  if (action == 'edit') {
    await _editCommunityPost(
      context: context,
      post: post,
      onChanged: onChanged,
    );
    return;
  }

  if (action == 'delete') {
    await _deleteCommunityPost(
      context: context,
      post: post,
      onChanged: onChanged,
    );
  }
}

Future<void> _editCommunityPost({
  required BuildContext context,
  required Map<String, dynamic> post,
  required Future<void> Function() onChanged,
}) async {
  final user = Supabase.instance.client.auth.currentUser;
  final postId = post['id']?.toString() ?? '';
  final authorId = post['author_id']?.toString() ?? '';

  if (user == null || postId.isEmpty || authorId != user.id) {
    return;
  }

  final result = await showDialog<_PostEditResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) {
      return _FullPostEditor(post: post);
    },
  );

  if (!context.mounted || result == null) {
    return;
  }

  final oldMediaPath = post['media_path']?.toString().trim() ?? '';

  if (result.body.isEmpty &&
      result.newPhoto == null &&
      (result.removePhoto || oldMediaPath.isEmpty)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('A post must contain text or a photo.')),
    );
    return;
  }

  String? uploadedPath;

  try {
    final update = <String, dynamic>{'body': result.body};

    if (result.newPhoto != null && result.newPhotoBytes != null) {
      final file = result.newPhoto!;
      final bytes = result.newPhotoBytes!;

      if (bytes.length > 15728640) {
        throw Exception('Feed photos must be 15 MB or smaller.');
      }

      final stamp = DateTime.now().microsecondsSinceEpoch;

      uploadedPath = '${user.id}/posts/${stamp}_${_safeFileName(file.name)}';

      await Supabase.instance.client.storage
          .from('feed-media')
          .uploadBinary(
            uploadedPath,
            bytes,
            fileOptions: const FileOptions(upsert: false),
          );

      update['media_path'] = uploadedPath;
      update['media_type'] = 'image';
    } else if (result.removePhoto) {
      update['media_path'] = null;
      update['media_type'] = null;
    }

    await Supabase.instance.client
        .from('community_posts')
        .update(update)
        .eq('id', postId)
        .eq('author_id', user.id);

    if ((result.removePhoto || result.newPhoto != null) &&
        oldMediaPath.isNotEmpty &&
        oldMediaPath != uploadedPath) {
      try {
        await Supabase.instance.client.storage.from('feed-media').remove([
          oldMediaPath,
        ]);
      } catch (_) {}
    }

    await onChanged();

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Post updated.')));
  } catch (error) {
    if (uploadedPath != null) {
      try {
        await Supabase.instance.client.storage.from('feed-media').remove([
          uploadedPath,
        ]);
      } catch (_) {}
    }

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Unable to edit post: $error')));
  }
}

Future<void> _deleteCommunityPost({
  required BuildContext context,
  required Map<String, dynamic> post,
  required Future<void> Function() onChanged,
}) async {
  final user = Supabase.instance.client.auth.currentUser;
  final postId = post['id']?.toString() ?? '';
  final authorId = post['author_id']?.toString() ?? '';
  final mediaPath = post['media_path']?.toString().trim() ?? '';

  if (user == null || postId.isEmpty || authorId != user.id) {
    return;
  }

  final confirmed =
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: const Color(0xFF0C1426),
            title: const Text(
              'Delete Post?',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            content: const Text(
              'This post will be permanently deleted.',
              style: TextStyle(color: Color(0xFFB9C4DB)),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFD93C67),
                ),
                onPressed: () {
                  Navigator.of(dialogContext).pop(true);
                },
                child: const Text('Delete'),
              ),
            ],
          );
        },
      ) ??
      false;

  if (!confirmed) {
    return;
  }

  try {
    try {
      await Supabase.instance.client
          .from('community_likes')
          .delete()
          .eq('post_id', postId);
    } catch (_) {}

    try {
      await Supabase.instance.client
          .from('community_comments')
          .delete()
          .eq('post_id', postId);
    } catch (_) {}

    await Supabase.instance.client
        .from('community_posts')
        .delete()
        .eq('id', postId)
        .eq('author_id', user.id);

    if (mediaPath.isNotEmpty) {
      try {
        await Supabase.instance.client.storage.from('feed-media').remove([
          mediaPath,
        ]);
      } catch (_) {}
    }

    await onChanged();

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Post deleted.')));
  } catch (error) {
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Unable to delete post: $error')));
  }
}

String _safeFileName(String value) {
  final safe = value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  return safe.isEmpty ? 'feed_image.jpg' : safe;
}

class _FullPostEditor extends StatefulWidget {
  const _FullPostEditor({required this.post});

  final Map<String, dynamic> post;

  @override
  State<_FullPostEditor> createState() => _FullPostEditorState();
}

class _FullPostEditorState extends State<_FullPostEditor> {
  late final TextEditingController _controller;

  PlatformFile? _newPhoto;
  Uint8List? _newPhotoBytes;

  bool _removePhoto = false;
  bool _picking = false;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(
      text: widget.post['body']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _existingPhotoUrl {
    return widget.post['_media_url']?.toString().trim() ?? '';
  }

  bool get _hasExistingPhoto {
    return !_removePhoto && _newPhoto == null && _existingPhotoUrl.isNotEmpty;
  }

  Future<void> _pickPhoto() async {
    if (_picking) {
      return;
    }

    setState(() {
      _picking = true;
    });

    try {
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

      if (files.isEmpty) {
        return;
      }

      final file = files.first;
      final bytes = await file.readAsBytes();

      if (bytes.length > 15728640) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo must be 15 MB or smaller.')),
        );

        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _newPhoto = file;
        _newPhotoBytes = bytes;
        _removePhoto = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _picking = false;
        });
      }
    }
  }

  void _removeCurrentPhoto() {
    setState(() {
      _newPhoto = null;
      _newPhotoBytes = null;
      _removePhoto = true;
    });
  }

  void _undoPhotoChange() {
    setState(() {
      _newPhoto = null;
      _newPhotoBytes = null;
      _removePhoto = false;
    });
  }

  void _save() {
    Navigator.of(context).pop(
      _PostEditResult(
        body: _controller.text.trim(),
        removePhoto: _removePhoto,
        newPhoto: _newPhoto,
        newPhotoBytes: _newPhotoBytes,
      ),
    );
  }

  Widget _mediaPreview() {
    if (_newPhotoBytes != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(
              _newPhotoBytes!,
              width: double.infinity,
              height: 300,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: IconButton.filled(
              onPressed: _removeCurrentPhoto,
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xCC172033),
              ),
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.white,
              ),
            ),
          ),
        ],
      );
    }

    if (_hasExistingPhoto) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              _existingPhotoUrl,
              width: double.infinity,
              height: 300,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return Container(
                  height: 220,
                  alignment: Alignment.center,
                  color: const Color(0xFF0C1830),
                  child: const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white38,
                    size: 42,
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: IconButton.filled(
              onPressed: _removeCurrentPhoto,
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xCC172033),
              ),
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.white,
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      height: 130,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF0C1830),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            color: Colors.white38,
            size: 34,
          ),
          SizedBox(height: 8),
          Text('No photo attached', style: TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = _newPhoto != null || _hasExistingPhoto;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 820),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF111B38), Color(0xFF091226), Color(0xFF070C18)],
            ),
            border: Border.all(
              color: const Color(0xFF725CFF).withValues(alpha: .55),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6D3EFF).withValues(alpha: .22),
                blurRadius: 38,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: const Color(0xFF39D8FF).withValues(alpha: .10),
                blurRadius: 50,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              children: [
                Positioned(
                  top: -80,
                  right: -60,
                  child: IgnorePointer(
                    child: Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7E4CFF)
                                .withValues(alpha: .16),
                            blurRadius: 90,
                            spreadRadius: 30,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -100,
                  left: -80,
                  child: IgnorePointer(
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF20C8FF)
                                .withValues(alpha: .09),
                            blurRadius: 100,
                            spreadRadius: 30,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(18, 15, 12, 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF172759).withValues(alpha: .94),
                            const Color(0xFF101B40).withValues(alpha: .92),
                            const Color(0xFF0B1530).withValues(alpha: .95),
                          ],
                        ),
                        border: Border(
                          bottom: BorderSide(
                            color: const Color(0xFF6078D8)
                                .withValues(alpha: .30),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF8B4CFF),
                                  Color(0xFF4B4EFF),
                                  Color(0xFF1E7CEB),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF7247FF)
                                      .withValues(alpha: .35),
                                  blurRadius: 18,
                                ),
                              ],
                            ),
                            child: IconButton(
                              tooltip: 'Close',
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'EDIT POST',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: .8,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'POST INTELLIGENCE CONTROL',
                                  style: TextStyle(
                                    color: Color(0xFF8FA9E8),
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.7,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF153E5A), Color(0xFF172C63)],
                              ),
                              border: Border.all(
                                color: const Color(0xFF58DFFF)
                                    .withValues(alpha: .45),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.auto_awesome_rounded,
                                  color: Color(0xFF5FE5FF),
                                  size: 13,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  'V3',
                                  style: TextStyle(
                                    color: Color(0xFF8EEBFF),
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: .8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.edit_note_rounded,
                                  color: Color(0xFF74DDFF),
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'POST MESSAGE',
                                  style: TextStyle(
                                    color: Color(0xFFC6D5F6),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF13234A),
                                    Color(0xFF0D1833),
                                  ],
                                ),
                                border: Border.all(
                                  color: const Color(0xFF7657FF)
                                      .withValues(alpha: .70),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF734DFF)
                                        .withValues(alpha: .12),
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                              child: TextField(
                                controller: _controller,
                                autofocus: true,
                                minLines: 4,
                                maxLines: 10,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                                decoration: const InputDecoration(
                                  hintText: "What's on your mind?",
                                  hintStyle: TextStyle(
                                    color: Color(0xFF8090B3),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.all(18),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Row(
                              children: [
                                Icon(
                                  Icons.photo_library_outlined,
                                  color: Color(0xFFB76DFF),
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'POST MEDIA',
                                  style: TextStyle(
                                    color: Color(0xFFC6D5F6),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(22),
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF101D3B),
                                    Color(0xFF0B1428),
                                  ],
                                ),
                                border: Border.all(
                                  color: const Color(0xFF4C669E)
                                      .withValues(alpha: .45),
                                ),
                              ),
                              child: _mediaPreview(),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF1B315E),
                                          Color(0xFF18234B),
                                        ],
                                      ),
                                      border: Border.all(
                                        color: const Color(0xFF63DFFF)
                                            .withValues(alpha: .42),
                                      ),
                                    ),
                                    child: TextButton.icon(
                                      onPressed: _picking ? null : _pickPhoto,
                                      icon: Icon(
                                        hasPhoto
                                            ? Icons.photo_camera_back_outlined
                                            : Icons
                                                  .add_photo_alternate_outlined,
                                        color: const Color(0xFF75E3FF),
                                      ),
                                      label: Text(
                                        hasPhoto
                                            ? 'Replace Photo'
                                            : 'Add Photo',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (hasPhoto) ...[
                                  const SizedBox(width: 10),
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF4A1934),
                                          Color(0xFF2D1427),
                                        ],
                                      ),
                                      border: Border.all(
                                        color: const Color(0xFFFF648C)
                                            .withValues(alpha: .42),
                                      ),
                                    ),
                                    child: IconButton(
                                      tooltip: 'Remove Photo',
                                      onPressed: _removeCurrentPhoto,
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: Color(0xFFFF7B9A),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (_removePhoto) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: _undoPhotoChange,
                                  icon: const Icon(
                                    Icons.undo_rounded,
                                    color: Color(0xFF95B9FF),
                                  ),
                                  label: const Text(
                                    'Restore Current Photo',
                                    style: TextStyle(color: Color(0xFFB8C9F4)),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF08101F).withValues(alpha: .96),
                        border: Border(
                          top: BorderSide(
                            color: const Color(0xFF5268A5)
                                .withValues(alpha: .30),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(50),
                                side: BorderSide(
                                  color: const Color(0xFF63749D)
                                      .withValues(alpha: .50),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Color(0xFFAEB9D1),
                              ),
                              label: const Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Color(0xFFC3CBE0),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFB04DFF),
                                    Color(0xFF7444FF),
                                    Color(0xFF20CFFF),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF7A4AFF)
                                        .withValues(alpha: .30),
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _save,
                                  borderRadius: BorderRadius.circular(16),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.check_circle_outline_rounded,
                                        color: Colors.white,
                                        size: 19,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'SAVE CHANGES',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: .7,
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
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
