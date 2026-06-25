import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../dashboard/presentation/dashboard_screen.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
class _C {
  static const bg = Color(0xFF050A18);
  static const surface = Color(0xFF0A1628);
  static const surfaceHigh = Color(0xFF0F1E35);
  static const accent = Color(0xFF00D4FF);
  static const accentDim = Color(0xFF0066CC);
  static const success = Color(0xFF00E676);
  static const danger = Color(0xFFFF3D3D);
  static const live = Color(0xFFFF6B35);
}

// ═══════════════════════════════════════════════════════════════════════════════
// LOGIN SCREEN
// ═══════════════════════════════════════════════════════════════════════════════
class LoginScreen extends StatelessWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Ambient background glows
          Positioned(
            top: -160,
            right: -80,
            child: _AmbientBlob(color: _C.accent, size: 480),
          ),
          Positioned(
            bottom: -120,
            left: -60,
            child: _AmbientBlob(color: const Color(0xFF6C3AFF), size: 360),
          ),
          // Subtle grid pattern
          const Positioned.fill(child: _GridOverlay()),
          // Main layout — left branding panel + right QR panel
          Row(
            children: [
              // ── Left: Brand Panel ─────────────────────────────────────
              Expanded(
                flex: 5,
                child: _BrandPanel(),
              ),
              // ── Vertical divider ──────────────────────────────────────
              Container(
                width: 1,
                margin: const EdgeInsets.symmetric(vertical: 60),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.white.withOpacity(0.08),
                      Colors.white.withOpacity(0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              // ── Right: QR Panel ───────────────────────────────────────
              Expanded(
                flex: 5,
                child: Center(child: TvQrSection()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Brand Panel ──────────────────────────────────────────────────────────────
class _BrandPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo mark
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [_C.accent, _C.accentDim],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _C.accent.withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(Icons.sports_cricket,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CRICTRAX',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    ),
                  ),
                  Text(
                    'TV SCORECARD',
                    style: TextStyle(
                      color: _C.accent.withOpacity(0.6),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.5,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const Spacer(),

          // Hero headline
          Text(
            'Live Cricket\nScoring\nfor Your TV.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 54,
              fontWeight: FontWeight.w900,
              height: 1.1,
              letterSpacing: -1.0,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Bring professional-grade scorecards\nto your big screen in seconds.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.38),
              fontSize: 16,
              height: 1.6,
            ),
          ),

          const SizedBox(height: 48),

          // Feature chips
          _FeatureRow(
            icon: Icons.bolt_rounded,
            color: _C.live,
            text: 'Real-time ball-by-ball updates',
          ),
          const SizedBox(height: 16),
          _FeatureRow(
            icon: Icons.phone_android_rounded,
            color: _C.accent,
            text: 'Control from the CRICTRAX mobile app',
          ),
          const SizedBox(height: 16),
          _FeatureRow(
            icon: Icons.lock_rounded,
            color: _C.success,
            text: 'Secure QR-based authentication',
          ),

          const Spacer(),

          // Bottom tag
          Text(
            'crictrax.app',
            style: TextStyle(
              color: Colors.white.withOpacity(0.12),
              fontSize: 13,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _FeatureRow({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 14),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withOpacity(0.55),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ─── Ambient Blob ─────────────────────────────────────────────────────────────
class _AmbientBlob extends StatelessWidget {
  final Color color;
  final double size;
  const _AmbientBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withOpacity(0.08),
            color.withOpacity(0.03),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

// ─── Grid Overlay ─────────────────────────────────────────────────────────────
class _GridOverlay extends StatelessWidget {
  const _GridOverlay();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GridPainter());
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.016)
      ..strokeWidth = 0.5;
    const spacing = 32.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter _) => false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TV QR SECTION  (all business logic UNCHANGED)
// ═══════════════════════════════════════════════════════════════════════════════
class TvQrSection extends StatefulWidget {
  const TvQrSection({Key? key}) : super(key: key);

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

    // Start visual countdown timer
    _timerCtrl.forward(from: 0);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _secondsLeft = (_secondsLeft - 1).clamp(0, 300));
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
                transitionDuration: const Duration(milliseconds: 800),
                pageBuilder: (_, __, ___) => DashboardScreen(
                  userId: userId,
                  displayName: displayName,
                  email: email,
                  sessionId: sessionId,
                ),
                transitionsBuilder: (_, animation, __, child) =>
                    FadeTransition(opacity: animation, child: child),
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
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_linking) return _buildLinkingState();
    if (_expired) return _buildExpiredState();
    if (_qrData == null) return _buildLoadingState();
    return _buildQrState();
  }

  // ── Linking State ─────────────────────────────────────────────────────────
  Widget _buildLinkingState() {
    return Container(
      key: const ValueKey('linking'),
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 56),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Success icon with glow
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _C.success.withOpacity(0.08),
              border:
              Border.all(color: _C.success.withOpacity(0.3), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: _C.success.withOpacity(0.25),
                  blurRadius: 40,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(Icons.check_rounded,
                color: _C.success, size: 42),
          ),
          const SizedBox(height: 28),
          const Text(
            'Account Linked!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Loading your dashboard…',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 36),
          SizedBox(
            width: 160,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                backgroundColor: _C.accent.withOpacity(0.08),
                valueColor: AlwaysStoppedAnimation<Color>(_C.accent),
                minHeight: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Expired State ─────────────────────────────────────────────────────────
  Widget _buildExpiredState() {
    return Container(
      key: const ValueKey('expired'),
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 56),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _C.danger.withOpacity(0.07),
              border:
              Border.all(color: _C.danger.withOpacity(0.2), width: 1.5),
            ),
            child: Icon(Icons.timer_off_rounded,
                color: _C.danger.withOpacity(0.7), size: 36),
          ),
          const SizedBox(height: 24),
          const Text(
            'QR Code Expired',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'The code has timed out after 5 minutes.\nGenerate a fresh one to continue.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.35),
              fontSize: 14,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
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
                        _C.accent.withOpacity(0.8),
                        _C.accentDim.withOpacity(0.8)
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: focused
                        ? [
                      BoxShadow(
                        color: _C.accent.withOpacity(0.45),
                        blurRadius: 20,
                        spreadRadius: 0,
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
                          fontSize: 15,
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
    );
  }

  // ── Loading State ─────────────────────────────────────────────────────────
  Widget _buildLoadingState() {
    return const Center(
      key: ValueKey('loading'),
      child: CircularProgressIndicator(
        color: _C.accent,
        strokeWidth: 2.5,
      ),
    );
  }

  // ── QR State ──────────────────────────────────────────────────────────────
  Widget _buildQrState() {
    final mins = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final secs = (_secondsLeft % 60).toString().padLeft(2, '0');
    final timerFraction = _secondsLeft / 300.0;
    final timerColor = timerFraction > 0.4
        ? _C.accent
        : timerFraction > 0.15
        ? _C.live
        : _C.danger;

    return Container(
      key: const ValueKey('qr'),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Header
          Text(
            'Scan to Sign In',
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Open CRICTRAX on your phone and\ntap "Link TV" to scan.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.38),
              fontSize: 15,
              height: 1.55,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 36),

          // QR code container
          _QrContainer(qrData: _qrData!, pulseAnim: _pulseAnim),

          const SizedBox(height: 28),

          // Countdown timer
          _CountdownTimer(
            mins: mins,
            secs: secs,
            fraction: timerFraction,
            color: timerColor,
          ),

          const SizedBox(height: 20),

          // Step hints
          _StepHints(),
        ],
      ),
    );
  }
}

// ─── QR Container ─────────────────────────────────────────────────────────────
class _QrContainer extends StatelessWidget {
  final String qrData;
  final Animation<double> pulseAnim;

  const _QrContainer({required this.qrData, required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (_, __) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer glow ring (pulsing)
            Container(
              width: 220 + 24 + (8 * pulseAnim.value),
              height: 220 + 24 + (8 * pulseAnim.value),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _C.accent
                        .withOpacity(0.12 + 0.08 * pulseAnim.value),
                    blurRadius: 40,
                    spreadRadius: 8,
                  ),
                ],
              ),
            ),
            // QR card
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _C.accent.withOpacity(0.25),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _C.accent
                            .withOpacity(0.15 + 0.10 * pulseAnim.value),
                        blurRadius: 32,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: qrData,
                    size: 200,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
            ),
            // Corner accent marks
            ..._cornerMarks(),
          ],
        );
      },
    );
  }

  List<Widget> _cornerMarks() {
    const size = 248.0;
    const markSize = 16.0;
    const markThick = 2.0;
    final color = _C.accent.withOpacity(0.6);

    Widget mark(double top, double left, bool flipH, bool flipV) {
      return Positioned(
        top: top,
        left: left,
        child: Transform.flip(
          flipX: flipH,
          flipY: flipV,
          child: SizedBox(
            width: markSize,
            height: markSize,
            child: CustomPaint(
              painter: _CornerMarkPainter(color: color, thickness: markThick),
            ),
          ),
        ),
      );
    }

    const offset = (size / 2) - markSize;
    return [
      mark(-offset - 4, -offset - 4, false, false),
      mark(-offset - 4, offset - 8, true, false),
      mark(offset - 8, -offset - 4, false, true),
      mark(offset - 8, offset - 8, true, true),
    ];
  }
}

