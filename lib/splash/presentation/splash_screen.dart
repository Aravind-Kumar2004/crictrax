import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
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

  // Stadium / broadcast layers (purely visual, riding the same controller)
  late Animation<double> _floodlightRise;   // 0 → 1: floodlights "switch on"
  late Animation<double> _stadiumReveal;    // 0 → 1: stadium image brightens in
  late Animation<double> _cameraZoom;       // 1.00 → 1.10 → 1.18: cinematic push-in
  late Animation<double> _welcomeFade;      // "WELCOME TO" block fade
  late Animation<double> _progressLabelFade; // "Preparing Live Broadcast..." label

  // Exit
  late Animation<double> _backgroundBlur;
  late Animation<double> _exitDarken;       // extra darkening right before navigation

  // Slow ambient particles — generated once, animated by controller value
  final List<_Particle> _particles =
  List.generate(22, (i) => _Particle.random(i));

  // Whether the CRICTRAX logo image asset is available. Resolved once at
  // build time via a FutureBuilder-free check using an AssetImage probe.
  bool? _hasLogoAsset;

  @override
  void initState() {
    super.initState();

    // Total: 2300ms — identical to original duration (timer/duration unchanged)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    // ── Act 1: scanline sweep (0 → ~400ms) ─────────────────────────────────
    _scanLine = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.17, curve: Curves.easeInOut),
      ),
    );

    // ── Floodlights / stadium reveal — screen starts almost black, then the
    //    stadium image slowly becomes visible as the "lights switch on" ────
    _floodlightRise = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.30, curve: Curves.easeOut),
      ),
    );
    _stadiumReveal = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
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
    _welcomeFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.70, 0.90, curve: Curves.easeIn),
      ),
    );
    _progressLabelFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.60, 0.75, curve: Curves.easeIn),
      ),
    );
    _progressBar = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.68, 0.95, curve: Curves.easeInOut),
      ),
    );

    // ── Cinematic camera: slow push-in 1.00 → 1.10 across the whole splash,
    //    then an additional punch 1.10 → 1.18 right before navigation ──────
    _cameraZoom = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.00, end: 1.10)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 85,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.10, end: 1.18)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 15,
      ),
    ]).animate(_controller);

    // ── Exit: darken slightly + blur right before navigation (unchanged
    //    interval/timing relative to original) ──────────────────────────────
    _backgroundBlur = Tween<double>(begin: 0.0, end: 15.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.85, 1.0, curve: Curves.easeInOut),
      ),
    );
    _exitDarken = Tween<double>(begin: 0.0, end: 0.35).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.85, 1.0, curve: Curves.easeInOut),
      ),
    );

    // ── Navigate to LoginScreen (UNCHANGED — navigation/timer logic intact) ─
    _controller.forward().then((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 800),
          pageBuilder: (_, __, ___) => LoginScreen(),
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


  Future<void> _probeLogoAsset(BuildContext context) async {
    if (_hasLogoAsset != null) return;
    try {
      final stream = const AssetImage(_Assets.crictraxLogo)
          .resolve(createLocalImageConfiguration(context));
      final completer = Completer<void>();
      late ImageStreamListener listener;
      listener = ImageStreamListener(
            (info, _) {
          if (mounted) setState(() => _hasLogoAsset = true);
          stream.removeListener(listener);
          if (!completer.isCompleted) completer.complete();
        },
        onError: (error, stack) {
          if (mounted) setState(() => _hasLogoAsset = false);
          stream.removeListener(listener);
          if (!completer.isCompleted) completer.complete();
        },
      );
      stream.addListener(listener);
      await completer.future;
    } catch (_) {
      if (mounted) setState(() => _hasLogoAsset = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    if (_hasLogoAsset == null) {
      // Fire-and-forget probe; UI falls back to icon until resolved.
      _probeLogoAsset(context);
    }

    return Scaffold(
      backgroundColor: _C.bg,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final zoom = _cameraZoom.value;
          return Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              // ── Layer 0: stadium broadcast image with cinematic zoom ─────
              Transform.scale(
                scale: zoom,
                child: Opacity(
                  opacity: _stadiumReveal.value,
                  child: Image.asset(
                    _Assets.stadiumBackground,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (_, __, ___) =>
                        Container(color: _C.bg), // graceful fallback
                  ),
                ),
              ),

              // ── Layer 0a: "floodlights switching on" — almost black at
              //    start, brightening via opacity + glow, no manual lights ──
              Opacity(
                opacity: (1.0 - _floodlightRise.value).clamp(0.0, 1.0),
                child: Container(color: Colors.black),
              ),

              // ── Layer 0b: dark broadcast overlay for text legibility ─────
              Container(color: Colors.black.withOpacity(0.40)),

              // ── Layer 0c: soft floodlight bloom rising with the reveal ──
              Opacity(
                opacity: _floodlightRise.value,
                child: _buildFloodlightBloom(size),
              ),

              // ── Layer 0d: ambient deep glow ─────────────────────────────
              Transform.scale(scale: zoom, child: _buildAmbientGlow(size)),

              // ── Layer 0e: slow drifting particles (depth) ───────────────
              Positioned.fill(
                child: CustomPaint(
                  painter: _ParticlePainter(
                    particles: _particles,
                    t: _controller.value,
                    accent: _C.accent,
                  ),
                ),
              ),

              // ── Layer 1: scanline sweep ────────────────────────────────
              _buildScanLine(size),

              // ── Layer 2: energy rings ──────────────────────────────────
              _buildRings(size),

              // ── Layer 3: centre icon + wordmark ───────────────────────
              Center(child: _buildCentreContent(size)),

              // ── Layer 4: progress bar (bottom) ─────────────────────────
              _buildProgressBar(size),

              // ── Layer 5: exit darken + blur (timing unchanged) ─────────
              Opacity(
                opacity: _exitDarken.value,
                child: Container(color: Colors.black),
              ),
              AnimatedOpacity(
                opacity: _exitDarken.value,
                duration: Duration.zero,
                child: Container(
                  color: Colors.black.withOpacity(0.25),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Floodlight bloom — soft radial glow suggesting stadium lights turning
  //    on, built purely from opacity/blur/glow (no manually drawn lights) ──
  Widget _buildFloodlightBloom(Size size) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Align(
              alignment: const Alignment(-0.7, -0.85),
              child: _bloomDot(),
            ),
            Align(
              alignment: const Alignment(0.7, -0.85),
              child: _bloomDot(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bloomDot() {
    return Container(
      width: 4,
      height: 4,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _C.accent.withOpacity(0.0),
        boxShadow: [
          BoxShadow(
            color: _C.accent.withOpacity(0.35),
            blurRadius: 120,
            spreadRadius: 60,
          ),
        ],
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
        // Logo container — glassmorphism + glow + blue bloom + scale anim
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

        const SizedBox(height: 22),

        // "WELCOME TO CRICTRAX TV / Experience Live Cricket Like Never
        //  Before" broadcast tagline block
        Opacity(
          opacity: _welcomeFade.value,
          child: _buildWelcomeBlock(),
        ),
      ],
    );
  }

  Widget _buildIconMark() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Lens flare streaks behind the logo
        Opacity(
          opacity: _iconGlow.value * 0.8,
          child: CustomPaint(
            size: const Size(220, 220),
            painter: _LensFlarePainter(accent: _C.accent),
          ),
        ),
        // Blue bloom / outer glow ring
        Opacity(
          opacity: _iconGlow.value,
          child: Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _C.accent.withOpacity(0.40 * _iconGlow.value),
                  blurRadius: 70,
                  spreadRadius: 14,
                ),
              ],
            ),
          ),
        ),

              ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                     child: Container(
                     width: 96,
                      height: 96,
                       padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          color: Colors.white.withOpacity(0.08), // Glass effect
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
                               ),
                                       boxShadow: [
                                                    BoxShadow(
                              color: _C.accent.withOpacity(0.2 * _iconGlow.value),
                                   blurRadius: 30,
                                    spreadRadius: 2,
                                     ),
                                  BoxShadow(
                                  color: Colors.black.withOpacity(0.25),
                                  blurRadius: 20,
                                    offset: const Offset(0, 8),
                                      ),
                                        ],
                                     ),
              child: (_hasLogoAsset == true)
                  ? Image.asset(
                _Assets.crictraxLogo,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.white.withOpacity(0.04),
                    border: Border.all(
                      color: _C.accent.withOpacity(0.3),
                      width: 1.2,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.sports_cricket,
                      color: Colors.white,
                      size: 56,
                    ),
                  ),
                ),
              )
                    : const Center(
                child: Icon(
                Icons.sports_cricket,
                color: Colors.white,
                size: 56,
              ),
            ),
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
          'TV  SCOREBOARD',
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

  // ── Progress Bar ─────────────────────────────────────────────────────────
  Widget _buildProgressBar(Size size) {
    return Positioned(
      bottom: 52,
      left: size.width / 2 - 110,
      width: 220,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Opacity(
            opacity: _progressLabelFade.value,
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
            opacity: (_progressBar.value * 3).clamp(0.0, 1.0),
            child: Container(
              height: 2.5,
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
                        blurRadius: 8,
                        spreadRadius: 0.5,
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
}

// ─── Particle model ───────────────────────────────────────────────────────────
class _Particle {
  final double x, y, speed, radius, phase;
  _Particle(this.x, this.y, this.speed, this.radius, this.phase);

  factory _Particle.random(int seed) {
    final r = math.Random(seed * 7919);
    return _Particle(
      r.nextDouble(),
      r.nextDouble(),
      0.05 + r.nextDouble() * 0.08,
      0.6 + r.nextDouble() * 1.8,
      r.nextDouble() * math.pi * 2,
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double t;
  final Color accent;

  _ParticlePainter({required this.particles, required this.t, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = accent.withOpacity(0.0);
    for (final p in particles) {
      // very slow upward drift, wraps around
      final dy = (p.y - t * p.speed) % 1.0;
      final dx = p.x + 0.015 * math.sin(t * 2 * math.pi + p.phase);
      final twinkle = (0.3 + 0.3 * math.sin(t * 6 * math.pi + p.phase)).clamp(0.0, 1.0);
      paint.color = accent.withOpacity(0.16 * twinkle);
      canvas.drawCircle(
        Offset(dx * size.width, dy * size.height),
        p.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.t != t;
}

// ─── Lens Flare Painter ───────────────────────────────────────────────────────
class _LensFlarePainter extends CustomPainter {
  final Color accent;
  _LensFlarePainter({required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final hPaint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.transparent, accent.withOpacity(0.35), Colors.transparent],
      ).createShader(Rect.fromCenter(center: center, width: size.width, height: 3));
    canvas.drawRect(
      Rect.fromCenter(center: center, width: size.width, height: 2),
      hPaint,
    );

    final vPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, accent.withOpacity(0.25), Colors.transparent],
      ).createShader(Rect.fromCenter(center: center, width: 3, height: size.height));
    canvas.drawRect(
      Rect.fromCenter(center: center, width: 2, height: size.height),
      vPaint,
    );

    final haloPaint = Paint()
      ..shader = RadialGradient(
        colors: [accent.withOpacity(0.18), Colors.transparent],
      ).createShader(Rect.fromCircle(center: center, radius: size.width / 2));
    canvas.drawCircle(center, size.width / 2, haloPaint);
  }

  @override
  bool shouldRepaint(_LensFlarePainter old) => false;
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