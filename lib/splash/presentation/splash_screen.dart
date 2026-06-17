import 'dart:ui';
import 'package:flutter/material.dart';
import '../../login/presentation/login_screen.dart';

class CinematicSplash extends StatefulWidget {
  const CinematicSplash({Key? key}) : super(key: key);

  @override
  State<CinematicSplash> createState() => _CinematicSplashState();
}

class _CinematicSplashState extends State<CinematicSplash>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowExpand;
  late Animation<double> _textFadeIn;
  late Animation<double> _textScale;
  late Animation<double> _backgroundBlur;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2300),
    );

    _glowExpand = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.5, curve: Curves.decelerate),
      ),
    );

    _textFadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.7, curve: Curves.easeIn),
      ),
    );

    _textScale = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.8, curve: Curves.easeOutBack),
      ),
    );

    _backgroundBlur = Tween<double>(begin: 0.0, end: 15.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.85, 1.0, curve: Curves.easeInOut),
      ),
    );

    _controller.forward().then((_) {
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
    return Scaffold(
      backgroundColor: const Color(0xFF050A18),
      body: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _glowExpand,
            builder: (context, child) => Container(
              width: 400 * _glowExpand.value,
              height: 400 * _glowExpand.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00A3FF).withOpacity(
                        (1.0 - _glowExpand.value).clamp(0.0, 0.5)),
                    blurRadius: 120 * _glowExpand.value,
                    spreadRadius: 30 * _glowExpand.value,
                  ),
                ],
              ),
            ),
          ),
          FadeTransition(
            opacity: _textFadeIn,
            child: ScaleTransition(
              scale: _textScale,
              child: const Text(
                'CRICTRAX',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 72,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _backgroundBlur,
            builder: (context, child) => BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: _backgroundBlur.value,
                sigmaY: _backgroundBlur.value,
              ),
              child: Container(color: Colors.transparent),
            ),
          ),
        ],
      ),
    );
  }
}