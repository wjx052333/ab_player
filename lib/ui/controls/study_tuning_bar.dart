import 'package:flutter/material.dart';

class StudyTuningBar extends StatelessWidget {
  final double currentSpeed;
  final int currentPauseSeconds;
  final int remainingLoops;
  final Function(double) onSpeedChanged;
  final Function(int) onPauseChanged;
  final Function(int) onLoopsChanged;

  const StudyTuningBar({
    super.key,
    required this.currentSpeed,
    required this.currentPauseSeconds,
    required this.remainingLoops,
    required this.onSpeedChanged,
    required this.onPauseChanged,
    required this.onLoopsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('速: ', style: TextStyle(color: Colors.white54, fontSize: 11)),
          for (final speed in [0.8, 1.0, 1.25, 1.5])
            Padding(
              padding: const EdgeInsets.only(right: 3),
              child: ChoiceChip(
                label: Text('${speed}x', style: const TextStyle(fontSize: 10)),
                selected: currentSpeed == speed,
                onSelected: (_) => onSpeedChanged(speed),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: EdgeInsets.zero,
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
          const SizedBox(width: 6),
          const Text('停: ', style: TextStyle(color: Colors.white54, fontSize: 11)),
          for (final pause in [0, 1, 2, 3])
            Padding(
              padding: const EdgeInsets.only(right: 3),
              child: ChoiceChip(
                label: Text('${pause}s', style: const TextStyle(fontSize: 10)),
                selected: currentPauseSeconds == pause,
                onSelected: (_) => onPauseChanged(pause),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: EdgeInsets.zero,
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
          const SizedBox(width: 6),
          const Text('循环: ', style: TextStyle(color: Colors.white54, fontSize: 11)),
          for (final loops in [-1, 3, 5])
            Padding(
              padding: const EdgeInsets.only(right: 3),
              child: ChoiceChip(
                label: Text(loops == -1 ? '∞' : '$loops次', style: const TextStyle(fontSize: 10)),
                selected: remainingLoops == loops,
                onSelected: (_) => onLoopsChanged(loops),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: EdgeInsets.zero,
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
        ],
      ),
    );
  }
}
