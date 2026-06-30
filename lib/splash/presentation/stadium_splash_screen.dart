import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../../dashboard/presentation/dashboard_screen.dart';

class StadiumSplashScreen extends StatefulWidget {
  final String userId;
  final String displayName;
  final String email;
  final String? sessionId;

  const StadiumSplashScreen({
    Key? key,
    required this.userId,
    required this.displayName,
    required this.email,
    this.sessionId,
  }) : super(key: key);

  @override
  State<StadiumSplashScreen> createState() => _StadiumSplashScreenState();
}

class _StadiumSplashScreenState extends State<StadiumSplashScreen>
    with TickerProviderStateMixin {
  // ── Audio ──────────────────────────────────────────────────────────────────
  final _player = AudioPlayer();

  // ── Animations ────────────────────────────────────────────────────────────
  late AnimationController _imageRevealCtrl;  // image fade-in
  late AnimationController _overlayFadeCtrl;  // dark overlay that lifts
  late AnimationController _exitFadeCtrl;     // fade-out before dashboard
  late Animation<double> _imageRevealAnim;
  late Animation<double> _overlayFadeAnim;
  late Animation<double> _exitFadeAnim;

  bool _navigating = false;

  // Clip: 17s → 23s = 6 seconds total
  static const _clipStart = Duration(seconds: 17);
  static const _clipDuration = Duration(seconds: 6);
  // Fade-out starts 1.2s before clip ends
  static const _fadeOutAt = Duration(milliseconds: 4800);

  @override
  void initState() {
    super.initState();

    // Image reveal — fades in over 800ms
    _imageRevealCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _imageRevealAnim = CurvedAnimation(
      parent: _imageRevealCtrl,
      curve: Curves.easeIn,
    );

    // Dark overlay lifts — starts immediately, eases over 1.2s
    _overlayFadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _overlayFadeAnim = CurvedAnimation(
      parent: _overlayFadeCtrl,
      curve: Curves.easeOut,
    );

    // Exit fade — fades entire splash to black before dashboard
    _exitFadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _exitFadeAnim = CurvedAnimation(
      parent: _exitFadeCtrl,
      curve: Curves.easeInOut,
    );

    _startSplash();
  }

  Future<void> _startSplash() async {
    // Play audio from 17s
    try {
      await _player.setSource(AssetSource('audio/crowd_cheer.mp3'));
      await _player.seek(_clipStart);
      await _player.resume();
    } catch (e) {
      debugPrint('Audio error: $e');
    }

    // Reveal image
    _imageRevealCtrl.forward();
    // Lift dark overlay
    _overlayFadeCtrl.forward();

    // Schedule fade-out at 4.8s
    Future.delayed(_fadeOutAt, () {
      if (mounted) _exitFadeCtrl.forward();
    });

    // Navigate at 6s
    Future.delayed(_clipDuration, () {
      if (mounted && !_navigating) _goToDashboard();
    });
  }

  void _goToDashboard() {
    if (_navigating) return;
    _navigating = true;
    _player.stop();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 900),
        pageBuilder: (_, __, ___) => DashboardScreen(
          userId: widget.userId,
          displayName: widget.displayName,
          email: widget.email,
          sessionId: widget.sessionId,
        ),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeInOut),
          child: child,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _player.dispose();
    _imageRevealCtrl.dispose();
    _overlayFadeCtrl.dispose();
    _exitFadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _imageRevealAnim,
          _overlayFadeAnim,
          _exitFadeAnim,
        ]),
        builder: (_, __) {
          return FadeTransition(
            // Exit fade — whole screen fades to black
            opacity: Tween<double>(begin: 1.0, end: 0.0).animate(_exitFadeAnim),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── Stadium image ──────────────────────────────────────────
                FadeTransition(
                  opacity: _imageRevealAnim,
                  child: Image.asset(
                    'assets/images/dash_bg.png',
                    fit: BoxFit.cover,
                  ),
                ),

                // ── Dark overlay that lifts (creates cinematic reveal) ─────
                FadeTransition(
                  opacity: Tween<double>(begin: 1.0, end: 0.0)
                      .animate(_overlayFadeAnim),
                  child: Container(color: Colors.black),
                ),

                // ── Bottom gradient + branding ─────────────────────────────
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: FadeTransition(
                    opacity: _overlayFadeAnim,
                    child: Container(
                      height: 280,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.92),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(
                            left: 60, right: 60, bottom: 48),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Logo row
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF00D4FF),
                                        Color(0xFF0066CC),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF00D4FF)
                                            .withOpacity(0.45),
                                        blurRadius: 20,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.sports_cricket,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'CRICTRAX',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 4,
                                      ),
                                    ),
                                    Text(
                                      'TV SCORECARD',
                                      style: TextStyle(
                                        color: const Color(0xFF00D4FF)
                                            .withOpacity(0.7),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 3,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Welcome back, ${widget.displayName.isNotEmpty ? widget.displayName : "Player"}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.45),
                                fontSize: 15,
                                letterSpacing: 0.3,
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
          );
        },
      ),
    );
  }
}