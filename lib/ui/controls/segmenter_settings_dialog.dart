import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/speech_segmenter.dart';

/// 断句参数设置：拖动滑块即时重新断句，波形上马上能看到效果
class SegmenterSettingsDialog extends StatefulWidget {
  final SpeechSegmenter initial;
  final ValueChanged<SpeechSegmenter> onChanged;

  const SegmenterSettingsDialog({super.key, required this.initial, required this.onChanged});

  static const _kThreshold = 'segmenter_threshold';
  static const _kSilence = 'segmenter_min_silence_ms';
  static const _kSpeech = 'segmenter_min_speech_ms';

  /// 读取已保存的断句参数，没有则用默认值
  static Future<SpeechSegmenter> load() async {
    final prefs = await SharedPreferences.getInstance();
    const d = SpeechSegmenter();
    return SpeechSegmenter(
      thresholdRatio: prefs.getDouble(_kThreshold) ?? d.thresholdRatio,
      minSilence: Duration(milliseconds: prefs.getInt(_kSilence) ?? d.minSilence.inMilliseconds),
      minSpeech: Duration(milliseconds: prefs.getInt(_kSpeech) ?? d.minSpeech.inMilliseconds),
    );
  }

  static Future<void> save(SpeechSegmenter s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kThreshold, s.thresholdRatio);
    await prefs.setInt(_kSilence, s.minSilence.inMilliseconds);
    await prefs.setInt(_kSpeech, s.minSpeech.inMilliseconds);
  }

  @override
  State<SegmenterSettingsDialog> createState() => _SegmenterSettingsDialogState();
}

class _SegmenterSettingsDialogState extends State<SegmenterSettingsDialog> {
  late SpeechSegmenter _seg = widget.initial;

  void _update(SpeechSegmenter seg) {
    setState(() => _seg = seg);
    widget.onChanged(seg);
    SegmenterSettingsDialog.save(seg);
  }

  Widget _row(String label, String value, double v, double min, double max, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(width: 64, child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12))),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
            ),
            child: Slider(value: v.clamp(min, max), min: min, max: max, onChanged: onChanged),
          ),
        ),
        SizedBox(
          width: 58,
          child: Text(value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace')),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('断句参数', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            const Spacer(),
            TextButton(
              onPressed: () => _update(const SpeechSegmenter()),
              style: TextButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 8)),
              child: const Text('恢复默认', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        _row('静音阈值', '${(_seg.thresholdRatio * 100).round()}%', _seg.thresholdRatio, 0.02, 0.4,
            (v) => _update(_seg.copyWith(thresholdRatio: v))),
        const Text('调大：更多弱音被当成停顿，断得更细', style: TextStyle(color: Colors.white38, fontSize: 10)),
        _row('最短停顿', '${_seg.minSilence.inMilliseconds}ms', _seg.minSilence.inMilliseconds.toDouble(), 60, 1000,
            (v) => _update(_seg.copyWith(minSilence: Duration(milliseconds: (v / 10).round() * 10)))),
        const Text('调小：更短的停顿也会断开', style: TextStyle(color: Colors.white38, fontSize: 10)),
        _row('最短语音', '${_seg.minSpeech.inMilliseconds}ms', _seg.minSpeech.inMilliseconds.toDouble(), 50, 800,
            (v) => _update(_seg.copyWith(minSpeech: Duration(milliseconds: (v / 10).round() * 10)))),
        const Text('调大：过滤掉更短的零碎声音', style: TextStyle(color: Colors.white38, fontSize: 10)),
      ],
    );
  }
}

/// 在右上角弹出一个不遮挡波形的小面板 (点面板外任意处关闭)
Future<void> showSegmenterSettings(
  BuildContext context, {
  required SpeechSegmenter initial,
  required ValueChanged<SpeechSegmenter> onChanged,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.transparent,
    builder: (ctx) => Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.only(top: 36, right: 8),
        child: Material(
          color: const Color(0xEE1B1B1B),
          borderRadius: BorderRadius.circular(6),
          elevation: 6,
          child: Container(
            width: 360,
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF3AAFA9).withValues(alpha: 0.5)),
            ),
            child: SegmenterSettingsDialog(initial: initial, onChanged: onChanged),
          ),
        ),
      ),
    ),
  );
}
