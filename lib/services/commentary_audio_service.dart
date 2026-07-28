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
    await _player.play(AssetSource('audio/commentary/boundry1.mpeg'));
  }

  Future<void> playSix() async {
    await _player.stop();
    await _player.play(AssetSource('audio/commentary/six3.mpeg'));
  }
  Future<void> playWicket() async {
    await _player.stop();
    await _player.play(
      AssetSource('audio/commentary/wicket1.mpeg'),
    );
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}