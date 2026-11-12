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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const BoxDecoration(
        color: Color(0xFF242424),
        border: Border(right: BorderSide(color: Color(0xFF383838), width: 1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _compactButton(Icons.flag, '设A点', Colors.amber, onSetA),
              _compactButton(Icons.outlined_flag, '设B点', Colors.orange, onSetB),
              _compactButton(Icons.close, '清除', Colors.redAccent, (state.pointA != null || state.pointB != null) ? onClear : null),
            ],
          ),
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

  Widget _compactButton(IconData icon, String label, Color color, VoidCallback? onPressed) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 14, color: color),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF333333),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onPressed,
    );
  }

  Widget _nudgeRow(String label, String timeStr, VoidCallback onMinus, VoidCallback onPlus) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label:$timeStr', style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
        const SizedBox(width: 2),
        InkWell(
          onTap: onMinus,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(3)),
            child: const Text('-0.1s', style: TextStyle(color: Colors.white60, fontSize: 10)),
          ),
        ),
        const SizedBox(width: 2),
        InkWell(
          onTap: onPlus,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(3)),
            child: const Text('+0.1s', style: TextStyle(color: Colors.white60, fontSize: 10)),
          ),
        ),
      ],
    );
  }
}
