import 'package:flutter/material.dart';

class CustomerMobileSocialMockup extends StatefulWidget {
  const CustomerMobileSocialMockup({super.key});

  @override
  State<CustomerMobileSocialMockup> createState() =>
      _CustomerMobileSocialMockupState();
}

class _CustomerMobileSocialMockupState
    extends State<CustomerMobileSocialMockup> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int _bottomIndex = 0;
  bool _showStories = true;

  final List<_StoryItemData> _stories = const [
    _StoryItemData(
      title: 'Your Story',
      subtitle: 'Share Today',
      icon: Icons.add_circle,
      accent: Color(0xFF7A5CFF),
      bg1: Color(0xFF12193A),
      bg2: Color(0xFF0A1028),
    ),
    _StoryItemData(
      title: 'Top Providers',
      subtitle: 'Find Experts',
      icon: Icons.groups_rounded,
      accent: Color(0xFF31D6FF),
      bg1: Color(0xFF10233D),
      bg2: Color(0xFF08162A),
    ),
    _StoryItemData(
      title: 'Meditation',
      subtitle: 'Find Your Calm',
      icon: Icons.spa_rounded,
      accent: Color(0xFF7B7CFF),
      bg1: Color(0xFF1B2247),
      bg2: Color(0xFF0A1128),
    ),
    _StoryItemData(
      title: 'Mobile Visits',
      subtitle: 'Wellness On-Demand',
      icon: Icons.fitness_center_rounded,
      accent: Color(0xFF33B0FF),
      bg1: Color(0xFF13284A),
      bg2: Color(0xFF08172E),
    ),
    _StoryItemData(
      title: 'Rewards',
      subtitle: 'Earn & Grow',
      icon: Icons.card_giftcard_rounded,
      accent: Color(0xFF3DE0C2),
      bg1: Color(0xFF11363B),
      bg2: Color(0xFF081B1E),
    ),
  ];

  final List<_PostData> _posts = const [
    _PostData(
      author: 'Prince X',
      tag: 'Mindset',
      timeAgo: '2h ago',
      verified: true,
      caption1: 'No self love, no real progress. Keep showing up.',
      caption2: 'Small steps create a stronger, happier you.',
      sideText: 'HIGHER\nHEALTHIER\nHAPPIER\nTOGETHER',
      footerBrand: '999 WELLNESS',
      imageTitle: 'A Healthier You\nBrighter Tomorrow',
      accent: Color(0xFF7A5CFF),
      imageTop: Color(0xFFF39B56),
      imageBottom: Color(0xFF1A2347),
      likes: '1.2K',
      comments: '124',
    ),
    _PostData(
      author: 'Tasha Wellness',
      tag: 'Meditation',
      timeAgo: '5h ago',
      verified: true,
      caption1: 'A peaceful mind changes everything.',
      caption2: 'Take a moment today. Breathe, be present, be proud.',
      sideText: 'GOOD\nPEOPLE\nHEALTHY MINDS\nBRIGHTER DAYS',
      footerBrand: '999 WELLNESS',
      imageTitle: 'Pause.\nBreathe.\nReset.',
      accent: Color(0xFF32D2FF),
      imageTop: Color(0xFF8CD6A4),
      imageBottom: Color(0xFF213442),
      likes: '892',
      comments: '76',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF050B1A),
      drawer: _buildDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 14),
                    _buildComposer(),
                    const SizedBox(height: 16),
                    _buildStoriesTabs(),
                    const SizedBox(height: 12),
                    _buildStories(),
                    const SizedBox(height: 14),
                    _buildQuickActions(),
                    const SizedBox(height: 14),
                    for (final post in _posts) ...[
                      _buildPostCard(post),
                      const SizedBox(height: 14),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildDrawer() {
    final items = <Map<String, dynamic>>[
      {'icon': Icons.home_rounded, 'label': 'Home'},
      {'icon': Icons.dynamic_feed_rounded, 'label': 'Feed'},
      {'icon': Icons.search_rounded, 'label': 'Search'},
      {'icon': Icons.calendar_month_rounded, 'label': 'Bookings'},
      {'icon': Icons.favorite_border_rounded, 'label': 'Favorites'},
      {'icon': Icons.person_outline_rounded, 'label': 'Profile'},
      {'icon': Icons.smart_toy_outlined, 'label': 'AI Assistant'},
      {'icon': Icons.chat_bubble_outline_rounded, 'label': 'Messages'},
      {'icon': Icons.settings_outlined, 'label': 'Settings'},
    ];

    return Drawer(
      backgroundColor: const Color(0xFF091127),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(14),
              decoration: _panelDecoration(
                borderColor: const Color(0xFF2E73FF),
              ),
              child: Row(
                children: [
                  _buildLogo(size: 52),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '999 Wellness',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Mind • Body • Community',
                          style: TextStyle(
                            color: Color(0xFF99A5D4),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final bool active = index == 0;
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: active
                          ? const LinearGradient(
                              colors: [Color(0xFF182B64), Color(0xFF0B1530)],
                            )
                          : null,
                      border: Border.all(
                        color: active
                            ? const Color(0xFF7A5CFF)
                            : const Color(0xFF1C2A59),
                      ),
                    ),
                    child: ListTile(
                      leading: Icon(
                        item['icon'] as IconData,
                        color: active ? const Color(0xFF8E7BFF) : Colors.white,
                      ),
                      title: Text(
                        item['label'] as String,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      onTap: () => Navigator.of(context).pop(),
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

  Widget _buildHeader() {
    return Row(
      children: [
        _iconShell(
          icon: Icons.menu_rounded,
          onTap: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        const SizedBox(width: 10),
        _buildLogo(size: 54),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '999 Wellness',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Mind • Body • Community',
                style: TextStyle(
                  color: Color(0xFF9EA9D6),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        _iconShell(icon: Icons.add_rounded),
        const SizedBox(width: 8),
        _iconShell(icon: Icons.search_rounded),
        const SizedBox(width: 8),
        Stack(
          clipBehavior: Clip.none,
          children: [
            _iconShell(icon: Icons.notifications_none_rounded),
            Positioned(
              right: 7,
              top: 7,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFB142FF),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
        _profileAvatar(size: 46),
      ],
    );
  }

  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: _panelDecoration(borderColor: const Color(0xFF245CDA)),
      child: Row(
        children: [
          _profileAvatar(size: 42),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              "What's on your mind?",
              style: TextStyle(
                color: Color(0xFFB8C2F0),
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          _iconShell(icon: Icons.image_outlined, compact: true),
        ],
      ),
    );
  }

  Widget _buildStoriesTabs() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF071225),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF152555)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showStories = true),
              child: _tabChip(label: 'Stories', active: _showStories),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showStories = false),
              child: _tabChip(label: 'Feed', active: !_showStories),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabChip({required String label, required bool active}) {
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: active
            ? const LinearGradient(
                colors: [Color(0xFF281D63), Color(0xFF13255D)],
              )
            : null,
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : const Color(0xFF9EA9D6),
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildStories() {
    return SizedBox(
      height: 188,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _stories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = _stories[index];
          return Container(
            width: 132,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [item.bg1, item.bg2],
              ),
              border: Border.all(color: item.accent.withValues(alpha: 0.75)),
              boxShadow: [
                BoxShadow(
                  color: item.accent.withValues(alpha: 0.18),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: item.accent, width: 2.4),
                    gradient: LinearGradient(
                      colors: [
                        item.accent.withValues(alpha: 0.20),
                        const Color(0xFF07122B),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(item.icon, color: Colors.white, size: 28),
                      if (index == 0)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2385FF),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF07122B),
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.add,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  item.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  item.subtitle,
                  style: const TextStyle(
                    color: Color(0xFFA7B4E5),
                    fontSize: 12.5,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _actionButton(
            icon: Icons.photo_camera_outlined,
            label: 'Photo',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _actionButton(
            icon: Icons.videocam_outlined,
            label: 'Go Live',
            iconColor: const Color(0xFFFF4A98),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: _primaryActionButton()),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    Color iconColor = Colors.white,
  }) {
    return Container(
      height: 54,
      decoration: _panelDecoration(
        borderColor: const Color(0xFF244FAF),
        radius: 16,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryActionButton() {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFFBF3EFF), Color(0xFF1FB6FF)],
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x332B8DFF), blurRadius: 18, spreadRadius: 1),
        ],
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.send_rounded, color: Colors.white),
          SizedBox(width: 8),
          Text(
            'Post',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(_PostData post) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: _panelDecoration(
        borderColor: post.accent.withValues(alpha: 0.65),
        radius: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _profileAvatar(size: 46, label: _initials(post.author)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          post.author,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16.5,
                          ),
                        ),
                        if (post.verified) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 18,
                            height: 18,
                            decoration: const BoxDecoration(
                              color: Color(0xFF2D8CFF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${post.timeAgo} • ${post.tag}',
                      style: const TextStyle(
                        color: Color(0xFF9CA8D4),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.more_horiz_rounded,
                color: Color(0xFFD6DBF7),
                size: 26,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            post.caption1,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.28,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            post.caption2,
            style: const TextStyle(
              color: Color(0xFFD7DEFF),
              fontSize: 16,
              height: 1.28,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              height: 208,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [post.imageTop, post.imageBottom],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -20,
                    top: 14,
                    child: Container(
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 18,
                    bottom: 18,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.imageTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 64,
                          height: 2,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 18,
                    top: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          post.sideText,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: 46,
                          height: 2,
                          color: Colors.white.withValues(alpha: 0.90),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          post.footerBrand,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    right: 122,
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.self_improvement_rounded,
                        color: Colors.white70,
                        size: 56,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.favorite, color: Color(0xFFFF4CA0), size: 24),
              const SizedBox(width: 8),
              Text(
                post.likes,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
              const SizedBox(width: 22),
              const Icon(
                Icons.mode_comment_outlined,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                post.comments,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
              const SizedBox(width: 22),
              const Icon(Icons.reply_outlined, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              const Text(
                'Share',
                style: TextStyle(color: Colors.white, fontSize: 15),
              ),
              const Spacer(),
              const Icon(
                Icons.bookmark_border_rounded,
                color: Colors.white,
                size: 24,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    final items = <Map<String, dynamic>>[
      {'icon': Icons.home_rounded, 'label': 'Home'},
      {'icon': Icons.search_rounded, 'label': 'Search'},
      {'icon': Icons.calendar_today_rounded, 'label': 'Bookings'},
      {'icon': Icons.favorite_border_rounded, 'label': 'Favorites'},
      {'icon': Icons.person_outline_rounded, 'label': 'Profile'},
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
      decoration: const BoxDecoration(color: Color(0xFF050B1A)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF071225),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFF162454)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          children: List.generate(items.length, (index) {
            final item = items[index];
            final bool active = _bottomIndex == index;
            return Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => setState(() => _bottomIndex = index),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item['icon'] as IconData,
                        color: active ? const Color(0xFF8E7BFF) : Colors.white,
                        size: 28,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        item['label'] as String,
                        style: TextStyle(
                          color: active
                              ? Colors.white
                              : const Color(0xFFCBD3F7),
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 34,
                        height: 3,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(99),
                          gradient: active
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFFB441FF),
                                    Color(0xFF298BFF),
                                  ],
                                )
                              : null,
                          color: active ? null : Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildLogo({double size = 52}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7E3CFF), Color(0xFF2290FF)],
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x337A5CFF), blurRadius: 18, spreadRadius: 2),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF081227),
        ),
        child: const Center(
          child: Text(
            '999',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _profileAvatar({double size = 44, String label = 'PX'}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFB53FFF), Color(0xFF2A8CFF)],
        ),
      ),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF0D1730),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.28,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconShell({
    required IconData icon,
    VoidCallback? onTap,
    bool compact = false,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: onTap,
      child: Container(
        width: compact ? 42 : 44,
        height: compact ? 42 : 44,
        decoration: BoxDecoration(
          color: const Color(0xFF091327),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF182C60)),
        ),
        child: Icon(icon, color: Colors.white, size: compact ? 22 : 24),
      ),
    );
  }

  BoxDecoration _panelDecoration({
    required Color borderColor,
    double radius = 18,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0A1430), Color(0xFF071225)],
      ),
      border: Border.all(color: borderColor),
      boxShadow: [
        BoxShadow(
          color: borderColor.withValues(alpha: 0.12),
          blurRadius: 20,
          spreadRadius: 1,
        ),
      ],
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'PX';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

class _StoryItemData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Color bg1;
  final Color bg2;

  const _StoryItemData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.bg1,
    required this.bg2,
  });
}

class _PostData {
  final String author;
  final String tag;
  final String timeAgo;
  final bool verified;
  final String caption1;
  final String caption2;
  final String sideText;
  final String footerBrand;
  final String imageTitle;
  final Color accent;
  final Color imageTop;
  final Color imageBottom;
  final String likes;
  final String comments;

  const _PostData({
    required this.author,
    required this.tag,
    required this.timeAgo,
    required this.verified,
    required this.caption1,
    required this.caption2,
    required this.sideText,
    required this.footerBrand,
    required this.imageTitle,
    required this.accent,
    required this.imageTop,
    required this.imageBottom,
    required this.likes,
    required this.comments,
  });
}
