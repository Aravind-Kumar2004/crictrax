import 'dart:async';
import 'package:flutter/material.dart';
import '../../login/presentation/login_screen.dart';

// ─── Design Tokens (shared with dashboard) ────────────────────────────────────
class _C {
  static const bg = Color(0xFF050A18);
  static const navy = Color(0xFF0A1430);
  static const accent = Color(0xFF00D4FF);
  static const accentDim = Color(0xFF0066CC);
  static const accentDeep = Color(0xFF003380);
  static const white = Colors.white;
}

class _Assets {
  static const stadiumBackground = 'assets/images/backgrounds/splash_bg.png';
  static const crictraxLogo = 'assets/images/crictrax_logo_login.png';
}

// ─── Cinematic Splash (lightweight, TV-safe rewrite) ──────────────────────────
class CinematicSplash extends StatefulWidget {
  const CinematicSplash({Key? key}) : super(key: key);

  @override
  State<CinematicSplash> createState() => _CinematicSplashState();
}

class _CinematicSplashState extends State<CinematicSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<double> _bgFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _wordFade;
  late final Animation<double> _wordSlide;
  late final Animation<double> _subtitleFade;
  late final Animation<double> _welcomeFade;
  late final Animation<double> _progressFade;
  late final Animation<double> _progressValue;
  late final Animation<double> _exitFade;

  @override
  void initState() {
    super.initState();

    // Total duration unchanged: 3 seconds.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _bgFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
      ),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.10, 0.45, curve: Curves.easeOut),
      ),
    );
    _logoScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.10, 0.50, curve: Curves.easeOutCubic),
      ),
    );

    _wordFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.40, 0.68, curve: Curves.easeOut),
      ),
    );
    _wordSlide = Tween<double>(begin: 12.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.40, 0.68, curve: Curves.easeOutCubic),
      ),
    );

    _subtitleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.55, 0.78, curve: Curves.easeIn),
      ),
    );

    _welcomeFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.66, 0.88, curve: Curves.easeIn),
      ),
    );

    _progressFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.55, 0.68, curve: Curves.easeIn),
      ),
    );
    _progressValue = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.60, 0.96, curve: Curves.easeInOut),
      ),
    );

    _exitFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.88, 1.0, curve: Curves.easeIn),
      ),
    );

    // ── Navigate to LoginScreen (navigation/timer logic unchanged) ─────────
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      debugPrint("FIRST FRAME RENDERED");

      await _controller.forward();

      if (!mounted) return;
      debugPrint("ANIMATION FINISHED");
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (_, __, ___) => LoginScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _C.bg,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // ── Layer 0: base color (always painted, avoids any black
              //    flash while the image asset decodes) ──────────────────
              Container(color: _C.bg),

              // ── Layer 1: stadium background image, simple fade-in ─────
              Opacity(
                opacity: _bgFade.value,
                child: Image.asset(
                  _Assets.stadiumBackground,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (_, __, ___) => Container(color: _C.bg),
                ),
              ),

              // ── Layer 2: dark overlay for legibility ───────────────────
              Container(color: Colors.black.withOpacity(0.45)),

              // ── Layer 3: centre content ────────────────────────────────
              Center(child: _buildCentreContent()),

              // ── Layer 4: progress bar ──────────────────────────────────
              _buildProgressBar(size),

              // ── Layer 5: exit fade (simple black overlay, no blur) ─────
              Opacity(
                opacity: _exitFade.value,
                child: Container(color: Colors.black),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCentreContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.scale(
          scale: _logoScale.value,
          child: Opacity(
            opacity: _logoFade.value,
            child: _buildLogoMark(),
          ),
        ),
        const SizedBox(height: 32),
        Transform.translate(
          offset: Offset(0, _wordSlide.value),
          child: Opacity(
            opacity: _wordFade.value,
            child: _buildWordmark(),
          ),
        ),
        const SizedBox(height: 12),
        Opacity(
          opacity: _subtitleFade.value,
          child: _buildSubtitle(),
        ),
        const SizedBox(height: 22),
        Opacity(
          opacity: _welcomeFade.value,
          child: _buildWelcomeBlock(),
        ),
      ],
    );
  }

  Widget _buildLogoMark() {
    return Container(
      width: 96,
      height: 96,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: _C.navy,
        border: Border.all(color: _C.accent.withOpacity(0.4), width: 1.4),
      ),
      child: Image.asset(
        _Assets.crictraxLogo,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(
            Icons.sports_cricket,
            color: Colors.white,
            size: 52,
          ),
        ),
      ),
    );
  }

  Widget _buildWordmark() {
    return const Text(
      'CRICTRAX',
      style: TextStyle(
        color: Colors.white,
        fontSize: 64,
        fontWeight: FontWeight.w900,
        letterSpacing: 10,
        height: 1.0,
      ),
    );
  }

  Widget _buildSubtitle() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 28, height: 1, color: _C.accent.withOpacity(0.4)),
        const SizedBox(width: 12),
        Text(
          'TV  SCOREBOARD',
          style: TextStyle(
            color: _C.accent.withOpacity(0.75),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 5.0,
          ),
        ),
        const SizedBox(width: 12),
        Container(width: 28, height: 1, color: _C.accent.withOpacity(0.4)),
      ],
    );
  }

  Widget _buildWelcomeBlock() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'WELCOME TO',
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 5.0,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'CRICTRAX TV',
          style: TextStyle(
            color: _C.accent.withOpacity(0.95),
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 3.0,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Experience Live Cricket Like Never Before',
          style: TextStyle(
            color: Colors.white.withOpacity(0.45),
            fontSize: 11,
            fontWeight: FontWeight.w400,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(Size size) {
    return Positioned(
      bottom: 52,
      left: size.width / 2 - 110,
      width: 220,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Opacity(
            opacity: _progressFade.value,
            child: Text(
              'Preparing Live Broadcast...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.8,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Opacity(
            opacity: _progressFade.value,
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                color: _C.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _progressValue.value,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: LinearGradient(
                      colors: [_C.accentDim, _C.accent],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}