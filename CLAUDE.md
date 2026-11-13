# Audacity Player - 核心架构与开发指南

Audacity 风格的 Android/桌面跨平台音频播放器与离线英语研读工作台。专注于英语精听、口语跟读（Shadowing）、桌面级 Audacity 质感时域波形交互，以及集成了 **340万词汇 ECDICT 升学考点数据库 + 纯原生 Dart 挂载 MDX/MDD 权威词典群（牛津/朗文等）+ 4级真人英美音发音引擎** 的横屏双栏查词工作台。

---

## 1. 核心架构与模块划分

```
lib/
├── main.dart                               # 应用入口、全局主题与横屏强锁
├── models/
│   ├── audio_track.dart                    # 音频音轨模型 (标题、时长、归一化波峰数组)
│   ├── speech_segment.dart                 # 说话区间模型 (start/end)
│   ├── repeat_state.dart                   # A-B 复读状态模型 (A/B 点、跟读停顿、循环次数、倍速)
│   ├── waveform_gesture_mode.dart          # 触控手势模式枚举 (drag: 拖动浏览, select: 划选区间)
│   └── dictionary/
│       ├── dict_example.dart               # 双语权威例句模型 (oxford / longman)
│       ├── dict_word_summary.dart          # 快速联想列表摘要模型 (标签、简明释义)
│       └── dict_word_detail.dart           # 词卡详情模型 (词形变化 exchange 解析、多行释义)
├── services/
│   ├── audio_player_service.dart           # just_audio 播放引擎封装 (播放、暂停、精准 Seek、倍速)
│   ├── waveform_extractor.dart             # 波形提取：Android/iOS 用 just_waveform 原生解码出真实响度包络 (100点/秒)，其他平台退回字节抽样粗略波形
│   ├── speech_segmenter.dart               # 断句检测：按响度包络+自适应阈值找出说话区间 (静音≥250ms 视为句间停顿)
│   ├── dictionary_db_service.dart          # SQLite 查词服务 (前缀联想、中高考/四六级升学权重排序)
│   ├── dictionary_audio_service.dart       # 4级发音调度服务 (MDD直读 -> 本地MP3 -> 有道API -> TTS)
│   └── mdict/
│       ├── mdict_html_page_builder.dart    # 将词条 HTML 拼成自包含页面 (内联 .css/.js、MDD 图片转 data URI、暗黑覆盖样式)
│       ├── mdict_crypto.dart               # 纯 Dart RIPEMD-128 与 MDict fastDecrypt 密钥解密算法
│       ├── mdict_header.dart               # MDDict XML 头部解析模型
│       ├── mdict_reader.dart               # 核心纯 Dart MDX/MDD 二进制 RandomAccess 寻道与块解压引擎
│       ├── mdict_dictionary_pack.dart      # 单套词典包封装 (.mdx + 配套 .mdd + .css + 暗黑主题自适应)
│       └── mdict_manager_service.dart      # 多词典管理器 (自动发现、热插拔添加/删除/排序、MDD 音频提取)
├── controllers/
│   └── ab_repeat_controller.dart           # A-B 复读状态机 (打点、到达B点静音停顿与 Seek A 倒计时)
└── ui/
    ├── audacity_theme.dart                 # Audacity 经典深暗示波器与金属面板主题色值
    ├── player_screen.dart                  # 主界面：顶部 32dp [🎧 播放器 | 📖 词典] Tab 切换 + 工作台
    ├── waveform/
    │   ├── audacity_waveform_view.dart     # 波形图交互容器 (光标锚定缩放、跟随逻辑、手势分流)
    │   ├── audacity_waveform_painter.dart  # CustomPainter 视口局部裁剪绘制 (标尺/波形/选区/指针)
    │   └── time_ruler_helper.dart          # 时间刻度步长自适应计算与毫秒格式化 (00:05.0)
    ├── controls/
    │   ├── ab_control_bar.dart             # 模式切换胶囊 + A-B 打点与 ±0.1s 步进微调
    │   ├── segmenter_settings_dialog.dart      # 断句参数浮层 (阈值/最短停顿/最短语音，持久化)
│   ├── study_tuning_bar.dart           # 紧凑型倍速 (0.8x~1.5x)、跟读停顿 (0~3s)、循环次数
    │   └── player_bottom_bar.dart          # 紧凑型播放滑块与播放/暂停/快进退主控
    └── dictionary/
        ├── dictionary_screen.dart          # 词典横屏 35:65 双栏工作台主容器
        └── widgets/
            ├── dict_search_sidebar.dart    # 35% 检索侧栏 (200ms 防抖搜索框 + 升学置顶联想列表)
            ├── dict_card_header.dart       # 词卡头部 (大词名、音标、US/UK 发音胶囊、考点彩色徽章、星级)
            ├── dict_meaning_column.dart    # ECDICT 速查 (中文核心释义词性归纳、词形变形徽章、英文释义)
            ├── dict_pack_chip_bar.dart     # 顶栏词典 Chip 条 (横向可拖动，溢出时显示「拖动查看更多」提示) + DictPanelController
            ├── dict_pack_panel_host.dart   # 点击 Chip 后从右侧滑出的词典释义浮层 (与词卡同大，覆盖整个词卡)
            ├── mdict_web_view.dart         # WebView 渲染单个 MDX 词条 (拦截 sound:// 与 entry://)
            ├── dict_examples_column.dart   # 权威例句分组卡片 (牛津/朗文例句与关键词高亮)
            └── dict_pack_manager_dialog.dart# 词典管理对话框 (启停开关、拖拽排序、外部 .mdx 文件挂载)
```

