import 'package:flutter/material.dart';

/// 半透明黑底小图标按钮 (波形图悬浮缩放键与底部播放控制共用)
class MiniIconButton extends StatelessWidget {
  /// 图标与文字二选一；文字用于没有合适图标的按钮 (如划选的「AB」)
  final IconData? icon;
  final String? label;
  final VoidCallback? onPressed;
  final String? tooltip;

  /// 非空表示处于选中态：用该颜色高亮图标与边框
  final Color? activeColor;

  const MiniIconButton({
    super.key,
    this.icon,
    this.label,
    required this.onPressed,
    this.tooltip,
    this.activeColor,
  }) : assert(icon != null || label != null);

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final color = activeColor ?? (enabled ? Colors.white70 : Colors.white24);
    return Container(
      decoration: BoxDecoration(
        color: activeColor != null ? activeColor!.withAlpha(70) : Colors.black.withAlpha(enabled ? 160 : 70),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: activeColor ?? Colors.white12, width: activeColor != null ? 1 : 0.5),
      ),
      child: IconButton(
        icon: label != null
            ? Text(label!, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold, height: 1))
            : Icon(icon, color: color, size: 18),
        tooltip: tooltip,
        onPressed: onPressed,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        padding: EdgeInsets.zero,
      ),
    );
  }
}
