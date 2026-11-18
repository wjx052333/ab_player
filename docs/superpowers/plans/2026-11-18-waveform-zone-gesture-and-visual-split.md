# 波形三段式手势分区与 A-B 划选融合 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 Audacity 风格波形视图改为三段式手势交互（中间 1/2 划选 A-B，上下各 1/4 平移拖动），中间覆盖半透明黄色蒙层与边界线，彻底移除左下角模式切换悬浮按钮。

**Architecture:** 
1. 在 `AudacityWaveformPainter` 中绘制中间 1/2 区域的黄色半透明蒙层及细分界线；
2. 在 `AudacityWaveformView` 的手势处理中，以起始触控点 $Y$ 坐标做分流判定（把手微调优先；中间 1/2 拖动为选区划选，上下各 1/4 为波形水平平移），并在点击时仅在中间 1/2 区域命中断句时选句，其他点击及上下区域统一执行 Seek；
3. 从 `AudacityWaveformView` 移除悬浮模式切换按钮及 `WaveformGestureMode` 参数，同步更新 `PlayerScreen`、模型与测试代码。

**Tech Stack:** Flutter CustomPainter, GestureDetector, Stack/LayoutBuilder, Flutter Test.

---

### Task 1: 视觉增强 - 在 `AudacityWaveformPainter` 中绘制中间 1/2 A-B 划选区蒙层与分界线

**Files:**
- Modify: `lib/ui/waveform/audacity_waveform_painter.dart:35-70`
- Test: `test/ui/waveform_subtitles_test.dart`

- [ ] **Step 1: 编写测试断言 painter 绘制流程无异常**

在 `test/ui/waveform_subtitles_test.dart` 中追加针对不同高度下的绘制测试：

```dart
testWidgets('AudacityWaveformPainter 正常绘制中间 1/2 选区提示区域与分界线', (tester) async {
  final painter = AudacityWaveformPainter(
    peaks: List.generate(200, (i) => 0.5),
    peaksPerSecond: 100,
    totalDuration: const Duration(seconds: 10),
    currentPosition: const Duration(seconds: 1),
    repeatState: const RepeatState(),
    scrollOffset: 0,
    pixelsPerSecond: 50,
  );
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: SizedBox(width: 600, height: 200, child: CustomPaint(painter: painter)),
  );
  expect(tester.takeException(), isNull);
});
```

- [ ] **Step 2: 运行测试验证**

Run: `flutter test test/ui/waveform_subtitles_test.dart`
Expected: PASS

- [ ] **Step 3: 在 `AudacityWaveformPainter` 实现绘制中间 1/2 区域黄色蒙层与分界线**

在 `lib/ui/waveform/audacity_waveform_painter.dart` 的 `paint` 方法中，在绘制标尺背景与波形背景后、绘制波峰之前，调用 `_drawSelectionZoneHint(canvas, size, rulerHeight)`：

```dart
  void _drawSelectionZoneHint(Canvas canvas, Size size, double rulerHeight) {
    final waveformHeight = size.height - rulerHeight;
    if (waveformHeight <= 0) return;

    final y1 = rulerHeight + waveformHeight * 0.25;
    final y2 = rulerHeight + waveformHeight * 0.75;

    // 绘制中间 1/2 区域半透明黄色提示蒙层
    final zonePaint = Paint()
      ..color = const Color(0xFFF4D03F).withValues(alpha: 0.07)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTRB(0, y1, size.width, y2), zonePaint);

    // 绘制上下分界辅助线 (1px)
    final linePaint = Paint()
      ..color = const Color(0xFFF4D03F).withValues(alpha: 0.25)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(0, y1), Offset(size.width, y1), linePaint);
    canvas.drawLine(Offset(0, y2), Offset(size.width, y2), linePaint);
  }
```

- [ ] **Step 4: 运行测试验证**

Run: `flutter test test/ui/waveform_subtitles_test.dart`
Expected: PASS

- [ ] **Step 5: 提交改动**

```bash
git add lib/ui/waveform/audacity_waveform_painter.dart test/ui/waveform_subtitles_test.dart
git commit -m "feat(waveform): draw selection zone hint and boundary lines in painter"
```

---

### Task 2: 手势重构 - 在 `AudacityWaveformView` 中实现三段式手势分流与移除切换按钮

**Files:**
- Modify: `lib/ui/waveform/audacity_waveform_view.dart`
- Create: `test/ui/waveform/audacity_waveform_view_test.dart`

- [ ] **Step 1: 编写 `AudacityWaveformView` 三段式手势单元测试**

创建 `test/ui/waveform/audacity_waveform_view_test.dart`：
测试点包含：
1. 中间 1/2 区域单指横向拖拽触发 `onRangeSelected`；
2. 上部 1/4 区域单指横向拖拽平移波形（不触发 `onRangeSelected`）；
3. 下部 1/4 区域单指横向拖拽平移波形（不触发 `onRangeSelected`）；
4. 中间 1/2 区域单指点击断句触发 `onRangeSelected`；
5. 上部 1/4 区域单指点击断句处只触发 `onSeek`，不触发 `onRangeSelected`；
6. 不再渲染原「拖动」与「AB」模式切换按钮。

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:audacity_player/models/repeat_state.dart';
import 'package:audacity_player/models/speech_segment.dart';
import 'package:audacity_player/ui/waveform/audacity_waveform_view.dart';