---

## 2. 关键设计与核心交互机制

### 2.1 屏幕方向与双工作台设计
- **默认横屏锁定**：
  - Android 原生：`android/app/src/main/AndroidManifest.xml` 中配置 `android:screenOrientation="sensorLandscape"`，冷启动即横屏。
  - Flutter 层：`lib/main.dart` 中调用 `SystemChrome.setPreferredOrientations` 锁定左右横屏。
- **顶部 32dp 全局导航与状态栏**：
  - 常驻分段切换按钮：`[ 🎧 播放器 ]` ⟷ `[ 📖 词典 ]`（通过 `IndexedStack` 保持播放状态与音频解码存活）；
  - 词典 Tab 下展示基础词库连接状态、已挂载外部 MDX 词典套数徽章、词库管理与指定文件入口。
- **70:30 播放器比例**：
  - 上半部（70% 高度）：全宽波形与标尺视口；
  - 下半部（30% 高度）：左右双列 1:2（左列 1/3 宽为 A-B 打点与微调，右列 2/3 宽为精听参数与进度条）；播放/从头播放/缩放/手势切换均为波形图上的悬浮按钮。
- **35:65 查词工作台双栏结构**：
  - 左侧检索栏（35% 宽）：常驻带清除按钮的防抖搜索框，前缀匹配升学高频词置顶；
  - 右侧横屏词卡（65% 宽）：
    - 顶部 Header：26pt 粗体词名、英美音发音按钮、最低考点等级（中考<高考<四级<六级<考研<雅思<托福<GRE，只显示最低一项）+柯林斯星级；
    - 主体：ECDICT 核心释义与形态速查占满词卡；词典 Chip（`📘 牛津初阶`、`📙 朗文当代 6th` 等，当前词有收录带绿点、无收录置灰）在词典 Tab 的顶栏、`词库管理` 按钮左侧，词典多时可左右拖动，被截断的一侧会出现渐隐和「拖动查看更多」提示；点击 Chip 后词典释义从右侧滑出，与词卡同大地盖住整个词卡，再点同一 Chip / 关闭按钮 / 系统返回键收起。

### 2.2 触控手势模式切换（双态分工）
波形图左下角悬浮两枚小按钮（✋ 图标 + 「AB」文字）（与右下角播放/缩放键同高），当前模式高亮：
1. **`✋ 拖动`（默认模式）**：单指水平滑动直接平移波形，单指点击跳转 Seek；
2. **`AB 划选`（选区模式）**：单指拖拽在波形上实时拉出半透明 A-B 复读区间；
3. **全局把手优先响应**：手指命中 `[A]` 或 `[B]` 把手热区时，直接拖拽微调起止点。

### 2.3 波形缩放、居中跟随与选区静止
- **以当前光标为视觉中心缩放**：缩放时计算光标屏幕投影，缩放后光标横向位置不变；
- **最小缩放边界（满屏即止）**：$\text{minPPS} = \text{width} / \text{totalDurationSeconds}$，全屏即止，杜绝波形压缩成一团；
- **触碰避让与冷却**：手势触碰波形暂停居中跟随，松手 1.5 秒后自动恢复跟随；
- **选区内免眩晕静止**：当 A-B 选区完全在当前屏幕视野内时，波形视口**锁定静止**，光标在选区内循环移动。

