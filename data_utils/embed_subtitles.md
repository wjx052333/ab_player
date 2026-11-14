### MP3 内嵌字幕（离线 STT，不在端上识别）
- **思路**：识别在 PC 上一次做完，字幕嵌进 MP3 的 ID3 标签，App 只负责读取显示，不做端上 STT。
- **PC 脚本** `data_utils/embed_subtitles.py`：用 faster-whisper 识别（默认 `small.en`，带逐词时间戳），或 `--srt` 导入现成字幕，写入 ID3v2.4 两个帧：标准 `SYLT`（按句同步歌词，通用播放器也能显示）和 `TXXX:SUBTITLE_JSON`（App 读这个）。
  - JSON 格式：`{"v":1,"lang":"en","sentences":[{"s":0.52,"e":3.10,"t":"Hello there.","w":[[0.52,0.80,"Hello"],...]}]}`，时间单位秒，`w` 为逐词时间戳（App 目前未用）。
  - 默认输出 `xxx.sub.mp3`；`--inplace` 改原文件（首次先备份 `.mp3.bak`）；`--show` 回读已嵌入字幕；`--dry-run` 只打印；传目录则批量处理（含所有子目录），已有字幕的跳过（`--force` 重做）。
  - 依赖 `pip install mutagen faster-whisper miniaudio numpy`。音频由 miniaudio 解码成 16kHz 单声道再喂给 Whisper，不依赖 ffmpeg / PyAV（新版 `av` 与 faster-whisper 不兼容，会报 `metadata_errors`）。国内加 pip 参数 `-i https://pypi.tuna.tsinghua.edu.cn/simple`（默认源极慢），模型下载连不上时设 `HF_ENDPOINT=https://hf-mirror.com`。
- **App 读取**：选音频后 `SubtitleReader.readFile` 只读文件开头的 ID3 标签（支持 v2.3/v2.4、UTF-8/UTF-16、标签级 unsynchronisation），无标签/无该帧/JSON 损坏都当作无字幕，不显示、不报错。字幕存在 `AudioTrack.subtitles`，重新断句时要保留。
- **显示**：`AudacityWaveformPainter._drawSubtitles` 把每句字幕直接叠画在波形上它自己的时间区间内，从标尺下沿向下多行排布，最多占波形区上半部分，放不下在最后一行以 `...` 截断；字号 `subtitleFontSize`（11），当前播放句高亮白色，区间太窄（<12px）的句子不显示。不占单独一行。
- **局限**：字幕按 Whisper 自己的时间区间显示，与波形断句（`SpeechSegmenter`）不一一对应——Whisper 句数常比波形断句少（`L212026.mp3` 上 base.en 17 句、small.en 7 句，波形断出 19 段），且词级时间戳比实际发声偏早约 0.3s。这个对齐问题暂未解决，字幕点击/选句/逐词查词也还没做。