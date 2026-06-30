import 'package:just_audio/just_audio.dart';

class BackgroundMusicService {
  BackgroundMusicService._();

  static final BackgroundMusicService instance =
  BackgroundMusicService._();

  final AudioPlayer player = AudioPlayer();

  bool _started = false;

  Future<void> startMusic() async {
    if (_started) return; // Prevent starting multiple times

    await player.setAudioSource(
      ConcatenatingAudioSource(
        children: [
          AudioSource.asset('assets/audio/background1.mp3'),
          AudioSource.asset('assets/audio/background2.mp3'),
        ],
      ),
    );

    await player.setLoopMode(LoopMode.all);

    await player.setVolume(0.20); // 20% volume (recommended)

    _started = true;

    await player.play();
  }

  Future<void> stopMusic() async {
    await player.stop();
    _started = false;
  }

  Future<void> dispose() async {
    await player.dispose();
  }
}