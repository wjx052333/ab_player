import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

typedef _DecodeNative = Int32 Function(
    Pointer<Uint8>, Int32, Pointer<Pointer<Int16>>, Pointer<Int32>);
typedef _DecodeDart = int Function(
    Pointer<Uint8>, int, Pointer<Pointer<Int16>>, Pointer<Int32>);
typedef _FreeNative = Void Function(Pointer<Int16>);
typedef _FreeDart = void Function(Pointer<Int16>);

/// Ogg/Speex -> WAV。
///
/// Sound_us_uk.mdd 里的发音都是 Ogg/Speex，而 Android 的 ExoPlayer/MediaPlayer 不支持 Speex，
/// 所以在 Android 上用原生 libspeex (`android/app/src/main/cpp`，经 dart:ffi 调用) 解成 PCM 再包成 WAV 播放。
/// 其他平台没有该原生库，[oggSpeexToWav] 返回 null。
class SpeexDecoder {
  static _DecodeDart? _decode;
  static _FreeDart? _free;
  static bool _loadTried = false;

  static bool _ensureLoaded() {
    if (_decode != null) return true;
    if (_loadTried) return false;
    _loadTried = true;
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final lib = DynamicLibrary.open('libspeexdec.so');
      _decode = lib.lookupFunction<_DecodeNative, _DecodeDart>('spx_decode_ogg');
      _free = lib.lookupFunction<_FreeNative, _FreeDart>('spx_free_pcm');
      return true;
    } catch (e) {
      debugPrint('Speex native library unavailable: $e');
      return false;
    }
  }

  static bool isOggSpeex(Uint8List b) =>
      b.length > 36 &&
      b[0] == 0x4F && b[1] == 0x67 && b[2] == 0x67 && b[3] == 0x53 && // OggS
      String.fromCharCodes(b.sublist(28, 36)) == 'Speex   ';

  /// 解码失败或当前平台不支持时返回 null。
  static Uint8List? oggSpeexToWav(Uint8List ogg) {
    if (!_ensureLoaded()) return null;
    final input = malloc<Uint8>(ogg.length);
    final outPcm = malloc<Pointer<Int16>>();
    final outRate = malloc<Int32>();
    try {
      input.asTypedList(ogg.length).setAll(0, ogg);
      final samples = _decode!(input, ogg.length, outPcm, outRate);
      if (samples <= 0) return null;
      final pcm = outPcm.value;
      try {
        return _wav(pcm.asTypedList(samples), outRate.value);
      } finally {
        _free!(pcm);
      }
    } finally {
      malloc.free(input);
      malloc.free(outPcm);
      malloc.free(outRate);
    }
  }

  static Uint8List _wav(Int16List pcm, int rate) {
    final dataLen = pcm.length * 2;
    final out = ByteData(44 + dataLen);
    void tag(int off, String s) {
      for (var i = 0; i < 4; i++) {
        out.setUint8(off + i, s.codeUnitAt(i));
      }
    }

    tag(0, 'RIFF');
    out.setUint32(4, 36 + dataLen, Endian.little);
    tag(8, 'WAVE');
    tag(12, 'fmt ');
    out.setUint32(16, 16, Endian.little);
    out.setUint16(20, 1, Endian.little); // PCM
    out.setUint16(22, 1, Endian.little); // mono
    out.setUint32(24, rate, Endian.little);
    out.setUint32(28, rate * 2, Endian.little);
    out.setUint16(32, 2, Endian.little);
    out.setUint16(34, 16, Endian.little);
    tag(36, 'data');
    out.setUint32(40, dataLen, Endian.little);
    for (var i = 0; i < pcm.length; i++) {
      out.setInt16(44 + i * 2, pcm[i], Endian.little);
    }
    return out.buffer.asUint8List();
  }
}
