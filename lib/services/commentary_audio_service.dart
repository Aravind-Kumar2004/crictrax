import 'package:audioplayers/audioplayers.dart';

class CommentaryAudioService {
  CommentaryAudioService._();

  static final CommentaryAudioService instance =
  CommentaryAudioService._();

  final AudioPlayer _player = AudioPlayer();

  Future<void> playSingle() async {
    await _player.stop();
    await _player.play(AssetSource('audio/commentary/single.mp3'));
  }

  Future<void> playDouble() async {
    await _player.stop();
    await _player.play(AssetSource('audio/commentary/double.mp3'));
  }

  Future<void> playFour() async {
    await _player.stop();
    await _player.play(AssetSource('audio/commentary/four.mp3'));
  }

  Future<void> playSix() async {
    await _player.stop();
    await _player.play(AssetSource('audio/commentary/six.mp3'));
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}