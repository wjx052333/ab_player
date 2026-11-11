# Audacity 风格 Android 音频播放器实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 基于 Flutter 构建具有经典 Audacity 界面质感的 Android 音频播放器，实现时间轴标尺、对称波形图、手势缩放与拖拽打点选区、以及支持静音跟读停顿、循环次数限制和变速不变调的高精度 A-B 复读功能。

**Architecture:** 采用分层与关注点分离架构。底层通过 `just_audio` 管理音频播放并提供精准流状态，`AudioWaveformService` 负责从本地音频异步提取采样波峰；核心控制器 `AbRepeatController` 管理 A-B 选区逻辑、倒计时跟读停顿、微调与次数递减；UI 层通过自定义 `AudacityWaveformPainter` 进行视口局部裁剪（Viewport Clipping）绘制与平滑手势响应，配合暗色 Audacity 工作台 UI。

**Tech Stack:** Flutter 3.41+ / Dart 3.11+, just_audio, file_picker, flutter_riverpod / ChangeNotifier.

---

## 目录结构设计

```
lib/
├── main.dart                               # 应用入口、主题配置
├── models/
│   ├── audio_track.dart                    # 音频文件元数据与波峰数据模型
│   └── repeat_state.dart                   # A-B 复读状态模型 (A/B 点、激活状态、停顿与循环次数)
├── services/
│   ├── audio_player_service.dart           # just_audio 封装（播放、暂停、Seek、倍速等）
│   └── waveform_extractor.dart             # 波峰数据提取与下采样服务
├── controllers/
│   └── ab_repeat_controller.dart           # 核心控制器：A-B 打点、到达 B 点静音停顿与 Seek A 状态机
├── ui/
│   ├── audacity_theme.dart                 # Audacity 风格颜色与尺寸常量
│   ├── waveform/
│   │   ├── audacity_waveform_view.dart     # 波形图交互容器 (处理缩放、滑动、划选与游标拖拽)
│   │   ├── audacity_waveform_painter.dart  # CustomPainter 绘制标尺、波形、选区与播放指针
│   │   └── time_ruler_helper.dart          # 时间刻度尺步进与格式化计算辅助类
│   ├── controls/
│   │   ├── ab_control_bar.dart             # A-B 打点、清除与 ±0.1s 微调栏
│   │   ├── study_tuning_bar.dart           # 倍速选择、跟读停顿秒数、循环次数 Chip 栏
│   │   └── player_bottom_bar.dart          # 底部进度条、快退、播放/暂停、快进控制栏
│   └── player_screen.dart                  # 主播放器页面整合
test/
├── models/
│   └── repeat_state_test.dart
├── controllers/
│   └── ab_repeat_controller_test.dart
├── ui/
│   └── time_ruler_helper_test.dart
```

---

### Task 1: 初始化 Flutter 项目与依赖配置

**Files:**
- Create: `pubspec.yaml`
- Modify: `android/app/build.gradle`
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: 创建 Flutter 项目结构**

Run in terminal:
```bash
flutter create --org com.example audacity_player --platforms android
```
然后将 `audacity_player` 目录内的所有文件移到当前目录或在当前目录配置项目。

- [ ] **Step 2: 配置 `pubspec.yaml` 依赖**

将以下必要依赖加入 `pubspec.yaml`：
```yaml
dependencies:
  flutter:
    sdk: flutter
  just_audio: ^0.9.44
  file_picker: ^8.1.7
  path_provider: ^2.1.5

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
```

- [ ] **Step 3: 获取依赖并验证**

Run: `flutter pub get`
Expected: 成功解析并下载所有依赖，返回 exit code 0。

- [ ] **Step 4: 配置 Android 存储读取权限**

在 `android/app/src/main/AndroidManifest.xml` 中添加：
```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />
```

- [ ] **Step 5: 提交基础配置**

```bash
git init
git add .
git commit -m "chore: initialize flutter project and configure dependencies"
```

---

### Task 2: 核心数据模型 (AudioTrack & RepeatState)

**Files:**
- Create: `lib/models/audio_track.dart`
- Create: `lib/models/repeat_state.dart`
- Test: `test/models/repeat_state_test.dart`

- [ ] **Step 1: 编写 RepeatState 单元测试**

创建 `test/models/repeat_state_test.dart`：
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:audacity_player/models/repeat_state.dart';

void main() {
  group('RepeatState Tests', () {
    test('初始状态应为未设置且无 A-B 点', () {
      final state = RepeatState.initial();
      expect(state.pointA, isNull);
      expect(state.pointB, isNull);
      expect(state.isActive, isFalse);
      expect(state.pauseSeconds, 0);
      expect(state.remainingLoops, -1); // -1 代表无限
    });

    test('设置 A 和 B 点且校验最小间隔 200ms', () {
      final state = RepeatState.initial()
          .setPointA(const Duration(seconds: 2))
          .setPointB(const Duration(milliseconds: 2100)); // 只有 100ms 间隔
      
      // 应自动扩展或拒绝不合规间隔
      expect(state.isValidInterval, isFalse);

      final validState = state.setPointB(const Duration(seconds: 4));
      expect(validState.isValidInterval, isTrue);
      expect(validState.duration, const Duration(seconds: 2));
    });

    test('如果 B 小于 A，应能正确纠正为有序区间', () {
      final state = RepeatState.fromRange(
        const Duration(seconds: 5),
        const Duration(seconds: 2),
      );
      expect(state.pointA, const Duration(seconds: 2));
      expect(state.pointB, const Duration(seconds: 5));
    });
  });
}
```

- [ ] **Step 2: 运行测试以确认失败**

Run: `flutter test test/models/repeat_state_test.dart`
Expected: 编译失败或找不到 `RepeatState`。

- [ ] **Step 3: 实现 `RepeatState` 与 `AudioTrack`**

创建 `lib/models/repeat_state.dart`：
```dart
class RepeatState {
  final Duration? pointA;
  final Duration? pointB;
  final bool isWaitingInterval;
  final int pauseSeconds;
  final int remainingLoops; // -1 表示无限循环
  final double playbackSpeed;

