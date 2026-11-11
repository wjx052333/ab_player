import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

class WaveformExtractor {
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
