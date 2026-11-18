# 波形区域手势分区与 A-B 划选融合设计规范

## 1. 概述与设计背景
目前 Audacity 波形区域（`AudacityWaveformView`）中，用户需要在左下角的「✋ 拖动」与「AB 划选」模式之间手动切换，导致浏览波形与设置 A-B 复读区间操作割裂，体验繁琐。

本设计将波形区域纵向划分为三段式手势感应区（上下 1/4 为平移拖动区，中间 1/2 为 A-B 划选区），并移除原有的模式切换悬浮按钮，实现拖动波形与划选 A-B 的手势无缝融合；同时在中间 1/2 区域增加半透明金色蒙层与边界线，提供直观的视觉引导。

---

## 2. 界面与视觉设计

### 2.1 区域比例定义
以波形内容区（排除顶部 26dp 的时间刻度标尺 `rulerHeight`）的有效高度 $H_{wave} = H_{total} - 26$ 为基准：
- **顶部拖动区（Top 1/4）**：$Y \in [26, 26 + 0.25 \times H_{wave})$
- **中间 A-B 划选区（Middle 1/2）**：$Y \in [26 + 0.25 \times H_{wave}, 26 + 0.75 \times H_{wave}]$
- **底部拖动区（Bottom 1/4）**：$Y \in (26 + 0.75 \times H_{wave}, H_{total}]$

### 2.2 视觉引导样式
- **中间 A-B 划选区背景**：覆盖半透明黄色蒙层，颜色值为 `Color(0xFFF4D03F).withValues(alpha: 0.07)`，呼应 A-B 选区主题色，且不遮盖波峰、零位线及断句青色高亮。
- **划选区分界辅助线**：在中间区域的上边界（$Y_1 = 26 + 0.25 \times H_{wave}$）与下边界（$Y_2 = 26 + 0.75 \times H_{wave}$）绘制 1px 细线，颜色值为 `Color(0xFFF4D03F).withValues(alpha: 0.25)`。
- **上下拖动区背景**：保持 Audacity 原生深黑背景 `AudacityTheme.background`。

### 2.3 移除左下角悬浮切换按钮
- 彻底移除 `AudacityWaveformView` 左下角悬浮的「✋ 拖动」与「AB 划选」`MiniIconButton` 胶囊组件。
- 右下角的播放/暂停与光标居中缩放快捷按钮保持不变。

---

## 3. 手势分流与交互逻辑

### 3.1 单指按下（ScaleStart / DragStart）
根据起始触控点 `localFocalPoint` 的坐标进行优先级判定：
1. **A/B 把手微调（最高优先级）**：
   - 若 $X$ 落在 A 点或 B 点垂直线左右 24px 热区内，无论 $Y$ 落在哪个区域，均优先进入对应把手微调模式。
2. **区域模式判断（记录起始模式）**：
   - 若起始触控点落在 **中间 1/2 区域**，当前单指拖动标记为 `_DragAction.selectRange`（划选 A-B 选区）。
   - 若起始触控点落在 **顶部 1/4、底部 1/4 或标尺区**，当前单指拖动标记为 `_DragAction.panWaveform`（平移波形）。

### 3.2 单指滑动（ScaleUpdate）
- 若处于把手微调：更新对应 A 或 B 点位置（保留吸附到断句边界特性）。
- 若为 `panWaveform`：根据水平位移 $\Delta X$ 平移波形视口 `_scrollOffset`。
- 若为 `selectRange`：以起始触控点对应时间为起点，当前触控点对应时间为终点，调用 `onRangeSelected` 动态拉出 A-B 区间（保留吸附到断句边界特性）。

### 3.3 单指点击（TapUp）
- 点击任意区域均可触发跳转（Seek）到点击对应的时间。
- **智能选句增强**：若点击落在 **中间 1/2 区域** 且命中了检测到的断句语音区间（`SpeechSegment`），则直接将 A-B 设为该句起止边界。若点击在上下 1/4 区域，即使有断句也仅执行普通 Seek。

### 3.4 多指触控（Pinch / Dual-finger Pan）
- 双指捏合缩放：在波形任意区域均有效，以两指焦点为时间锚点缩放。
- 双指拖拽平移：任意区域均支持双指平移。

---

## 4. 架构调整与废弃清理

1. **`AudacityWaveformView` 接口精简**：
   - 移除属性 `final WaveformGestureMode gestureMode` 与回调 `final ValueChanged<WaveformGestureMode> onGestureModeChanged`。
2. **`PlayerScreen` 清理**：
   - 移除 `_gestureMode` 状态与对波形手势模式的传递。
3. **`AudacityWaveformPainter` 渲染更新**：
   - 在波峰绘制前（或断句背景与波峰之间）绘制中间 1/2 区域的半透明黄色背景与上下分界线。
4. **模型与测试更新**：
   - 若没有其他模块依赖 `WaveformGestureMode`，可做对应调整或精简；
   - 更新或新增波形手势与 UI 测试用例，确保新分区手势在单元测试和集成测试中均有可靠覆盖。
