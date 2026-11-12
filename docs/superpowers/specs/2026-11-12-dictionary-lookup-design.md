# 离线词典查词工作台设计规范 (Dictionary Lookup Workbench)

## 1. 概述与设计背景
本项目基于已有的 Audacity 风格 Android/桌面端横屏英语播放器，扩展横屏双栏英语查词工作台。利用本地现有的 `ecdict-ultimate.db`（1.2GB，340 万词条）、`LongmanDictionaryOfContemporaryEnglish6thEnEn.mdx`（朗文第6版）、`oxfordPrimary.mdx`（牛津初阶）及 `Sound_us_uk.mdd`（真人美音/英音音频库），构建具备前缀联想、升学词汇加权置顶、双列横屏大词卡、权威双语例句（牛津/朗文）与离线/在线混合发音能力的查词引擎。

---

## 2. 核心架构与数据流

```
                                 [ 用户输入查询 ]
                                        │
                                        ▼ (200ms 防抖)
                      [ DictionaryDbService (本地 SQLite) ]
                     ┌──────────────────┴──────────────────┐
                     ▼                                     ▼
         [ ecdict-ultimate.db (只读) ]            [ dict_extra.db (例句库) ]
      - 340万词汇前缀匹配 (sd_1 索引)                - 牛津初阶例句 (oxford)
      - zk (中小学)/cet4 (四级) 优先置顶             - 朗文当代例句 (longman)
      - 核心中英释义 / 词形变化
                     │                                     │
                     └──────────────────┬──────────────────┘
                                        ▼
                            [ 组装 DictWordDetail ]
                                        │
                                        ▼
                       [ DictionaryAudioService 发音调度 ]
                     ┌──────────────────┼──────────────────┐
                     ▼ (第1层: 本地离线)   ▼ (第2层: 有道拉取)   ▼ (第3层: 保底)
           [ english-sounds/*.mp3 ]   [ 有道开放 API ]       [ 系统 TTS 朗读 ]
           (来自 Sound_us_uk 解包)     (下载并持久化缓存)      (无网且无音频时)
                                        │
                                        ▼
                         [ 横屏 35:65 双栏工作台界面 ]
```

---

## 3. 数据预处理流程与数据结构 (`data_utils/`)

在项目根目录设立 `data_utils/` 目录，存放预处理脚本；生成的数据资产存放在 `data_download/` 目录：

### 3.1 预处理脚本规划
1. **`extract_oxford.py`**：解压并解析 `oxfordPrimary.mdx`，提取牛津初阶词汇的中英文浅显例句与基础定义。
2. **`extract_longman.py`**：解析 `LongmanDictionaryOfContemporaryEnglish6thEnEn.mdx`，清洗提取朗文当代的高品质语料库典型例句与习惯搭配。
3. **`extract_sounds.py`**：从 `Sound_us_uk.mdd` 中解包高频词的真人音频，按 `${word}_us.mp3` 与 `${word}_uk.mp3` 标准化重命名至 `data_download/english-sounds/`。
4. **`build_dict_extra.py`**：将牛津与朗文例句整合写入轻量 SQLite 数据库 `data_download/dict_extra.db`。

### 3.2 数据库 Schema

#### `data_download/dict_extra.db`
```sql
CREATE TABLE IF NOT EXISTS examples (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    word VARCHAR(64) COLLATE NOCASE NOT NULL,
    source VARCHAR(16) NOT NULL, -- 'oxford' 或 'longman'
    en_text TEXT NOT NULL,
    cn_text TEXT,
    order_index INTEGER DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_examples_word ON examples (word COLLATE NOCASE);
```

#### `data_download/ecdict-ultimate.db`（原生保留）
* 查询主要字段：`word`, `phonetic`, `translation`, `definition`, `tag`, `collins`, `oxford`, `exchange`, `frq`。

---

## 4. 业务逻辑与服务层设计 (Services & Models)

### 4.1 数据模型 (`lib/models/dictionary/`)
* **`DictWordSummary`**：左侧联想列表轻量展示。
  * `String word`
  * `String phonetic`
  * `String briefTranslation`（单行截断精简释义）
  * `List<String> tags`（`zk`, `gk`, `cet4`, `cet6`, `ky` 等）
  * `int collins`（星级 0~5）
* **`DictExample`**：权威例句模型。
  * `String source`（`oxford` / `longman`）
  * `String enText`
  * `String? cnText`
* **`DictWordDetail`**：词卡完整信息。
  * 包含 `DictWordSummary` 所有属性；
  * `List<String> fullTranslations`（按词性结构化的中文释义）；
  * `String definition`（英文释义）；
  * `Map<String, String> exchanges`（复数/过去式/进行时等映射）；
  * `List<DictExample> examples`（牛津与朗文例句集合）。

### 4.2 词典数据库服务 (`DictionaryDbService`)
* **路径自适应探测策略**：
  1. 探测 `data_download/ecdict-ultimate.db`（桌面开发环境）；
  2. 探测 `path_provider` 系统下载目录（Android/移动端）；
  3. 支持手动选择并持久化记录路径。
