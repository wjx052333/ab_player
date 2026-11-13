import 'dart:math';
import '../models/speech_segment.dart';

/// 基于响度包络的断句检测：低于阈值且持续足够久的静音即视为句间停顿
class SpeechSegmenter {
  /// 静音阈值占「高响度」(95 分位) 的比例；调大则更多弱音被判为停顿，断得更细
  final double thresholdRatio;

  /// 短于该时长的静音不算断句 (词间气口)
  final Duration minSilence;

  /// 短于该时长的声音块视为噪声丢弃
  final Duration minSpeech;

  /// 每段首尾向外扩的余量，避免切掉词头词尾
  final Duration padding;

  const SpeechSegmenter({
    this.thresholdRatio = 0.12,
    this.minSilence = const Duration(milliseconds: 150),
    this.minSpeech = const Duration(milliseconds: 150),
    this.padding = const Duration(milliseconds: 40),
  });

  SpeechSegmenter copyWith({
    double? thresholdRatio,
    Duration? minSilence,
    Duration? minSpeech,
    Duration? padding,
  }) =>
      SpeechSegmenter(
        thresholdRatio: thresholdRatio ?? this.thresholdRatio,
        minSilence: minSilence ?? this.minSilence,
        minSpeech: minSpeech ?? this.minSpeech,
        padding: padding ?? this.padding,
      );

  /// [peaks] 为归一化响度包络，[peaksPerSecond] 为每秒采样点数
  List<SpeechSegment> detect(List<double> peaks, double peaksPerSecond) {
    if (peaks.length < 2 || peaksPerSecond <= 0) return [];

    final sorted = List<double>.of(peaks)..sort();
    final floor = sorted[(sorted.length * 0.10).floor()];
    final loud = sorted[min(sorted.length - 1, (sorted.length * 0.95).floor())];
    if (loud <= 0) return [];
    // 阈值取「底噪的 2.5 倍」与「高响度 × thresholdRatio」中较大者，并保证低于高响度
    final threshold = min(max(floor * 2.5, loud * thresholdRatio), loud * 0.5);

    int toFrames(Duration d) => max(1, (d.inMicroseconds * peaksPerSecond / 1e6).round());
    final minSilenceF = toFrames(minSilence);
    final minSpeechF = toFrames(minSpeech);

    // 1. 阈值二值化 -> 连续声音块 [start, end)
    final blocks = <List<int>>[];
    int? start;
    for (var i = 0; i < peaks.length; i++) {
      final isVoice = peaks[i] > threshold;
      if (isVoice && start == null) start = i;
      if (!isVoice && start != null) {
        blocks.add([start, i]);
        start = null;
      }
    }
    if (start != null) blocks.add([start, peaks.length]);

    // 2. 间隔不足 minSilence 的声音块合并
    final merged = <List<int>>[];
    for (final b in blocks) {
      if (merged.isNotEmpty && b[0] - merged.last[1] < minSilenceF) {
        merged.last[1] = b[1];
      } else {
        merged.add([b[0], b[1]]);
      }
    }

    // 3. 丢弃过短的块，换算成时间并加余量
    Duration toTime(int frame) => Duration(microseconds: (frame / peaksPerSecond * 1e6).round());
    final total = toTime(peaks.length);
    return [
      for (final b in merged)
        if (b[1] - b[0] >= minSpeechF)
          SpeechSegment(
            _clamp(toTime(b[0]) - padding, Duration.zero, total),
            _clamp(toTime(b[1]) + padding, Duration.zero, total),
          ),
    ];
  }

  Duration _clamp(Duration d, Duration lo, Duration hi) => d < lo ? lo : (d > hi ? hi : d);
}