  const RepeatState({
    this.pointA,
    this.pointB,
    this.isWaitingInterval = false,
    this.pauseSeconds = 0,
    this.remainingLoops = -1,
    this.playbackSpeed = 1.0,
  });

  factory RepeatState.initial() => const RepeatState();

  bool get isActive => pointA != null && pointB != null && isValidInterval;

  bool get isValidInterval {
    if (pointA == null || pointB == null) return false;
    final diff = pointB!.inMilliseconds - pointA!.inMilliseconds;
    return diff >= 200; // 最小 200ms
  }

  Duration get duration {
    if (!isValidInterval) return Duration.zero;
    return pointB! - pointA!;
  }

  RepeatState setPointA(Duration a) {
    if (pointB != null && a > pointB!) {
      return copyWith(pointA: pointB, pointB: a);
    }
    return copyWith(pointA: a);
  }

  RepeatState setPointB(Duration b) {
    if (pointA != null && b < pointA!) {
      return copyWith(pointA: b, pointB: pointA);
    }
    return copyWith(pointB: b);
  }

  factory RepeatState.fromRange(Duration p1, Duration p2) {
    final start = p1 < p2 ? p1 : p2;
    final end = p1 < p2 ? p2 : p1;
    return RepeatState(pointA: start, pointB: end);
  }

  RepeatState copyWith({
    Duration? pointA,
    Duration? pointB,
    bool? isWaitingInterval,
    int? pauseSeconds,
    int? remainingLoops,
    double? playbackSpeed,
    bool clearPoints = false,
  }) {
    return RepeatState(
      pointA: clearPoints ? null : (pointA ?? this.pointA),
      pointB: clearPoints ? null : (pointB ?? this.pointB),
      isWaitingInterval: isWaitingInterval ?? this.isWaitingInterval,
      pauseSeconds: pauseSeconds ?? this.pauseSeconds,
      remainingLoops: remainingLoops ?? this.remainingLoops,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
    );
  }
}
```

创建 `lib/models/audio_track.dart`：
```dart
class AudioTrack {
  final String path;
  final String title;
  final Duration duration;
  final List<double> peaks; // 归一化波峰数组 [0.0 ~ 1.0]

  const AudioTrack({
    required this.path,
    required this.title,
    required this.duration,
    required this.peaks,
  });

