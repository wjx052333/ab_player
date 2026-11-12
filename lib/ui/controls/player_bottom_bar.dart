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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                TimeRulerHelper.formatTime(currentPosition),
                style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace'),
              ),
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
              Text(
                TimeRulerHelper.formatTime(totalDuration),
                style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace'),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.replay_5, color: Colors.white70, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: onSeekBack5s,
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 32,
                height: 32,
                child: IconButton.filled(
                  onPressed: onPlayPause,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF3AAFA9),
                    padding: EdgeInsets.zero,
                  ),
                  icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.forward_5, color: Colors.white70, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: onSeekForward5s,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
