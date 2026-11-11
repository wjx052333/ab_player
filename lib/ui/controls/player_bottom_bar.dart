import 'package:flutter/material.dart';
import '../waveform/time_ruler_helper.dart';

class PlayerBottomBar extends StatelessWidget {
  final bool isPlaying;
  final Duration currentPosition;
  final Duration totalDuration;
  final VoidCallback onPlayPause;
  final VoidCallback onSeekBack5s;
  final VoidCallback onSeekForward5s;
  final Function(Duration) onSeek;

  const PlayerBottomBar({
    super.key,
    required this.isPlaying,
    required this.currentPosition,
    required this.totalDuration,
    required this.onPlayPause,
    required this.onSeekBack5s,
    required this.onSeekForward5s,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    final maxMs = totalDuration.inMilliseconds > 0 ? totalDuration.inMilliseconds.toDouble() : 1.0;
    final currMs = currentPosition.inMilliseconds.toDouble().clamp(0.0, maxMs);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF1E1E1E),
      child: Column(
        children: [
          Row(
            children: [
              Text(TimeRulerHelper.formatTime(currentPosition), style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  ),
                  child: Slider(
                    value: currMs,
                    min: 0.0,
                    max: maxMs,
                    onChanged: (val) => onSeek(Duration(milliseconds: val.toInt())),
                  ),
                ),
              ),
              Text(TimeRulerHelper.formatTime(totalDuration), style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.replay_5, color: Colors.white70, size: 28),
                onPressed: onSeekBack5s,
              ),
              const SizedBox(width: 24),
              FloatingActionButton(
                onPressed: onPlayPause,
                backgroundColor: const Color(0xFF3AAFA9),
                child: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 24),
              IconButton(
                icon: const Icon(Icons.forward_5, color: Colors.white70, size: 28),
                onPressed: onSeekForward5s,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
