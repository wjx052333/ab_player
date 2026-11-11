import 'package:flutter_test/flutter_test.dart';
import 'package:audacity_player/ui/waveform/time_ruler_helper.dart';

void main() {
  group('TimeRulerHelper Tests', () {
    test('格式化毫秒为 Audacity 经典格式', () {
      expect(TimeRulerHelper.formatTime(const Duration(seconds: 5)), '00:05.0');
      expect(TimeRulerHelper.formatTime(const Duration(minutes: 1, seconds: 23, milliseconds: 450)), '01:23.4');
    });

    test('根据缩放比例自适应选择合适刻度步长', () {
      final stepLowZoom = TimeRulerHelper.calculateMajorStep(pixelsPerSecond: 20);
      expect(stepLowZoom.inSeconds >= 5, isTrue);

      final stepHighZoom = TimeRulerHelper.calculateMajorStep(pixelsPerSecond: 200);
      expect(stepHighZoom.inSeconds <= 1, isTrue);
    });
  });
}
