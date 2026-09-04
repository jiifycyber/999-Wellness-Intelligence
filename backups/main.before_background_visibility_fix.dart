import 'dart:ui';

import 'package:flutter/material.dart';

void main() {
  runApp(const WellnessIntelligenceApp());
}

class WellnessIntelligenceApp extends StatelessWidget {
  const WellnessIntelligenceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '999 Wellness Intelligence',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF09060F),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF9A62FF),
          brightness: Brightness.dark,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withOpacity(0.06),
          hintStyle: const TextStyle(color: Colors.white54),
          labelStyle: const TextStyle(color: Colors.white70),
          prefixIconColor: Colors.white70,
          suffixIconColor: Colors.white70,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.14)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFB991FF), width: 1.4),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

enum UserRole { customer, therapist, admin }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  UserRole _selectedRole = UserRole.customer;
  bool _obscurePassword = true;
  bool _rememberMe = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.customer:
        return 'Customer';
      case UserRole.therapist:
        return 'Therapist';
      case UserRole.admin:
        return 'Owner / Admin';
    }
  }

  void _handleContinue() {
    FocusScope.of(context).unfocus();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'UI is working. Auth is not connected yet. Role: ${_roleLabel(_selectedRole)}',
        ),
      ),
    );
  }

  void _handleCreateAccount() {
    FocusScope.of(context).unfocus();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Create Account screen will be connected next.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 900;

          return Stack(
            children: [
              const _BackgroundLayer(),
              SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 18 : 28,
                    vertical: isMobile ? 20 : 26,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1380),
                      child: Column(
                        children: [
                          _TopBrandRow(isMobile: isMobile),
                          SizedBox(height: isMobile ? 24 : 18),
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 560),
                              child: _GlassPanel(
                                padding: EdgeInsets.all(isMobile ? 22 : 24),
                                child: _buildLoginCard(isMobile),
                              ),
                            ),
                          ),
                          SizedBox(height: isMobile ? 22 : 18),
                          _FeatureRow(isMobile: isMobile),
                          const SizedBox(height: 14),
                          Text(
                            'Secure. Private. Professional.    Your wellness journey starts here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.72),
                              fontSize: isMobile ? 12 : 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoginCard(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.spa_outlined, color: Color(0xFFD8C3FF), size: 34),
        const SizedBox(height: 12),
        Text(
          'WELCOME TO',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: isMobile ? 16 : 20,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '999 WELLNESS',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: const Color(0xFFB882FF),
            fontSize: isMobile ? 34 : 44,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 110,
          height: 2,
          margin: const EdgeInsets.symmetric(horizontal: 90),
          decoration: BoxDecoration(
            color: const Color(0xFFE2C56E),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE2C56E).withOpacity(0.55),
                blurRadius: 8,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'BOOK PROFESSIONAL MASSAGE THERAPISTS.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.88),
            fontSize: isMobile ? 14 : 18,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 28),
        _buildRoleSelector(isMobile),
        const SizedBox(height: 22),
        Text(
          'EMAIL ADDRESS',
          style: TextStyle(
            color: Colors.white.withOpacity(0.92),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            hintText: 'Enter your email',
            prefixIcon: Icon(Icons.mail_outline_rounded),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'PASSWORD',
          style: TextStyle(
            color: Colors.white.withOpacity(0.92),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          onSubmitted: (_) => _handleContinue(),
          decoration: InputDecoration(
            hintText: 'Enter your password',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Theme(
              data: Theme.of(context).copyWith(
                checkboxTheme: CheckboxThemeData(
                  fillColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return const Color(0xFF9D65FF);
                    }
                    return Colors.transparent;
                  }),
                  side: BorderSide(color: Colors.white.withOpacity(0.5)),
                ),
              ),
              child: Checkbox(
                value: _rememberMe,
                onChanged: (value) {
                  setState(() {
                    _rememberMe = value ?? false;
                  });
                },
              ),
            ),
            const Text('Remember me', style: TextStyle(fontSize: 14)),
            const Spacer(),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Forgot Password will be connected next.'),
                  ),
                );
              },
              child: const Text('Forgot password?'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 60,
          child: FilledButton(
            onPressed: _handleContinue,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF914DFF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 10,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'CONTINUE',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                SizedBox(width: 10),
                Icon(Icons.arrow_forward_rounded),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(child: Divider(color: Colors.white.withOpacity(0.16))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                'OR',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(child: Divider(color: Colors.white.withOpacity(0.16))),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 58,
          child: OutlinedButton.icon(
            onPressed: _handleCreateAccount,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text(
              'CREATE ACCOUNT',
              style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(
                color: const Color(0xFF9D65FF).withOpacity(0.75),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleSelector(bool isMobile) {
    return Row(
      children: [
        Expanded(
          child: _RoleCard(
            title: 'CUSTOMER',
            icon: Icons.person_outline_rounded,
            selected: _selectedRole == UserRole.customer,
            onTap: () {
              setState(() {
                _selectedRole = UserRole.customer;
              });
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _RoleCard(
            title: 'THERAPIST',
            icon: Icons.spa_outlined,
            selected: _selectedRole == UserRole.therapist,
            onTap: () {
              setState(() {
                _selectedRole = UserRole.therapist;
              });
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _RoleCard(
            title: isMobile ? 'ADMIN' : 'OWNER / ADMIN',
            icon: Icons.shield_outlined,
            selected: _selectedRole == UserRole.admin,
            onTap: () {
              setState(() {
                _selectedRole = UserRole.admin;
              });
            },
          ),
        ),
      ],
    );
  }
}

class _TopBrandRow extends StatelessWidget {
  const _TopBrandRow({required this.isMobile});

  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      return Column(
        children: [
          const Icon(Icons.spa_rounded, size: 46, color: Color(0xFFC38CFF)),
          const SizedBox(height: 8),
          const Text(
            '999 WELLNESS',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.3,
            ),
          ),
          Text(
            'INTELLIGENCE',
            style: TextStyle(
              color: const Color(0xFFD3BBFF).withOpacity(0.95),
              fontSize: 14,
              letterSpacing: 6,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'PROFESSIONAL MASSAGE\n& WELLNESS MARKETPLACE',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.88),
              fontSize: 14,
              height: 1.35,
              letterSpacing: 0.8,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        const Icon(Icons.spa_rounded, size: 56, color: Color(0xFFC38CFF)),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '999 WELLNESS',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
            Text(
              'INTELLIGENCE',
              style: TextStyle(
                color: const Color(0xFFD3BBFF).withOpacity(0.95),
                fontSize: 15,
                letterSpacing: 7,
              ),
            ),
          ],
        ),
        const SizedBox(width: 20),
        Container(width: 1, height: 52, color: Colors.white.withOpacity(0.24)),
        const SizedBox(width: 20),
        Expanded(
          child: Text(
            'PROFESSIONAL MASSAGE\n& WELLNESS MARKETPLACE',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 18,
              height: 1.35,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.isMobile});

  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        Icons.lock_outline_rounded,
        'SECURE & PRIVATE',
        'Your information\nis protected',
      ),
      (
        Icons.spa_outlined,
        'PROFESSIONAL VERIFIED',
        'Licensed & experienced\nmassage therapists',
      ),
      (
        Icons.calendar_month_outlined,
        'EASY ONLINE BOOKING',
        'Book anytime,\nanywhere',
      ),
      (
        Icons.favorite_border_rounded,
        'WELLNESS YOUR WAY',
        'Relax. Reconnect.\nFeel your best.',
      ),
    ];

    if (isMobile) {
      return Column(
        children: items
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _FeatureTile(
                  icon: item.$1,
                  title: item.$2,
                  subtitle: item.$3,
                ),
              ),
            )
            .toList(),
      );
    }

    return Row(
      children: items
          .map(
            (item) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _FeatureTile(
                  icon: item.$1,
                  title: item.$2,
                  subtitle: item.$3,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF9D65FF).withOpacity(0.18),
              border: Border.all(
                color: const Color(0xFFC8A8FF).withOpacity(0.5),
              ),
            ),
            child: Icon(icon, color: const Color(0xFFE4D5FF), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: Colors.white.withOpacity(0.72),
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

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeColor = const Color(0xFF9A62FF);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: selected ? activeColor.withOpacity(0.34) : Colors.transparent,
          border: Border.all(
            color: selected
                ? activeColor.withOpacity(0.9)
                : Colors.white.withOpacity(0.15),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: activeColor.withOpacity(0.18),
                    blurRadius: 20,
                    spreadRadius: 0.5,
                  ),
                ]
              : [],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : Colors.white.withOpacity(0.72),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Colors.white : Colors.white.withOpacity(0.82),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child, required this.padding});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: const Color(0xFF140D1E).withOpacity(0.80),
            border: Border.all(
              color: const Color(0xFFB88DFF).withOpacity(0.24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 36,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _BackgroundLayer extends StatelessWidget {
  const _BackgroundLayer();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF07040C), Color(0xFF140A1B), Color(0xFF09050E)],
            ),
          ),
        ),
        Positioned.fill(
          child: Opacity(
            opacity: 0.90,
            child: Image.asset(
              'assets/login_background.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.05),
                  const Color(0xFF110915).withOpacity(0.18),
                  Colors.black.withOpacity(0.30),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: -80,
          top: 80,
          child: _GlowCircle(
            size: 280,
            color: const Color(0xFF6B2DFF).withOpacity(0.22),
          ),
        ),
        Positioned(
          right: -100,
          top: 100,
          child: _GlowCircle(
            size: 320,
            color: const Color(0xFF8D54FF).withOpacity(0.20),
          ),
        ),
        Positioned(
          left: 120,
          bottom: -120,
          child: _GlowCircle(
            size: 260,
            color: const Color(0xFF3A0D55).withOpacity(0.25),
          ),
        ),
        Positioned(
          right: 90,
          bottom: -100,
          child: _GlowCircle(
            size: 250,
            color: const Color(0xFF5B1C91).withOpacity(0.22),
          ),
        ),
      ],
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}
