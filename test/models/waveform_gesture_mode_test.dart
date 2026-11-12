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

    test('提供易读的中文标签与说明', () {
      expect(WaveformGestureMode.drag.label, '拖动');
      expect(WaveformGestureMode.select.label, '划选');
    });
  });
}
