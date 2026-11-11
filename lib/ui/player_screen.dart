import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../controllers/ab_repeat_controller.dart';
import '../models/audio_track.dart';
import '../services/audio_player_service.dart';
import '../services/waveform_extractor.dart';
import 'controls/ab_control_bar.dart';
import 'controls/player_bottom_bar.dart';
import 'controls/study_tuning_bar.dart';
import 'waveform/audacity_waveform_view.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final AudioPlayerService _playerService = AudioPlayerService();
  final WaveformExtractor _waveformExtractor = WaveformExtractor();
  late final AbRepeatController _repeatController;

  AudioTrack _track = AudioTrack.empty();
  Duration _currentPos = Duration.zero;
  bool _isPlaying = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _repeatController = AbRepeatController(
      onSeekRequest: (d) => _playerService.seek(d),
      onPauseRequest: () => _playerService.pause(),
      onResumeRequest: () => _playerService.play(),
    );

    _playerService.positionStream.listen((pos) {
      if (mounted) {
        setState(() => _currentPos = pos);
        _repeatController.onPositionChanged(pos);
      }
    });

    _playerService.playerStateStream.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state.playing);
      }
    });

    _repeatController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      final name = result.files.single.name;

      setState(() => _isLoading = true);
      try {
        await _playerService.loadFile(path);
        final peaks = await _waveformExtractor.extractPeaks(path);
        setState(() {
          _track = AudioTrack(
            path: path,
            title: name,
            duration: _playerService.duration,
            peaks: peaks,
          );
          _repeatController.clearSelection();
        });
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _playerService.dispose();
    _repeatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        title: Text(_track.title, style: const TextStyle(fontSize: 16)),
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _pickAudioFile,
            tooltip: '打开音频',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF3AAFA9)))
          : Column(
              children: [
                // 核心波形视图视口
                Expanded(
                  child: AudacityWaveformView(
                    peaks: _track.peaks,
                    totalDuration: _track.duration,
                    currentPosition: _currentPos,
                    repeatState: _repeatController.state,
                    onSeek: (pos) => _playerService.seek(pos),
                    onRangeSelected: (p1, p2) => _repeatController.setSelectionRange(p1, p2),
                    onPointAMoved: (pos) => _repeatController.markPointA(pos),
                    onPointBMoved: (pos) => _repeatController.markPointB(pos),
                  ),
                ),

                // A-B 复读打点与微调控制
                AbControlBar(
                  state: _repeatController.state,
                  currentPosition: _currentPos,
                  onSetA: () => _repeatController.markPointA(_currentPos),
                  onSetB: () => _repeatController.markPointB(_currentPos),
                  onClear: () => _repeatController.clearSelection(),
                  onNudgeA: (ms) => _repeatController.nudgeA(ms),
                  onNudgeB: (ms) => _repeatController.nudgeB(ms),
                ),

                // 倍速、跟读留白停顿、循环次数
                StudyTuningBar(
                  currentSpeed: _repeatController.state.playbackSpeed,
                  currentPauseSeconds: _repeatController.state.pauseSeconds,
                  remainingLoops: _repeatController.state.remainingLoops,
                  onSpeedChanged: (speed) {
                    _repeatController.setPlaybackSpeed(speed);
                    _playerService.setSpeed(speed);
                  },
                  onPauseChanged: (pause) => _repeatController.setPauseSeconds(pause),
                  onLoopsChanged: (loops) => _repeatController.setRemainingLoops(loops),
                ),

                // 底部播放控制器
                PlayerBottomBar(
                  isPlaying: _isPlaying,
                  currentPosition: _currentPos,
                  totalDuration: _track.duration,
                  onPlayPause: () => _isPlaying ? _playerService.pause() : _playerService.play(),
                  onSeekBack5s: () => _playerService.seek(_currentPos - const Duration(seconds: 5)),
                  onSeekForward5s: () => _playerService.seek(_currentPos + const Duration(seconds: 5)),
                  onSeek: (pos) => _playerService.seek(pos),
                ),
              ],
            ),
    );
  }
}
