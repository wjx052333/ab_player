"""离线复现 App 的断句算法，用来给某个音频调参数。

算法与 lib/services/speech_segmenter.dart、lib/services/waveform_extractor.dart 保持一致：
  1. 解码 MP3，按 10ms 一格取峰值包络，再按 99.5 分位拉伸到满幅 (同 just_waveform + peaksFromWaveform)
  2. 阈值 = min(max(底噪10分位 * 2.5, 高响度95分位 * threshold), 高响度 * 0.5)
  3. 超过阈值的连续块 -> 间隔不足 min_silence 的合并 -> 丢弃短于 min_speech 的 -> 首尾各扩 padding

依赖：pip install miniaudio numpy
用法：
  python data_utils/segment_audio.py data_download/L212026.mp3
  python data_utils/segment_audio.py data_download/L212026.mp3 --threshold 0.15 --min-silence 200
  python data_utils/segment_audio.py data_download/L212026.mp3 --plot   # 另打印强度时间线 (每字符 100ms)

默认参数要与 SpeechSegmenter 的默认值同步 (阈值 12%、最短停顿 150ms、最短语音 150ms、余量 40ms)。
"""
import argparse

import numpy as np

FPS = 100  # 包络密度：点/秒 (10ms 一点)


def load_envelope(path: str) -> np.ndarray:
    import miniaudio

    d = miniaudio.mp3_read_file_f32(path)
    x = np.abs(np.array(d.samples).reshape(-1, d.nchannels)).max(axis=1)
    n = d.sample_rate // FPS
    m = len(x) // n
    p = x[: m * n].reshape(m, n).max(axis=1)
    ref = np.sort(p)[min(len(p) - 1, int(len(p) * 0.995))]
    return np.clip(p / ref, 0, 1) if ref > 0 else p


def segment(p, threshold=0.12, min_silence=0.15, min_speech=0.15, padding=0.04):
    s = np.sort(p)
    floor = s[int(len(s) * 0.10)]
    loud = s[min(len(s) - 1, int(len(s) * 0.95))]
    thr = min(max(floor * 2.5, loud * threshold), loud * 0.5)

    blocks, start = [], None
    for i, v in enumerate(p):
        if v > thr and start is None:
            start = i
        if v <= thr and start is not None:
            blocks.append([start, i])
            start = None
    if start is not None:
        blocks.append([start, len(p)])

    merged = []
    for b in blocks:
        if merged and b[0] - merged[-1][1] < round(min_silence * FPS):
            merged[-1][1] = b[1]
        else:
            merged.append(b)

    total = len(p) / FPS
    segs = [
        (max(0.0, b[0] / FPS - padding), min(total, b[1] / FPS + padding))
        for b in merged
        if b[1] - b[0] >= round(min_speech * FPS)
    ]
    return thr, segs


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('audio')
    ap.add_argument('--threshold', type=float, default=0.12, help='静音阈值占高响度的比例')
    ap.add_argument('--min-silence', type=int, default=150, help='最短停顿 ms')
    ap.add_argument('--min-speech', type=int, default=150, help='最短语音 ms')
    ap.add_argument('--padding', type=int, default=40, help='首尾余量 ms')
    ap.add_argument('--plot', action='store_true', help='打印强度时间线')
    a = ap.parse_args()

    p = load_envelope(a.audio)
    thr, segs = segment(p, a.threshold, a.min_silence / 1000, a.min_speech / 1000, a.padding / 1000)
    print(f'时长 {len(p) / FPS:.1f}s  阈值 {thr:.3f}  共 {len(segs)} 句')
    for i, (s, e) in enumerate(segs, 1):
        print(f'{i:3d}  {s:7.2f} - {e:7.2f}  ({e - s:.2f}s)')

    if a.plot:
        line = ''.join(' .:-=+*#%@'[min(9, int(p[i : i + 10].min() * 10))] for i in range(0, len(p), 10))
        for i in range(0, len(line), 100):
            print(f'{i / 10:5.1f}s {line[i:i + 100]}')


if __name__ == '__main__':
    main()
