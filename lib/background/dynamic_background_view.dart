import 'package:flutter/material.dart';
import 'background_manager.dart';

class DynamicBackgroundView<T> extends StatelessWidget {
  const DynamicBackgroundView({
    super.key,
    required this.backgroundImage,
    required this.manager,
    required this.selectedTab,
    required this.foreground,
    this.glowColor = const Color(0xFF00D4FF),
    this.transitionDuration = const Duration(milliseconds: 450),
    this.backgroundOverlayColor = const Color(0xCC050A18),
    this.leftPlayerWidthFactor = 0.30,
    this.rightPlayerWidthFactor = 0.30,
  });

  /// Static background image for the current screen.
  final String backgroundImage;

  /// Background asset manager.
  final BackgroundManager<T> manager;

  /// Current selected tab.
  final T selectedTab;

  /// Screen UI rendered above the background.
  final Widget foreground;

  /// Player glow color.
  final Color glowColor;

  /// Fade duration for right player.
  final Duration transitionDuration;

  /// Dark overlay for readability.
  final Color backgroundOverlayColor;

  /// Width factors.
  final double leftPlayerWidthFactor;
  final double rightPlayerWidthFactor;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Stack(
      fit: StackFit.expand,
      children: [

        //═══════════════════════════════════════════════════════════════
        // Background
        //═══════════════════════════════════════════════════════════════
        Image.asset(
          backgroundImage,
          fit: BoxFit.cover,
        ),

        // Dark overlay
        Container(
          color: backgroundOverlayColor,
        ),

        //═══════════════════════════════════════════════════════════════
        // Static Left Player
        //═══════════════════════════════════════════════════════════════
        Positioned(
          left: -(size.width * leftPlayerWidthFactor * 0.18),
          bottom: 0,
          child: IgnorePointer(
            child: _GlowingPlayer(
              imagePath: manager.leftPlayerAsset,
              width: size.width * leftPlayerWidthFactor,
              glowColor: glowColor,
            ),
          ),
        ),

        //═══════════════════════════════════════════════════════════════
        // Dynamic Right Player
        //═══════════════════════════════════════════════════════════════
        Positioned(
          right: -(size.width * rightPlayerWidthFactor * 0.12),
          bottom: 0,
          child: IgnorePointer(
            child: _CrossFadePlayer(
              imagePath: manager.rightPlayerFor(selectedTab),
              width: size.width * rightPlayerWidthFactor,
              duration: transitionDuration,
              glowColor: glowColor,
            ),
          ),
        ),

        //═══════════════════════════════════════════════════════════════
        // Foreground UI
        //═══════════════════════════════════════════════════════════════
        foreground,
      ],
    );
  }
}

class _CrossFadePlayer extends StatelessWidget {
  const _CrossFadePlayer({
    required this.imagePath,
    required this.width,
    required this.duration,
    required this.glowColor,
  });

  final String imagePath;
  final double width;
  final Duration duration;
  final Color glowColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.bottomCenter,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      child: _GlowingPlayer(
        key: ValueKey(imagePath),
        imagePath: imagePath,
        width: width,
        glowColor: glowColor,
      ),
    );
  }
}

class _GlowingPlayer extends StatelessWidget {
  const _GlowingPlayer({
    super.key,
    required this.imagePath,
    required this.width,
    required this.glowColor,
  });

  final String imagePath;
  final double width;
  final Color glowColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [

          // Glow
          Positioned(
            bottom: width * 0.05,
            child: Container(
              width: width * 0.75,
              height: width * 0.55,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    glowColor.withOpacity(0.35),
                    glowColor.withOpacity(0.12),
                    Colors.transparent,
                  ],
                  stops: const [
                    0.0,
                    0.55,
                    1.0,
                  ],
                ),
              ),
            ),
          ),

          // Player PNG
          Image.asset(
            imagePath,
            width: width,
            fit: BoxFit.contain,
            alignment: Alignment.bottomCenter,
            gaplessPlayback: true,
          ),
        ],
      ),
    );
  }
}