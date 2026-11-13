/// 一段连续的说话区间 (相邻两段之间即为句间停顿)
class SpeechSegment {
  final Duration start;
  final Duration end;

  const SpeechSegment(this.start, this.end);

  Duration get length => end - start;

  bool contains(Duration t) => t >= start && t <= end;
}
