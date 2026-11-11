class TimeRulerHelper {
  static String formatTime(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final tenths = (d.inMilliseconds.remainder(1000) / 100).floor();
    return '$minutes:$seconds.$tenths';
  }

  static Duration calculateMajorStep({required double pixelsPerSecond}) {
    if (pixelsPerSecond >= 150) {
      return const Duration(milliseconds: 500);
    } else if (pixelsPerSecond >= 80) {
      return const Duration(seconds: 1);
    } else if (pixelsPerSecond >= 40) {
      return const Duration(seconds: 2);
    } else if (pixelsPerSecond >= 20) {
      return const Duration(seconds: 5);
    } else {
      return const Duration(seconds: 10);
    }
  }
}
