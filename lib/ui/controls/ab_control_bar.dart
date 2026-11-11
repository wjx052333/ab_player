import 'package:flutter/material.dart';
import '../../models/repeat_state.dart';
import '../waveform/time_ruler_helper.dart';

class AbControlBar extends StatelessWidget {
  final RepeatState state;
  final Duration currentPosition;
  final VoidCallback onSetA;
  final VoidCallback onSetB;
  final VoidCallback onClear;
  final Function(int) onNudgeA;
  final Function(int) onNudgeB;

  const AbControlBar({
    super.key,
    required this.state,
    required this.currentPosition,
    required this.onSetA,
    required this.onSetB,
    required this.onClear,
    required this.onNudgeA,
    required this.onNudgeB,
  });

  @override
  Widget build(BuildContext context) {
    final aText = state.pointA != null ? TimeRulerHelper.formatTime(state.pointA!) : '--:--.-';
    final bText = state.pointB != null ? TimeRulerHelper.formatTime(state.pointB!) : '--:--.-';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: const Color(0xFF2B2B2B),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.flag, size: 16, color: Colors.amber),
                label: const Text('设为 A 点'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF383838)),
                onPressed: onSetA,
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.outlined_flag, size: 16, color: Colors.orange),
                label: const Text('设为 B 点'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF383838)),
                onPressed: onSetB,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
                label: const Text('清除'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                onPressed: state.pointA != null || state.pointB != null ? onClear : null,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _nudgeRow('A', aText, () => onNudgeA(-100), () => onNudgeA(100)),
              _nudgeRow('B', bText, () => onNudgeB(-100), () => onNudgeB(100)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _nudgeRow(String label, String timeStr, VoidCallback onMinus, VoidCallback onPlus) {
    return Row(
      children: [
        Text('$label: $timeStr', style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'monospace')),
        const SizedBox(width: 4),
        InkWell(
          onTap: onMinus,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(3)),
            child: const Text('-0.1s', style: TextStyle(color: Colors.white60, fontSize: 11)),
          ),
        ),
        const SizedBox(width: 4),
        InkWell(
          onTap: onPlus,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(3)),
            child: const Text('+0.1s', style: TextStyle(color: Colors.white60, fontSize: 11)),
          ),
        ),
      ],
    );
  }
}
