# 波形图播放自动跟随与触控手势模式切换实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现音频播放时波形图自动居中平滑跟随滚动（用户触摸时暂停跟随，松手后冷却恢复）；并在 A-B 控制区左侧添加醒目的双态模式切换按钮，默认单指拖动浏览波形，切换后单指划选 A-B 区间。

**Architecture:** 定义 `WaveformGestureMode` 枚举；在 `AudacityWaveformView` 中监听播放位置与播放状态，实现居中自动滚动算法与用户干预计时器；改造手势处理器，在拖动模式下将单指滑动转化为视口平移（`_scrollOffset`），在划选模式下触发区间划选；在 `AbControlBar` 最左侧增加高对比度醒目的模式切换组件。

**Tech Stack:** Flutter / Dart, CustomPainter, Timer.

---

### Task 1: 创建触控手势模式枚举 (WaveformGestureMode)

**Files:**
- Create: `lib/models/waveform_gesture_mode.dart`
- Create: `test/models/waveform_gesture_mode_test.dart`

- [ ] **Step 1: 编写手势模式单元测试**

创建 `test/models/waveform_gesture_mode_test.dart`：
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:audacity_player/models/waveform_gesture_mode.dart';

void main() {
  group('WaveformGestureMode Tests', () {
    test('包含拖动模式和划选模式', () {
      expect(WaveformGestureMode.drag.isDrag, isTrue);
      expect(WaveformGestureMode.drag.isSelect, isFalse);
      expect(WaveformGestureMode.select.isSelect, isTrue);
      expect(WaveformGestureMode.select.isDrag, isFalse);
    });

    test('提供易读的中文标签与图标说明', () {
      expect(WaveformGestureMode.drag.label, '拖动');
      expect(WaveformGestureMode.select.label, '划选');
    });
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/models/waveform_gesture_mode_test.dart`
Expected: 找不到 `WaveformGestureMode` 编译失败。

- [ ] **Step 3: 实现 `WaveformGestureMode` 枚举**

创建 `lib/models/waveform_gesture_mode.dart`：
```dart
enum WaveformGestureMode {
  drag,
  select;

  bool get isDrag => this == WaveformGestureMode.drag;
  bool get isSelect => this == WaveformGestureMode.select;

  String get label {
    switch (this) {
      case WaveformGestureMode.drag:
        return '拖动';
      case WaveformGestureMode.select:
        return '划选';
    }
  }
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/models/waveform_gesture_mode_test.dart`
Expected: ALL PASS。

- [ ] **Step 5: 提交模式模型**

```bash
git add lib/models/waveform_gesture_mode.dart test/models/waveform_gesture_mode_test.dart
git commit -m "feat: add WaveformGestureMode enum with tests"
```

---

### Task 2: 在 A-B 控制区左侧集成醒目手势切换器 (AbControlBar)

**Files:**
- Modify: `lib/ui/controls/ab_control_bar.dart`

- [ ] **Step 1: 在 AbControlBar 左侧添加醒目双态切换器**

修改 `lib/ui/controls/ab_control_bar.dart`：
- 接收 `gestureMode` 与 `onGestureModeChanged` 回调；
- 在左侧增加高对比度、带图标的胶囊按钮：当前激活项用醒目颜色（拖动用 `#3AAFA9` 青绿，划选用 `#F4D03F` 明黄）；
- 保持横向单行可滚动与纵向自适应，防止溢出。

```dart
import 'package:flutter/material.dart';
import '../../models/repeat_state.dart';
import '../../models/waveform_gesture_mode.dart';
import '../waveform/time_ruler_helper.dart';

class AbControlBar extends StatelessWidget {
  final RepeatState state;
  final Duration currentPosition;
  final WaveformGestureMode gestureMode;
  final ValueChanged<WaveformGestureMode> onGestureModeChanged;
  final VoidCallback onSetA;
  final VoidCallback onSetB;
  final VoidCallback onClear;
  final Function(int) onNudgeA;
  final Function(int) onNudgeB;

  const AbControlBar({
    super.key,
    required this.state,
    required this.currentPosition,
    required this.gestureMode,
    required this.onGestureModeChanged,
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: const BoxDecoration(
        color: Color(0xFF242424),
        border: Border(right: BorderSide(color: Color(0xFF383838), width: 1)),
      ),
      child: Center(
        child: SingleChildScrollView(
          child: Row(
            children: [
              // 1. 最左侧：醒目的手势切换控件
              _buildGestureSwitcher(),
              const SizedBox(width: 8),

              // 2. 右侧：A-B 控制按键与时间微调
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _compactButton(Icons.flag, '设A点', Colors.amber, onSetA),
                          const SizedBox(width: 6),
                          _compactButton(Icons.outlined_flag, '设B点', Colors.orange, onSetB),
                          const SizedBox(width: 6),
                          _compactButton(
                            Icons.close,
                            '清除',
                            Colors.redAccent,
                            (state.pointA != null || state.pointB != null) ? onClear : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 5),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _nudgeGroup('A', aText, () => onNudgeA(-100), () => onNudgeA(100)),
                          const SizedBox(width: 8),
                          _nudgeGroup('B', bText, () => onNudgeB(-100), () => onNudgeB(100)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGestureSwitcher() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF444444), width: 1),
      ),
      padding: const EdgeInsets.all(2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _gestureOption(
            icon: Icons.pan_tool_outlined,
            label: '拖动',
            isActive: gestureMode.isDrag,
            activeColor: const Color(0xFF3AAFA9),
            onTap: () => onGestureModeChanged(WaveformGestureMode.drag),
          ),
          const SizedBox(height: 2),
          _gestureOption(
            icon: Icons.content_cut,
            label: '划选',
            isActive: gestureMode.isSelect,
            activeColor: const Color(0xFFF4D03F),
            onTap: () => onGestureModeChanged(WaveformGestureMode.select),
          ),
        ],
      ),
    );
  }

  Widget _gestureOption({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withAlpha(50) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: isActive ? activeColor : Colors.transparent, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: isActive ? activeColor : Colors.white54),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                color: isActive ? activeColor : Colors.white60,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _compactButton(IconData icon, String label, Color color, VoidCallback? onPressed) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 13, color: color),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF333333),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onPressed,
    );
  }

  Widget _nudgeGroup(String label, String timeStr, VoidCallback onMinus, VoidCallback onPlus) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label:$timeStr',
          style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace'),
        ),
        const SizedBox(width: 3),
        InkWell(
          onTap: onMinus,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(3)),
            child: const Text('-0.1s', style: TextStyle(color: Colors.white60, fontSize: 10)),
          ),
        ),
        const SizedBox(width: 3),
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

- [ ] **Step 3: 提交 A-B 控制栏手势切换器**

```bash
git add lib/ui/controls/ab_control_bar.dart
git commit -m "feat: add prominent gesture mode switcher in AbControlBar"
```

---

### Task 3: 重构波形视口 (AudacityWaveformView)：播放居中跟随与单指拖动平移

**Files:**
- Modify: `lib/ui/waveform/audacity_waveform_view.dart`

- [ ] **Step 1: 实现播放居中跟随与两种手势模式**

修改 `lib/ui/waveform/audacity_waveform_view.dart`：
1. 接收 `isPlaying` 与 `gestureMode`；
2. 在 `didUpdateWidget` 中：如果 `widget.isPlaying == true` 且 `!_isUserInteracting`，根据当前播放进度自动计算 `_scrollOffset` 保持播放指针居中：
   $$\text{targetOffset} = \text{currentPosInSeconds} \times \text{pixelsPerSecond} - \frac{\text{width}}{2}$$
   并将 `_scrollOffset` clamp 在 `[0, maxScroll]`；
3. 手势逻辑分流：
   - 命中 A/B 把手优先拖动微调；
   - 捏合（`scale != 1.0`）执行缩放；
   - 单指操作时：
     - 如果 `gestureMode.isDrag`：将水平位移用于更新 `_scrollOffset`（实现单指自由拖动波形）；
     - 如果 `gestureMode.isSelect`：拉出选区；
4. 触摸时设置 `_isUserInteracting = true` 暂停自动跟随；抬手启动 1.5 秒无操作 Timer，超时后恢复自动跟随。

```dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/repeat_state.dart';
import '../../models/waveform_gesture_mode.dart';
import 'audacity_waveform_painter.dart';

class AudacityWaveformView extends StatefulWidget {
  final List<double> peaks;
  final Duration totalDuration;
  final Duration currentPosition;
  final RepeatState repeatState;
  final bool isPlaying;
  final WaveformGestureMode gestureMode;
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
    required this.isPlaying,
    required this.gestureMode,
    required this.onSeek,
    required this.onRangeSelected,
    required this.onPointAMoved,
    required this.onPointBMoved,
  });

  @override
  State<AudacityWaveformView> createState() => _AudacityWaveformViewState();
}

class _AudacityWaveformViewState extends State<AudacityWaveformView> {
  double _pixelsPerSecond = 50.0;
  double _scrollOffset = 0.0;

  double? _dragStartX;
  double? _dragStartScrollOffset;
  int? _activeHandle; // 1: A, 2: B

  bool _isUserInteracting = false;
  Timer? _interactionCooldownTimer;

  @override
  void didUpdateWidget(covariant AudacityWaveformView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 播放中且用户未在触控交互时，波形居中跟随播放指针
    if (widget.isPlaying && !_isUserInteracting) {
      _centerPlayhead();
    }
  }

  void _centerPlayhead({double? viewportWidth}) {
    final width = viewportWidth ?? (context.findRenderObject() as RenderBox?)?.size.width ?? 0;
    if (width <= 0) return;

    final currentSec = widget.currentPosition.inMilliseconds / 1000.0;
    final playheadX = currentSec * _pixelsPerSecond;
    final targetScroll = playheadX - (width / 2);

    setState(() {
      _scrollOffset = targetScroll.clamp(0.0, _maxScroll(width));
    });
  }

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
  void dispose() {
    _interactionCooldownTimer?.cancel();
    super.dispose();
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
                // 点击跳转后立即恢复居中
                _isUserInteracting = false;
                _interactionCooldownTimer?.cancel();
                _centerPlayhead(viewportWidth: width);
              },
              onScaleStart: (details) {
                _isUserInteracting = true;
                _interactionCooldownTimer?.cancel();

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
                _dragStartScrollOffset = _scrollOffset;
              },
              onScaleUpdate: (details) {
                // 1. 如果在拖动手柄 (A/B 把手微调优先级最高)
                if (_activeHandle == 1) {
                  final pos = _xToDuration(details.localFocalPoint.dx, width);
                  widget.onPointAMoved(pos);
                  return;
                } else if (_activeHandle == 2) {
                  final pos = _xToDuration(details.localFocalPoint.dx, width);
                  widget.onPointBMoved(pos);
                  return;
                }

                // 2. 双指捏合缩放
                if (details.scale != 1.0) {
                  setState(() {
                    _pixelsPerSecond = (_pixelsPerSecond * details.scale).clamp(10.0, 300.0);
                    _scrollOffset = _scrollOffset.clamp(0.0, _maxScroll(width));
                  });
                  return;
                }

                // 3. 单指操作：根据当前手势模式分流
                if (details.pointerCount == 1 && _dragStartX != null) {
                  final currentX = details.localFocalPoint.dx;

                  if (widget.gestureMode.isDrag) {
                    // ✋ 拖动模式：平移波形
                    final deltaX = currentX - _dragStartX!;
                    setState(() {
                      _scrollOffset = ((_dragStartScrollOffset ?? _scrollOffset) - deltaX).clamp(0.0, _maxScroll(width));
                    });
                  } else {
                    // ✂️ 划选模式：拉出 A-B 选区
                    final p1 = _xToDuration(_dragStartX!, width);
                    final p2 = _xToDuration(currentX, width);
                    widget.onRangeSelected(p1, p2);
                  }
                } else if (details.pointerCount == 2) {
                  // 双指拖拽平移
                  setState(() {
                    _scrollOffset = (_scrollOffset - details.focalPointDelta.dx).clamp(0.0, _maxScroll(width));
                  });
                }
              },
              onScaleEnd: (details) {
                _dragStartX = null;
                _dragStartScrollOffset = null;
                _activeHandle = null;

                // 松手 1.5 秒后平滑恢复播放居中跟随
                _interactionCooldownTimer?.cancel();
                _interactionCooldownTimer = Timer(const Duration(milliseconds: 1500), () {
                  if (mounted) {
                    _isUserInteracting = false;
                    if (widget.isPlaying) {
                      _centerPlayhead(viewportWidth: width);
                    }
                  }
                });
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
        color: Colors.black.withAlpha(153),
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

Run: `flutter analyze lib/ui/waveform/audacity_waveform_view.dart`
Expected: 0 issues。

- [ ] **Step 3: 提交波形跟随与拖动模式代码**

```bash
git add lib/ui/waveform/audacity_waveform_view.dart
git commit -m "feat: implement waveform auto-follow playhead and drag-to-scroll gesture mode"
```

---

### Task 4: 主界面串联与全量测试验证

**Files:**
- Modify: `lib/ui/player_screen.dart`
- Modify: `test/widget_test.dart`

- [ ] **Step 1: 在 PlayerScreen 中管理手势模式状态并传参**

修改 `lib/ui/player_screen.dart`：
- 添加状态 `WaveformGestureMode _gestureMode = WaveformGestureMode.drag;`
- 将 `_gestureMode` 传给 `AudacityWaveformView` 与 `AbControlBar`；
- 将 `isPlaying: _isPlaying` 传给 `AudacityWaveformView`；
- 在 `_pickAudioFile` 或切换音频时保持状态。

- [ ] **Step 2: 更新 `test/widget_test.dart` 验证手势切换与默认状态**

在 `test/widget_test.dart` 中添加断言：
- 默认展示 `拖动` 与 `划选` 切换按钮；
- 点击 `划选` 能成功切换模式；
- 运行测试确保无溢出无报错。

- [ ] **Step 3: 运行全量单元测试与分析**

Run: `flutter test`
Expected: ALL PASS。

Run: `flutter analyze`
Expected: 0 issues。

- [ ] **Step 4: 提交主应用串联改动**

```bash
git add lib/ui/player_screen.dart test/widget_test.dart
git commit -m "feat: wire up gesture mode switcher and auto-follow in player screen"
```
