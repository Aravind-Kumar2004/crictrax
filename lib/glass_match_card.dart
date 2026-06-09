import 'dart:ui';
import 'package:flutter/material.dart';

class GlassMatchCard extends StatefulWidget {
  final String matchTitle;
  final String score;

  const GlassMatchCard({
    Key? key,
    required this.matchTitle,
    required this.score,
  }) : super(key: key);

  @override
  State<GlassMatchCard> createState() => _GlassMatchCardState();
}

class _GlassMatchCardState extends State<GlassMatchCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (hasFocus) {
        setState(() {
          _isFocused = hasFocus;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        transform: Matrix4.identity()..scale(_isFocused ? 1.08 : 1.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _isFocused ? Colors.white : Colors.white.withOpacity(0.2),
            width: _isFocused ? 3 : 1.5,
          ),
          boxShadow: _isFocused
              ? [
            BoxShadow(
              color: Colors.blueAccent.withOpacity(0.5),
              blurRadius: 30,
              spreadRadius: 5,
            )
          ]
              : [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            // The Glassmorphism Blur Effect
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              width: 300,
              height: 180,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.matchTitle,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.score,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}