### 2.3.1 断句可视化与吸附
- **真实响度**：用 `just_waveform` 原生解码 MP3 等压缩格式，得到 10ms 一点的响度包络；绘制时按屏幕像素列取区间最大值，缩小后也不丢峰值。
- **断句标注**：`SpeechSegmenter` 找出说话区间，波形上画淡青底色 + 首尾竖线 + 底部色条，无底色的暗区即句间停顿。仅真实包络做断句，粗略波形不检测。
- **断句参数可调**：顶栏「断句参数」按钮（原右侧时间显示位置）打开浮层，可调静音阈值（占高响度比例，默认 12%）、最短停顿（默认 150ms）、最短语音（默认 150ms）；拖动即时重新断句，参数存 `SharedPreferences`。默认值依据 `L212026.mp3`（底噪较高）调出，原 6%/250ms 只能断出 3 段。离线调参脚本 `data_utils/segment_audio.py`（算法与 Dart 一致，需 `pip install miniaudio numpy`），可对任意 MP3 打印句子起止时间，改默认值时两边要同步。
- **一键选句**：`AB 划选` 模式下点击某个句子，A-B 直接设为该句边界。
- **边界吸附**：划选或拖 A/B 把手时，靠近句子起止点（≤10px，最多 300ms）自动吸附，避免截断单词。

### 2.3.2 加载进度与退出确认
- **加载等待界面**：选择音频后显示分阶段进度条（读取音频 → 解码波形 xx% → 分析断句）。
- **默认缩放**：初始 30 像素/秒（最大 300，最小为刚好铺满视口）。
- **切到词典立即停播**：切换到词典 Tab 时暂停播放，并取消跟读停顿倒计时，避免计时器稍后又恢复播放。
- **双击返回才退出**：系统返回/边缘滑动首次只提示「再滑一次退出」，2 秒内再次才退出；词典释义浮层打开时，返回键仍只用来收起浮层。

### 2.4 A-B 复读状态机 (`AbRepeatController`)
- **最小保护间隔**：A 点与 B 点强制满足 $T_A < T_B$，最小间隔 200ms；
- **跟读停顿（Shadowing Pause）**：到达 B 点后静音暂停 $N$ 秒供跟读，倒计时结束后自动 Seek 回 A 点循环播放；
- **步进微调与无损变速**：独立 `[-0.1s]` / `[+0.1s]` 调点；Sonic 算法支持 0.8x~1.5x 变速不变调。

---

## 3. 词典引擎与原生 MDX/MDD 容器架构

### 3.1 ECDICT 升学考点快速检索 (`DictionaryDbService`)
- 底层连接 `ecdict-ultimate.db`（SQLite 只读访问），毫秒级前缀联想匹配；
- 排序算法对升学考点赋予极高权重：
  $$\text{精确匹配} \to \text{zk (中考)} \to \text{cet4 (四级)} \to \text{cet6 (六级)} \to \text{gk (高考)} \to \text{柯林斯星级} \to \text{词频 frq}$$
- 支持提取 `exchange` 字段并格式化映射为中文化词形变化（过去式、复数、现在分词、第三人称单数、比较级等）。

### 3.2 纯 Dart 原生 MDX / MDD 二进制解析引擎 (`lib/services/mdict/`)
采用纯 Dart（`RandomAccessFile` + `dart:io` 原生 `ZLibDecoder`）直读原生 `.mdx` 和 `.mdd` 容器，零第三方 C/C++ 或 Python 依赖：
- **超低内存占用**：几百兆至 1.3GB 的大词典无需全量进内存，仅解析并缓存几十 KB 的 Key Block Info 稀疏索引；
- **双层二分查找**：对查询词先在内存索引树中二分定位 Key Block（0.1ms），按需从磁盘 Seek 读取该 32KB 块解压，块内再次二分查得 `recordOffset`；
- **解密套件**：纯 Dart 完整实现 64 轮 `RIPEMD-128` 摘要算法，支持 `Encrypted="2"` 的 MDict v2.0 Key Block 解密；
- **双字节字符对齐**：MDD 资源路径规范采用 UTF-16LE（双字节对齐），MDX 采用 UTF-8，自动识别解码；
- **内置 LRU 缓存**：对最近访问的块维持热点缓存，高频查词无感知。