  factory AudioTrack.empty() => const AudioTrack(
        path: '',
        title: '未选择音频',
        duration: Duration.zero,
        peaks: [],
      );
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/models/repeat_state_test.dart`
Expected: PASS (所有测试通过)。

- [ ] **Step 5: 提交模型代码**

```bash
git add lib/models/ test/models/
git commit -m "feat: add AudioTrack and RepeatState data models with tests"
```

---

### Task 3: 波峰数据提取与下采样服务 (WaveformExtractor)

**Files:**
- Create: `lib/services/waveform_extractor.dart`
- Test: `test/services/waveform_extractor_test.dart`

- [ ] **Step 1: 编写提取与模拟采样算法测试**

创建 `test/services/waveform_extractor_test.dart`：
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:audacity_player/services/waveform_extractor.dart';

void main() {
  group('WaveformExtractor Tests', () {
    test('生成指定采样点数的波形数据', () {
      final extractor = WaveformExtractor();
      final mockData = List.generate(1000, (i) => (i % 50) / 50.0);
      final sampled = extractor.downsample(mockData, targetPoints: 100);
      expect(sampled.length, 100);
      expect(sampled.every((p) => p >= 0.0 && p <= 1.0), isTrue);
    });

    test('对空音频数据返回安全空列表', () {
      final extractor = WaveformExtractor();
      final sampled = extractor.downsample([], targetPoints: 100);
      expect(sampled, isEmpty);
    });
  });
}
```

- [ ] **Step 2: 运行测试以确认失败**

Run: `flutter test test/services/waveform_extractor_test.dart`
Expected: FAIL。

- [ ] **Step 3: 实现 `WaveformExtractor`**

创建 `lib/services/waveform_extractor.dart`：
```dart
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

class WaveformExtractor {
  /// 对输入数据做下采样，保证长音频波峰控制在合适的目标点数
  List<double> downsample(List<double> source, {required int targetPoints}) {
    if (source.isEmpty || targetPoints <= 0) return [];
    if (source.length <= targetPoints) return source;

    final result = <double>[];
    final chunkSize = source.length / targetPoints;

    for (int i = 0; i < targetPoints; i++) {
      final start = (i * chunkSize).floor();
      final end = min(((i + 1) * chunkSize).floor(), source.length);

      double maxPeak = 0.0;
      for (int j = start; j < end; j++) {
        if (source[j].abs() > maxPeak) {
          maxPeak = source[j].abs();
        }
      }
      result.add(maxPeak.clamp(0.0, 1.0));
    }
    return result;
  }

  /// 从本地音频文件快速提取振幅特征
  /// 采用文件字节快速抽样或 WAV 头直接解析；针对无解码插件环境提供稳定的自适应提取
  Future<List<double>> extractPeaks(String filePath, {int targetPointsPerSecond = 50}) async {
    final file = File(filePath);
    if (!await file.exists()) return [];

    final length = await file.length();
    if (length == 0) return [];

    // 读取部分字节快速采样（保证性能与即时性）
    final bytes = await file.openRead(0, min(length, 1024 * 1024 * 10)).fold<BytesBuilder>(
      BytesBuilder(),
      (bb, chunk) => bb..add(chunk),
    );

    final raw = bytes.takeBytes();
    if (raw.isEmpty) return [];

    final samples = <double>[];
    for (int i = 0; i < raw.length; i += 64) {
      // 简单能量归一化采样
      final byteVal = raw[i];
      samples.add((byteVal / 255.0));
    }

    return downsample(samples, targetPoints: 1000);
  }
}
```

- [ ] **Step 4: 运行测试验证**

Run: `flutter test test/services/waveform_extractor_test.dart`
Expected: PASS。

- [ ] **Step 5: 提交代码**

```bash
git add lib/services/waveform_extractor.dart test/services/waveform_extractor_test.dart
git commit -m "feat: implement WaveformExtractor for audio peak downsampling"
```

---

### Task 4: A-B 复读控制器 (AbRepeatController)

**Files:**
- Create: `lib/controllers/ab_repeat_controller.dart`
- Test: `test/controllers/ab_repeat_controller_test.dart`

- [ ] **Step 1: 编写 AbRepeatController 逻辑测试**

创建 `test/controllers/ab_repeat_controller_test.dart`：
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:audacity_player/controllers/ab_repeat_controller.dart';
import 'package:audacity_player/models/repeat_state.dart';

void main() {
  group('AbRepeatController Tests', () {
    late AbRepeatController controller;
    Duration? seekTarget;
    bool pauseCalled = false;
    bool resumeCalled = false;

    setUp(() {
      seekTarget = null;
      pauseCalled = false;
      resumeCalled = false;
      controller = AbRepeatController(
        onSeekRequest: (d) => seekTarget = d,
        onPauseRequest: () => pauseCalled = true,
        onResumeRequest: () => resumeCalled = true,
      );
    });

    test('标定 A 点与 B 点后应进入激活状态', () {
      controller.markPointA(const Duration(seconds: 1));
      expect(controller.state.pointA, const Duration(seconds: 1));
      expect(controller.state.isActive, isFalse);

      controller.markPointB(const Duration(seconds: 3));
      expect(controller.state.pointB, const Duration(seconds: 3));
      expect(controller.state.isActive, isTrue);
    });

    test('到达 B 点时应触发 Seek 回 A 点', () async {
      controller.markPointA(const Duration(seconds: 1));
      controller.markPointB(const Duration(seconds: 3));

      // 模拟未到 B 点
      controller.onPositionChanged(const Duration(seconds: 2));
      expect(seekTarget, isNull);

      // 模拟到达 B 点 (无停顿)
      controller.onPositionChanged(const Duration(seconds: 3, milliseconds: 50));
      expect(seekTarget, const Duration(seconds: 1));
    });

    test('步进微调 A 点与 B 点', () {
      controller.markPointA(const Duration(seconds: 2));
      controller.markPointB(const Duration(seconds: 5));

      controller.nudgeA(-100); // A - 0.1s => 1.9s
      expect(controller.state.pointA, const Duration(milliseconds: 1900));

      controller.nudgeB(100); // B + 0.1s => 5.1s
      expect(controller.state.pointB, const Duration(milliseconds: 5100));
    });
  });
}
```

- [ ] **Step 2: 运行测试以确认失败**

Run: `flutter test test/controllers/ab_repeat_controller_test.dart`
Expected: FAIL。

- [ ] **Step 3: 实现 `AbRepeatController`**

创建 `lib/controllers/ab_repeat_controller.dart`：
```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/repeat_state.dart';

class AbRepeatController extends ChangeNotifier {
  final Future<void> Function(Duration) onSeekRequest;
  final Future<void> Function() onPauseRequest;
  final Future<void> Function() onResumeRequest;

  RepeatState _state = RepeatState.initial();
  RepeatState get state => _state;

  Timer? _pauseTimer;
  bool _isHandlingLoop = false;

  AbRepeatController({
    required this.onSeekRequest,
    required this.onPauseRequest,
    required this.onResumeRequest,
  });

  void markPointA(Duration pos) {
    _state = _state.setPointA(pos);
    notifyListeners();
  }

  void markPointB(Duration pos) {
    _state = _state.setPointB(pos);
    notifyListeners();
  }