* **搜索匹配与升学权重排序规则**：
  * SQL 前缀查询：`WHERE word LIKE ? COLLATE NOCASE`
  * 排序权重算法：
    ```sql
    ORDER BY
      CASE WHEN word = ? COLLATE NOCASE THEN 0 ELSE 1 END,
      CASE
        WHEN tag LIKE '%zk%' THEN 1
        WHEN tag LIKE '%cet4%' THEN 2
        WHEN tag LIKE '%cet6%' THEN 3
        WHEN tag LIKE '%gk%' THEN 4
        ELSE 5
      END,
      collins DESC,
      CASE WHEN frq > 0 THEN frq ELSE 999999 END ASC
    LIMIT 40;
    ```

### 4.3 发音与音频调度服务 (`DictionaryAudioService`)
* **发音解析管道**：
  * 输入：`word`、`accent` (`us` 或 `uk`)
  * 步骤 1：探测本地 `data_download/english-sounds/${word}_${accent}.mp3`；若存在，`just_audio` 立即播放；
  * 步骤 2：若不存在，向有道 API 发送 GET 请求（`https://dict.youdao.com/dictvoice?audio=${word}&type=${accent == 'uk' ? 1 : 2}`），下载二进制流并持久化至 `english-sounds/` 目录，随后调用 `just_audio` 播放；
  * 步骤 3：若网络异常或无返回，降级调用系统 TTS 引擎完成本地语音合成朗读。
* **例句发音支持**：
  * 支持直接传入整句文本，调用系统 TTS 进行高清例句朗读。

---

## 5. UI 布局与交互体验设计 (Landscape UI)

### 5.1 顶部导航与模块切换
* 在全局 32dp 顶部栏嵌入分段按钮：`[ 🎧 播放器 ]` ⟷ `[ 📖 词典 ]`。
* 右侧提供当前词典库状态指示徽章（例如：`词库: 340万词 + 权威例句`）及自定义文件路径切换入口。

### 5.2 查词工作台双栏结构 (35% : 65%)

```
+-----------------------------------------------------------------------------------------+
| [🎧 播放器 | 📖 词典]   词典库状态: 已就绪 (ecdict + 权威例句库)             [ 📁 切换路径 ]   | (顶栏 32dp)
+-----------------------------------+-----------------------------------------------------+
| [🔍 输入英文查词...     ] (带清除按钮) |  [WORD]  test        /test/     [US 🔊]  [UK 🔊]    |
+-----------------------------------+  [🏷️ 中考] [🏷️ 四级] [🏷️ 六级]      ⭐⭐⭐⭐⭐ (星级) |
| · test                /test/      +--------------------------+--------------------------+
|   n. 试验；检验                    | 【核心释义 & 词形变化】    | 【权威双语例句】 (牛津/朗文) |
|                                   |                          |                          |
| · tester              /'testə/    |  n.                      | 📘 [牛津初阶]        [🔊] |
|   n. 测试员；试验仪                |  · 试验；检验             |  This test is very easy. |
|                                   |  · 考卷；化验             |  这次测试非常简单。       |
| · testing             /'testɪŋ/   |                          |                          |
|   n. 测试 adj. 试验的              |  vt.                     | 📙 [朗文当代]        [🔊] |
|                                   |  · 测验；检验             |  The new drug is         |
| · testify             /'testɪfaɪ/ |                          |  undergoing clinical     |
|   v. 证明；作证                    | 【词形变形】              |  trials.                 |
|                                   |  复数: tests             |  新药正在进行临床试验。   |
| (前缀联想列表，升学高频词优先置顶)  |  过去式: tested           |                          |
+-----------------------------------+--------------------------+--------------------------+
```

1. **左侧检索栏（35% 宽）**：
   * 顶部常驻搜索框，内置放大镜图标、文字清除按钮及防抖查询触发机制；
   * 搜索结果列表项采用紧凑两行排版（首行粗体词名 + 浅灰音标；次行单行高对比度中文核心词义）。
2. **右侧横屏词卡（65% 宽）**：
   * **头部面**：28sp 醒目大词名、国际音标、`[US 🔊]` 和 `[UK 🔊]` 胶囊点按发音按钮、升学彩色徽章（`中考`/`四级`/`六级`等）、柯林斯金黄色星级；
   * **双子列主体**：
     * **左子列（核心释义与形态）**：按词性分组卡片式排版中文释义，附带复数、过去式等词形变形徽章，底部可折叠查看英文释义；
     * **右子列（权威例句专区）**：按 **📘 牛津初阶** 与 **📙 朗文当代** 明确卡片分组展示。每条例句配备独立发音按钮 `[🔊]`，英文句子中自动加粗高亮目标词，中文译文附于其后。

---

## 6. 测试与验证计划
1. **数据预处理脚本测试**：验证 `extract_oxford.py`、`extract_longman.py`、`extract_sounds.py` 输出格式正确性及 `dict_extra.db` 索引性能。
2. **数据库服务单元测试**：测试前缀联想速度、升学词汇权重排序（`zk`/`cet4` 优先排前）、词形变形解析逻辑。
3. **音频管道测试**：测试本地文件播放、有道接口下载缓存与断网系统 TTS 降级回落。
4. **横屏 UI 渲染测试**：在不同横屏屏幕尺寸下测试双栏布局与双子列滚动，确保无溢出风险并完全兼容 Audacity 暗色主题。