### 3.3 可扩展多词典 Tab 架构 (`MDictManagerService`)
- **开箱即用自动挂载**：启动自动探测 `data_download/` 目录下的词典（如 `oxfordPrimary.mdx`、`Longman...mdx`、`Sound_us_uk.mdd`）；
- **用户动态热插拔**：用户可通过查词工作台顶栏的 `[ 词库管理 ]`，点击 `[+ 添加 MDX/MDD 词典文件]`（通过 `file_picker`）随时挂载新词典（如 Oxford 10th、Collins 等）；
- **动态新增 Chip**：顶栏 Chip 条根据当前启用的词典包动态渲染，顺序与词库管理中的拖拽排序一致；
- **持久化记录**：使用 `SharedPreferences` 保存外挂词典路径和启用状态，重启自动恢复；
- **WebView 渲染**：词条用 `webview_flutter` 渲染，`MDictHtmlPageBuilder` 把词典自带的 `.css`、`.js` 内联进页面（朗文的展开/收起、弹出菜单依赖其 JS），`.mdd` 里的图片转 data URI，再叠加暗黑主题覆盖样式。不能改回 `flutter_widget_from_html`：它不解析 `<style>` 样式表也不执行 JS，朗文会渲染成一团。
- **链接拦截**：`sound://` 先按 MDD 里的精确路径播放（`DictionaryAudioService.playResource`，如朗文 `hwd/ame/1/test1.mp3`），找不到再退回按单词播放；`entry://` 单词链接联动检索，`entry://#锚点` 在页内滚动。

#### 3.3.1 在 PC 上复现 / 排查词典渲染问题
`webview_flutter` 没有 Windows 桌面实现，且本项目没有 `windows/` 平台，所以 App 在 PC 上跑不起来。排查渲染问题时用「导出页面 + 无头 Chrome 截图」，不需要真机：

1. 导出 App 实际交给 WebView 的页面（读本地 `data_download/` 里的 `.mdx/.mdd`，缺文件时测试自动跳过）：
   ```bash
   flutter test test/render/longman_page_export_test.dart   # 生成 build/render/longman_page.html
   ```
   想换词 / 换词典，改该测试里的 `lookupDefinition('test')` 与 `_base` 路径。
2. 用无头 Chrome 截图（Windows 路径示例，窗口尺寸按手机横屏词典面板宽度约 500 设置）：
   ```bash
   "/c/Program Files/Google/Chrome/Application/chrome.exe" --headless=new --disable-gpu --hide-scrollbars \
     --window-size=500,1400 --screenshot="C:\temp\english\build\render\longman_after.png" \
     "file:///C:/temp/english/build/render/longman_page.html"
   ```
3. 看 `build/render/longman_after.png`。截图是静态的，看不到点击交互（展开/收起、弹出菜单）：这类用 Chrome 直接打开 `longman_page.html` 手动点；真机上的最终表现仍以 `flutter run` 为准。
4. 对照基线：`flutter test test/render/longman_render_test.dart` 会按旧方案（`flutter_widget_from_html`）渲染并输出 `build/render/longman_before.png`，用来说明为什么不能退回去。
5. 排查要点：先看导出的 HTML 里 CSS/JS/图片是否已内联（页面构建器的测试断言了这三点）；样式不对时先在 Chrome 里确认是词典自身 CSS 还是 `darkOverrideCss` 覆盖导致。

`build/` 已在 `.gitignore` 中，截图与导出页面不会入库。

### 3.4 跨平台目录管理规范 (Android vs Windows/Desktop)
为杜绝 Android 上因工作目录只读或权限不足导致的 `FileSystemException: Cannot create directory (errno = 13)`，项目中涉及文件存储与探测时严格遵循跨平台分层策略：
- **音频下载缓存 (`english-sounds/`)**：
  - **Android**：优先 `Download/english/sounds/`（`StoragePermissionService.getPublicAppDirectories()`，与词库同一父目录；写入前做可写探测），无权限时退回应用沙盒；旧版沙盒缓存仍可读取；
  - **iOS / Android 无权限降级**：严禁硬编码相对路径，通过 `path_provider` 调用 `getApplicationSupportDirectory()`，存入应用专属沙盒路径（`.../app_flutter/english-sounds`），无需高危外部存储权限，系统安全可写且卸载时自动清理；异常时降级至 `Directory.systemTemp`；
  - **Windows / Desktop**：优先探测项目工作区 `data_download/english-sounds`（便于本地开发与持久化检查），若不存在则使用系统文档目录 `getApplicationDocumentsDirectory()/english-sounds`。
