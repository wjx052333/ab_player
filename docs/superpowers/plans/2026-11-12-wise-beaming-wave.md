# 路线2：纯原生 Dart MDX/MDD 解析引擎与可扩展多词典 Tab 架构实施方案

## 1. 业务背景与设计目标 (Context)

用户要求采用**路线2（在客户端直接挂载与读取原生 `.mdx` / `.mdd` 容器）**，并对查词工作台右侧区域进行架构扩展：
1. **快慢双列分工**：
   - **左子列（快速渲染）**：保持目前基于 `ecdict-ultimate.db` SQLite 的毫秒级核心中文释义、词形变形与考点标签快速展示。
   - **右子列（权威多词典 Tab 页）**：改造为动态多 Tab 视图。每一个 Tab 对应用户加载的一套 `.mdx` + `.mdd` 词典包（例如当前已有的“牛津小学双语”、“朗文当代第6版”，以及后续随时挂载的“牛津第10版”、“柯林斯高阶”等）。
2. **完全可扩展与热插拔**：
   - 用户可以随时加载、卸载或切换任意数量的 MDX/MDD 词典文件，随加随用；
   - 启动时自动探测本地 `data_download/` 现有词典目录并就绪；
   - 记录用户自定义挂载的词典列表与排序（`SharedPreferences` 持久化）。
3. **原生 MDD 音频多级调度**：
   - 发音时优先检索原生 `.mdd` 音频包（如 `Sound_us_uk.mdd` 或词典自带的 `.mdd`），直接读取并播放，无需解压成数万个碎文件；若未匹配则平滑回退至有道 API 下载缓存与系统 TTS。

---

## 2. 核心架构设计 (Architecture)

```
                            [ 用户查词: word ]
                                    │
           ┌────────────────────────┴────────────────────────┐
           ▼                                                 ▼
[ DictionaryDbService (SQLite) ]                   [ MDictManagerService ]
   ecdict-ultimate.db 快速查询                       多词典管理器 (管理 N 个词典包)
   - 国际音标 / 升学考点标签                          ┌─────────────────┴─────────────────┐
   - 核心中文释义 / 词形变形                          ▼                                   ▼
           │                                [ Oxford Primary ]                 [ Longman 6th ]
           │                                 .mdx + .mdd + .css                 .mdx + .mdd + .css
           │                                         │                                   │
           │                                         └─────────────────┬─────────────────┘
           │                                                           ▼
           │                                                [ 词条 HTML / 例句富文本 ]
           │                                                           │
           ▼                                                           ▼
[ 左子列 (ECDICT 核心速查 45%) ]                       [ 右子列 (动态多 Tab 权威词典 55%) ]
- 中文词性归纳卡片                                     TabBar: [ 📘 牛津初阶 | 📙 朗文当代 | ➕ 管理 ]
- 过去式/复数/进行时变形                                TabBarView:
- 英文精简释义                                          - 注入专属 CSS 样式并暗黑主题自适应
                                                       - 拦截 sound:// 点击播放 MDD 音频
                                                       - 拦截 entry:// 点击跨词跳转
```

---

## 3. 模块拆解与具体实现步骤

### 模块 A：纯 Dart 原生 MDX / MDD 二进制引擎 (`lib/services/mdict/`)

无需任何 C/C++ 或 Python 依赖，基于 `dart:io` 的 `RandomAccessFile` 与 `dart:io` 的 `ZLibDecoder` 实现对数以 GB 计大文件的低内存、毫秒级随机读取。

1. **`lib/services/mdict/mdict_crypto.dart`**：
   - MDict v2.0 `Encrypted="2"` 解密套件：
     - 纯 Dart 完整实现 64 轮的 `ripemd128(Uint8List message)` 摘要计算；
     - 实现 `fastDecrypt(Uint8List data, Uint8List key)` 异或混淆解密算法，用于解密 key block info 索引块。
2. **`lib/services/mdict/mdict_header.dart`**：
   - 提取文件头 4 字节大端长度 + UTF-16LE XML 字符串；
   - 解析 `GeneratedByEngineVersion`（"2.0" 使用 64 位整型）、`Encrypted`、`Encoding`、`Title`、`Description`。
   - 自动确定编码（MDX 默认 UTF-8，MDD 资源文件路径默认 UTF-16LE）。