void main() {
  testWidgets('AudacityWaveformView 三段式手势分流测试', (tester) async {
    Duration? seekPos;
    Duration? rangeA;
    Duration? rangeB;

    const widgetHeight = 226.0; // ruler 26, waveformHeight 200: top [26, 76], mid [76, 176], bot [176, 226]
    final segments = [
      const SpeechSegment(start: Duration(seconds: 1), end: Duration(seconds: 3)),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 500,
          height: widgetHeight,
          child: AudacityWaveformView(
            peaks: List.generate(500, (i) => 0.5),
            peaksPerSecond: 50,
            segments: segments,
            totalDuration: const Duration(seconds: 10),
            currentPosition: Duration.zero,
            repeatState: const RepeatState(),
            isPlaying: false,
            onSeek: (pos) => seekPos = pos,
            onRangeSelected: (a, b) {
              rangeA = a;
              rangeB = b;
            },
            onPointAMoved: (_) {},
            onPointBMoved: (_) {},
            onPlayPause: () {},
            onRestart: () {},
          ),
        ),
      ),
    ));

    // 验证左下角模式切换按钮已被移除
    expect(find.byTooltip('拖动'), findsNothing);
    expect(find.byTooltip('划选'), findsNothing);

    // 1. 上 1/4 区域 (Y = 50) 拖拽：平移波形，不触发 onRangeSelected
    final topDragStart = const Offset(100, 50);
    final topDragEnd = const Offset(180, 50);
    final gesture1 = await tester.startGesture(topDragStart);
    await tester.pump(const Duration(milliseconds: 50));
    await gesture1.moveTo(topDragEnd);
    await tester.pump(const Duration(milliseconds: 50));
    await gesture1.up();
    await tester.pump();
    expect(rangeA, isNull);
    expect(rangeB, isNull);

    // 2. 中间 1/2 区域 (Y = 120) 拖拽：划选选区，触发 onRangeSelected
    final midDragStart = const Offset(100, 120);
    final midDragEnd = const Offset(200, 120);
    final gesture2 = await tester.startGesture(midDragStart);
    await tester.pump(const Duration(milliseconds: 50));
    await gesture2.moveTo(midDragEnd);
    await tester.pump(const Duration(milliseconds: 50));
    await gesture2.up();
    await tester.pump();
    expect(rangeA, isNotNull);
    expect(rangeB, isNotNull);

    // 3. 点击测试：在中间区域点击命中句子 (秒数 ~2s，对应 X 约 60px)
    rangeA = null;
    rangeB = null;
    seekPos = null;
    // 当 pixelsPerSecond 为 30(初始): 2s 对应 X = 60
    await tester.tapAt(const Offset(60, 120));
    await tester.pump();
    expect(rangeA, equals(const Duration(seconds: 1)));
    expect(rangeB, equals(const Duration(seconds: 3)));

    // 4. 点击测试：在上部区域 (Y = 50) 点击相同 X 坐标：仅触发 onSeek，不选句
    rangeA = null;
    rangeB = null;
    seekPos = null;
    await tester.tapAt(const Offset(60, 50));
    await tester.pump();
    expect(rangeA, isNull);
    expect(seekPos, isNotNull);
  });
}
```

- [ ] **Step 2: 运行测试验证失败（此时构造函数仍要求 gestureMode 且旧逻辑未改）**

Run: `flutter test test/ui/waveform/audacity_waveform_view_test.dart`
Expected: FAIL (Compilation error: missing gestureMode argument or gesture behavior differences)

- [ ] **Step 3: 修改 `AudacityWaveformView`**

在 `lib/ui/waveform/audacity_waveform_view.dart` 中：
1. 移除 `gestureMode`、`onGestureModeChanged` 字段与导入；
2. 引入内部拖拽行为状态枚举：`enum _DragAction { pan, selectRange }`；
3. 新增辅助方法判断是否处于中间 1/2 选区：
   ```dart
   bool _isInMiddleSelectionZone(double y, double totalHeight) {
     const rulerHeight = 26.0;
     final waveHeight = totalHeight - rulerHeight;
     if (waveHeight <= 0) return false;
     final y1 = rulerHeight + waveHeight * 0.25;
     final y2 = rulerHeight + waveHeight * 0.75;
     return y >= y1 && y <= y2;
   }
   ```
4. 在 `GestureDetector` 的 `onTapUp` 中：
   ```dart
   onTapUp: (details) {
     final target = _xToDuration(details.localPosition.dx, width);
     final inMiddle = _isInMiddleSelectionZone(details.localPosition.dy, constraints.maxHeight);
     final seg = inMiddle ? _segmentAt(target) : null;
     if (seg != null) {
       widget.onRangeSelected(seg.start, seg.end);
     } else {
       widget.onSeek(target);
     }
     _isUserInteracting = false;
     _interactionCooldownTimer?.cancel();
     _checkAndFollowPlayhead(viewportWidth: width);
   },
   ```
5. 在 `onScaleStart` 中判定 `_dragAction`：
   ```dart
   _dragStartX = localX;
   _dragStartScrollOffset = _scrollOffset;
   final localY = details.localFocalPoint.dy;
   if (_isInMiddleSelectionZone(localY, constraints.maxHeight)) {
     _dragAction = _DragAction.selectRange;
   } else {
     _dragAction = _DragAction.pan;
   }
   ```
6. 在 `onScaleUpdate` 的单指逻辑中，根据 `_dragAction` 执行平移或划选：
   ```dart
   if (details.pointerCount == 1 && _dragStartX != null) {
     final currentX = details.localFocalPoint.dx;
     if (_dragAction == _DragAction.pan) {
       final deltaX = currentX - _dragStartX!;
       setState(() {
         _scrollOffset = ((_dragStartScrollOffset ?? _scrollOffset) - deltaX).clamp(0.0, _maxScroll(width));
       });
     } else {
       final p1 = _snapToBoundary(_xToDuration(_dragStartX!, width));
       final p2 = _snapToBoundary(_xToDuration(currentX, width));
       widget.onRangeSelected(p1, p2);
     }
   }
   ```
7. 移除左下角模式切换悬浮小部件（`// 悬浮手势模式切换 (靠左，与右侧快捷按钮同高)` 对应的 `Positioned` 整个块）。

