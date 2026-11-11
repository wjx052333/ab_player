import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/repeat_state.dart';
import 'audacity_waveform_painter.dart';

class AudacityWaveformView extends StatefulWidget {
  final List<double> peaks;
  final Duration totalDuration;
  final Duration currentPosition;
  final RepeatState repeatState;
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
    required this.onSeek,
    required this.onRangeSelected,
    required this.onPointAMoved,
    required this.onPointBMoved,
  });

  @override
  State<AudacityWaveformView> createState() => _AudacityWaveformViewState();
}

class _AudacityWaveformViewState extends State<AudacityWaveformView> {
  double _pixelsPerSecond = 50.0; // 默认缩放级别
  double _scrollOffset = 0.0;

  double? _dragStartX;
  int? _activeHandle; // 1: A, 2: B

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
              },
              onScaleStart: (details) {
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
              },
              onScaleUpdate: (details) {
                // 1. 如果在拖动手柄
                if (_activeHandle == 1) {
                  final pos = _xToDuration(details.localFocalPoint.dx, width);
                  widget.onPointAMoved(pos);
                  return;
                } else if (_activeHandle == 2) {
                  final pos = _xToDuration(details.localFocalPoint.dx, width);
                  widget.onPointBMoved(pos);
                  return;
                }

                // 2. 双指缩放
                if (details.scale != 1.0) {
                  setState(() {
                    _pixelsPerSecond = (_pixelsPerSecond * details.scale).clamp(10.0, 300.0);
                    _scrollOffset = _scrollOffset.clamp(0.0, _maxScroll(width));
                  });
                  return;
                }

                // 3. 拖拽滚动 / 选区
                if (details.pointerCount == 1 && _dragStartX != null) {
                  final currentX = details.localFocalPoint.dx;
                  final p1 = _xToDuration(_dragStartX!, width);
                  final p2 = _xToDuration(currentX, width);
                  widget.onRangeSelected(p1, p2);
                } else if (details.pointerCount == 2) {
                  // 双指平移
                  setState(() {
                    _scrollOffset = (_scrollOffset - details.focalPointDelta.dx).clamp(0.0, _maxScroll(width));
                  });
                }
              },
              onScaleEnd: (details) {
                _dragStartX = null;
                _activeHandle = null;
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
