import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../models/subtitle_sentence.dart';

/// 从 MP3 的 ID3v2 标签读取内嵌字幕 (`TXXX:SUBTITLE_JSON`，由 data_utils/embed_subtitles.py 写入)。
/// 没有标签、没有该帧或格式不对都返回空列表，调用方据此不显示字幕。
class SubtitleReader {
  static const frameDescription = 'SUBTITLE_JSON';

  /// 只读文件开头的 ID3 标签部分，不会把整个 MP3 读进内存
  static Future<List<SubtitleSentence>> readFile(String path) async {
    try {
      final raf = await File(path).open();
      try {
        final header = await raf.read(10);
        final size = _tagSize(header);
        if (size == null) return const [];
        final body = await raf.read(size);
        return parse(Uint8List.fromList([...header, ...body]));
      } finally {
        await raf.close();
      }
    } catch (_) {
      return const [];
    }
  }

  /// [data] 为以 `ID3` 头开头的标签字节 (后面跟音频帧也无妨)
  static List<SubtitleSentence> parse(Uint8List data) {
    try {
      final size = _tagSize(data);
      if (size == null) return const [];
      final version = data[3];
      if (version != 3 && version != 4) return const [];
      final flags = data[5];

      var tag = data.sublist(10, (10 + size).clamp(10, data.length));
      if (flags & 0x80 != 0) tag = _removeUnsynchronisation(tag);

      var pos = 0;
      if (flags & 0x40 != 0 && tag.length >= 4) {
        // 扩展头：v2.4 大小为 synchsafe 且含自身，v2.3 大小不含自身
        final ext = version == 4 ? _synchsafe(tag, 0) : _be32(tag, 0) + 4;
        pos = ext;
      }

      while (pos + 10 <= tag.length) {
        final id = latin1.decode(tag.sublist(pos, pos + 4), allowInvalid: true);
        if (id.codeUnitAt(0) == 0) break; // 进入填充区
        final frameSize = version == 4 ? _synchsafe(tag, pos + 4) : _be32(tag, pos + 4);
        final start = pos + 10;
        final end = start + frameSize;
        if (frameSize <= 0 || end > tag.length) break;
        if (id == 'TXXX') {
          final json = _subtitleJson(tag.sublist(start, end));
          if (json != null) return _sentences(json);
        }
        pos = end;
      }
    } catch (_) {
      // 损坏的标签按「无字幕」处理
    }
    return const [];
  }

  static int? _tagSize(Uint8List h) {
    if (h.length < 10 || h[0] != 0x49 || h[1] != 0x44 || h[2] != 0x33) return null; // 'ID3'
    return _synchsafe(h, 6);
  }

  static int _synchsafe(Uint8List b, int o) => (b[o] << 21) | (b[o + 1] << 14) | (b[o + 2] << 7) | b[o + 3];

  static int _be32(Uint8List b, int o) => (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];

  static Uint8List _removeUnsynchronisation(Uint8List b) {
    final out = BytesBuilder();
    for (var i = 0; i < b.length; i++) {
      out.addByte(b[i]);
      if (b[i] == 0xFF && i + 1 < b.length && b[i + 1] == 0) i++;
    }
    return out.toBytes();
  }

  /// TXXX 帧体：编码字节 + 描述 + 终止符 + 值；描述匹配才返回值
  static String? _subtitleJson(Uint8List f) {
    if (f.length < 2) return null;
    final enc = f[0];
    final wide = enc == 1 || enc == 2;
    final termLen = wide ? 2 : 1;

    var i = 1;
    while (i + termLen <= f.length) {
      if (f[i] == 0 && (!wide || f[i + 1] == 0)) break;
      i += wide ? 2 : 1;
    }
    if (i + termLen > f.length) return null;
    final desc = _decode(enc, f.sublist(1, i));
    if (desc != frameDescription) return null;
    return _decode(enc, f.sublist(i + termLen)).replaceAll('\u0000', '');
  }

  static String _decode(int enc, Uint8List b) {
    switch (enc) {
      case 0:
        return latin1.decode(b);
      case 1:
        return _utf16(b);
      case 2:
        return _utf16(b, bigEndianDefault: true);
      default:
        return utf8.decode(b, allowMalformed: true);
    }
  }

  static String _utf16(Uint8List b, {bool bigEndianDefault = false}) {
    var big = bigEndianDefault;
    var start = 0;
    if (b.length >= 2) {
      if (b[0] == 0xFE && b[1] == 0xFF) {
        big = true;
        start = 2;
      } else if (b[0] == 0xFF && b[1] == 0xFE) {
        big = false;
        start = 2;
      }
    }
    final units = <int>[
      for (var i = start; i + 1 < b.length; i += 2) big ? (b[i] << 8) | b[i + 1] : (b[i + 1] << 8) | b[i],
    ];
    return String.fromCharCodes(units);
  }

  static List<SubtitleSentence> _sentences(String json) {
    final root = jsonDecode(json);
    if (root is! Map || root['sentences'] is! List) return const [];
    final out = <SubtitleSentence>[];
    for (final s in root['sentences'] as List) {
      if (s is! Map) continue;
      final start = s['s'], end = s['e'], text = s['t'];
      if (start is! num || end is! num || text is! String || text.trim().isEmpty) continue;
      out.add(SubtitleSentence(
        Duration(milliseconds: (start * 1000).round()),
        Duration(milliseconds: (end * 1000).round()),
        text.trim(),
      ));
    }
    out.sort((a, b) => a.start.compareTo(b.start));
    return out;
  }
}