3. **`lib/services/mdict/mdict_reader.dart`**：
   - 采用 `RandomAccessFile` 随机寻道定位；
   - 内存只保留轻量级的 Key Block Info 索引表（每个块几十字节，25 万词条的索引仅占几十 KB 内存）；
   - **二分查找**：对查询词先在索引表中二分查找命中目标 Key Block，按需读取该单个块（32KB）解压，再块内二分查出 `recordOffset` 与 `recordLength`；
   - **记录解压**：根据 `recordOffset` 定位对应 Record Block，解压获取 HTML 释义字符串（`.mdx`）或二进制原始音频/图片数据（`.mdd`）；
   - 内置轻量 LRU 块级缓存，避免高频二次 I/O。

### 模块 B：词典包模型与多词典管理服务 (`lib/services/mdict/`)

1. **`lib/services/mdict/mdict_dictionary_pack.dart`**：
   - 词典包封装：包含 `id`, `title`, `.mdx` Reader, 可选同名 `.mdd` Reader, 可选 `.css` 样式内容；
   - 提供 `lookupDefinition(String word)` 与 `lookupResource(String resourcePath)`；
   - 提供暗色主题 CSS 适配能力（自动校正硬编码黑色文字为 Audacity 柔和浅灰）。
2. **`lib/services/mdict/mdict_manager_service.dart`**：
   - **自动发现**：启动时扫描 `data_download/` 及 App Documents 目录，自动挂载存在的词典包：
     - `data_download/oxfordPrimary/oxfordPrimary.mdx`（牛津初阶）
     - `data_download/LongmanDictionaryOfContemporaryEnglish6thEnEn/LongmanDictionaryOfContemporaryEnglish6thEnEn.mdx`（朗文第6版）
     - `data_download/Sound_us_uk/Sound_us_uk.mdd`（发音专库）
   - **动态扩容接口**：
     - `addPackFromFiles({required String mdxPath, String? mddPath, String? cssPath})`
     - `removePack(String id)`
     - `togglePackEnabled(String id, bool enabled)`
     - `reorderPacks(List<String> orderedIds)`
   - **持久化记录**：使用 `SharedPreferences` 保存用户自定义外挂词典的路径和启用状态，热启/冷启自恢复。
   - **音视频提取**：提供统一的 `getAudioBytes(String word, {String accent = 'us'})` 接口，自动遍历已挂载的 `.mdd` 资源。

### 模块 C：音频服务升级与 MDD 优先调度 (`lib/services/dictionary_audio_service.dart`)

将已有的 3 级发音管道升级为 **4 级管道（MDD 优先）**：
- **第 1 级（MDD 离线容器）**：优先从 `MDictManagerService` 中检索 `Sound_us_uk.mdd` 及各词典 companion `.mdd` 中的音频记录（支持 `\word.spx`, `\word_uk.spx`, `\word.mp3`, `\word_us.mp3`），取出字节流直接播放；
- **第 2 级（本地散装 MP3 缓存）**：检测 `english-sounds/${word}_${accent}.mp3`；
- **第 3 级（在线有道 API）**：联网拉取并自动持久化缓存到本地；
- **第 4 级（系统 TTS 保底）**：断网且无音频时由系统合成朗读。

### 模块 D：UI 重构 —— 动态多 Tab 权威词典工作台

1. **引入 HTML 渲染组件**：
   - 在 `pubspec.yaml` 中添加 `flutter_widget_from_html: ^0.15.3`，提供原生高性能 HTML 解析，支持 CSS 自定义和 `onTapUrl` 链接点击拦截。
2. **新建 `lib/ui/dictionary/widgets/dict_tabs_column.dart`**：
   - 接收当前已激活的 `List<MDictDictionaryPack>` 与目标查询词；
   - 头部渲染可滑动的 Audacity 金属灰风格 `TabBar`：每个 Tab 显示词典标题（如 `📘 牛津初阶`、`📙 朗文当代`），末尾保留 `[ ➕ 管理 ]` 胶囊按钮；
   - `TabBarView` 动态生成各词典的释义视图：
     - 若该词典有词条：嵌入词典 `.css`，渲染权威图文排版；
     - 拦截 `sound://...` 点击：调用 `audioService` 播放 MDD 原声；
     - 拦截 `entry://...` 点击：联动左侧快速切换查词；
     - 若该词典未收录该词：呈现柔和提示“该词典未收录此词条”。
