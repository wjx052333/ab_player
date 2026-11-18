import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/repeat_state.dart';
import '../../models/speech_segment.dart';
import '../../models/subtitle_sentence.dart';
import '../controls/mini_icon_button.dart';
import 'audacity_waveform_painter.dart';

enum _DragAction { pan, selectRange }

class AudacityWaveformView extends StatefulWidget {
  final List<double> peaks;
  final double peaksPerSecond;
  final List<SpeechSegment> segments;
  final List<SubtitleSentence> subtitles;
  final Duration totalDuration;
  final Duration currentPosition;
  final RepeatState repeatState;
  final bool isPlaying;
  final Function(Duration) onSeek;
  final Function(Duration, Duration) onRangeSelected;
  final Function(Duration) onPointAMoved;
  final Function(Duration) onPointBMoved;
  final VoidCallback onPlayPause;
  final VoidCallback onRestart;

  const AudacityWaveformView({
    super.key,
    required this.peaks,
    this.peaksPerSecond = 0,
    this.segments = const [],
    this.subtitles = const [],
    required this.totalDuration,
    required this.currentPosition,
    required this.repeatState,
    required this.isPlaying,
    required this.onSeek,
    required this.onRangeSelected,
    required this.onPointAMoved,
    required this.onPointBMoved,
    required this.onPlayPause,
    required this.onRestart,
  });

  @override
  State<AudacityWaveformView> createState() => _AudacityWaveformViewState();
}

class _AudacityWaveformViewState extends State<AudacityWaveformView> {
  double _pixelsPerSecond = 30.0;
  double _scrollOffset = 0.0;

  double? _dragStartX;
  double? _dragStartScrollOffset;
  _DragAction? _dragAction;
  int? _activeHandle; // 1: A, 2: B

  bool _isUserInteracting = false;
  Timer? _interactionCooldownTimer;

  @override
  void didUpdateWidget(covariant AudacityWaveformView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 播放中且用户未在触控交互时，检查是否需要跟随
    if (widget.isPlaying && !_isUserInteracting) {
      _checkAndFollowPlayhead();
    }
  }

  /// 最小缩放比例：计算刚好占满视口宽度的 PPS，不能再缩小
  double _minPixelsPerSecond(double width) {
    final totalSec = widget.totalDuration.inMilliseconds / 1000.0;
    if (totalSec <= 0 || width <= 0) return 10.0;
    return max(5.0, width / totalSec);
  }

  /// 判断 A-B 选区是否都在当前屏幕可视范围内
  bool _isSelectionFullyVisible(double width) {
    if (!widget.repeatState.isActive ||
        widget.repeatState.pointA == null ||
        widget.repeatState.pointB == null) {
      return false;
    }

    final aSec = widget.repeatState.pointA!.inMilliseconds / 1000.0;
    final bSec = widget.repeatState.pointB!.inMilliseconds / 1000.0;

    final ax = aSec * _pixelsPerSecond - _scrollOffset;
    final bx = bSec * _pixelsPerSecond - _scrollOffset;

    // 两端都在屏幕可见宽度内（预留少许安全边距）
    return ax >= -5 && bx <= width + 5;
  }

