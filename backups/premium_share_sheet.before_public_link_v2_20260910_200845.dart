import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> showPremiumWellnessShareSheet(
  BuildContext context,
  Map<String, dynamic> post,
) async {
  final postId = post['id']?.toString().trim() ?? '';
  final authorName =
      post['author_name']?.toString().trim() ?? '999 Wellness Member';
  final body = post['body']?.toString().trim() ?? '';
  final mediaUrl = post['_media_url']?.toString().trim() ?? '';

  final base = Uri.base;

  final shareUrl = base
      .replace(
        queryParameters: {
          ...base.queryParameters,
          if (postId.isNotEmpty) 'post': postId,
        },
      )
      .toString();

  final shareText = body.isNotEmpty
      ? '$body\n\nShared from 999 Wellness\n$shareUrl'
      : 'Check out this post from $authorName on 999 Wellness.\n\n$shareUrl';

  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    useSafeArea: false,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: .72),
    builder: (sheetContext) {
      return _PremiumWellnessShareSheet(
        authorName: authorName,
        body: body,
        mediaUrl: mediaUrl,
        shareUrl: shareUrl,
        shareText: shareText,
      );
    },
  );
}

class _PremiumWellnessShareSheet extends StatelessWidget {
  const _PremiumWellnessShareSheet({
    required this.authorName,
    required this.body,
    required this.mediaUrl,
    required this.shareUrl,
    required this.shareText,
  });

  final String authorName;
  final String body;
  final String mediaUrl;
  final String shareUrl;
  final String shareText;

