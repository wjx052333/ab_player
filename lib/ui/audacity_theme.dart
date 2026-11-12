import 'package:flutter/material.dart';

class AudacityTheme {
  // 波形图视口区域：更深邃的示波器暗黑底色
  static const Color background = Color(0xFF141414);
  static const Color rulerBackground = Color(0xFF0F0F0F);
  static const Color rulerTick = Color(0xFF666666);
  static const Color rulerText = Color(0xFF9E9E9E);

  static const Color centerLine = Color(0xFF282828);
  static const Color waveform = Color(0xFF3AAFA9); // 青绿色波形
  static const Color waveformBorder = Color(0xFF2B7A78);

  static const Color playhead = Color(0xFFE74C3C); // 红色播放指针
  static const Color selectionMask = Color(0x33FFFFFF); // 选区半透明白色高亮
  static const Color selectionBorder = Color(0xFFF4D03F); // 选区边界明黄
  static const Color handleTag = Color(0xFFF39C12); // 把手颜色

  // 下方控制面板区域：工业控制台金属灰，与上方波形区形成明显视觉对比
  static const Color panelBackground = Color(0xFF2A2A2A);
  static const Color panelBorder = Color(0xFF383838);
}
