import 'package:flutter/material.dart';
import '../waveform/time_ruler_helper.dart';

/// 单行紧凑进度条：当前时间 ─滑块─ 总时长 (播放/从头播放按钮悬浮在波形图上)
class PlayerBottomBar extends StatelessWidget {
  final Duration currentPosition;
  final Duration totalDuration;
  final Function(Duration) onSeek;

  const PlayerBottomBar({
    super.key,
    required this.currentPosition,
    required this.totalDuration,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    final maxMs = totalDuration.inMilliseconds > 0 ? totalDuration.inMilliseconds.toDouble() : 1.0;
    final currMs = currentPosition.inMilliseconds.toDouble().clamp(0.0, maxMs);
    const timeStyle = TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Text(TimeRulerHelper.formatTime(currentPosition), style: timeStyle),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
              ),
              child: Slider(
                value: currMs,
                min: 0.0,
                max: maxMs,
                onChanged: (val) => onSeek(Duration(milliseconds: val.toInt())),
              ),
            ),
          ),
          Text(TimeRulerHelper.formatTime(totalDuration), style: timeStyle),
        ],
      ),
    );
  }
}
