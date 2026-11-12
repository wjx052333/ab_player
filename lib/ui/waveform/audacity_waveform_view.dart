import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/repeat_state.dart';
import '../../models/waveform_gesture_mode.dart';
import 'audacity_waveform_painter.dart';

class AudacityWaveformView extends StatefulWidget {
  final List<double> peaks;
  final Duration totalDuration;
  final Duration currentPosition;
  final RepeatState repeatState;
  final bool isPlaying;
  final WaveformGestureMode gestureMode;
  final Function(Duration) onSeek;
  final Function(Duration, Duration) onRangeSelected;
  final Function(Duration) onPointAMoved;
  final Function(Duration) onPointBMoved;

  const AudacityWaveformView({
    super.key,
    required this.peaks,
    required this.totalDuration,
    required this.currentPosition,
    required this.repeatState,
    required this.isPlaying,
    required this.gestureMode,
    required this.onSeek,
    required this.onRangeSelected,
    required this.onPointAMoved,
    required this.onPointBMoved,
  });

  @override
  State<AudacityWaveformView> createState() => _AudacityWaveformViewState();
}

class _AudacityWaveformViewState extends State<AudacityWaveformView> {
  double _pixelsPerSecond = 50.0;
  double _scrollOffset = 0.0;

  double? _dragStartX;
  double? _dragStartScrollOffset;
  int? _activeHandle; // 1: A, 2: B

  bool _isUserInteracting = false;
  Timer? _interactionCooldownTimer;

  @override
  void didUpdateWidget(covariant AudacityWaveformView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 播放中且用户未在触控交互时，波形居中跟随播放指针
    if (widget.isPlaying && !_isUserInteracting) {
      _centerPlayhead();
    }
  }

  void _centerPlayhead({double? viewportWidth}) {
    final width = viewportWidth ?? (context.findRenderObject() as RenderBox?)?.size.width ?? 0;
    if (width <= 0) return;

    final currentSec = widget.currentPosition.inMilliseconds / 1000.0;
    final playheadX = currentSec * _pixelsPerSecond;
    final targetScroll = playheadX - (width / 2);

    setState(() {
      _scrollOffset = targetScroll.clamp(0.0, _maxScroll(width));
    });
  }

  Duration _xToDuration(double x, double width) {
    final clampedX = (x + _scrollOffset).clamp(0.0, _maxScroll(width) + width);
    final seconds = clampedX / _pixelsPerSecond;
    return Duration(milliseconds: (seconds * 1000).toInt());
  }

  double _maxScroll(double width) {
    final totalWidth = (widget.totalDuration.inMilliseconds / 1000.0) * _pixelsPerSecond;
    return max(0.0, totalWidth - width);
  }

  @override
  void dispose() {
    _interactionCooldownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        return Stack(
          children: [
            GestureDetector(
              onTapUp: (details) {
                final target = _xToDuration(details.localPosition.dx, width);
                widget.onSeek(target);
                // 点击跳转后立即恢复居中
                _isUserInteracting = false;
                _interactionCooldownTimer?.cancel();
                _centerPlayhead(viewportWidth: width);
              },
              onScaleStart: (details) {
                _isUserInteracting = true;
                _interactionCooldownTimer?.cancel();

                final localX = details.localFocalPoint.dx;
                // 检测是否命中 A 或 B 把手 (热区 36px)
                if (widget.repeatState.pointA != null) {
                  final ax = (widget.repeatState.pointA!.inMilliseconds / 1000.0) * _pixelsPerSecond - _scrollOffset;
                  if ((localX - ax).abs() < 24) {
                    _activeHandle = 1;
                    return;
                  }
                }
                if (widget.repeatState.pointB != null) {
                  final bx = (widget.repeatState.pointB!.inMilliseconds / 1000.0) * _pixelsPerSecond - _scrollOffset;
                  if ((localX - bx).abs() < 24) {
                    _activeHandle = 2;
                    return;
                  }
                }
                _dragStartX = localX;
                _dragStartScrollOffset = _scrollOffset;
              },
              onScaleUpdate: (details) {
                // 1. 如果在拖动手柄 (A/B 把手微调优先级最高)
                if (_activeHandle == 1) {
                  final pos = _xToDuration(details.localFocalPoint.dx, width);
                  widget.onPointAMoved(pos);
                  return;
                } else if (_activeHandle == 2) {
                  final pos = _xToDuration(details.localFocalPoint.dx, width);
                  widget.onPointBMoved(pos);
                  return;
                }

                // 2. 双指捏合缩放
                if (details.scale != 1.0) {
                  setState(() {
                    _pixelsPerSecond = (_pixelsPerSecond * details.scale).clamp(10.0, 300.0);
                    _scrollOffset = _scrollOffset.clamp(0.0, _maxScroll(width));
                  });
                  return;
                }

                // 3. 单指操作：根据当前手势模式分流
                if (details.pointerCount == 1 && _dragStartX != null) {
                  final currentX = details.localFocalPoint.dx;

                  if (widget.gestureMode.isDrag) {
                    // ✋ 拖动模式：平移波形
                    final deltaX = currentX - _dragStartX!;
                    setState(() {
                      _scrollOffset = ((_dragStartScrollOffset ?? _scrollOffset) - deltaX).clamp(0.0, _maxScroll(width));
                    });
                  } else {
                    // ✂️ 划选模式：拉出 A-B 选区
                    final p1 = _xToDuration(_dragStartX!, width);
                    final p2 = _xToDuration(currentX, width);
                    widget.onRangeSelected(p1, p2);
                  }
                } else if (details.pointerCount == 2) {
                  // 双指拖拽平移
                  setState(() {
                    _scrollOffset = (_scrollOffset - details.focalPointDelta.dx).clamp(0.0, _maxScroll(width));
                  });
                }
              },
              onScaleEnd: (details) {
                _dragStartX = null;
                _dragStartScrollOffset = null;
                _activeHandle = null;

                // 松手 1.5 秒后平滑恢复播放居中跟随
                _interactionCooldownTimer?.cancel();
                _interactionCooldownTimer = Timer(const Duration(milliseconds: 1500), () {
                  if (mounted) {
                    _isUserInteracting = false;
                    if (widget.isPlaying) {
                      _centerPlayhead(viewportWidth: width);
                    }
                  }
                });
              },
              child: CustomPaint(
                size: Size(width, constraints.maxHeight),
                painter: AudacityWaveformPainter(
                  peaks: widget.peaks,
                  totalDuration: widget.totalDuration,
                  currentPosition: widget.currentPosition,
                  repeatState: widget.repeatState,
                  scrollOffset: _scrollOffset,
                  pixelsPerSecond: _pixelsPerSecond,
                ),
              ),
            ),

            // 悬浮缩放快捷按钮
            Positioned(
              right: 12,
              bottom: 8,
              child: Row(
                children: [
                  _miniButton(Icons.zoom_in, () {
                    setState(() => _pixelsPerSecond = (_pixelsPerSecond * 1.3).clamp(10.0, 300.0));
                  }),
                  const SizedBox(width: 6),
                  _miniButton(Icons.zoom_out, () {
                    setState(() => _pixelsPerSecond = (_pixelsPerSecond / 1.3).clamp(10.0, 300.0));
                  }),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _miniButton(IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(153),
        borderRadius: BorderRadius.circular(4),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white70, size: 18),
        onPressed: onPressed,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        padding: EdgeInsets.zero,
      ),
    );
  }
}