3. **新建 `lib/ui/dictionary/widgets/dict_pack_manager_dialog.dart`**：
   - 词典管理对话框：展示当前所有挂载词典的条目数与状态；
   - 支持勾选启用/禁用、拖拽调整 Tab 前后顺序；
   - 提供 `[ 📁 导入外部 MDX 词典 ]` 按钮，调用 `FilePicker`，用户选择任何本地 `.mdx` 即可自动配对同名 `.mdd` 和 `.css` 并挂载为全新 Tab！
4. **改造 `lib/ui/dictionary/dictionary_screen.dart`**：
   - 注入并初始化 `MDictManagerService`；
   - 将右侧主体由原来的固定 50:50 示例列，调整为：
     - **左子列（45%）**：`DictMeaningColumn`（ECDICT 中文核心释义、词形变形、英文定义）；
     - **右子列（55%）**：`DictTabsColumn`（动态多 Tab 权威词典群）；
   - 顶部状态栏增加当前挂载词典数量指示徽章与快速管理入口。

---

## 4. 关键文件清单与改动点

| 文件路径 | 状态 | 职责 |
| :--- | :--- | :--- |
| `lib/services/mdict/mdict_crypto.dart` | **新建** | 纯 Dart RIPEMD-128 摘要算法与 MDict 快速解密函数 |
| `lib/services/mdict/mdict_header.dart` | **新建** | XML 字典头解析模型 |
| `lib/services/mdict/mdict_reader.dart` | **新建** | 核心二进制 RandomAccess 寻道、二分查找与块解压引擎 |
| `lib/services/mdict/mdict_dictionary_pack.dart` | **新建** | 词典包抽象（MDX + MDD + CSS + 暗黑样式修正） |
| `lib/services/mdict/mdict_manager_service.dart` | **新建** | 多词典动态加载、探测、热插拔管理与音频提取调度 |
| `lib/services/dictionary_audio_service.dart` | **修改** | 集成 MDD 优先发音调度（MDD -> 本地缓存 -> 有道 -> TTS） |
| `lib/ui/dictionary/widgets/dict_tabs_column.dart` | **新建** | 右子列可扩展动态 Tab 栏与 HTML 内容渲染组件 |
| `lib/ui/dictionary/widgets/dict_pack_manager_dialog.dart` | **新建** | 词典包管理、启停、排序与自定义外部词典导入弹窗 |
| `lib/ui/dictionary/dictionary_screen.dart` | **修改** | 组装 MDict 管理服务，渲染双子列（左 ECDICT，右 MDict Tabs） |
| `pubspec.yaml` | **修改** | 添加 `flutter_widget_from_html: ^0.15.3` |

---

## 5. 测试与验证计划 (Verification Plan)

1. **纯 Dart MDict 二进制读取单元测试** (`test/services/mdict_reader_test.dart`)：
   - 测试 `oxfordPrimary.mdx` 文件头解析（版本、词条数、标题）；
   - 测试单词索引二分检索与定义解密，验证查询 `test`、`apple` 能正确获取原始 HTML 文本；
   - 测试 `Sound_us_uk.mdd` 资源定位，验证查询 `\test.spx` 能正确解出非空音频字节流。
2. **多词典包管理与动态切换测试** (`test/services/mdict_manager_service_test.dart`)：
   - 模拟加载 1 个、2 个及动态增加新词典包；
   - 测试禁用/启用指定词典包对查询结果的过滤；
   - 测试 `SharedPreferences` 保存与恢复配置。
3. **工作台 UI 与 Tab 页渲染组件测试** (`test/ui/dictionary/dict_tabs_column_test.dart`)：
   - 验证多 Tab 标签生成与切换；
   - 验证点击管理按钮能呼出词典管理弹窗；
   - 验证在横屏模式下与左子列 `DictMeaningColumn` 并排不发生 RenderFlex Overflow 溢出。
4. **全量静态检查与回归测试**：
   - 执行 `flutter analyze` 确保 0 errors, 0 warnings；
   - 执行 `flutter test` 确保所有既有音频播放器测试和新增词典测试 100% 通过。
