import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class CelebrationVideoService {
  CelebrationVideoService._();

  static final CelebrationVideoService instance =
  CelebrationVideoService._();

  bool _isPlaying = false;

  VideoPlayerController? _controller;
  BuildContext? _dialogContext;

  Future<void> showFour(BuildContext context) async {
    debugPrint("🏏 showFour() called");
    await _playVideo(context, 'assets/audio/commentary/four1.mp4');
  }

  Future<void> showSix(BuildContext context) async {
    debugPrint("🏏 showSix() called");
    await _playVideo(context, 'assets/audio/commentary/six1.mp4');
  }

  Future<void> showWicket(BuildContext context) async {
    debugPrint("🏏 showWicket() called");
    await _playVideo(context, 'assets/audio/commentary/wicket.mp4');
  }

  Future<void> _playVideo(
      BuildContext context,
      String assetPath,
      ) async {
    // Stop currently playing video
    if (_isPlaying) {
      debugPrint("⏹ Stopping previous celebration video");

      try {
        await _controller?.pause();

        if (_dialogContext != null &&
            Navigator.of(_dialogContext!, rootNavigator: true).canPop()) {
          Navigator.of(_dialogContext!, rootNavigator: true).pop();
        }

        await _controller?.dispose();
      } catch (e) {
        debugPrint("Dispose Error: $e");
      }

      _controller = null;
      _dialogContext = null;
      _isPlaying = false;
    }

    _isPlaying = true;

    final controller = VideoPlayerController.asset(assetPath);
    _controller = controller;

    try {
      await controller.initialize();
      await controller.setLooping(false);

      controller.addListener(() async {
        if (!controller.value.isInitialized) return;

        final finished =
            controller.value.position >= controller.value.duration &&
                !controller.value.isPlaying;

        if (finished) {
          if (_dialogContext != null &&
              Navigator.of(_dialogContext!, rootNavigator: true).canPop()) {
            Navigator.of(_dialogContext!, rootNavigator: true).pop();
          }

          await controller.dispose();

          _controller = null;
          _dialogContext = null;
          _isPlaying = false;
        }
      });

      await showGeneralDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (_, __, ___) {
          controller.play();

          return Builder(
            builder: (dialogContext) {
              _dialogContext = dialogContext;

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
        },
      );
    } catch (e) {
      debugPrint("Celebration Video Error: $e");

      try {
        await controller.dispose();
      } catch (_) {}

      _controller = null;
      _dialogContext = null;
      _isPlaying = false;
    }
  }
}