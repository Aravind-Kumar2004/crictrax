import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../login/presentation/login_screen.dart';

// ─── Design Tokens (shared with dashboard) ────────────────────────────────────
class _C {
  static const bg = Color(0xFF050A18);
  static const accent = Color(0xFF00D4FF);
  static const accentDim = Color(0xFF0066CC);
  static const accentDeep = Color(0xFF003380);
  static const white = Colors.white;
}

// ─── Cinematic Splash ─────────────────────────────────────────────────────────
class CinematicSplash extends StatefulWidget {
  const CinematicSplash({Key? key}) : super(key: key);

  @override
  State<CinematicSplash> createState() => _CinematicSplashState();
}

class _CinematicSplashState extends State<CinematicSplash>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Act 1 — scanline sweep
  late Animation<double> _scanLine;

  // Act 2 — energy rings
  late Animation<double> _ringExpand;
  late Animation<double> _ringFade;

  // Act 3 — icon
  late Animation<double> _iconRotate;
  late Animation<double> _iconScale;
  late Animation<double> _iconGlow;

  // Act 4 — wordmark
  late Animation<double> _wordReveal;   // clip reveal (0→1)
  late Animation<double> _subtitleFade;
  late Animation<double> _progressBar;

  // Exit
  late Animation<double> _backgroundBlur;

  @override
  void initState() {
    super.initState();

    // Total: 2300ms — identical to original duration
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2300),
    );

    // ── Act 1: scanline sweep (0 → 400ms) ──────────────────────────────────
    _scanLine = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.17, curve: Curves.easeInOut),
      ),
    );

    // ── Act 2: ring expansion (300ms → 800ms) ──────────────────────────────
    _ringExpand = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.13, 0.5, curve: Curves.decelerate),
      ),
    );
    _ringFade = Tween<double>(begin: 0.8, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.65, curve: Curves.easeOut),
      ),
    );

    // ── Act 3: icon materialise (600ms → 1300ms) ───────────────────────────
    _iconRotate = Tween<double>(begin: -0.15, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.26, 0.60, curve: Curves.easeOutBack),
      ),
    );
    _iconScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.26, 0.58, curve: Curves.easeOutBack),
      ),
    );
    _iconGlow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.40, 0.70, curve: Curves.easeOut),
      ),
    );

    // ── Act 4: wordmark + progress (1100ms → 2000ms) ───────────────────────
    _wordReveal = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.48, 0.78, curve: Curves.easeOut),
      ),
    );
    _subtitleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.62, 0.82, curve: Curves.easeIn),
      ),
    );
    _progressBar = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.68, 0.95, curve: Curves.easeInOut),
      ),
    );

    // ── Exit blur (identical to original interval: 0.85→1.0) ───────────────
    _backgroundBlur = Tween<double>(begin: 0.0, end: 15.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.85, 1.0, curve: Curves.easeInOut),
      ),
    );

    // ── Navigate to LoginScreen (UNCHANGED) ────────────────────────────────
    _controller.forward().then((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 800),
          pageBuilder: (_, __, ___) => const LoginScreen(),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
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
            alignment: Alignment.center,
            children: [
              // ── Layer 0: ambient deep glow ─────────────────────────────
              _buildAmbientGlow(size),

              // ── Layer 1: scanline sweep ────────────────────────────────
              _buildScanLine(size),

              // ── Layer 2: energy rings ──────────────────────────────────
              _buildRings(size),

              // ── Layer 3: centre icon + wordmark ───────────────────────
              Center(child: _buildCentreContent(size)),

              // ── Layer 4: progress bar (bottom) ─────────────────────────
              _buildProgressBar(size),

              // ── Layer 5: exit blur (UNCHANGED logic) ──────────────────
              BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: _backgroundBlur.value,
                  sigmaY: _backgroundBlur.value,
                ),
                child: Container(color: Colors.transparent),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Ambient Glow ─────────────────────────────────────────────────────────
  Widget _buildAmbientGlow(Size size) {
    return Positioned.fill(
      child: CustomPaint(
        painter: _AmbientGlowPainter(
          progress: _ringExpand.value,
          accent: _C.accent,
        ),
      ),
    );
  }

  // ── Scanline Sweep ───────────────────────────────────────────────────────
  Widget _buildScanLine(Size size) {
    if (_scanLine.value <= 0 || _scanLine.value >= 1) return const SizedBox();
    final y = size.height * _scanLine.value;
    return Positioned(
      top: y - 1,
      left: 0,
      right: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Main bright line
          Container(
            height: 1.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  _C.accent.withOpacity(0.3),
                  _C.accent,
                  _C.accent.withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          // Soft trailing glow
          Container(
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _C.accent.withOpacity(0.06),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Energy Rings ─────────────────────────────────────────────────────────
  Widget _buildRings(Size size) {
    return Positioned.fill(
      child: CustomPaint(
        painter: _RingsPainter(
          expand: _ringExpand.value,
          fade: _ringFade.value,
          accent: _C.accent,
          accentDim: _C.accentDim,
        ),
      ),
    );
  }

  // ── Centre Content ───────────────────────────────────────────────────────
  Widget _buildCentreContent(Size size) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icon container
        Transform.rotate(
          angle: _iconRotate.value * math.pi,
          child: Transform.scale(
            scale: _iconScale.value,
            child: _buildIconMark(),
          ),
        ),

        const SizedBox(height: 36),

        // Wordmark with clip reveal
        ClipRect(
          child: Align(
            heightFactor: _wordReveal.value.clamp(0.0, 1.0),
            alignment: Alignment.topCenter,
            child: _buildWordmark(),
          ),
        ),

        const SizedBox(height: 12),

        // Subtitle
        Opacity(
          opacity: _subtitleFade.value,
          child: _buildSubtitle(),
        ),
      ],
    );
  }

  Widget _buildIconMark() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer glow ring
        Opacity(
          opacity: _iconGlow.value,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _C.accent.withOpacity(0.35 * _iconGlow.value),
                  blurRadius: 60,
                  spreadRadius: 10,
                ),
              ],
            ),
          ),
        ),
        // Icon container
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                _C.accent.withOpacity(0.18),
                _C.accentDim.withOpacity(0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: _C.accent.withOpacity(0.35),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _C.accent.withOpacity(0.2 * _iconGlow.value),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.sports_cricket,
            color: Colors.white,
            size: 40,
          ),
        ),
      ],
    );
  }

  Widget _buildWordmark() {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: [
          Colors.white,
          _C.accent.withOpacity(0.85),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bounds),
      child: const Text(
        'CRICTRAX',
        style: TextStyle(
          color: Colors.white, // masked by shader
          fontSize: 72,
          fontWeight: FontWeight.w900,
          letterSpacing: 12,
          height: 1.0,
        ),
      ),
    );
  }

  Widget _buildSubtitle() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 1,
          color: _C.accent.withOpacity(0.4),
        ),
        const SizedBox(width: 12),
        Text(
          'TV  SCORECARD',
          style: TextStyle(
            color: _C.accent.withOpacity(0.65),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 5.0,
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 28,
          height: 1,
          color: _C.accent.withOpacity(0.4),
        ),
      ],
    );
  }

  // ── Progress Bar ─────────────────────────────────────────────────────────
  Widget _buildProgressBar(Size size) {
    return Positioned(
      bottom: 52,
      left: size.width / 2 - 100,
      width: 200,
      child: Opacity(
        opacity: (_progressBar.value * 3).clamp(0.0, 1.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Track
            Container(
              height: 1.5,
              decoration: BoxDecoration(
                color: _C.accent.withOpacity(0.10),
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _progressBar.value,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: LinearGradient(
                      colors: [_C.accentDim, _C.accent],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _C.accent.withOpacity(0.6),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Ambient Glow Painter ─────────────────────────────────────────────────────
class _AmbientGlowPainter extends CustomPainter {
  final double progress;
  final Color accent;

  _AmbientGlowPainter({required this.progress, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          accent.withOpacity(0.12 * progress),
          accent.withOpacity(0.04 * progress),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCenter(
        center: center,
        width: size.width * 1.4,
        height: size.width * 1.4,
      ));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(_AmbientGlowPainter old) =>
      old.progress != progress;
}

// ─── Rings Painter ────────────────────────────────────────────────────────────
class _RingsPainter extends CustomPainter {
  final double expand;
  final double fade;
  final Color accent;
  final Color accentDim;

  _RingsPainter({
    required this.expand,
    required this.fade,
    required this.accent,
    required this.accentDim,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (expand <= 0 || fade <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width * 0.55;

    // Three staggered rings
    final rings = [
      (delay: 0.0, width: 1.5, opacity: 0.7),
      (delay: 0.12, width: 1.0, opacity: 0.4),
      (delay: 0.22, width: 0.7, opacity: 0.2),
    ];

    for (final ring in rings) {
      final t = ((expand - ring.delay) / (1.0 - ring.delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final radius = maxR * t;
      final alpha = (fade * ring.opacity * (1.0 - t * 0.6)).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = accent.withOpacity(alpha)
        ..strokeWidth = ring.width
        ..style = PaintingStyle.stroke;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) =>
      old.expand != expand || old.fade != fade;
}