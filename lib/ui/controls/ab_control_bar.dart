import 'package:flutter/material.dart';
import '../../models/repeat_state.dart';
import '../../models/waveform_gesture_mode.dart';
import '../waveform/time_ruler_helper.dart';

class AbControlBar extends StatelessWidget {
  final RepeatState state;
  final Duration currentPosition;
  final WaveformGestureMode gestureMode;
  final ValueChanged<WaveformGestureMode> onGestureModeChanged;
  final VoidCallback onSetA;
  final VoidCallback onSetB;
  final VoidCallback onClear;
  final Function(int) onNudgeA;
  final Function(int) onNudgeB;

  const AbControlBar({
    super.key,
    required this.state,
    required this.currentPosition,
    required this.gestureMode,
    required this.onGestureModeChanged,
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: const BoxDecoration(
        color: Color(0xFF242424),
        border: Border(right: BorderSide(color: Color(0xFF383838), width: 1)),
      ),
      child: Center(
        child: SingleChildScrollView(
          child: Row(
            children: [
              // 1. 最左侧：醒目的手势切换控件
              _buildGestureSwitcher(),
              const SizedBox(width: 8),

              // 2. 右侧：A-B 控制按键与时间微调
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
                    const SizedBox(height: 5),
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

  Widget _buildGestureSwitcher() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF444444), width: 1),
      ),
      padding: const EdgeInsets.all(2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _gestureOption(
            icon: Icons.pan_tool_outlined,
            label: '拖动',
            isActive: gestureMode.isDrag,
            activeColor: const Color(0xFF3AAFA9),
            onTap: () => onGestureModeChanged(WaveformGestureMode.drag),
          ),
          const SizedBox(height: 2),
          _gestureOption(
            icon: Icons.content_cut,
            label: '划选',
            isActive: gestureMode.isSelect,
            activeColor: const Color(0xFFF4D03F),
            onTap: () => onGestureModeChanged(WaveformGestureMode.select),
          ),
        ],
      ),
    );
  }

  Widget _gestureOption({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withAlpha(50) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: isActive ? activeColor : Colors.transparent, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: isActive ? activeColor : Colors.white54),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                color: isActive ? activeColor : Colors.white60,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _compactButton(IconData icon, String label, Color color, VoidCallback? onPressed) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 13, color: color),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF333333),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
          style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace'),
        ),
        const SizedBox(width: 3),
        InkWell(
          onTap: onMinus,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(3)),
            child: const Text('-0.1s', style: TextStyle(color: Colors.white60, fontSize: 10)),
          ),
        ),
        const SizedBox(width: 3),
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
