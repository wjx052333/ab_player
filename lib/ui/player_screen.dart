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
import 'waveform/time_ruler_helper.dart';

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
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF3AAFA9)))
            : Column(
                children: [
                  // 1. 顶部紧凑标题与信息栏 (高度约 34dp)
                  Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    color: const Color(0xFF181818),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: _pickAudioFile,
                          child: const Row(
                            children: [
                              Icon(Icons.folder_open, size: 18, color: Color(0xFF3AAFA9)),
                              SizedBox(width: 6),
                              Text('打开音频', style: TextStyle(color: Color(0xFF3AAFA9), fontSize: 13)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            _track.title,
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${TimeRulerHelper.formatTime(_currentPos)} / ${TimeRulerHelper.formatTime(_track.duration)}',
                          style: const TextStyle(color: Colors.white60, fontSize: 12, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),

                  // 2. 上半部分：全宽波形与时间标尺视口 (占 58% 高度)
                  Expanded(
                    flex: 58,
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

                  // 3. 下半部分：左右分栏控制区 (占 42% 高度)
                  Expanded(
                    flex: 42,
                    child: Container(
                      color: const Color(0xFF222222),
                      child: Row(
                        children: [
                          // 左侧列：A-B 控制与微调
                          Expanded(
                            flex: 46,
                            child: AbControlBar(
                              state: _repeatController.state,
                              currentPosition: _currentPos,
                              onSetA: () => _repeatController.markPointA(_currentPos),
                              onSetB: () => _repeatController.markPointB(_currentPos),
                              onClear: () => _repeatController.clearSelection(),
                              onNudgeA: (ms) => _repeatController.nudgeA(ms),
                              onNudgeB: (ms) => _repeatController.nudgeB(ms),
                            ),
                          ),

                          // 右侧列：精听参数调节 + 底部播放控制
                          Expanded(
                            flex: 54,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
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
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
