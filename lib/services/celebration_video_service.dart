import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class CelebrationVideoService {
  CelebrationVideoService._();

  static final CelebrationVideoService instance =
  CelebrationVideoService._();

  bool _isPlaying = false;

  Future<void> showFour(BuildContext context) async {
    debugPrint("🏏 showFour() called");
    await _playVideo(context, 'assets/audio/commentary/four1.mp4');
  }

  Future<void> showSix(BuildContext context) async {
    await _playVideo(context, 'assets/audio/commentary/six1.mp4');
  }

  Future<void> showWicket(BuildContext context) async {
    await _playVideo(context, 'assets/audio/commentary/wicket.mp4');
  }

  Future<void> _playVideo(BuildContext context,
      String assetPath,) async {
    if (_isPlaying) return;

    _isPlaying = true;

    final controller = VideoPlayerController.asset(assetPath);

    try {
      await controller.initialize();
      controller.setLooping(false);

      controller.addListener(() {
        if (controller.value.isInitialized &&
            controller.value.position >= controller.value.duration &&
            !controller.value.isPlaying) {
          if (Navigator.of(context, rootNavigator: true).canPop()) {
            Navigator.of(context, rootNavigator: true).pop();
          }
        }
      });

      await showGeneralDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (_, __, ___) {
          controller.play();


          return Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
            ),
          );
        },
      );

      await controller.dispose();
    } catch (e) {
      debugPrint("Celebration Video Error: $e");
      await controller.dispose();
    }

    _isPlaying = false;
  }
}