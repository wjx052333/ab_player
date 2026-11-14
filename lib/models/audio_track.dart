import 'speech_segment.dart';
import 'subtitle_sentence.dart';

class AudioTrack {
  final String path;
  final String title;
  final Duration duration;
  final List<double> peaks; // 归一化波峰数组 [0.0 ~ 1.0]
  final double peaksPerSecond; // peaks 的时间密度 (点/秒)
  final List<SpeechSegment> segments; // 自动检测出的说话区间 (句子)
  final List<SubtitleSentence> subtitles; // MP3 内嵌字幕，没有则为空

  const AudioTrack({
    required this.path,
    required this.title,
    required this.duration,
    required this.peaks,
    this.peaksPerSecond = 0,
    this.segments = const [],
    this.subtitles = const [],
  });

  factory AudioTrack.empty() => const AudioTrack(
        path: '',
        title: '未选择音频',
        duration: Duration.zero,
        peaks: [],
      );
}
