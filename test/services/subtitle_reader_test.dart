import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audacity_player/services/subtitle_reader.dart';
import 'package:flutter_test/flutter_test.dart';

const _json = '{"v":1,"lang":"en","sentences":['
    '{"s":0.52,"e":3.1,"t":"Hello there.","w":[]},'
    '{"s":4,"e":6.5,"t":"你好 world","w":[]}]}';

Uint8List _synchsafe(int n) => Uint8List.fromList([(n >> 21) & 0x7F, (n >> 14) & 0x7F, (n >> 7) & 0x7F, n & 0x7F]);

Uint8List _be32(int n) => Uint8List.fromList([(n >> 24) & 0xFF, (n >> 16) & 0xFF, (n >> 8) & 0xFF, n & 0xFF]);

Uint8List _utf16le(String s) {
  final out = <int>[0xFF, 0xFE];
  for (final u in s.codeUnits) {
    out..add(u & 0xFF)..add(u >> 8);
  }
  return Uint8List.fromList(out);
}

Uint8List _frame(String id, List<int> body, {required int version}) =>
    Uint8List.fromList([...id.codeUnits, ...(version == 4 ? _synchsafe(body.length) : _be32(body.length)), 0, 0, ...body]);

Uint8List _tag(List<Uint8List> frames, {required int version, int padding = 0}) {
  final body = [for (final f in frames) ...f, ...List.filled(padding, 0)];
  return Uint8List.fromList(['I'.codeUnitAt(0), 'D'.codeUnitAt(0), '3'.codeUnitAt(0), version, 0, 0, ..._synchsafe(body.length), ...body]);
}

Uint8List _txxxUtf8(String desc, String value, int version) =>
    _frame('TXXX', [3, ...utf8.encode(desc), 0, ...utf8.encode(value)], version: version);

void main() {
  test('v2.4 UTF-8 TXXX 帧解析出句子，跳过其他帧与填充', () {
    final tag = _tag([
      _frame('TIT2', [3, ...utf8.encode('title')], version: 4),
      _txxxUtf8('OTHER', 'x', 4),
      _txxxUtf8('SUBTITLE_JSON', _json, 4),
    ], version: 4, padding: 20);
    final subs = SubtitleReader.parse(tag);
    expect(subs, hasLength(2));
    expect(subs[0].start, const Duration(milliseconds: 520));
    expect(subs[0].end, const Duration(milliseconds: 3100));
    expect(subs[0].text, 'Hello there.');
    expect(subs[1].text, '你好 world');
    expect(subs[1].start, const Duration(seconds: 4));
  });

  test('v2.3 UTF-16 TXXX 帧', () {
    final body = [1, ..._utf16le('SUBTITLE_JSON'), 0, 0, ..._utf16le(_json)];
    final tag = _tag([_frame('TXXX', body, version: 3)], version: 3);
    expect(SubtitleReader.parse(tag), hasLength(2));
  });

  test('没有字幕帧、不是 ID3、JSON 损坏都返回空', () {
    expect(SubtitleReader.parse(_tag([_txxxUtf8('OTHER', 'x', 4)], version: 4)), isEmpty);
    expect(SubtitleReader.parse(Uint8List.fromList(List.filled(32, 0xFF))), isEmpty);
    expect(SubtitleReader.parse(_tag([_txxxUtf8('SUBTITLE_JSON', '{oops', 4)], version: 4)), isEmpty);
  });

  test('readFile 只读标签，音频数据跟在后面也能解析；缺文件返回空', () async {
    final dir = await Directory.systemTemp.createTemp('subtitle_reader_test');
    addTearDown(() => dir.delete(recursive: true));
    final f = File('${dir.path}/a.mp3');
    await f.writeAsBytes([..._tag([_txxxUtf8('SUBTITLE_JSON', _json, 4)], version: 4), ...List.filled(500, 0xFF)]);
    expect(await SubtitleReader.readFile(f.path), hasLength(2));
    expect(await SubtitleReader.readFile('${dir.path}/missing.mp3'), isEmpty);
  });
}
