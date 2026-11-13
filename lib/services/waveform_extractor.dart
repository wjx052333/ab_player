import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:just_waveform/just_waveform.dart';
import 'package:path_provider/path_provider.dart';

/// 波形提取结果：归一化响度包络及其时间密度
class WaveformData {
  final List<double> peaks;
  final double peaksPerSecond;

  const WaveformData(this.peaks, this.peaksPerSecond);
}

class WaveformExtractor {
  /// 真实解码的包络密度 (点/秒)，10ms 一点，足够分辨句间停顿
  static const int realPixelsPerSecond = 100;

  /// 解码音频得到真实响度包络 (Android/iOS 原生解码 MP3 等压缩格式)；
  /// 不支持的平台或解码失败时退回字节抽样的粗略波形
  Future<WaveformData> extract(String filePath, {ValueChanged<double>? onProgress}) async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        final real = await _extractReal(filePath, onProgress);
        if (real.peaks.isNotEmpty) return real;
      } catch (e) {
        debugPrint('真实波形解码失败，退回粗略波形: $e');
      }
    }
    final rough = await extractPeaks(filePath);
    return WaveformData(rough, 0);
  }

  Future<WaveformData> _extractReal(String filePath, ValueChanged<double>? onProgress) async {
    final dir = await getTemporaryDirectory();
    final out = File('${dir.path}/${filePath.hashCode.toUnsigned(32)}.wave');
    Waveform? wave;
    await for (final p in JustWaveform.extract(
      audioInFile: File(filePath),
      waveOutFile: out,
      zoom: const WaveformZoom.pixelsPerSecond(realPixelsPerSecond),
    )) {
      onProgress?.call(p.progress);
      if (p.waveform != null) {
        wave = p.waveform;
        break;
      }
    }
    if (wave == null) return const WaveformData([], 0);
    return WaveformData(peaksFromWaveform(wave), wave.sampleRate / wave.samplesPerPixel);
  }

  /// 把 min/max 采样对转成归一化响度 (取绝对值较大者，按 99.5 分位拉伸到满幅)
  @visibleForTesting
  List<double> peaksFromWaveform(Waveform wave) {
    final full = wave.flags == 0 ? 32768.0 : 128.0;
    final raw = List<double>.generate(
      wave.length,
      (i) => max(wave.getPixelMax(i).abs(), wave.getPixelMin(i).abs()) / full,
    );
    if (raw.isEmpty) return raw;
    final sorted = List<double>.of(raw)..sort();
    final ref = sorted[min(sorted.length - 1, (sorted.length * 0.995).floor())];
    if (ref <= 0) return raw;
    return [for (final v in raw) (v / ref).clamp(0.0, 1.0)];
  }

  /// 对输入数据做下采样，保证长音频波峰控制在合适的目标点数
  List<double> downsample(List<double> source, {required int targetPoints}) {
    if (source.isEmpty || targetPoints <= 0) return [];
    if (source.length <= targetPoints) return source;

    final result = <double>[];
    final chunkSize = source.length / targetPoints;

    for (int i = 0; i < targetPoints; i++) {
      final start = (i * chunkSize).floor();
      final end = min(((i + 1) * chunkSize).floor(), source.length);

      double maxPeak = 0.0;
      for (int j = start; j < end; j++) {
        if (source[j].abs() > maxPeak) {
          maxPeak = source[j].abs();
        }
      }
      result.add(maxPeak.clamp(0.0, 1.0));
    }
    return result;
  }

  /// 从本地音频文件快速提取振幅特征
  /// 采用文件字节快速抽样或 WAV 头直接解析；针对无解码插件环境提供稳定的自适应提取
  Future<List<double>> extractPeaks(String filePath, {int targetPointsPerSecond = 50}) async {
    final file = File(filePath);
    if (!await file.exists()) return [];

    final length = await file.length();
    if (length == 0) return [];

    // 读取部分字节快速采样（保证性能与即时性）
    final bytes = await file.openRead(0, min(length, 1024 * 1024 * 10)).fold<BytesBuilder>(
      BytesBuilder(),
      (bb, chunk) => bb..add(chunk),
    );

    final raw = bytes.takeBytes();
    if (raw.isEmpty) return [];

    final samples = <double>[];
    for (int i = 0; i < raw.length; i += 64) {
      // 简单能量归一化采样
      final byteVal = raw[i];
      samples.add((byteVal / 255.0));
    }

    return downsample(samples, targetPoints: 1000);
  }
}
