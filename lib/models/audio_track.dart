class AudioTrack {
  final String path;
  final String title;
  final Duration duration;
  final List<double> peaks; // 归一化波峰数组 [0.0 ~ 1.0]

  const AudioTrack({
    required this.path,
    required this.title,
    required this.duration,
    required this.peaks,
  });

  factory AudioTrack.empty() => const AudioTrack(
        path: '',
        title: '未选择音频',
        duration: Duration.zero,
        peaks: [],
      );
}
