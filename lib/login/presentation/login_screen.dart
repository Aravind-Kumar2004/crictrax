import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crictrax/splash/presentation/stadium_splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../dashboard/presentation/dashboard_screen.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
class _C {
  static const bg          = Color(0xFF050A18);
  static const surface     = Color(0xFF0A1628);
  static const surfaceHigh = Color(0xFF0F1E35);
  static const accent      = Color(0xFF00D4FF);
  static const accentDim   = Color(0xFF0066CC);
  static const success     = Color(0xFF00E676);
  static const danger      = Color(0xFFFF3D3D);
  static const live        = Color(0xFFFF6B35);

  static const accentGrad = LinearGradient(
    colors: [Color(0xFF00D4FF), Color(0xFF0066CC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ─── Global TV Scale Helper ───────────────────────────────────────────────────
double _tvScale(BuildContext context) {
  return MediaQuery.of(context).size.width / 1920.0;
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;

  late AnimationController _floatCtrl;
  late Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
    _glowAnim = CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut);

    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
    _floatAnim = CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    _floatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final s = _tvScale(context);
    final playerWidth = size.width * 0.40;
    final playerHeight = size.height * 0.85;

    return Scaffold(
      backgroundColor: _C.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. Stadium background ──────────────────────────────────────────
          Positioned.fill(
            child: Image.asset(
              'assets/images/backgrounds/login_bg.jpg',
              fit: BoxFit.cover,
            ),
          ),

          // ── 2. Dark cinematic overlay ──────────────────────────────────────
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xCC050A18),
                    Color(0x88050A18),
                    Color(0xBB050A18),
                    Color(0xEE050A18),
                  ],
                  stops: [0.0, 0.3, 0.65, 1.0],
                ),
              ),
            ),
          ),

          // ── 3. Left player glow ────────────────────────────────────────────
          Positioned(
            left: -30,
            bottom: 0,
            child: _PlayerGlow(
              alignment: Alignment.centerLeft,
              size: size.height * 0.85,
            ),
          ),

          // ── 4. Right player glow ───────────────────────────────────────────
          Positioned(
            right: -30,
            bottom: 0,
            child: _PlayerGlow(
              alignment: Alignment.centerRight,
              size: size.height * 0.85,
            ),
          ),

          // ── 5. Left player PNG — clipped to a fixed width so it can't balloon ──
          Positioned(
            left: -100,
            bottom: 0,
            child: Image.asset(
              'assets/images/players/login_left_player.png',
              height: playerHeight,
              fit: BoxFit.contain,
              alignment: Alignment.bottomLeft,
            ),
          ),

          // ── 6. Right player PNG — same fixed width, clipped from the right ──
          Positioned(
            right: -100,
            bottom: 0,
            child: Image.asset(
              'assets/images/players/login_right_player.png',
              height: playerHeight,
              fit: BoxFit.contain,
              alignment: Alignment.bottomRight,
            ),
          ),

          // ── 7. Center content — plain scrollable column, NEVER goes blank ──
          Positioned.fill(
            child: SafeArea(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _HeroHeadline(),
                      SizedBox(height: 20 * s),
                      AnimatedBuilder(
                        animation: _floatAnim,
                        builder: (_, child) => Transform.translate(
                          offset: Offset(0, -3 + 3 * _floatAnim.value),
                          child: child,
                        ),
                        child: TvQrSection(glowAnim: _glowAnim),
                      ),
                      SizedBox(height: 24 * s),
                      _BottomSteps(),
                      SizedBox(height: 14 * s),
                      _Footer(),
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

// ═══════════════════════════════════════════════════════════════════════════════
// PLAYER GLOW — ambient behind each player
// ═══════════════════════════════════════════════════════════════════════════════
class _PlayerGlow extends StatelessWidget {
  final Alignment alignment;
  final double size;
  const _PlayerGlow({required this.alignment, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size * 0.55,
      height: size,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: alignment,
          colors: [
            _C.accent.withOpacity(0.18),
            _C.accent.withOpacity(0.06),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}


class _HeroHeadline extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = _tvScale(context);
    return Column(
      children: [
        Text(
          'WELCOME TO',
          style: TextStyle(
            color: Colors.white.withOpacity(0.75),
            fontSize: 14 * s,
            fontWeight: FontWeight.w600,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 2),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Colors.white, Color(0xFFD0F4FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(bounds),
          child: Text(
            'CRICTRAX TV',
            style: TextStyle(
              color: Colors.white,
              fontSize: 40 * s,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              height: 1.0,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'LIVE CRICKET',
                style: TextStyle(color: _C.accent),
              ),
              TextSpan(
                text: '   •   ',
                style: TextStyle(color: _C.accent.withOpacity(0.5)),
              ),
              TextSpan(
                text: 'TOURNAMENT',
                style: TextStyle(color: _C.accent),
              ),
              TextSpan(
                text: '   •   ',
                style: TextStyle(color: _C.accent.withOpacity(0.5)),
              ),
              TextSpan(
                text: 'STATISTICS',
                style: TextStyle(color: _C.accent),
              ),
            ],
          ),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

class _TagDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 4,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _C.accent.withOpacity(0.6),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BOTTOM STEPS
// ═══════════════════════════════════════════════════════════════════════════════
class _BottomSteps extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _StepItem(
          icon: Icons.phone_android_rounded,
          number: '1',
          label: 'Open\nCRICTRAX App',
        ),
        _StepArrow(),
        _StepItem(
          icon: Icons.link_rounded,
          number: '2',
          label: 'Tap\n"Link TV"',
        ),
        _StepArrow(),
        _StepItem(
          icon: Icons.qr_code_scanner_rounded,
          number: '3',
          label: 'Scan\nQR Code',
        ),
      ],
    );
  }
}

class _StepItem extends StatelessWidget {
  final IconData icon;
  final String number;
  final String label;

  const _StepItem({
    required this.icon,
    required this.number,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            // Glow ring
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _C.accent.withOpacity(0.22),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            // Icon circle
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _C.accent.withOpacity(0.1),
                border: Border.all(
                    color: _C.accent.withOpacity(0.4), width: 1.5),
              ),
              child: Icon(icon, color: _C.accent, size: 22),
            ),
            // Number badge
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _C.accentGrad,
                  boxShadow: [
                    BoxShadow(
                      color: _C.accent.withOpacity(0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    number,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.55),
            fontSize: 11,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _StepArrow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24, left: 14, right: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _C.accent.withOpacity(0.2),
                  _C.accent.withOpacity(0.55),
                ],
              ),
            ),
          ),
          Icon(Icons.arrow_forward_rounded,
              color: _C.accent.withOpacity(0.55), size: 14),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FOOTER
// ═══════════════════════════════════════════════════════════════════════════════
class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Powered by ',
              style: TextStyle(
                color: Colors.white.withOpacity(0.35),
                fontSize: 12,
              ),
            ),
            Text(
              'CRICTRAX',
              style: TextStyle(
                color: _C.accent,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'Version 1.0',
          style: TextStyle(
            color: Colors.white.withOpacity(0.18),
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TV QR SECTION — all business logic COMPLETELY UNCHANGED
//
// SIZING FIX ONLY:
//   • `build()` computes a single `cardHeight` (was previously named
//     `loadingCardHeight` and only ever reached the loading state).
//   • `_buildContent` now threads that same `cardHeight` into all four
//     state builders instead of just `_buildLoadingState`.
//   • `_buildQrCard`, `_buildLinkingState`, and `_buildExpiredState` each
//     gained a `cardHeight` parameter and now set `height: cardHeight` on
//     their outer Container — previously two of them referenced an
//     out-of-scope variable (a compile error) and the third never set a
//     height at all, which is why the card visibly resized between states.
// No session creation, QR generation, countdown timer, navigation, or
// animation logic was touched.
// ═══════════════════════════════════════════════════════════════════════════════
class TvQrSection extends StatefulWidget {
  final Animation<double> glowAnim;
  const TvQrSection({Key? key, required this.glowAnim}) : super(key: key);

  @override
  State<TvQrSection> createState() => _TvQrSectionState();
}

class _TvQrSectionState extends State<TvQrSection>
    with TickerProviderStateMixin {
  // ── State (UNCHANGED) ─────────────────────────────────────────────────────
  String? _sessionId;
  String? _qrData;
  bool _expired = false;
  bool _linking = false;
  StreamSubscription? _sub;

  // ── Animation ─────────────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  late AnimationController _timerCtrl;

  // Countdown display
  int _secondsLeft = 300;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnim =
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);

    _timerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(minutes: 5),
    );

    _createSession();
  }

  // ── Business Logic (COMPLETELY UNCHANGED) ─────────────────────────────────
  Future<void> _createSession() async {
    _countdownTimer?.cancel();
    setState(() {
      _expired = false;
      _sessionId = null;
      _qrData = null;
      _linking = false;
      _secondsLeft = 300;
    });

    final sessionId = const Uuid().v4();
    final expiresAt = DateTime.now().add(const Duration(minutes: 5));

    await FirebaseFirestore.instance
        .collection('tv_sessions')
        .doc(sessionId)
        .set({
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'userId': null,
      'displayName': null,
      'email': null,
    });

    setState(() {
      _sessionId = sessionId;
      _qrData = 'crictrax://link-tv?session=$sessionId';
    });

    _timerCtrl.forward(from: 0);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() =>
      _secondsLeft = (_secondsLeft - 1).clamp(0, 300));
    });

    _listenForLink(sessionId);

    Future.delayed(const Duration(minutes: 5), () {
      if (mounted && _sessionId == sessionId && !_linking) {
        setState(() => _expired = true);
        _sub?.cancel();
        _countdownTimer?.cancel();
      }
    });
  }

  void _listenForLink(String sessionId) {
    _sub?.cancel();
    _sub = FirebaseFirestore.instance
        .collection('tv_sessions')
        .doc(sessionId)
        .snapshots()
        .listen((snap) {
      if (!snap.exists) return;
      final data = snap.data()!;
      if (data['status'] == 'linked' && mounted) {
        _sub?.cancel();
        _countdownTimer?.cancel();
        final userId = data['userId'] as String;
        final displayName = data['displayName'] as String? ?? '';
        final email = data['email'] as String? ?? '';

        setState(() => _linking = true);

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                transitionDuration:
                const Duration(milliseconds: 600),
                pageBuilder: (_, __, ___) => StadiumSplashScreen(
                  userId: userId,
                  displayName: displayName,
                  email: email,
                  sessionId: sessionId,
                ),
                transitionsBuilder:
                    (_, animation, __, child) =>
                    FadeTransition(
                        opacity: animation, child: child),
              ),
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pulseCtrl.dispose();
    _timerCtrl.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // ── Responsive sizing (relative to actual screen, clamped so it never
    //    balloons on TV panels reporting large logical sizes). `cardHeight`
    //    is now the single source of truth for every state's outer card. ───
    final screenSize = MediaQuery.of(context).size;
    final cardWidth = (screenSize.width * 0.24).clamp(320.0, 520.0);
    final qrSize = (screenSize.width * 0.11).clamp(140.0, 190.0);
    final cardHeight = (screenSize.height * 0.48).clamp(300.0, 400.0);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: _buildContent(context, cardWidth, qrSize, cardHeight),
    );
  }

  Widget _buildContent(BuildContext context, double cardWidth, double qrSize,
      double cardHeight) {
    if (_linking) return _buildLinkingState(context, cardWidth, cardHeight);
    if (_expired) return _buildExpiredState(context, cardWidth, cardHeight);
    if (_qrData == null) return _buildLoadingState(cardWidth, cardHeight);
    return _buildQrCard(context, cardWidth, qrSize, cardHeight);
  }

  // ── QR Glass Card ─────────────────────────────────────────────────────────
  Widget _buildQrCard(
      BuildContext context, double cardWidth, double qrSize, double cardHeight) {
    final s = _tvScale(context);
    final mins =
    (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final secs =
    (_secondsLeft % 60).toString().padLeft(2, '0');
    final timerFraction = _secondsLeft / 300.0;
    final timerColor = timerFraction > 0.4
        ? _C.accent
        : timerFraction > 0.15
        ? _C.live
        : _C.danger;

    return AnimatedBuilder(
      animation: widget.glowAnim,
      builder: (_, child) => Container(
        key: const ValueKey('qr'),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: _C.accent.withOpacity(
                  0.18 + 0.14 * widget.glowAnim.value),
              blurRadius: 40 + 16 * widget.glowAnim.value,
              spreadRadius: 2,
            ),
          ],
        ),
        child: child,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: cardWidth,
            height: cardHeight,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _C.accent.withOpacity(0.4),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── SCAN TO LOGIN header ─────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              _C.accent.withOpacity(0.5),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'SCAN TO LOGIN',
                      style: TextStyle(
                        color: _C.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.5,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _C.accent.withOpacity(0.5),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 14 * s),

                // ── QR Code ──────────────────────────────────────
                _PremiumQrCode(
                  qrData: _qrData!,
                  pulseAnim: _pulseAnim,
                  qrSize: qrSize,
                ),

                SizedBox(height: 14 * s),

                // ── Scan instruction ─────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.phone_android_rounded,
                      color: Colors.white.withOpacity(0.45),
                      size: 14,
                    ),
                    const SizedBox(width: 7),
                    RichText(
                      text: TextSpan(
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.45),
                          fontSize: 10,
                        ),
                        children: [
                          const TextSpan(text: 'Scan using the '),
                          TextSpan(
                            text: 'CRICTRAX',
                            style: TextStyle(
                              color: _C.accent,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const TextSpan(text: ' Mobile App'),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 14 * s),

                // ── Countdown ────────────────────────────────────
                _PremiumCountdown(
                  mins: mins,
                  secs: secs,
                  fraction: timerFraction,
                  color: timerColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Linking State ─────────────────────────────────────────────────────────
  Widget _buildLinkingState(
      BuildContext context, double cardWidth, double cardHeight) {
    final s = _tvScale(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          key: const ValueKey('linking'),
          width: cardWidth,
          height: cardHeight,
          padding: const EdgeInsets.symmetric(
              horizontal: 40, vertical: 48),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
                color: _C.success.withOpacity(0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: _C.success.withOpacity(0.2),
                blurRadius: 36,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _C.success.withOpacity(0.1),
                  border: Border.all(
                      color: _C.success.withOpacity(0.4),
                      width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: _C.success.withOpacity(0.3),
                      blurRadius: 28,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(Icons.check_rounded,
                    color: _C.success, size: 38),
              ),
              SizedBox(height: 24 * s),
              const Text(
                'Account Linked!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: 10 * s),
              Text(
                'Loading your dashboard…',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 14 * s,
                ),
              ),
              const SizedBox(height: 32),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  backgroundColor: _C.accent.withOpacity(0.08),
                  valueColor:
                  AlwaysStoppedAnimation<Color>(_C.accent),
                  minHeight: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Expired State ─────────────────────────────────────────────────────────
  Widget _buildExpiredState(
      BuildContext context, double cardWidth, double cardHeight) {
    final s = _tvScale(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          key: const ValueKey('expired'),
          width: cardWidth,
          height: cardHeight,
          padding: const EdgeInsets.symmetric(
              horizontal: 40, vertical: 48),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
                color: _C.danger.withOpacity(0.35), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _C.danger.withOpacity(0.08),
                  border: Border.all(
                      color: _C.danger.withOpacity(0.3),
                      width: 1.5),
                ),
                child: Icon(Icons.timer_off_rounded,
                    color: _C.danger.withOpacity(0.8), size: 32),
              ),
              SizedBox(height: 20 * s),
              const Text(
                'QR Code Expired',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Timed out after 5 minutes.\nGenerate a fresh code to continue.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.35),
                  fontSize: 13,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Focus(
                child: Builder(builder: (ctx) {
                  final focused = Focus.of(ctx).hasFocus;
                  return GestureDetector(
                    onTap: _createSession,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: focused
                              ? [_C.accent, _C.accentDim]
                              : [
                            _C.accent.withOpacity(0.85),
                            _C.accentDim.withOpacity(0.85)
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: focused
                            ? [
                          BoxShadow(
                            color:
                            _C.accent.withOpacity(0.5),
                            blurRadius: 20,
                          )
                        ]
                            : [],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.refresh_rounded,
                              color: Colors.white, size: 18),
                          SizedBox(width: 10),
                          Text(
                            'Generate New QR',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Loading State ─────────────────────────────────────────────────────────
  Widget _buildLoadingState(double cardWidth, double cardHeight) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          key: const ValueKey('loading'),
          width: cardWidth,
          height: cardHeight,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
                color: _C.accent.withOpacity(0.3), width: 1.5),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    color: _C.accent,
                    strokeWidth: 2.5,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Preparing session…',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 13,
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

// ═══════════════════════════════════════════════════════════════════════════════
// PREMIUM QR CODE — white card with glow
// ═══════════════════════════════════════════════════════════════════════════════
class _PremiumQrCode extends StatelessWidget {
  final String qrData;
  final Animation<double> pulseAnim;
  final double qrSize;

  const _PremiumQrCode({
    required this.qrData,
    required this.pulseAnim,
    required this.qrSize,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (_, __) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _C.accent
                .withOpacity(0.3 + 0.2 * pulseAnim.value),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _C.accent
                  .withOpacity(0.20 + 0.15 * pulseAnim.value),
              blurRadius: 28 + 8 * pulseAnim.value,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: QrImageView(
          data: qrData,
          size: qrSize,
          backgroundColor: Colors.white,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PREMIUM COUNTDOWN
// ═══════════════════════════════════════════════════════════════════════════════
class _PremiumCountdown extends StatelessWidget {
  final String mins, secs;
  final double fraction;
  final Color color;

  const _PremiumCountdown({
    required this.mins,
    required this.secs,
    required this.fraction,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final s = _tvScale(context);
    return Column(
      children: [
        Container(
          height: 1,
          color: Colors.white.withOpacity(0.08),
        ),
        SizedBox(height: 14 * s),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timer_rounded, color: color.withOpacity(0.8), size: 16),
            const SizedBox(width: 8),
            Text(
              'EXPIRES IN',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '$mins : $secs',
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                height: 1,
              ),
            ),
          ],
        ),
        SizedBox(height: 10 * s),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: fraction,
            backgroundColor: Colors.white.withOpacity(0.06),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 4,
          ),
        ),
      ],
    );
  }
}