- **离线词典探测 (`ecdict-ultimate.db`, `.mdx`, `.mdd`)**：
  - **分层探测优先级**：
    1. 用户自定义路径（通过 UI 选取并由 `SharedPreferences` 持久化 `custom_ecdict_path`）；
    2. 桌面环境探测：相对开发路径 `data_download/...`；
    3. 移动端/Android 规范探测：通过原生 `MethodChannel` (`StoragePermissionService`) 动态解析权威主下载目录 `Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)` 以及外置 SD 卡 `StorageManager.storageVolumes` 下的 `Download/` 目录，**并且只读其下的 `english/` 子目录**（`Download/english/`），不再扫描 Download 根目录，避免文件散放；
    4. 常见系统路径兜底：`/storage/emulated/0/Download/english`、`/sdcard/Download/english`；
    5. 应用沙盒外部与内部文档目录：`getDownloadsDirectory()`、`getApplicationDocumentsDirectory()`、`getApplicationSupportDirectory()`。

### 3.5 4级发音调度管道 (`DictionaryAudioService`)
彻底杜绝手机文件系统中产生数万个散落 MP3 碎文件的弊端：
1. **第 1 级（MDD 离线容器，优先推荐）**：优先从 `Sound_us_uk.mdd` 或词典自带 MDD 中获取美音/英音（支持 `\word.spx`, `\word_uk.spx`, `\word.mp3`），取出二进制音频流写入临时播放缓存播放；
2. **第 2 级（本地散装 MP3 缓存，Android 在 `Download/english/sounds/`）**：检测跨平台安全缓存目录下的 `${word}_${accent}.mp3`；
3. **第 3 级（在线有道开放 API）**：若本地缺失且有网络，自动拉取有道音频并持久化保存到安全缓存目录；
4. **第 4 级（系统 TTS 保底）**：断网且完全无离线资源时降级回退至 `flutter_tts` 本地语音合成。

---

## 4. 常用开发与构建命令

本项目已配置国内镜像源（`pub.flutter-io.cn`、阿里云与国内 Gradle 镜像）。

```bash
# 获取依赖
flutter pub get

# 静态代码检查 (严格确保 0 errors, 0 warnings)
flutter analyze

# 运行全量测试套件 (包含播放器控制、波形采样、ECDICT 搜索、MDict 纯 Dart 引擎与词典浮层 UI 测试)
flutter test

# 单独运行特定测试文件
flutter test test/widget_test.dart
flutter test test/services/mdict_reader_test.dart
flutter test test/services/mdict_manager_service_test.dart
flutter test test/ui/dictionary/dict_pack_panel_host_test.dart
flutter test test/ui/dictionary/dict_pack_manager_dialog_test.dart   # 含横屏矮屏 overflow 回归
flutter test test/integration/dictionary_lookup_integration_test.dart

# 本地调试运行 (支持真机/桌面热重载 'r')
flutter run
```

---

## 5. 编辑文件注意事项：保持 LF 换行符

仓库内文件均为 **LF** 换行（`git ls-files --eol` 显示 `i/lf w/lf`），且未配置 `.gitattributes`。在 Windows 上用脚本批量改文件时，换行符很容易被悄悄改成 CRLF，导致 `git diff` 把整个文件都标成改动、真实改动被淹没。

- **首选 `Edit` / `Write` 工具改文件**，不要用脚本改源码；它们会保持原有换行符。
- **必须用 Python 时**：Windows 下文本模式 `open(p, 'w')` 会把 `\n` 写成 `\r\n`。读写都要显式带 `newline=''`，或用二进制读写：
  ```python
  s = open(p, encoding='utf-8', newline='').read()
  # ... 替换 ...
  open(p, 'w', encoding='utf-8', newline='').write(s)
  ```
- **用 `sed -i` 替换文本**通常安全（不改换行符）；不要用 `sed 's/$/\r/'` 之类的命令。
- **改完必须自检**：`git diff --stat` 里若某个文件改动行数远超实际修改量（几乎整文件都是增删），就是换行符被改了。修复方式：`sed -i 's/\r$//' <文件>` 转回 LF，再看 `git diff --stat` 恢复正常。
- 新建文件同样使用 LF。