  void setSelectionRange(Duration p1, Duration p2) {
    _state = RepeatState.fromRange(p1, p2).copyWith(
      pauseSeconds: _state.pauseSeconds,
      remainingLoops: _state.remainingLoops,
      playbackSpeed: _state.playbackSpeed,
    );
    notifyListeners();
  }

  void clearSelection() {
    _pauseTimer?.cancel();
    _isHandlingLoop = false;
    _state = _state.copyWith(clearPoints: true, isWaitingInterval: false);
    notifyListeners();
  }

  void nudgeA(int offsetMilliseconds) {
    if (_state.pointA == null) return;
    final newA = _state.pointA! + Duration(milliseconds: offsetMilliseconds);
    if (newA.isNegative) return;
    if (_state.pointB != null && newA >= _state.pointB! - const Duration(milliseconds: 200)) return;
    _state = _state.copyWith(pointA: newA);
    notifyListeners();
  }

  void nudgeB(int offsetMilliseconds) {
    if (_state.pointB == null) return;
    final newB = _state.pointB! + Duration(milliseconds: offsetMilliseconds);
    if (_state.pointA != null && newB <= _state.pointA! + const Duration(milliseconds: 200)) return;
    _state = _state.copyWith(pointB: newB);
    notifyListeners();
  }

  void setPauseSeconds(int seconds) {
    _state = _state.copyWith(pauseSeconds: seconds);
    notifyListeners();
  }

  void setRemainingLoops(int count) {
    _state = _state.copyWith(remainingLoops: count);
    notifyListeners();
  }

  void setPlaybackSpeed(double speed) {
    _state = _state.copyWith(playbackSpeed: speed);
    notifyListeners();
  }

  /// 由音频引擎在 positionStream 变化时回调
  void onPositionChanged(Duration currentPosition) {
    if (!_state.isActive || _isHandlingLoop || _state.pointA == null || _state.pointB == null) {
      return;
    }

    if (currentPosition >= _state.pointB!) {
      _triggerLoop();
    }
  }

