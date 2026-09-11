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
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: .78),
    builder: (_) => _PremiumWellnessShareSheet(
      authorName: authorName,
      body: body,
      mediaUrl: mediaUrl,
      shareUrl: shareUrl,
      shareText: shareText,
    ),
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

  Future<void> _shareMore(BuildContext context) async {
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
    String failureText,
  ) async {
    try {
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );

      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(failureText)));
      }
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failureText)));
    }
  }

  Widget _target({
    required String label,
    required Widget icon,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 46,
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
                      color: colors.first.withValues(alpha: .32),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: icon,
              ),
              const SizedBox(height: 7),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFE4ECFF),
                  fontSize: 7,
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
    final preview = body.isEmpty
        ? 'Share this wellness post with your network.'
        : body;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .82,
          ),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF071D4A), Color(0xFF071534), Color(0xFF150733)],
            ),
            border: Border(
              top: BorderSide(
                color: const Color(0xFF36E2FF).withValues(alpha: .90),
                width: 1.5,
              ),
              left: BorderSide(
                color: const Color(0xFF654FFF).withValues(alpha: .38),
              ),
              right: BorderSide(
                color: const Color(0xFF654FFF).withValues(alpha: .38),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF23DFFF).withValues(alpha: .20),
                blurRadius: 42,
              ),
              BoxShadow(
                color: const Color(0xFF933EFF).withValues(alpha: .24),
                blurRadius: 55,
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(17, 10, 17, 25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 74,
                    height: 5,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(50),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF31E4FF), Color(0xFF9140FF)],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF8D3CFF),
                            Color(0xFF315FFF),
                            Color(0xFF1DE2FF),
                          ],
                        ),
                        border: Border.all(
                          color: const Color(0xFF42E8FF),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF743FFF)
                                .withValues(alpha: .40),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.hub_rounded,
                        color: Colors.white,
                        size: 27,
                      ),
                    ),
                    const SizedBox(width: 13),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Share This Post',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Spread wellness. Inspire change.',
                            style: TextStyle(
                              color: Color(0xFFA7B9DE),
                              fontSize: 11,
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
                        color: const Color(0xFF0A2250),
                        border: Border.all(color: const Color(0xFF5878FF)),
                      ),
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
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
                    borderRadius: BorderRadius.circular(22),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF071D43),
                        Color(0xFF0C1D47),
                        Color(0xFF111040),
                      ],
                    ),
                    border: Border.all(
                      color: const Color(0xFF31DFFF).withValues(alpha: .72),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 90,
                        height: 74,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
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
                                      color: Color(0xFF62DFFF),
                                      size: 30,
                                    ),
                                  );
                                },
                              )
                            : const Center(
                                child: Icon(
                                  Icons.dynamic_feed_rounded,
                                  color: Color(0xFF62DFFF),
                                  size: 30,
                                ),
                              ),
                      ),
                      const SizedBox(width: 12),
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
                                color: Color(0xFF91A6D4),
                                fontSize: 8.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              preview,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFBCC9E5),
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
                Row(
                  children: [
                    _target(
                      label: 'Copy Link',
                      colors: const [Color(0xFF1268D7), Color(0xFF17DCF6)],
                      icon: const Icon(Icons.link_rounded, color: Colors.white),
                      onTap: () => _copyLink(context),
                    ),
                    _target(
                      label: 'Messages',
                      colors: const [Color(0xFF079E58), Color(0xFF2AE69A)],
                      icon: const Icon(
                        Icons.chat_bubble_rounded,
                        color: Colors.white,
                        size: 21,
                      ),
                      onTap: () {
                        final value = Uri.encodeComponent(shareText);
                        _openUrl(
                          context,
                          'sms:?body=$value',
                          'Unable to open Messages.',
                        );
                      },
                    ),
                    _target(
                      label: 'Facebook',
                      colors: const [Color(0xFF1648D7), Color(0xFF287DFF)],
                      icon: const Text(
                        'f',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      onTap: () {
                        final value = Uri.encodeComponent(shareUrl);
                        _openUrl(
                          context,
                          'https://www.facebook.com/sharer/sharer.php?u=$value',
                          'Unable to open Facebook.',
                        );
                      },
                    ),
                    _target(
                      label: 'X',
                      colors: const [Color(0xFF351060), Color(0xFF9023E8)],
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
                        final value = Uri.encodeComponent(shareUrl);
                        _openUrl(
                          context,
                          'https://twitter.com/intent/tweet?text=$message&url=$value',
                          'Unable to open X.',
                        );
                      },
                    ),
                    _target(
                      label: 'WhatsApp',
                      colors: const [Color(0xFF07984F), Color(0xFF29E780)],
                      icon: const Icon(
                        Icons.phone_in_talk_rounded,
                        color: Colors.white,
                      ),
                      onTap: () {
                        final value = Uri.encodeComponent(shareText);
                        _openUrl(
                          context,
                          'https://wa.me/?text=$value',
                          'Unable to open WhatsApp.',
                        );
                      },
                    ),
                    _target(
                      label: 'More',
                      colors: const [Color(0xFF6714B5), Color(0xFFB52EFF)],
                      icon: const Icon(
                        Icons.more_horiz_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                      onTap: () => _shareMore(context),
                    ),
                  ],
                ),
                const SizedBox(height: 17),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 12,
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
                      color: const Color(0xFF684CFF).withValues(alpha: .70),
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
                                fontSize: 8,
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
        ),
      ),
    );
  }
}
