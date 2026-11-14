"""在 PC 上离线识别英语音频并把字幕嵌入 MP3 的 ID3 标签，App 播放时直接读取，无需端上 STT。

写入两个标准 ID3v2.4 帧：
  1. SYLT  (同步歌词)：每句一行 [(文本, 起点毫秒)]，通用播放器也能显示；
  2. TXXX:SUBTITLE_JSON：App 读取的完整数据，含句子起止与逐词时间戳：
       {"v":1,"lang":"en","sentences":[{"s":0.52,"e":3.10,"t":"Hello there.",
         "w":[[0.52,0.80,"Hello"],[0.84,1.20,"there."]]}]}
     时间单位为秒，词的文本保留 Whisper 原样（含标点），便于直接展示。

字幕来源二选一：
  * 识别：faster-whisper (CTranslate2，CPU 可跑，GPU 更快)，首次运行会下载模型；
  * 已有字幕：--srt 文件 / --text 纯文本（按 --srt 的时间，或 --text 配合 Whisper 的时间做校正暂不支持）。

依赖：pip install mutagen faster-whisper miniaudio numpy     （--srt 模式只需 mutagen）
  音频由 miniaudio 解码成 16kHz 单声道再交给 Whisper，不依赖 ffmpeg / PyAV (新版 av 与 faster-whisper 不兼容)。
  国内下载慢可加 pip 参数 -i https://pypi.tuna.tsinghua.edu.cn/simple ；Whisper 模型从 HuggingFace 下载，
  连不上时先设置环境变量 HF_ENDPOINT=https://hf-mirror.com
  $env:HF_ENDPOINT="https://hf-mirror.com"
用法：
  python data_utils/embed_subtitles.py data_download/L212026.mp3                  # 识别并写入 data_download/L212026.sub.mp3
  python data_utils/embed_subtitles.py data_download/L212026.mp3 --inplace        # 直接改原文件 (先备份为 .mp3.bak)
  python data_utils/embed_subtitles.py a.mp3 --model small.en --device cuda
  python data_utils/embed_subtitles.py a.mp3 --srt a.srt --inplace                # 用现成字幕
  python data_utils/embed_subtitles.py a.mp3 --dry-run                            # 只打印，不写文件
  python data_utils/embed_subtitles.py a.mp3 --show                               # 查看已嵌入的字幕
  python data_utils/embed_subtitles.py data_download --inplace                    # 批量：目录及其所有子目录下的 mp3，已有字幕的跳过 (--force 重做)

模型选择：tiny.en/base.en 快但漏词；small.en 是精听材料的性价比点；medium.en/large-v3 最准最慢。
"""
import argparse
import functools
import json
import re
import shutil
import sys
from pathlib import Path

SUBTITLE_FRAME = 'TXXX:SUBTITLE_JSON'
SYLT_DESC = 'subtitles'


def load_audio_16k(path):
    """解码成 Whisper 需要的 16kHz 单声道 float32"""
    import miniaudio
    import numpy as np

    # 由 Python 读字节再解码：miniaudio.decode_file 在 Windows 上打不开含中文等非 ASCII 的路径 (报 -7)
    d = miniaudio.decode(
        Path(path).read_bytes(), output_format=miniaudio.SampleFormat.SIGNED16, nchannels=1, sample_rate=16000
    )
    return np.asarray(d.samples, dtype=np.float32) / 32768.0


@functools.lru_cache(maxsize=1)
def load_model(model_name, device, compute_type):
    """批量处理时只加载一次模型"""
    from faster_whisper import WhisperModel

    print(f'加载模型 {model_name} ({device}) ...', file=sys.stderr)
    return WhisperModel(model_name, device=device, compute_type=compute_type)


def transcribe(path, model_name, device, compute_type, language, beam_size):
    model = load_model(model_name, device, compute_type)
    segments, info = model.transcribe(
        load_audio_16k(path),
        language=language,
        word_timestamps=True,
        beam_size=beam_size,
        vad_filter=True,  # 滤掉长静音，减少幻觉
        condition_on_previous_text=False,  # 精听材料句间独立，避免重复幻觉扩散
    )
    total = info.duration or 0
    out = []
    for seg in segments:
        text = seg.text.strip()
        if not text:
            continue
        words = [[round(w.start, 3), round(w.end, 3), w.word.strip()] for w in (seg.words or []) if w.word.strip()]
        # 句子边界取词级时间戳，比 segment 自带的边界更贴合发声
        s = words[0][0] if words else seg.start
        e = words[-1][1] if words else seg.end
        out.append({'s': round(s, 3), 'e': round(e, 3), 't': text, 'w': words})
        if total:
            print(f'\r识别中 {min(seg.end / total, 1) * 100:5.1f}%', end='', file=sys.stderr, flush=True)
    print(file=sys.stderr)
    return out, info.language


_SRT_TIME = re.compile(r'(\d+):(\d+):(\d+)[,.](\d+)')


def _srt_seconds(s):
    h, m, sec, ms = _SRT_TIME.match(s.strip()).groups()
    return int(h) * 3600 + int(m) * 60 + int(sec) + int(ms.ljust(3, '0')[:3]) / 1000