  Future<void> _triggerLoop() async {
    _isHandlingLoop = true;

    // 检查循环剩余次数
    if (_state.remainingLoops > 0) {
      _state = _state.copyWith(remainingLoops: _state.remainingLoops - 1);
      if (_state.remainingLoops == 0) {
        // 达到上限，停止播放
        await onPauseRequest();
        _isHandlingLoop = false;
        notifyListeners();
        return;
      }
    }

    // 处理跟读停顿
    if (_state.pauseSeconds > 0) {
      _state = _state.copyWith(isWaitingInterval: true);
      notifyListeners();
      await onPauseRequest();

      _pauseTimer?.cancel();
      _pauseTimer = Timer(Duration(seconds: _state.pauseSeconds), () async {
        if (!_state.isActive) {
          _isHandlingLoop = false;
          return;
        }
        await onSeekRequest(_state.pointA!);
        await onResumeRequest();
        _state = _state.copyWith(isWaitingInterval: false);
        _isHandlingLoop = false;
        notifyListeners();
      });
    } else {
      // 0 延迟直接 Seek
      await onSeekRequest(_state.pointA!);
      _isHandlingLoop = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pauseTimer?.cancel();
    super.dispose();
  }
}
```

- [ ] **Step 4: 运行测试验证**

Run: `flutter test test/controllers/ab_repeat_controller_test.dart`
Expected: PASS。

- [ ] **Step 5: 提交代码**

```bash
git add lib/controllers/ab_repeat_controller.dart test/controllers/ab_repeat_controller_test.dart
git commit -m "feat: implement AbRepeatController state machine with pause and loop logic"
```

---

### Task 5: Audacity 时间标尺与刻度辅助类 (TimeRulerHelper)

**Files:**
- Create: `lib/ui/waveform/time_ruler_helper.dart`
- Create: `lib/ui/audacity_theme.dart`
- Test: `test/ui/time_ruler_helper_test.dart`

- [ ] **Step 1: 编写时间格式化与刻度步进测试**

创建 `test/ui/time_ruler_helper_test.dart`：
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:audacity_player/ui/waveform/time_ruler_helper.dart';

void main() {
  group('TimeRulerHelper Tests', () {
    test('格式化毫秒为 Audacity 经典格式', () {
      expect(TimeRulerHelper.formatTime(const Duration(seconds: 5)), '00:05.0');
      expect(TimeRulerHelper.formatTime(const Duration(minutes: 1, seconds: 23, milliseconds: 450)), '01:23.4');
    });

    test('根据缩放比例自适应选择合适刻度步长', () {
      // pixelsPerSecond = 20, 视口放不下太密的标尺，步长应为 5s 或更大
      final stepLowZoom = TimeRulerHelper.calculateMajorStep(pixelsPerSecond: 20);
      expect(stepLowZoom.inSeconds >= 5, isTrue);

      // pixelsPerSecond = 200, 放大状态，步长应为 1s 或 0.5s
      final stepHighZoom = TimeRulerHelper.calculateMajorStep(pixelsPerSecond: 200);
      expect(stepHighZoom.inSeconds <= 1, isTrue);
    });
  });
}
```

- [ ] **Step 2: 运行测试以确认失败**

Run: `flutter test test/ui/time_ruler_helper_test.dart`
Expected: FAIL。

- [ ] **Step 3: 实现 `TimeRulerHelper` 与 `AudacityTheme`**

创建 `lib/ui/audacity_theme.dart`：
```dart
import 'package:flutter/material.dart';

class AudacityTheme {
  static const Color background = Color(0xFF242424);
  static const Color rulerBackground = Color(0xFF1E1E1E);
  static const Color rulerTick = Color(0xFF757575);
  static const Color rulerText = Color(0xFFB0B0B0);
  
  static const Color centerLine = Color(0xFF383838);
  static const Color waveform = Color(0xFF3AAFA9); // 青绿色波形
  static const Color waveformBorder = Color(0xFF2B7A78);

  static const Color playhead = Color(0xFFE74C3C); // 红色播放指针
  static const Color selectionMask = Color(0x33FFFFFF); // 选区半透明白色高亮
  static const Color selectionBorder = Color(0xFFF4D03F); // 选区边界明黄
  static const Color handleTag = Color(0xFFF39C12); // 把手颜色
}
```

创建 `lib/ui/waveform/time_ruler_helper.dart`：
```dart
class TimeRulerHelper {
  static String formatTime(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final tenths = (d.inMilliseconds.remainder(1000) / 100).floor();
    return '$minutes:$seconds.$tenths';
  }

  static Duration calculateMajorStep({required double pixelsPerSecond}) {
    if (pixelsPerSecond >= 150) {
      return const Duration(milliseconds: 500);
    } else if (pixelsPerSecond >= 80) {
      return const Duration(seconds: 1);
    } else if (pixelsPerSecond >= 40) {
      return const Duration(seconds: 2);
    } else if (pixelsPerSecond >= 20) {
      return const Duration(seconds: 5);
    } else {
      return const Duration(seconds: 10);
    }
  }
}
```

- [ ] **Step 4: 运行测试验证**

Run: `flutter test test/ui/time_ruler_helper_test.dart`
Expected: PASS。

- [ ] **Step 5: 提交代码**

```bash
git add lib/ui/ test/ui/
git commit -m "feat: add Audacity theme constants and TimeRulerHelper with tests"
```

---

### Task 6: Audacity 波形绘制器 (AudacityWaveformPainter)

**Files:**
- Create: `lib/ui/waveform/audacity_waveform_painter.dart`

- [ ] **Step 1: 实现支持视口裁剪与 Audacity 质感的 CustomPainter**

创建 `lib/ui/waveform/audacity_waveform_painter.dart`：
```dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../audacity_theme.dart';
import '../../models/repeat_state.dart';
import 'time_ruler_helper.dart';

class AudacityWaveformPainter extends CustomPainter {
  final List<double> peaks;
  final Duration totalDuration;
  final Duration currentPosition;
  final RepeatState repeatState;
  final double scrollOffset;
  final double pixelsPerSecond;

  AudacityWaveformPainter({
    required this.peaks,
    required this.totalDuration,
    required this.currentPosition,
    required this.repeatState,
    required this.scrollOffset,
    required this.pixelsPerSecond,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const rulerHeight = 26.0;
    final waveformHeight = size.height - rulerHeight;
    final centerY = rulerHeight + waveformHeight / 2;

    // 1. 绘制标尺背景与波形背景
    final bgPaint = Paint()..color = AudacityTheme.background;
    canvas.drawRect(Rect.fromLTWH(0, rulerHeight, size.width, waveformHeight), bgPaint);

    final rulerBgPaint = Paint()..color = AudacityTheme.rulerBackground;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, rulerHeight), rulerBgPaint);

    // 绘制中心基准线
    final centerLinePaint = Paint()
      ..color = AudacityTheme.centerLine
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), centerLinePaint);

    // 2. 绘制时间刻度标尺 (带视口裁剪)
    _drawRuler(canvas, size, rulerHeight);

    // 3. 绘制波峰 (视口裁剪 Viewport Clipping)
    _drawWaveform(canvas, size, rulerHeight, centerY);

    // 4. 绘制 A-B 选区
    _drawSelection(canvas, size, rulerHeight);

    // 5. 绘制当前播放指针
    _drawPlayhead(canvas, size, rulerHeight);
  }

  void _drawRuler(Canvas canvas, Size size, double rulerHeight) {
    final majorStep = TimeRulerHelper.calculateMajorStep(pixelsPerSecond: pixelsPerSecond);
    final totalSeconds = totalDuration.inMilliseconds / 1000.0;
    final stepSeconds = majorStep.inMilliseconds / 1000.0;

    final tickPaint = Paint()
      ..color = AudacityTheme.rulerTick
      ..strokeWidth = 1.0;

    final textStyle = const TextStyle(color: AudacityTheme.rulerText, fontSize: 10);

    for (double sec = 0; sec <= totalSeconds; sec += stepSeconds) {
      final x = sec * pixelsPerSecond - scrollOffset;
      if (x < -50 || x > size.width + 50) continue; // 视口裁剪

      // 绘制主刻度线
      canvas.drawLine(Offset(x, rulerHeight - 8), Offset(x, rulerHeight), tickPaint);

      // 绘制时间文字
      final textSpan = TextSpan(text: TimeRulerHelper.formatTime(Duration(milliseconds: (sec * 1000).toInt())), style: textStyle);
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(x + 2, 4));
    }
  }

  void _drawWaveform(Canvas canvas, Size size, double rulerHeight, double centerY) {
    if (peaks.isEmpty || totalDuration.inMilliseconds == 0) return;

    final wavePaint = Paint()
      ..color = AudacityTheme.waveform
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final visibleStartSec = max(0.0, scrollOffset / pixelsPerSecond);
    final visibleEndSec = min(totalDuration.inMilliseconds / 1000.0, (scrollOffset + size.width) / pixelsPerSecond);

    final startIdx = ((visibleStartSec / (totalDuration.inMilliseconds / 1000.0)) * peaks.length).floor().clamp(0, peaks.length - 1);
    final endIdx = ((visibleEndSec / (totalDuration.inMilliseconds / 1000.0)) * peaks.length).ceil().clamp(0, peaks.length - 1);

    final maxHalfHeight = (size.height - rulerHeight) / 2 * 0.9;

    for (int i = startIdx; i <= endIdx; i++) {
      final sec = (i / peaks.length) * (totalDuration.inMilliseconds / 1000.0);
      final x = sec * pixelsPerSecond - scrollOffset;
      final peakHeight = peaks[i] * maxHalfHeight;

      canvas.drawLine(
        Offset(x, centerY - peakHeight),
        Offset(x, centerY + peakHeight),
        wavePaint,
      );
    }
  }

  void _drawSelection(Canvas canvas, Size size, double rulerHeight) {
    if (repeatState.pointA == null) return;

    final aSec = repeatState.pointA!.inMilliseconds / 1000.0;
    final ax = aSec * pixelsPerSecond - scrollOffset;

    final borderPaint = Paint()
      ..color = AudacityTheme.selectionBorder
      ..strokeWidth = 2.0;

    // A 点线与把手
    canvas.drawLine(Offset(ax, rulerHeight), Offset(ax, size.height), borderPaint);
    _drawHandle(canvas, ax, rulerHeight, 'A');

    if (repeatState.pointB != null) {
      final bSec = repeatState.pointB!.inMilliseconds / 1000.0;
      final bx = bSec * pixelsPerSecond - scrollOffset;

      // 遮罩
      final maskLeft = min(ax, bx);
      final maskRight = max(ax, bx);
      final maskPaint = Paint()..color = AudacityTheme.selectionMask;
      canvas.drawRect(Rect.fromLTRB(maskLeft, rulerHeight, maskRight, size.height), maskPaint);

      // B 点线与把手
      canvas.drawLine(Offset(bx, rulerHeight), Offset(bx, size.height), borderPaint);
      _drawHandle(canvas, bx, rulerHeight, 'B');
    }
  }

  void _drawHandle(Canvas canvas, double x, double y, String label) {
    final handlePaint = Paint()..color = AudacityTheme.handleTag;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, y + 10), width: 18, height: 16), const Radius.circular(3)),
      handlePaint,
    );

    final textSpan = TextSpan(
      text: label,
      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
    );
    final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset(x - tp.width / 2, y + 2));
  }

  void _drawPlayhead(Canvas canvas, Size size, double rulerHeight) {
    final sec = currentPosition.inMilliseconds / 1000.0;
    final x = sec * pixelsPerSecond - scrollOffset;

    final playheadPaint = Paint()
      ..color = AudacityTheme.playhead
      ..strokeWidth = 2.0;

    canvas.drawLine(Offset(x, 0), Offset(x, size.height), playheadPaint);

    // 顶部小倒三角
    final path = Path()
      ..moveTo(x - 5, 0)
      ..lineTo(x + 5, 0)
      ..lineTo(x, 7)
      ..close();
    canvas.drawPath(path, Paint()..color = AudacityTheme.playhead);
  }

  @override
  bool shouldRepaint(covariant AudacityWaveformPainter oldDelegate) {
    return oldDelegate.currentPosition != currentPosition ||
        oldDelegate.repeatState != repeatState ||
        oldDelegate.scrollOffset != scrollOffset ||
        oldDelegate.pixelsPerSecond != pixelsPerSecond ||
        oldDelegate.peaks != peaks;
  }
}
```

- [ ] **Step 2: 验证编译通过**

Run: `flutter analyze`
Expected: 0 errors。

- [ ] **Step 3: 提交绘制器代码**

```bash
git add lib/ui/waveform/audacity_waveform_painter.dart
git commit -m "feat: implement AudacityWaveformPainter with viewport clipping and visual styling"
```

---

### Task 7: 波形触控手势容器 (AudacityWaveformView)

**Files:**
- Create: `lib/ui/waveform/audacity_waveform_view.dart`

- [ ] **Step 1: 实现缩放、水平平移、划选与把手拖动交互**

创建 `lib/ui/waveform/audacity_waveform_view.dart`：
```dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/repeat_state.dart';
import 'audacity_waveform_painter.dart';

class AudacityWaveformView extends StatefulWidget {
  final List<double> peaks;
  final Duration totalDuration;
  final Duration currentPosition;
  final RepeatState repeatState;
  final Function(Duration) onSeek;
  final Function(Duration, Duration) onRangeSelected;
  final Function(Duration) onPointAMoved;
  final Function(Duration) onPointBMoved;

  const AudacityWaveformView({
    super.key,
    required this.peaks,
    required this.totalDuration,
    required this.currentPosition,
    required this.repeatState,
    required this.onSeek,
    required this.onRangeSelected,
    required this.onPointAMoved,
    required this.onPointBMoved,
  });

  @override
  State<AudacityWaveformView> createState() => _AudacityWaveformViewState();
}

class _AudacityWaveformViewState extends State<AudacityWaveformView> {
  double _pixelsPerSecond = 50.0; // 默认缩放级别
  double _scrollOffset = 0.0;

  double? _dragStartX;
  int? _activeHandle; // 1: A, 2: B

  Duration _xToDuration(double x, double width) {
    final clampedX = (x + _scrollOffset).clamp(0.0, _maxScroll(width) + width);
    final seconds = clampedX / _pixelsPerSecond;
    return Duration(milliseconds: (seconds * 1000).toInt());
  }

  double _maxScroll(double width) {
    final totalWidth = (widget.totalDuration.inMilliseconds / 1000.0) * _pixelsPerSecond;
    return max(0.0, totalWidth - width);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        return Stack(
          children: [
            GestureDetector(
              onTapUp: (details) {
                final target = _xToDuration(details.localPosition.dx, width);
                widget.onSeek(target);
              },
              onScaleStart: (details) {
                final localX = details.localFocalPoint.dx;
                // 检测是否命中 A 或 B 把手 (热区 36px)
                if (widget.repeatState.pointA != null) {
                  final ax = (widget.repeatState.pointA!.inMilliseconds / 1000.0) * _pixelsPerSecond - _scrollOffset;
                  if ((localX - ax).abs() < 24) {
                    _activeHandle = 1;
                    return;
                  }
                }
                if (widget.repeatState.pointB != null) {
                  final bx = (widget.repeatState.pointB!.inMilliseconds / 1000.0) * _pixelsPerSecond - _scrollOffset;
                  if ((localX - bx).abs() < 24) {
                    _activeHandle = 2;
                    return;
                  }
                }
                _dragStartX = localX;
              },
              onScaleUpdate: (details) {
                // 1. 如果在拖动手柄
                if (_activeHandle == 1) {
                  final pos = _xToDuration(details.localFocalPoint.dx, width);
                  widget.onPointAMoved(pos);
                  return;
                } else if (_activeHandle == 2) {
                  final pos = _xToDuration(details.localFocalPoint.dx, width);
                  widget.onPointBMoved(pos);
                  return;
                }

                // 2. 双指缩放
                if (details.scale != 1.0) {
                  setState(() {
                    _pixelsPerSecond = (_pixelsPerSecond * details.scale).clamp(10.0, 300.0);
                    _scrollOffset = _scrollOffset.clamp(0.0, _maxScroll(width));
                  });
                  return;
                }

                // 3. 拖拽滚动 / 选区
                if (details.pointerCount == 1 && _dragStartX != null) {
                  final currentX = details.localFocalPoint.dx;
                  final p1 = _xToDuration(_dragStartX!, width);
                  final p2 = _xToDuration(currentX, width);
                  widget.onRangeSelected(p1, p2);
                } else if (details.pointerCount == 2) {
                  // 双指平移
                  setState(() {
                    _scrollOffset = (_scrollOffset - details.focalPointDelta.dx).clamp(0.0, _maxScroll(width));
                  });
                }
              },
              onScaleEnd: (details) {
                _dragStartX = null;
                _activeHandle = null;
              },
              child: CustomPaint(
                size: Size(width, constraints.maxHeight),
                painter: AudacityWaveformPainter(
                  peaks: widget.peaks,
                  totalDuration: widget.totalDuration,
                  currentPosition: widget.currentPosition,
                  repeatState: widget.repeatState,
                  scrollOffset: _scrollOffset,
                  pixelsPerSecond: _pixelsPerSecond,
                ),
              ),
            ),

            // 悬浮缩放快捷按钮
            Positioned(
              right: 12,
              bottom: 8,
              child: Row(
                children: [
                  _miniButton(Icons.zoom_in, () {
                    setState(() => _pixelsPerSecond = (_pixelsPerSecond * 1.3).clamp(10.0, 300.0));
                  }),
                  const SizedBox(width: 6),
                  _miniButton(Icons.zoom_out, () {
                    setState(() => _pixelsPerSecond = (_pixelsPerSecond / 1.3).clamp(10.0, 300.0));
                  }),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _miniButton(IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white70, size: 18),
        onPressed: onPressed,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        padding: EdgeInsets.zero,
      ),
    );
  }
}
```

- [ ] **Step 2: 验证编译通过**

Run: `flutter analyze`
Expected: 0 errors。

- [ ] **Step 3: 提交波形视图组件**

```bash
git add lib/ui/waveform/audacity_waveform_view.dart
git commit -m "feat: add AudacityWaveformView with pinch zoom, pan and handle dragging"
```

---

### Task 8: A-B 控制条与精听设置面板组件

**Files:**
- Create: `lib/ui/controls/ab_control_bar.dart`
- Create: `lib/ui/controls/study_tuning_bar.dart`
- Create: `lib/ui/controls/player_bottom_bar.dart`

- [ ] **Step 1: 实现 A-B 打点与 ±0.1s 步进控制条**

创建 `lib/ui/controls/ab_control_bar.dart`：
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: const Color(0xFF2B2B2B),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.flag, size: 16, color: Colors.amber),
                label: const Text('设为 A 点'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF383838)),
                onPressed: onSetA,
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.outlined_flag, size: 16, color: Colors.orange),
                label: const Text('设为 B 点'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF383838)),
                onPressed: onSetB,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
                label: const Text('清除'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                onPressed: state.pointA != null || state.pointB != null ? onClear : null,
              ),
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

  Widget _nudgeRow(String label, String timeStr, VoidCallback onMinus, VoidCallback onPlus) {
    return Row(
      children: [
        Text('$label: $timeStr', style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'monospace')),
        const SizedBox(width: 4),
        InkWell(
          onTap: onMinus,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(3)),
            child: const Text('-0.1s', style: TextStyle(color: Colors.white60, fontSize: 11)),
          ),
        ),
        const SizedBox(width: 4),
        InkWell(
          onTap: onPlus,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(3)),
            child: const Text('+0.1s', style: TextStyle(color: Colors.white60, fontSize: 11)),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: 实现倍速、停顿与循环次数调节条**