  Future<void> _copyLink(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: shareUrl));

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Post link copied.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _systemShare(BuildContext context) async {
    try {
      await SharePlus.instance.share(
        ShareParams(title: '999 Wellness', text: shareText),
      );
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open system sharing.')),
      );
    }
  }

  Future<void> _openUrl(
    BuildContext context,
    String url,
    String errorMessage,
  ) async {
    try {
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );

      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errorMessage)));
    }
  }

  Widget _shareTarget({
    required String label,
    required Widget icon,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 58,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: colors,
                  ),
                  border: Border.all(color: colors.last.withValues(alpha: .75)),
                  boxShadow: [
                    BoxShadow(
                      color: colors.first.withValues(alpha: .28),
                      blurRadius: 14,
                    ),
                  ],
                ),
                child: icon,
              ),
              const SizedBox(height: 7),
              Text(
                label,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFE5EDFF),
                  fontSize: 7.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);

    final sheetHeight = screen.height < 650
        ? screen.height * .60
        : screen.height * .52;

    final previewText = body.isEmpty
        ? 'Share this wellness post with your network.'
        : body;

    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(maxWidth: 620, maxHeight: sheetHeight),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF071C49), Color(0xFF09163B), Color(0xFF150832)],
            ),
            border: Border(
              top: BorderSide(
                color: const Color(0xFF35E5FF).withValues(alpha: .90),
                width: 1.5,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF24DFFF).withValues(alpha: .20),
                blurRadius: 38,
              ),
              BoxShadow(
                color: const Color(0xFF8E42FF).withValues(alpha: .20),
                blurRadius: 48,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),

              Container(
                width: 72,
                height: 5,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(50),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2BE5FF), Color(0xFF9043FF)],
                  ),
                ),
              ),

              Flexible(
                fit: FlexFit.loose,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(17, 15, 17, 22),
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF8B40FF),
                                Color(0xFF3B5CFF),
                                Color(0xFF21DFFF),
                              ],
                            ),
                            border: Border.all(
                              color: const Color(0xFF48EBFF),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.hub_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),

                        const SizedBox(width: 12),

                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Share This Post',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Spread wellness. Inspire change.',
                                style: TextStyle(
                                  color: Color(0xFFA9B8DD),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF0A2350),
                            border: Border.all(color: const Color(0xFF5878FF)),
                          ),
                          child: IconButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: const Color(0xFF081B40),
                        border: Border.all(
                          color: const Color(0xFF32DFFF).withValues(alpha: .65),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 86,
                            height: 70,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(13),
                              color: const Color(0xFF09152D),
                            ),
                            child: mediaUrl.isNotEmpty
                                ? Image.network(
                                    mediaUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) {
                                      return const Center(
                                        child: Icon(
                                          Icons.dynamic_feed_rounded,
                                          color: Color(0xFF65E2FF),
                                          size: 28,
                                        ),
                                      );
                                    },
                                  )
                                : const Center(
                                    child: Icon(
                                      Icons.dynamic_feed_rounded,
                                      color: Color(0xFF65E2FF),
                                      size: 28,
                                    ),
                                  ),
                          ),

                          const SizedBox(width: 11),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  authorName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                const Text(
                                  '999 Wellness',
                                  style: TextStyle(
                                    color: Color(0xFF8FA5D4),
                                    fontSize: 8.5,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  previewText,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFFBBC8E4),
                                    fontSize: 8.5,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    SizedBox(
                      height: 76,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _shareTarget(
                            label: 'Copy Link',
                            colors: const [
                              Color(0xFF1268D7),
                              Color(0xFF17DCF6),
                            ],
                            icon: const Icon(
                              Icons.link_rounded,
                              color: Colors.white,
                            ),
                            onTap: () => _copyLink(context),
                          ),

                          _shareTarget(
                            label: 'Messages',
                            colors: const [
                              Color(0xFF079E58),
                              Color(0xFF2AE69A),
                            ],
                            icon: const Icon(
                              Icons.chat_bubble_rounded,
                              color: Colors.white,
                              size: 21,
                            ),
                            onTap: () {
                              final encoded = Uri.encodeComponent(shareText);

                              _openUrl(
                                context,
                                'sms:?body=$encoded',
                                'Unable to open Messages.',
                              );
                            },
                          ),

                          _shareTarget(
                            label: 'Facebook',
                            colors: const [
                              Color(0xFF1648D7),
                              Color(0xFF287DFF),
                            ],
                            icon: const Text(
                              'f',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            onTap: () {
                              final encoded = Uri.encodeComponent(shareUrl);

                              _openUrl(
                                context,
                                'https://www.facebook.com/sharer/sharer.php?u=$encoded',
                                'Unable to open Facebook.',
                              );
                            },
                          ),

                          _shareTarget(
                            label: 'X',
                            colors: const [
                              Color(0xFF351060),
                              Color(0xFF9023E8),
                            ],
                            icon: const Text(
                              'X',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            onTap: () {
                              final message = Uri.encodeComponent(
                                body.isEmpty
                                    ? 'Check out this post on 999 Wellness.'
                                    : body,
                              );

                              final url = Uri.encodeComponent(shareUrl);

                              _openUrl(
                                context,
                                'https://twitter.com/intent/tweet?text=$message&url=$url',
                                'Unable to open X.',
                              );
                            },
                          ),

                          _shareTarget(
                            label: 'WhatsApp',
                            colors: const [
                              Color(0xFF07984F),
                              Color(0xFF29E780),
                            ],
                            icon: const Icon(
                              Icons.phone_in_talk_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                            onTap: () {
                              final encoded = Uri.encodeComponent(shareText);

                              _openUrl(
                                context,
                                'https://wa.me/?text=$encoded',
                                'Unable to open WhatsApp.',
                              );
                            },
                          ),

                          _shareTarget(
                            label: 'More',
                            colors: const [
                              Color(0xFF6714B5),
                              Color(0xFFB52EFF),
                            ],
                            icon: const Icon(
                              Icons.more_horiz_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                            onTap: () => _systemShare(context),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF082F70),
                            Color(0xFF17245F),
                            Color(0xFF38105F),
                          ],
                        ),
                        border: Border.all(
                          color: const Color(0xFF684CFF).withValues(alpha: .68),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            color: Color(0xFF5DEBFF),
                            size: 23,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Share wellness. Grow the community.',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Together we create a healthier, brighter world.',
                                  style: TextStyle(
                                    color: Color(0xFFAAB8D9),
                                    fontSize: 7.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '999',
                            style: TextStyle(
                              color: Color(0xFF32E7FF),
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
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
