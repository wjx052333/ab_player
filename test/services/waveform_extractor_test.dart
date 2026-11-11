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
