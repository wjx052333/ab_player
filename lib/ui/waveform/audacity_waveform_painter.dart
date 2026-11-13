import 'dart:math';
import 'package:flutter/material.dart';
import '../audacity_theme.dart';
import '../../models/repeat_state.dart';
import '../../models/speech_segment.dart';
import 'time_ruler_helper.dart';

class AudacityWaveformPainter extends CustomPainter {
  final List<double> peaks;
  final double peaksPerSecond; // 0 表示按 peaks 铺满总时长推算
  final List<SpeechSegment> segments;
  final Duration totalDuration;
  final Duration currentPosition;
  final RepeatState repeatState;
  final double scrollOffset;
  final double pixelsPerSecond;

  AudacityWaveformPainter({
    required this.peaks,
    this.peaksPerSecond = 0,
    this.segments = const [],
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

    // 3a. 说话区间底色 (没有底色的暗区即句间停顿)
    _drawSegments(canvas, size, rulerHeight);

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

  /// 说话区间：淡青底色 + 区间首尾竖线 + 底部色条，一眼分出「句子」与「停顿」
  void _drawSegments(Canvas canvas, Size size, double rulerHeight) {
    if (segments.isEmpty) return;
    final fill = Paint()..color = const Color(0x143AAFA9);
    final edge = Paint()
      ..color = const Color(0x663AAFA9)
      ..strokeWidth = 1.0;
    final bar = Paint()..color = AudacityTheme.waveform;

    for (final seg in segments) {
      final x1 = seg.start.inMilliseconds / 1000.0 * pixelsPerSecond - scrollOffset;
      final x2 = seg.end.inMilliseconds / 1000.0 * pixelsPerSecond - scrollOffset;
      if (x2 < 0 || x1 > size.width) continue;
      canvas.drawRect(Rect.fromLTRB(x1, rulerHeight, x2, size.height), fill);
      canvas.drawLine(Offset(x1, rulerHeight), Offset(x1, size.height), edge);
      canvas.drawLine(Offset(x2, rulerHeight), Offset(x2, size.height), edge);
      canvas.drawRect(Rect.fromLTRB(x1, size.height - 3, x2, size.height), bar);
    }
  }

  void _drawWaveform(Canvas canvas, Size size, double rulerHeight, double centerY) {
    final totalSec = totalDuration.inMilliseconds / 1000.0;
    if (peaks.isEmpty || totalSec <= 0) return;

    final wavePaint = Paint()
      ..color = AudacityTheme.waveform
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.butt;

    final pps = peaksPerSecond > 0 ? peaksPerSecond : peaks.length / totalSec;
    final maxHalfHeight = (size.height - rulerHeight) / 2 * 0.9;

    // 按屏幕像素列取该列覆盖时间段内的最大响度，缩得再小也不丢峰值
    for (int px = 0; px <= size.width; px++) {
      final t0 = (px + scrollOffset) / pixelsPerSecond;
      if (t0 > totalSec) break;
      final t1 = (px + 1 + scrollOffset) / pixelsPerSecond;
      final i0 = (t0 * pps).floor().clamp(0, peaks.length - 1);
      final i1 = max(i0, (t1 * pps).ceil() - 1).clamp(0, peaks.length - 1);

      double peak = 0;
      for (int i = i0; i <= i1; i++) {
        if (peaks[i] > peak) peak = peaks[i];
      }
      final h = max(0.5, peak * maxHalfHeight);
      canvas.drawLine(Offset(px.toDouble(), centerY - h), Offset(px.toDouble(), centerY + h), wavePaint);
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
        oldDelegate.peaks != peaks ||
        oldDelegate.segments != segments;
  }
}
