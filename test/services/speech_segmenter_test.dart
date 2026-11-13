import 'package:flutter_test/flutter_test.dart';
import 'package:audacity_player/services/speech_segmenter.dart';

void main() {
  // 100 点/秒：0-1s 说话，1-1.6s 静音，1.6-3s 说话，3-3.1s 静音，3.1-4s 说话
  List<double> build() => [
        for (var i = 0; i < 400; i++)
          if ((i >= 100 && i < 160) || (i >= 300 && i < 310)) 0.01 else 0.8,
      ];

  test('长静音处断句，短于 minSilence 的气口不拆开', () {
    final segs = const SpeechSegmenter().detect(build(), 100);
    expect(segs.length, 2);
    expect(segs[0].end.inMilliseconds, closeTo(1040, 20));
    expect(segs[1].start.inMilliseconds, closeTo(1560, 20));
    expect(segs[1].end.inMilliseconds, closeTo(4000, 20));
  });

  test('空数据与全静音返回空列表', () {
    expect(const SpeechSegmenter().detect([], 100), isEmpty);
    expect(const SpeechSegmenter().detect(List.filled(200, 0.0), 100), isEmpty);
  });
}
