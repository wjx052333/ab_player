import 'dart:math';
import 'package:flutter/material.dart';
import '../audacity_theme.dart';
import '../../models/repeat_state.dart';
import 'time_ruler_helper.dart';

class AudacityWaveformPainter extends CustomPainter {
  final List<double> peaks;
  final Duration totalDuration;
  final Duration currentPosition;
  final RepeatState repeatState;
  final double scrollOffset;
  final double pixelsPerSecond;

  AudacityWaveformPainter({
    required this.peaks,
    required this.totalDuration,
    required this.currentPosition,
    required this.repeatState,
    required this.scrollOffset,
    required this.pixelsPerSecond,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const rulerHeight = 26.0;
    final waveformHeight = size.height - rulerHeight;
    final centerY = rulerHeight + waveformHeight / 2;

    // 1. 绘制标尺背景与波形背景
    final bgPaint = Paint()..color = AudacityTheme.background;
    canvas.drawRect(Rect.fromLTWH(0, rulerHeight, size.width, waveformHeight), bgPaint);

    final rulerBgPaint = Paint()..color = AudacityTheme.rulerBackground;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, rulerHeight), rulerBgPaint);

    // 绘制中心基准线
    final centerLinePaint = Paint()
      ..color = AudacityTheme.centerLine
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), centerLinePaint);

    // 2. 绘制时间刻度标尺 (带视口裁剪)
    _drawRuler(canvas, size, rulerHeight);

    // 3. 绘制波峰 (视口裁剪 Viewport Clipping)
    _drawWaveform(canvas, size, rulerHeight, centerY);

    // 4. 绘制 A-B 选区
    _drawSelection(canvas, size, rulerHeight);

    // 5. 绘制当前播放指针
    _drawPlayhead(canvas, size, rulerHeight);
  }

  void _drawRuler(Canvas canvas, Size size, double rulerHeight) {
    final majorStep = TimeRulerHelper.calculateMajorStep(pixelsPerSecond: pixelsPerSecond);
    final totalSeconds = totalDuration.inMilliseconds / 1000.0;
    final stepSeconds = majorStep.inMilliseconds / 1000.0;

    final tickPaint = Paint()
      ..color = AudacityTheme.rulerTick
      ..strokeWidth = 1.0;

    const textStyle = TextStyle(color: AudacityTheme.rulerText, fontSize: 10);

    for (double sec = 0; sec <= totalSeconds; sec += stepSeconds) {
      final x = sec * pixelsPerSecond - scrollOffset;
      if (x < -50 || x > size.width + 50) continue; // 视口裁剪

      // 绘制主刻度线
      canvas.drawLine(Offset(x, rulerHeight - 8), Offset(x, rulerHeight), tickPaint);

      // 绘制时间文字
      final textSpan = TextSpan(text: TimeRulerHelper.formatTime(Duration(milliseconds: (sec * 1000).toInt())), style: textStyle);
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(x + 2, 4));
    }
  }

  void _drawWaveform(Canvas canvas, Size size, double rulerHeight, double centerY) {
    if (peaks.isEmpty || totalDuration.inMilliseconds == 0) return;

    final wavePaint = Paint()
      ..color = AudacityTheme.waveform
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final visibleStartSec = max(0.0, scrollOffset / pixelsPerSecond);
    final visibleEndSec = min(totalDuration.inMilliseconds / 1000.0, (scrollOffset + size.width) / pixelsPerSecond);

    final startIdx = ((visibleStartSec / (totalDuration.inMilliseconds / 1000.0)) * peaks.length).floor().clamp(0, peaks.length - 1);
    final endIdx = ((visibleEndSec / (totalDuration.inMilliseconds / 1000.0)) * peaks.length).ceil().clamp(0, peaks.length - 1);

    final maxHalfHeight = (size.height - rulerHeight) / 2 * 0.9;

    for (int i = startIdx; i <= endIdx; i++) {
      final sec = (i / peaks.length) * (totalDuration.inMilliseconds / 1000.0);
      final x = sec * pixelsPerSecond - scrollOffset;
      final peakHeight = peaks[i] * maxHalfHeight;

      canvas.drawLine(
        Offset(x, centerY - peakHeight),
        Offset(x, centerY + peakHeight),
        wavePaint,
      );
    }
  }

  void _drawSelection(Canvas canvas, Size size, double rulerHeight) {
    if (repeatState.pointA == null) return;

    final aSec = repeatState.pointA!.inMilliseconds / 1000.0;
    final ax = aSec * pixelsPerSecond - scrollOffset;

    final borderPaint = Paint()
      ..color = AudacityTheme.selectionBorder
      ..strokeWidth = 2.0;

    // A 点线与把手
    canvas.drawLine(Offset(ax, rulerHeight), Offset(ax, size.height), borderPaint);
    _drawHandle(canvas, ax, rulerHeight, 'A');

    if (repeatState.pointB != null) {
      final bSec = repeatState.pointB!.inMilliseconds / 1000.0;
      final bx = bSec * pixelsPerSecond - scrollOffset;

      // 遮罩
      final maskLeft = min(ax, bx);
      final maskRight = max(ax, bx);
      final maskPaint = Paint()..color = AudacityTheme.selectionMask;
      canvas.drawRect(Rect.fromLTRB(maskLeft, rulerHeight, maskRight, size.height), maskPaint);

      // B 点线与把手
      canvas.drawLine(Offset(bx, rulerHeight), Offset(bx, size.height), borderPaint);
      _drawHandle(canvas, bx, rulerHeight, 'B');
    }
  }

  void _drawHandle(Canvas canvas, double x, double y, String label) {
    final handlePaint = Paint()..color = AudacityTheme.handleTag;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, y + 10), width: 18, height: 16), const Radius.circular(3)),
      handlePaint,
    );

    final textSpan = TextSpan(
      text: label,
      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
    );
    final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset(x - tp.width / 2, y + 2));
  }

  void _drawPlayhead(Canvas canvas, Size size, double rulerHeight) {
    final sec = currentPosition.inMilliseconds / 1000.0;
    final x = sec * pixelsPerSecond - scrollOffset;

    final playheadPaint = Paint()
      ..color = AudacityTheme.playhead
      ..strokeWidth = 2.0;

    canvas.drawLine(Offset(x, 0), Offset(x, size.height), playheadPaint);

    // 顶部小倒三角
    final path = Path()
      ..moveTo(x - 5, 0)
      ..lineTo(x + 5, 0)
      ..lineTo(x, 7)
      ..close();
    canvas.drawPath(path, Paint()..color = AudacityTheme.playhead);
  }

  @override
  bool shouldRepaint(covariant AudacityWaveformPainter oldDelegate) {
    return oldDelegate.currentPosition != currentPosition ||
        oldDelegate.repeatState != repeatState ||
        oldDelegate.scrollOffset != scrollOffset ||
        oldDelegate.pixelsPerSecond != pixelsPerSecond ||
        oldDelegate.peaks != peaks;
  }
}
