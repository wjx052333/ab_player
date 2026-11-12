# Audacity Player - 核心架构与开发指南

Audacity 风格的 Android 音频播放器，专注于英语精听、口语跟读（Shadowing）与音乐分段研读。核心特色是桌面级 Audacity 质感时域波形图、时间标尺、手势缩放与框选、以及高精度 A-B 复读引擎。

---

## 1. 核心架构与模块划分

```
lib/
├── main.dart                               # 应用入口、全局主题与横屏强锁
├── models/
│   ├── audio_track.dart                    # 音频音轨模型 (标题、时长、归一化波峰数组)
│   ├── repeat_state.dart                   # A-B 复读状态模型 (A/B 点、跟读停顿、循环次数、倍速)
│   └── waveform_gesture_mode.dart          # 触控手势模式枚举 (drag: 拖动浏览, select: 划选区间)
├── services/
│   ├── audio_player_service.dart           # just_audio 播放引擎封装 (播放、暂停、精准 Seek、倍速)
│   └── waveform_extractor.dart             # 本地音频快速采样与波峰下采样算法
├── controllers/
│   └── ab_repeat_controller.dart           # A-B 复读状态机 (打点、到达B点静音停顿与 Seek A 倒计时)
└── ui/
    ├── audacity_theme.dart                 # Audacity 经典深暗示波器与金属面板主题色值
    ├── player_screen.dart                  # 主界面：上下分层 + 底部左右双列横屏工作台
    ├── waveform/
    │   ├── audacity_waveform_view.dart     # 波形图交互容器 (光标锚定缩放、跟随逻辑、手势分流)
    │   ├── audacity_waveform_painter.dart  # CustomPainter 视口局部裁剪绘制 (标尺/波形/选区/指针)
    │   └── time_ruler_helper.dart          # 时间刻度步长自适应计算与毫秒格式化 (00:05.0)
    └── controls/
        ├── ab_control_bar.dart             # 模式切换胶囊 + A-B 打点与 ±0.1s 步进微调
        ├── study_tuning_bar.dart           # 紧凑型倍速 (0.8x~1.5x)、跟读停顿 (0~3s)、循环次数
        └── player_bottom_bar.dart          # 紧凑型播放滑块与播放/暂停/快进退主控
```

---

## 2. 关键设计与核心交互机制

### 2.1 屏幕方向与防溢出设计
- **默认横屏锁定**：
  - Android 原生：`android/app/src/main/AndroidManifest.xml` 中配置 `android:screenOrientation="sensorLandscape"`，冷启动即横屏。
  - Flutter 层：`lib/main.dart` 中调用 `SystemChrome.setPreferredOrientations` 锁定左右横屏。
- **52:48 上下黄金比例**：
  - 上半部（52% 高度）：全宽波形与标尺视口，横向时间轴视野开阔；
  - 下半部（48% 高度）：左右双列（左列 A-B 与手势，右列精听参数与播放主控）。
  - 下方所有控制栏包裹 `SingleChildScrollView` 并设置紧凑 Material 规范，杜绝真机底部小白条/手势导航栏引起的 RenderFlex Overflow。
- **界面层次对比**：
  - 上半部波形区为暗夜黑灰（`#141414` / `#0F0F0F`），带深色微边框，宛如嵌入式示波器屏幕；
  - 下半部控制区为工作台面板灰（`#2A2A2A`），层次分明。

### 2.2 触控手势模式切换（双态分工）
`AbControlBar` 最左侧常驻醒目的切换胶囊：
1. **`[✋ 拖动]`（默认模式）**：
   - 单指水平滑动：直接拖拽平移波形（更新 `_scrollOffset`），自由浏览前后音频；
   - 单指点击波形：Seek 跳转到对应时间戳。
2. **`[✂️ 划选]`（选区模式）**：
   - 单指拖拽：在波形上实时拉出半透明 A-B 复读区间。
3. **全局把手优先响应**：
   - 无论处于何种模式，手指命中 `[A]` 或 `[B]` 把手热区时，均可直接拖拽微调起止点。

### 2.3 波形缩放与光标锚定机制
- **以当前光标（Playhead）为视觉中心缩放**：
  - 点击缩放按钮或双指捏合时，计算当前光标在屏幕上的横向投影，缩放后光标在屏幕上的位置纹丝不动，波形以光标为中心向两侧展开或收缩，彻底避免“缩放后找不到光标”。
- **最小缩放边界（满屏即止）**：
  - 动态计算 $\text{minPPS} = \text{width} / \text{totalDurationSeconds}$；
  - 缩小到音频刚好填满屏幕时达到极限，不再缩小，波形永远清晰展开，【缩小】按钮自动置灰。

### 2.4 播放自动跟随与选区静止优化
- **居中平滑跟随**：正常播放时，播放指针自动保持在屏幕横向中央，波形向左推进；
- **触碰避让与冷却**：手指触碰波形时暂停跟随，把控权归还用户；松手 1.5 秒后（或点击跳转后）自动恢复居中跟随；
- **选区内免眩晕静止**：当 A-B 选区完全在当前屏幕视野内时，波形视口**锁定静止**，光标在选区内循环移动，消除复读时的画面抖动与眩晕。

### 2.5 A-B 复读控制逻辑 (`AbRepeatController`)
- **最小保护间隔**：A 点与 B 点强制满足 $T_A < T_B$，最小间隔 200ms，防止高频震荡；
- **跟读停顿（Shadowing Pause）**：到达 B 点后立即静音暂停，倒计时 $N$ 秒留白供用户开口跟读，结束后自动 Seek 回 A 点恢复播放；
- **微调步进**：支持 A 点与 B 点独立 `[-0.1s]` / `[+0.1s]` 精准打点；
- **变速不变调**：依托 `just_audio` 底层 Sonic 算法，支持 0.8x、1.0x、1.25x、1.5x 保持音调不失真。

---

## 3. 常用开发与构建命令

本项目已配置国内镜像源（`pub.flutter-io.cn`、阿里云与国内 Gradle 镜像）。

```bash
# 获取依赖
flutter pub get

# 静态代码检查 (确保 0 warnings)
flutter analyze

# 运行全量测试套件 (包含模型测试、状态机测试、极限小屏防溢出测试)
flutter test

# 单独运行特定测试文件
flutter test test/widget_test.dart
flutter test test/controllers/ab_repeat_controller_test.dart

# 本地调试运行 (支持真机热重载 'r')
flutter run
```