  void _checkAndFollowPlayhead({double? viewportWidth}) {
    final width = viewportWidth ?? (context.findRenderObject() as RenderBox?)?.size.width ?? 0;
    if (width <= 0) return;

    // 如果 A-B 选区完全在当前屏幕视野内，锁定波形静止，不跟随滚动
    if (_isSelectionFullyVisible(width)) {
      return;
    }

    _centerPlayhead(viewportWidth: width);
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

  /// 以当前光标（Playhead）为视觉锚点进行缩放
  void _zoomAroundPlayhead(double factor, double width) {
    final minPPS = _minPixelsPerSecond(width);
    const maxPPS = 300.0;

    final newPPS = (_pixelsPerSecond * factor).clamp(minPPS, maxPPS);
    if ((newPPS - _pixelsPerSecond).abs() < 0.001) return;

    final currentSec = widget.currentPosition.inMilliseconds / 1000.0;
    final oldPlayheadScreenX = currentSec * _pixelsPerSecond - _scrollOffset;

    // 如果光标在视口范围内，以光标屏幕横坐标为锚点；否则以视口正中央为锚点
    final anchorScreenX = (oldPlayheadScreenX >= 0 && oldPlayheadScreenX <= width)
        ? oldPlayheadScreenX
        : (width / 2);

    final newScroll = currentSec * newPPS - anchorScreenX;
    final newMaxScroll = max(0.0, (widget.totalDuration.inMilliseconds / 1000.0) * newPPS - width);

    setState(() {
      _pixelsPerSecond = newPPS;
      _scrollOffset = newScroll.clamp(0.0, newMaxScroll);
    });
  }

  Duration _xToDuration(double x, double width) {
    final clampedX = (x + _scrollOffset).clamp(0.0, _maxScroll(width) + width);
    final seconds = clampedX / _pixelsPerSecond;
    return Duration(milliseconds: (seconds * 1000).toInt());
  }

  SpeechSegment? _segmentAt(Duration t) {
    for (final seg in widget.segments) {
      if (seg.contains(t)) return seg;
    }
    return null;
  }

  /// 吸附距离：屏幕上 10px 对应的时长，但不超过 300ms
  Duration get _snapRadius {
    final ms = (10 / _pixelsPerSecond * 1000).clamp(0.0, 300.0);
    return Duration(milliseconds: ms.round());
  }

  /// 靠近句子起止点时吸附过去，使切出的区间贴着断句、不截断单词
  Duration _snapToBoundary(Duration t) {
    Duration best = t;
    var bestDist = _snapRadius;
    for (final seg in widget.segments) {
      for (final edge in [seg.start, seg.end]) {
        final d = Duration(microseconds: (edge - t).inMicroseconds.abs());
        if (d <= bestDist) {
          best = edge;
          bestDist = d;
        }
      }
    }
    return best;
  }

  double _maxScroll(double width) {
    final totalWidth = (widget.totalDuration.inMilliseconds / 1000.0) * _pixelsPerSecond;
    return max(0.0, totalWidth - width);
  }

  /// 判断 Y 坐标是否落在中间 1/2 A-B 划选区域内
  bool _isInMiddleSelectionZone(double y, double totalHeight) {
    const rulerHeight = 26.0;
    final waveHeight = totalHeight - rulerHeight;
    if (waveHeight <= 0) return false;
    final y1 = rulerHeight + waveHeight * 0.25;
    final y2 = rulerHeight + waveHeight * 0.75;
    return y >= y1 && y <= y2;
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
        final height = constraints.maxHeight;
        final minPPS = _minPixelsPerSecond(width);
        final canZoomOut = _pixelsPerSecond > minPPS + 0.5;
        final canZoomIn = _pixelsPerSecond < 300.0 - 0.5;

        return Stack(
          children: [
            GestureDetector(
              onTapUp: (details) {
                final target = _xToDuration(details.localPosition.dx, width);
                final inMiddle = _isInMiddleSelectionZone(details.localPosition.dy, height);
                // 仅在中间 1/2 划选区域点中某个句子时：直接把 A-B 设成该句边界；其他位置统一 Seek
                final seg = inMiddle ? _segmentAt(target) : null;
                if (seg != null) {
                  widget.onRangeSelected(seg.start, seg.end);
                } else {
                  widget.onSeek(target);
                }
                // 点击跳转后立即响应
                _isUserInteracting = false;
                _interactionCooldownTimer?.cancel();
                _checkAndFollowPlayhead(viewportWidth: width);
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

                // 判断单指拖拽类型：中间 1/2 为划选 A-B，上下各 1/4 为平移波形
                final localY = details.localFocalPoint.dy;
                if (_isInMiddleSelectionZone(localY, height)) {
                  _dragAction = _DragAction.selectRange;
                } else {
                  _dragAction = _DragAction.pan;
                }
              },
              onScaleUpdate: (details) {
                // 1. 如果在拖动手柄 (A/B 把手微调优先级最高)
                if (_activeHandle == 1) {
                  final pos = _snapToBoundary(_xToDuration(details.localFocalPoint.dx, width));
                  widget.onPointAMoved(pos);
                  return;
                } else if (_activeHandle == 2) {
                  final pos = _snapToBoundary(_xToDuration(details.localFocalPoint.dx, width));
                  widget.onPointBMoved(pos);
                  return;
                }

                // 2. 双指捏合缩放 (以手势焦点为锚点)
                if (details.scale != 1.0) {
                  final focalX = details.localFocalPoint.dx;
                  final timeAtFocal = (focalX + _scrollOffset) / _pixelsPerSecond;

                  final newPPS = (_pixelsPerSecond * details.scale).clamp(minPPS, 300.0);
                  final newScroll = timeAtFocal * newPPS - focalX;
                  final newMaxScroll = max(0.0, (widget.totalDuration.inMilliseconds / 1000.0) * newPPS - width);

                  setState(() {
                    _pixelsPerSecond = newPPS;
                    _scrollOffset = newScroll.clamp(0.0, newMaxScroll);
                  });
                  return;
                }

                // 3. 单指操作：根据按下位置所在区域分流
                if (details.pointerCount == 1 && _dragStartX != null) {
                  final currentX = details.localFocalPoint.dx;

                  if (_dragAction == _DragAction.pan) {
                    // 上下 1/4 区域：平移波形
                    final deltaX = currentX - _dragStartX!;
                    setState(() {
                      _scrollOffset = ((_dragStartScrollOffset ?? _scrollOffset) - deltaX).clamp(0.0, _maxScroll(width));
                    });
                  } else {
                    // 中间 1/2 区域：拉出 A-B 选区
                    final p1 = _snapToBoundary(_xToDuration(_dragStartX!, width));
                    final p2 = _snapToBoundary(_xToDuration(currentX, width));
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
                _dragAction = null;
                _activeHandle = null;

                // 松手 1.5 秒后平滑恢复播放跟随 (若 A-B 不在全屏内)
                _interactionCooldownTimer?.cancel();
                _interactionCooldownTimer = Timer(const Duration(milliseconds: 1500), () {
                  if (mounted) {
                    _isUserInteracting = false;
                    if (widget.isPlaying) {
                      _checkAndFollowPlayhead(viewportWidth: width);
                    }
                  }
                });
              },
              child: CustomPaint(
                size: Size(width, constraints.maxHeight),
                painter: AudacityWaveformPainter(
                  peaks: widget.peaks,
                  peaksPerSecond: widget.peaksPerSecond,
                  segments: widget.segments,
                  subtitles: widget.subtitles,
                  totalDuration: widget.totalDuration,
                  currentPosition: widget.currentPosition,
                  repeatState: widget.repeatState,
                  scrollOffset: _scrollOffset,
                  pixelsPerSecond: _pixelsPerSecond,
                ),
              ),
            ),

            // 悬浮快捷按钮：播放/暂停、从头播放、缩放 (缩放以光标为中心，缩小到充满屏幕即止)
            Positioned(
              right: 12,
              bottom: 8,
              child: Row(
                children: [
                  MiniIconButton(
                    icon: widget.isPlaying ? Icons.pause : Icons.play_arrow,
                    tooltip: widget.isPlaying ? '暂停' : '播放',
                    onPressed: widget.onPlayPause,
                  ),
                  const SizedBox(width: 6),
                  MiniIconButton(icon: Icons.replay, tooltip: '从头播放', onPressed: widget.onRestart),
                  const SizedBox(width: 14),
                  MiniIconButton(
                    icon: Icons.zoom_in,
                    onPressed: canZoomIn ? () => _zoomAroundPlayhead(1.3, width) : null,
                  ),
                  const SizedBox(width: 6),
                  MiniIconButton(
                    icon: Icons.zoom_out,
                    onPressed: canZoomOut ? () => _zoomAroundPlayhead(1 / 1.3, width) : null,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

}
