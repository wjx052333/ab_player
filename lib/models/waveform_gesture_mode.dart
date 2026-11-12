enum WaveformGestureMode {
  drag,
  select;

  bool get isDrag => this == WaveformGestureMode.drag;
  bool get isSelect => this == WaveformGestureMode.select;

  String get label {
    switch (this) {
      case WaveformGestureMode.drag:
        return '拖动';
      case WaveformGestureMode.select:
        return '划选';
    }
  }
}
