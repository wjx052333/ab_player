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
      const SpeechSegment(Duration(seconds: 1), Duration(seconds: 3)),
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
