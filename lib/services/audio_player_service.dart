import 'package:just_audio/just_audio.dart';

class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  Duration get currentPosition => _player.position;
  Duration get duration => _player.duration ?? Duration.zero;
  bool get isPlaying => _player.playing;

  Future<void> loadFile(String path) async {
    await _player.setFilePath(path);
  }

  Future<void> play() async => await _player.play();
  Future<void> pause() async => await _player.pause();
  Future<void> seek(Duration position) async => await _player.seek(position);
  Future<void> setSpeed(double speed) async => await _player.setSpeed(speed);

  Future<void> dispose() async {
    await _player.dispose();
  }
}
