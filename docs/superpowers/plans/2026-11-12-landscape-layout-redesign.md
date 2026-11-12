# 默认横屏与双列紧凑布局重构实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 配置应用默认启动即为横屏模式，并将界面整体重构为上下分层结构（上半部分全宽波形视口，下半部分左右并列 A-B 控制与精听播放主控），根除真机溢出（Overflow）问题，提升波形可视面积与操作体验。

**Architecture:** AndroidManifest.xml 与 Flutter SystemChrome 强锁横屏；对 UI 结构进行解耦重构，将垂直紧凑化改造后的 `AbControlBar` 与 `StudyTuningBar` + `PlayerBottomBar` 放入底部的 `Row` (45%:55% 比例)，波形视图放入 `Expanded(flex: 3)`，底部控制区放入 `Expanded(flex: 2)` 或弹性容器，外加 `SafeArea` 保护。

**Tech Stack:** Flutter / Dart, Android Manifest, services SystemChrome.

---

### Task 1: 屏幕方向配置（默认横屏）

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `lib/main.dart`

- [ ] **Step 1: 修改 Android 原生清单配置**

在 `android/app/src/main/AndroidManifest.xml` 中的 `activity` 节点添加：
```xml
android:screenOrientation="sensorLandscape"
```

- [ ] **Step 2: 修改 `lib/main.dart` 添加 SystemChrome 横屏锁定**

在 `main()` 函数中调用：
```dart
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const AudacityPlayerApp());
}
```

- [ ] **Step 3: 运行静态分析验证**

Run: `flutter analyze`
Expected: 0 issues。

- [ ] **Step 4: 提交横屏配置**

```bash
git add android/app/src/main/AndroidManifest.xml lib/main.dart
git commit -m "feat: enforce default sensorLandscape orientation"
```

---

### Task 2: 紧凑化重构 A-B 控制栏 (AbControlBar)

**Files:**
- Modify: `lib/ui/controls/ab_control_bar.dart`

- [ ] **Step 1: 压缩高度，适配横屏左侧半屏排布**

将按钮与数值行紧凑化，按钮使用紧凑内边距与字体，时间数值面板与微调按钮更省高度：
```dart
import 'package:flutter/material.dart';
import '../../models/repeat_state.dart';
import '../waveform/time_ruler_helper.dart';

class AbControlBar extends StatelessWidget {
  final RepeatState state;
  final Duration currentPosition;
  final VoidCallback onSetA;
  final VoidCallback onSetB;
  final VoidCallback onClear;
  final Function(int) onNudgeA;
  final Function(int) onNudgeB;

  const AbControlBar({
    super.key,
    required this.state,
    required this.currentPosition,
    required this.onSetA,
    required this.onSetB,
    required this.onClear,
    required this.onNudgeA,
    required this.onNudgeB,
  });

  @override
  Widget build(BuildContext context) {
    final aText = state.pointA != null ? TimeRulerHelper.formatTime(state.pointA!) : '--:--.-';
    final bText = state.pointB != null ? TimeRulerHelper.formatTime(state.pointB!) : '--:--.-';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const BoxDecoration(
        color: Color(0xFF242424),
        border: Border(right: BorderSide(color: Color(0xFF383838), width: 1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _compactButton(Icons.flag, '设A点', Colors.amber, onSetA),
              _compactButton(Icons.outlined_flag, '设B点', Colors.orange, onSetB),
              _compactButton(Icons.close, '清除', Colors.redAccent, (state.pointA != null || state.pointB != null) ? onClear : null),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _nudgeRow('A', aText, () => onNudgeA(-100), () => onNudgeA(100)),
              _nudgeRow('B', bText, () => onNudgeB(-100), () => onNudgeB(100)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _compactButton(IconData icon, String label, Color color, VoidCallback? onPressed) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 14, color: color),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF333333),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onPressed,
    );
  }

  Widget _nudgeRow(String label, String timeStr, VoidCallback onMinus, VoidCallback onPlus) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label:$timeStr', style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
        const SizedBox(width: 2),
        InkWell(
          onTap: onMinus,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(3)),
            child: const Text('-0.1s', style: TextStyle(color: Colors.white60, fontSize: 10)),
          ),
        ),
        const SizedBox(width: 2),
        InkWell(
          onTap: onPlus,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(3)),
            child: const Text('+0.1s', style: TextStyle(color: Colors.white60, fontSize: 10)),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: 验证编译通过**

Run: `flutter analyze lib/ui/controls/ab_control_bar.dart`
Expected: 0 issues。

- [ ] **Step 3: 提交紧凑型 A-B 栏**

```bash
git add lib/ui/controls/ab_control_bar.dart
git commit -m "refactor: compact AbControlBar for landscape side-by-side layout"
```

---

### Task 3: 紧凑化重构精听设置与底部播放栏 (StudyTuningBar & PlayerBottomBar)

**Files:**
- Modify: `lib/ui/controls/study_tuning_bar.dart`
- Modify: `lib/ui/controls/player_bottom_bar.dart`

- [ ] **Step 1: 优化 StudyTuningBar 紧凑布局**

让 ChoiceChip 尺寸更小，文字更紧凑，横向可滚动或并排：
```dart
import 'package:flutter/material.dart';

class StudyTuningBar extends StatelessWidget {
  final double currentSpeed;
  final int currentPauseSeconds;
  final int remainingLoops;
  final Function(double) onSpeedChanged;
  final Function(int) onPauseChanged;
  final Function(int) onLoopsChanged;

