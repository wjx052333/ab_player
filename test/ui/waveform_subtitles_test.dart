import 'package:audacity_player/models/repeat_state.dart';
import 'package:audacity_player/models/subtitle_sentence.dart';
import 'package:audacity_player/ui/waveform/audacity_waveform_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('字幕直接画在波形上：窄区间、长文本、视口外句子都不抛异常', (tester) async {
    final painter = AudacityWaveformPainter(
      peaks: List.generate(1000, (i) => (i % 10) / 10),
      peaksPerSecond: 100,
      subtitles: const [
        SubtitleSentence(Duration(seconds: 1), Duration(seconds: 4), 'It is a very long sentence that needs many lines to be shown in full on the waveform.'),
        SubtitleSentence(Duration(seconds: 4), Duration(milliseconds: 4050), 'tiny'),
        SubtitleSentence(Duration(seconds: 100), Duration(seconds: 104), 'off screen'),
      ],
      totalDuration: const Duration(seconds: 10),
      currentPosition: const Duration(seconds: 2),
      repeatState: const RepeatState(),
      scrollOffset: 0,
      pixelsPerSecond: 60,
    );
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(width: 600, height: 120, child: CustomPaint(painter: painter)),
    ));
    expect(tester.takeException(), isNull);
  });

  test('shouldRepaint 在字幕变化时返回 true', () {
    AudacityWaveformPainter make(List<SubtitleSentence> s) => AudacityWaveformPainter(
          peaks: const [],
          subtitles: s,
          totalDuration: Duration.zero,
          currentPosition: Duration.zero,
          repeatState: const RepeatState(),
          scrollOffset: 0,
          pixelsPerSecond: 30,
        );
    expect(make(const []).shouldRepaint(make(const [SubtitleSentence(Duration.zero, Duration(seconds: 1), 'a')])), isTrue);
  });

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
    ));
    expect(tester.takeException(), isNull);
  });
}
