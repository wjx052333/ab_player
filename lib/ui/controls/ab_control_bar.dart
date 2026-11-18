import 'package:flutter/material.dart';
import '../../models/repeat_state.dart';
import '../audacity_theme.dart';
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: const BoxDecoration(
        color: AudacityTheme.panelBackground,
        border: Border(right: BorderSide(color: AudacityTheme.panelBorder, width: 1)),
      ),
      child: Center(
        child: SingleChildScrollView(
          child: Row(
            children: [
              // A-B 控制按键与时间微调
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _compactButton(Icons.flag, '设A点', Colors.amber, onSetA),
                          const SizedBox(width: 6),
                          _compactButton(Icons.outlined_flag, '设B点', Colors.orange, onSetB),
                          const SizedBox(width: 6),
                          _compactButton(
                            Icons.close,
                            '清除',
                            Colors.redAccent,
                            (state.pointA != null || state.pointB != null) ? onClear : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _nudgeGroup('A', aText, () => onNudgeA(-100), () => onNudgeA(100)),
                          const SizedBox(width: 8),
                          _nudgeGroup('B', bText, () => onNudgeB(-100), () => onNudgeB(100)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _compactButton(IconData icon, String label, Color color, VoidCallback? onPressed) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 15, color: color),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF383838),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onPressed,
    );
  }

  Widget _nudgeGroup(String label, String timeStr, VoidCallback onMinus, VoidCallback onPlus) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label:$timeStr',
          style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace'),
        ),
        const SizedBox(width: 3),
        InkWell(
          onTap: onMinus,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(3)),
            child: const Text('-0.1s', style: TextStyle(color: Colors.white60, fontSize: 9)),
          ),
        ),
        const SizedBox(width: 3),
        InkWell(
          onTap: onPlus,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(3)),
            child: const Text('+0.1s', style: TextStyle(color: Colors.white60, fontSize: 9)),
          ),
        ),
      ],
    );
  }
}
