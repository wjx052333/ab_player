class RepeatState {
  final Duration? pointA;
  final Duration? pointB;
  final bool isWaitingInterval;
  final int pauseSeconds;
  final int remainingLoops; // -1 表示无限循环
  final double playbackSpeed;

  const RepeatState({
    this.pointA,
    this.pointB,
    this.isWaitingInterval = false,
    this.pauseSeconds = 0,
    this.remainingLoops = -1,
    this.playbackSpeed = 1.0,
  });

  factory RepeatState.initial() => const RepeatState();

  bool get isActive => pointA != null && pointB != null && isValidInterval;

  bool get isValidInterval {
    if (pointA == null || pointB == null) return false;
    final diff = pointB!.inMilliseconds - pointA!.inMilliseconds;
    return diff >= 200; // 最小 200ms
  }

  Duration get duration {
    if (!isValidInterval) return Duration.zero;
    return pointB! - pointA!;
  }

  RepeatState setPointA(Duration a) {
    if (pointB != null && a > pointB!) {
      return copyWith(pointA: pointB, pointB: a);
    }
    return copyWith(pointA: a);
  }

  RepeatState setPointB(Duration b) {
    if (pointA != null && b < pointA!) {
      return copyWith(pointA: b, pointB: pointA);
    }
    return copyWith(pointB: b);
  }

  factory RepeatState.fromRange(Duration p1, Duration p2) {
    final start = p1 < p2 ? p1 : p2;
    final end = p1 < p2 ? p2 : p1;
    return RepeatState(pointA: start, pointB: end);
  }

  RepeatState copyWith({
    Duration? pointA,
    Duration? pointB,
    bool? isWaitingInterval,
    int? pauseSeconds,
    int? remainingLoops,
    double? playbackSpeed,
    bool clearPoints = false,
  }) {
    return RepeatState(
      pointA: clearPoints ? null : (pointA ?? this.pointA),
      pointB: clearPoints ? null : (pointB ?? this.pointB),
      isWaitingInterval: isWaitingInterval ?? this.isWaitingInterval,
      pauseSeconds: pauseSeconds ?? this.pauseSeconds,
      remainingLoops: remainingLoops ?? this.remainingLoops,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
    );
  }
}