- [ ] **Step 4: 运行新测试验证**

Run: `flutter test test/ui/waveform/audacity_waveform_view_test.dart`
Expected: PASS

- [ ] **Step 5: 提交改动**

```bash
git add lib/ui/waveform/audacity_waveform_view.dart test/ui/waveform/audacity_waveform_view_test.dart
git commit -m "feat(waveform): implement 3-zone gesture handling and remove mode switcher buttons"
```

---

### Task 3: 协同清理 - 更新 `PlayerScreen`、清理不再使用的属性与相关测试

**Files:**
- Modify: `lib/ui/player_screen.dart`
- Modify: `test/widget_test.dart`
- Modify: `CLAUDE.md`

- [ ] **Step 1: 检查 `PlayerScreen` 中残留的 `_gestureMode`**

在 `lib/ui/player_screen.dart` 中：
1. 移除 `WaveformGestureMode _gestureMode = WaveformGestureMode.drag;`；
2. 移除传递给 `AudacityWaveformView` 的 `gestureMode` 与 `onGestureModeChanged`；
3. 检查是否有未使用的 import。

- [ ] **Step 2: 更新 `test/widget_test.dart`**

在 `test/widget_test.dart` 中：
移除对已删除的 `find.byTooltip('拖动')` 与 `find.byTooltip('划选')` 的查找和点击测试，替换为验证波形图和 A-B 状态正常加载：
```dart
    // 验证核心组件均正常渲染
    expect(find.text('打开音频'), findsOneWidget);
    expect(find.text('设A点'), findsOneWidget);
    expect(find.text('设B点'), findsOneWidget);
    expect(find.text('清除'), findsOneWidget);

    // 验证模式切换按钮已移除，无需频繁切换
    expect(find.byTooltip('拖动'), findsNothing);
    expect(find.byTooltip('划选'), findsNothing);

    // 确保绝对没有任何 RenderFlex 溢出
    expect(overflowDetails, isNull);
```

- [ ] **Step 3: 更新 `CLAUDE.md` 相关章节**

在 `CLAUDE.md` 中：
更新 `2.2 触控手势模式切换` 为 `2.2 触控手势三段式分区与 A-B 划选融合`，说明中间 1/2 为划选区（半透明黄色蒙层提示），上下各 1/4 为始终平移拖动区，移除旧的模式切换按钮。

- [ ] **Step 4: 运行静态分析与全量测试**

Run: `flutter analyze`
Expected: 0 issues found

Run: `flutter test test/ui/waveform/audacity_waveform_view_test.dart test/ui/waveform_subtitles_test.dart test/widget_test.dart`
Expected: All tests pass

- [ ] **Step 5: 提交改动**

```bash
git add lib/ui/player_screen.dart test/widget_test.dart CLAUDE.md
git commit -m "refactor(player): remove gestureMode from PlayerScreen, update smoke tests and docs"
```

---

### Task 4: 端到端验证与清理

**Files:**
- Test: All tests

- [ ] **Step 1: 运行全量测试套件确认无回归**

Run: `flutter test test/widget_test.dart test/ui/waveform/audacity_waveform_view_test.dart test/ui/waveform_subtitles_test.dart test/controllers/ab_repeat_controller_test.dart test/models/repeat_state_test.dart`
Expected: All pass

- [ ] **Step 2: 运行代码静态检查**

Run: `flutter analyze`
Expected: No issues found!

- [ ] **Step 3: 检查 git status 保持整洁**

Run: `git status`
Expected: Clean working tree