def parse_srt(path):
    raw = Path(path).read_text(encoding='utf-8-sig')
    out = []
    for block in re.split(r'\r?\n\s*\r?\n', raw.strip()):
        lines = [ln for ln in block.splitlines() if ln.strip()]
        idx = next((i for i, ln in enumerate(lines) if '-->' in ln), None)
        if idx is None:
            continue
        a, b = lines[idx].split('-->')
        text = ' '.join(ln.strip() for ln in lines[idx + 1 :])
        text = re.sub(r'<[^>]+>', '', text).strip()  # 去掉 <i> 等标签
        if text:
            s, e = _srt_seconds(a), _srt_seconds(b.split()[0])
            out.append({'s': round(s, 3), 'e': round(e, 3), 't': text, 'w': _spread_words(text, s, e)})
    return out


def _spread_words(text, s, e):
    """SRT 没有逐词时间：按字符数比例把句子时间均分给各词 (近似值，仅供词高亮)"""
    words = text.split()
    total = sum(len(w) for w in words) or 1
    t, out = s, []
    for w in words:
        d = (e - s) * len(w) / total
        out.append([round(t, 3), round(t + d, 3), w])
        t += d
    return out


def embed(src, dst, sentences, lang):
    from mutagen.id3 import ID3, ID3NoHeaderError, SYLT, TXXX, Encoding

    if Path(dst) != Path(src):
        shutil.copyfile(src, dst)
    try:
        tags = ID3(dst)
    except ID3NoHeaderError:
        tags = ID3()
    tags.delall('SYLT')
    tags.delall(SUBTITLE_FRAME)

    iso_lang = {'en': 'eng', 'zh': 'zho'}.get(lang, 'eng')
    tags.add(
        SYLT(
            encoding=Encoding.UTF8,
            lang=iso_lang,
            format=2,  # 时间戳单位：毫秒
            type=1,  # 歌词
            desc=SYLT_DESC,
            text=[(s['t'], int(round(s['s'] * 1000))) for s in sentences],
        )
    )
    payload = json.dumps({'v': 1, 'lang': lang, 'sentences': sentences}, ensure_ascii=False, separators=(',', ':'))
    tags.add(TXXX(encoding=Encoding.UTF8, desc='SUBTITLE_JSON', text=payload))
    tags.save(dst, v2_version=4)


def read_embedded(path):
    from mutagen.id3 import ID3, ID3NoHeaderError

    try:
        tags = ID3(path)
    except ID3NoHeaderError:
        return None
    frame = tags.get(SUBTITLE_FRAME)
    return json.loads(frame.text[0]) if frame and frame.text else None


def print_sentences(sentences, with_words=False):
    for i, s in enumerate(sentences, 1):
        print(f'{i:3d}  {s["s"]:7.2f} - {s["e"]:7.2f}  {s["t"]}')
        if with_words:
            print('       ' + ' '.join(f'{w[2]}@{w[0]:.2f}' for w in s['w']))


def process(path, a):
    path = Path(path)
    if a.show:
        data = read_embedded(path)
        if not data:
            print(f'{path}: 无内嵌字幕')
            return
        print(f'{path}: {len(data["sentences"])} 句')
        print_sentences(data['sentences'], a.words)
        return

    if not a.force and not a.dry_run and read_embedded(path):
        print(f'{path}: 已有内嵌字幕，跳过 (--force 重做)')
        return

    if a.srt:
        sentences, lang = parse_srt(a.srt), a.language or 'en'
    else:
        sentences, lang = transcribe(path, a.model, a.device, a.compute_type, a.language, a.beam_size)

    print(f'{path}: 共 {len(sentences)} 句')
    if a.dry_run or a.words:
        print_sentences(sentences, a.words)
    if a.dry_run:
        return
    if not sentences:
        print('未识别到任何句子，不写入', file=sys.stderr)
        return

    if a.inplace:
        backup = path.with_suffix(path.suffix + '.bak')
        if not backup.exists():
            shutil.copyfile(path, backup)
        dst = path
    else:
        dst = path.with_suffix('.sub.mp3')
    embed(path, dst, sentences, lang)
    print(f'已写入 {dst}')


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('audio', help='mp3 文件，或包含 mp3 的目录')
    ap.add_argument('--inplace', action='store_true', help='直接改原文件 (首次会备份为 .mp3.bak)')
    ap.add_argument('--srt', help='使用现成 SRT 字幕而不是识别 (仅单文件)')
    ap.add_argument('--model', default='small.en', help='Whisper 模型，默认 small.en；多语言用 small/medium/large-v3')
    ap.add_argument('--language', default=None, help='语言代码，默认 .en 模型为 en，其他自动检测')
    ap.add_argument('--device', default='auto', help='auto/cpu/cuda')
    ap.add_argument('--compute-type', default='auto', help='auto (默认：CPU 用 int8，GPU 用 float16) / int8 / float16 / float32')
    ap.add_argument('--beam-size', type=int, default=5)
    ap.add_argument('--dry-run', action='store_true', help='只打印识别结果，不写文件')
    ap.add_argument('--show', action='store_true', help='查看已嵌入的字幕')
    ap.add_argument('--words', action='store_true', help='同时打印逐词时间戳')
    ap.add_argument('--force', action='store_true', help='已有内嵌字幕也重新生成')
    a = ap.parse_args()

    if a.language is None and a.model.endswith('.en'):
        a.language = 'en'

    target = Path(a.audio)
    files = sorted(target.rglob('*.mp3')) if target.is_dir() else [target]
    files = [f for f in files if not f.name.endswith('.sub.mp3')]
    if not files:
        sys.exit(f'没有找到 mp3: {target}')
    if a.srt and len(files) > 1:
        sys.exit('--srt 只能用于单个文件')
    for f in files:
        process(f, a)


if __name__ == '__main__':
    main()