  const StudyTuningBar({
    super.key,
    required this.currentSpeed,
    required this.currentPauseSeconds,
    required this.remainingLoops,
    required this.onSpeedChanged,
    required this.onPauseChanged,
    required this.onLoopsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('速: ', style: TextStyle(color: Colors.white54, fontSize: 11)),
          for (final speed in [0.8, 1.0, 1.25, 1.5])
            Padding(
              padding: const EdgeInsets.only(right: 3),
              child: ChoiceChip(
                label: Text('${speed}x', style: const TextStyle(fontSize: 10)),
                selected: currentSpeed == speed,
                onSelected: (_) => onSpeedChanged(speed),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
          const SizedBox(width: 6),
          const Text('停: ', style: TextStyle(color: Colors.white54, fontSize: 11)),
          for (final pause in [0, 1, 2, 3])
            Padding(
              padding: const EdgeInsets.only(right: 3),
              child: ChoiceChip(
                label: Text('${pause}s', style: const TextStyle(fontSize: 10)),
                selected: currentPauseSeconds == pause,
                onSelected: (_) => onPauseChanged(pause),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
          const SizedBox(width: 6),
          const Text('循环: ', style: TextStyle(color: Colors.white54, fontSize: 11)),
          for (final loops in [-1, 3, 5])
            Padding(
              padding: const EdgeInsets.only(right: 3),
              child: ChoiceChip(
                label: Text(loops == -1 ? '∞' : '$loops次', style: const TextStyle(fontSize: 10)),
                selected: remainingLoops == loops,
                onSelected: (_) => onLoopsChanged(loops),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: 紧凑化 PlayerBottomBar**

减小 Slider 高度与按键大小，适配横屏下半部分右侧面板：
```dart
import 'package:flutter/material.dart';
import '../waveform/time_ruler_helper.dart';

class PlayerBottomBar extends StatelessWidget {
  final bool isPlaying;
  final Duration currentPosition;
  final Duration totalDuration;
  final VoidCallback onPlayPause;
  final VoidCallback onSeekBack5s;
  final VoidCallback onSeekForward5s;
  final Function(Duration) onSeek;

  const PlayerBottomBar({
    super.key,
    required this.isPlaying,
    required this.currentPosition,
    required this.totalDuration,
    required this.onPlayPause,
    required this.onSeekBack5s,
    required this.onSeekForward5s,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    final maxMs = totalDuration.inMilliseconds > 0 ? totalDuration.inMilliseconds.toDouble() : 1.0;
    final currMs = currentPosition.inMilliseconds.toDouble().clamp(0.0, maxMs);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(TimeRulerHelper.formatTime(currentPosition), style: const TextStyle(color: Colors.white70, fontSize: 10)),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                  ),
                  child: Slider(
                    value: currMs,
                    min: 0.0,
                    max: maxMs,
                    onChanged: (val) => onSeek(Duration(milliseconds: val.toInt())),
                  ),
                ),
              ),
              Text(TimeRulerHelper.formatTime(totalDuration), style: const TextStyle(color: Colors.white70, fontSize: 10)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.replay_5, color: Colors.white70, size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: onSeekBack5s,
              ),
              const SizedBox(width: 16),
              FloatingActionButton.small(
                onPressed: onPlayPause,
                backgroundColor: const Color(0xFF3AAFA9),
                child: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.forward_5, color: Colors.white70, size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: onSeekForward5s,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: 验证编译通过**

Run: `flutter analyze lib/ui/controls/`
Expected: 0 issues。

- [ ] **Step 4: 提交右侧紧凑控制栏**

```bash
git add lib/ui/controls/study_tuning_bar.dart lib/ui/controls/player_bottom_bar.dart
git commit -m "refactor: compact StudyTuningBar and PlayerBottomBar for landscape integration"
```

---

### Task 4: 主页面横屏上下分层 + 底部左右双列重构与测试

**Files:**
- Modify: `lib/ui/player_screen.dart`
- Modify: `test/widget_test.dart`

- [ ] **Step 1: 重构 PlayerScreen**

顶部轻量 TitleBar，波形视口 `Expanded(flex: 3)`，下半部分用 `Expanded(flex: 2)` 包裹一个左右分栏的 `Row`，同时用 `SafeArea` 保证横屏不被刘海和手势栏遮挡：
```dart
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
```

- [ ] **Step 2: 更新 `test/widget_test.dart` 并在横屏尺寸下测试防溢出**

修改 `test/widget_test.dart`，加入横屏尺寸模拟，验证无溢出：
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:audacity_player/main.dart';

void main() {
  testWidgets('AudacityPlayerApp landscape smoke and anti-overflow test', (WidgetTester tester) async {
    // 模拟常见手机横屏分辨率 (800 x 400)
    tester.view.physicalSize = const Size(800, 400);
    tester.view.devicePixelRatio = 1.0;

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const AudacityPlayerApp());
    expect(find.text('打开音频'), findsOneWidget);
    expect(find.text('设A点'), findsOneWidget);
    expect(find.text('设B点'), findsOneWidget);
    expect(find.text('清除'), findsOneWidget);

    // 确保没有溢出错误发生
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 3: 运行全量单元测试与分析**

Run: `flutter test`
Expected: ALL PASS。

Run: `flutter analyze`
Expected: 0 issues。

- [ ] **Step 4: 提交全部横屏布局改动**

```bash
git add lib/ui/player_screen.dart test/widget_test.dart
git commit -m "feat: complete landscape layout redesign with side-by-side controls and anti-overflow verification"
```
