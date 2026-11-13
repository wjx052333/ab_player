import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../controllers/ab_repeat_controller.dart';
import '../models/audio_track.dart';
import '../models/waveform_gesture_mode.dart';
import '../services/audio_player_service.dart';
import '../services/dictionary_audio_service.dart';
import '../services/dictionary_db_service.dart';
import '../services/mdict/mdict_manager_service.dart';
import '../services/waveform_extractor.dart';
import 'audacity_theme.dart';
import 'controls/ab_control_bar.dart';
import 'controls/player_bottom_bar.dart';
import 'controls/study_tuning_bar.dart';
import 'dictionary/dictionary_screen.dart';
import 'dictionary/widgets/dict_pack_chip_bar.dart';
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
  final DictionaryDbService _dictDbService = DictionaryDbService();
  final GlobalKey<DictionaryScreenState> _dictScreenKey = GlobalKey<DictionaryScreenState>();
  late final MDictManagerService _mdictManager;
  final DictPanelController _panelController = DictPanelController();
  late final DictionaryAudioService _dictAudioService;
  late final AbRepeatController _repeatController;

  int _selectedTabIndex = 0; // 0: Player, 1: Dictionary
  AudioTrack _track = AudioTrack.empty();
  Duration _currentPos = Duration.zero;
  bool _isPlaying = false;
  bool _isLoading = false;
  WaveformGestureMode _gestureMode = WaveformGestureMode.drag;

  @override
  void initState() {
    super.initState();
    _mdictManager = MDictManagerService();
    _dictAudioService = DictionaryAudioService(mdictManager: _mdictManager);

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
    _dictDbService.dispose();
    _mdictManager.dispose();
    _panelController.dispose();
    _dictAudioService.dispose();
    super.dispose();
  }

  Widget _buildTopTabBar() {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      color: const Color(0xFF101010),
      child: Row(
        children: [
          // Tab switcher buttons
          _buildTabButton(index: 0, title: '🎧 播放器'),
          const SizedBox(width: 8),
          _buildTabButton(index: 1, title: '📖 词典'),
          const SizedBox(width: 14),
          const VerticalDivider(color: Color(0xFF2C2C2C), width: 1, indent: 6, endIndent: 6),
          const SizedBox(width: 12),
          // Tab specific quick actions
          if (_selectedTabIndex == 0) ...[
            InkWell(
              onTap: _pickAudioFile,
              child: const Row(
                children: [
                  Icon(Icons.folder_open, size: 16, color: Color(0xFF3AAFA9)),
                  SizedBox(width: 4),
                  Text('打开音频', style: TextStyle(color: Color(0xFF3AAFA9), fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _track.title,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${TimeRulerHelper.formatTime(_currentPos)} / ${TimeRulerHelper.formatTime(_track.duration)}',
              style: const TextStyle(color: Colors.white60, fontSize: 11, fontFamily: 'monospace'),
            ),
          ] else ...[
            const SizedBox(width: 12),
            Expanded(
              child: DictPackChipBar(
                managerService: _mdictManager,
                controller: _panelController,
              ),
            ),
            const SizedBox(width: 8),
            if (_isPlaying) ...[
              const Icon(Icons.volume_up, size: 14, color: Color(0xFF3AAFA9)),
              const SizedBox(width: 8),
            ],
            InkWell(
              onTap: () => _dictScreenKey.currentState?.openPackManager(),
              child: const Row(
                children: [
                  Icon(Icons.settings, size: 16, color: Color(0xFF3AAFA9)),
                  SizedBox(width: 4),
                  Text('词库管理', style: TextStyle(color: Color(0xFF3AAFA9), fontSize: 12)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabButton({required int index, required String title}) {
    final isSelected = _selectedTabIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedTabIndex = index),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2C3E50) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: isSelected ? Border.all(color: const Color(0xFF3AAFA9).withValues(alpha: 0.6)) : null,
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? const Color(0xFFDEF2F1) : Colors.white60,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerBody() {
    return Column(
      children: [
        // 上半部分：全宽波形与时间标尺视口
        Expanded(
          flex: 52,
          child: Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFF262626), width: 1),
                bottom: BorderSide(color: Color(0xFF333333), width: 1.5),
              ),
            ),
            child: AudacityWaveformView(
              peaks: _track.peaks,
              totalDuration: _track.duration,
              currentPosition: _currentPos,
              repeatState: _repeatController.state,
              isPlaying: _isPlaying,
              gestureMode: _gestureMode,
              onSeek: (pos) => _playerService.seek(pos),
              onRangeSelected: (p1, p2) => _repeatController.setSelectionRange(p1, p2),
              onPointAMoved: (pos) => _repeatController.markPointA(pos),
              onPointBMoved: (pos) => _repeatController.markPointB(pos),
            ),
          ),
        ),
        // 下半部分：左右分栏控制区
        Expanded(
          flex: 48,
          child: Container(
            color: AudacityTheme.panelBackground,
            child: Row(
              children: [
                // 左侧列：手势切换 + A-B 控制与微调
                Expanded(
                  flex: 48,
                  child: AbControlBar(
                    state: _repeatController.state,
                    currentPosition: _currentPos,
                    gestureMode: _gestureMode,
                    onGestureModeChanged: (mode) => setState(() => _gestureMode = mode),
                    onSetA: () => _repeatController.markPointA(_currentPos),
                    onSetB: () => _repeatController.markPointB(_currentPos),
                    onClear: () => _repeatController.clearSelection(),
                    onNudgeA: (ms) => _repeatController.nudgeA(ms),
                    onNudgeB: (ms) => _repeatController.nudgeB(ms),
                  ),
                ),
                // 右侧列：精听参数调节 + 底部播放控制
                Expanded(
                  flex: 52,
                  child: Container(
                    decoration: const BoxDecoration(
                      border: Border(left: BorderSide(color: Color(0xFF1E1E1E), width: 1.5)),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
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
                ),
              ],
            ),
          ),
        ),
      ],
    );
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
                  // 1. 顶部紧凑标题与标签切换栏 (高度 32dp)
                  _buildTopTabBar(),

                  // 2. 主体工作区 (保持播放器状态存活)
                  Expanded(
                    child: IndexedStack(
                      index: _selectedTabIndex,
                      children: [
                        _buildPlayerBody(),
                        DictionaryScreen(
                          key: _dictScreenKey,
                          dbService: _dictDbService,
                          audioService: _dictAudioService,
                          mdictManager: _mdictManager,
                          panelController: _panelController,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