class _CornerMarkPainter extends CustomPainter {
  final Color color;
  final double thickness;
  const _CornerMarkPainter({required this.color, required this.thickness});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, size.height), const Offset(0, 0), paint);
    canvas.drawLine(const Offset(0, 0), Offset(size.width, 0), paint);
  }

  @override
  bool shouldRepaint(_CornerMarkPainter _) => false;
}

// ─── Countdown Timer ──────────────────────────────────────────────────────────
class _CountdownTimer extends StatelessWidget {
  final String mins;
  final String secs;
  final double fraction;
  final Color color;

  const _CountdownTimer({
    required this.mins,
    required this.secs,
    required this.fraction,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Progress track
        SizedBox(
          width: 200,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              backgroundColor: Colors.white.withOpacity(0.06),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 2,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_rounded, color: color.withOpacity(0.6), size: 13),
            const SizedBox(width: 5),
            Text(
              'Expires in $mins:$secs',
              style: TextStyle(
                color: color.withOpacity(0.7),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Step Hints ───────────────────────────────────────────────────────────────
class _StepHints extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.025),
        borderRadius: BorderRadius.circular(12),
        border:
        Border.all(color: Colors.white.withOpacity(0.05), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Step(n: '1', text: 'Open CRICTRAX'),
          _StepDivider(),
          _Step(n: '2', text: 'Tap "Link TV"'),
          _StepDivider(),
          _Step(n: '3', text: 'Scan code'),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String n;
  final String text;
  const _Step({required this.n, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _C.accent.withOpacity(0.12),
            border: Border.all(color: _C.accent.withOpacity(0.25)),
          ),
          child: Center(
            child: Text(
              n,
              style: TextStyle(
                color: _C.accent,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: 7),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withOpacity(0.35),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _StepDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        width: 16,
        height: 1,
        color: Colors.white.withOpacity(0.08),
      ),
    );
  }
}