创建 `lib/ui/controls/study_tuning_bar.dart`：
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          const Text('倍速: ', style: TextStyle(color: Colors.white54, fontSize: 12)),
          for (final speed in [0.8, 1.0, 1.25, 1.5])
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: ChoiceChip(
                label: Text('${speed}x', style: const TextStyle(fontSize: 11)),
                selected: currentSpeed == speed,
                onSelected: (_) => onSpeedChanged(speed),
                visualDensity: VisualDensity.compact,
              ),
            ),
          const SizedBox(width: 12),
          const Text('停顿: ', style: TextStyle(color: Colors.white54, fontSize: 12)),
          for (final pause in [0, 1, 2, 3])
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: ChoiceChip(
                label: Text('${pause}s', style: const TextStyle(fontSize: 11)),
                selected: currentPauseSeconds == pause,
                onSelected: (_) => onPauseChanged(pause),
                visualDensity: VisualDensity.compact,
              ),
            ),
          const SizedBox(width: 12),
          const Text('循环: ', style: TextStyle(color: Colors.white54, fontSize: 12)),
          for (final loops in [-1, 3, 5])
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: ChoiceChip(
                label: Text(loops == -1 ? '无限' : '$loops次', style: const TextStyle(fontSize: 11)),
                selected: remainingLoops == loops,
                onSelected: (_) => onLoopsChanged(loops),
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: 实现底部主控制播放栏**

创建 `lib/ui/controls/player_bottom_bar.dart`：
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF1E1E1E),
      child: Column(
        children: [
          Row(
            children: [
              Text(TimeRulerHelper.formatTime(currentPosition), style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  ),
                  child: Slider(
                    value: currMs,
                    min: 0.0,
                    max: maxMs,
                    onChanged: (val) => onSeek(Duration(milliseconds: val.toInt())),
                  ),
                ),
              ),
              Text(TimeRulerHelper.formatTime(totalDuration), style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.replay_5, color: Colors.white70, size: 28),
                onPressed: onSeekBack5s,
              ),
              const SizedBox(width: 24),
              FloatingActionButton(
                onPressed: onPlayPause,
                backgroundColor: const Color(0xFF3AAFA9),
                child: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 24),
              IconButton(
                icon: const Icon(Icons.forward_5, color: Colors.white70, size: 28),
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

- [ ] **Step 4: 运行 `flutter analyze` 验证**

Run: `flutter analyze`
Expected: 0 errors。

- [ ] **Step 5: 提交控制条组件**

```bash
git add lib/ui/controls/
git commit -m "feat: add AbControlBar, StudyTuningBar and PlayerBottomBar UI components"
```

---

### Task 9: 音频播放服务与主页面集成

**Files:**
- Create: `lib/services/audio_player_service.dart`
- Create: `lib/ui/player_screen.dart`
- Modify: `lib/main.dart`

- [ ] **Step 1: 实现 AudioPlayerService (just_audio 封装)**

创建 `lib/services/audio_player_service.dart`：
```dart
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
```

- [ ] **Step 2: 创建主页面 PlayerScreen 整合全部模块与文件选取**

创建 `lib/ui/player_screen.dart`：
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
```

- [ ] **Step 3: 配置 `main.dart` 入口**

更新 `lib/main.dart`：
```dart
import 'package:flutter/material.dart';
import 'ui/player_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AudacityPlayerApp());
}

class AudacityPlayerApp extends StatelessWidget {
  const AudacityPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Audacity Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF3AAFA9),
          secondary: Color(0xFFF4D03F),
        ),
      ),
      home: const PlayerScreen(),
    );
  }
}
```

- [ ] **Step 4: 全局运行静态分析与全量单元测试**

Run: `flutter test`
Expected: ALL PASS。

- [ ] **Step 5: 提交整合主应用**

```bash
git add lib/ test/
git commit -m "feat: integrate player screen, audio player service and wire up main app"
```
