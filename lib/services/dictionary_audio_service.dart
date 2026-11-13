import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'storage_permission_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'mdict/mdict_manager_service.dart';

class DictionaryAudioService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();
  final MDictManagerService? mdictManager;
  final String? customSoundsDir;

  String? _resolvedSoundsDir;
  bool _isInit = false;

  DictionaryAudioService({
    this.mdictManager,
    this.customSoundsDir,
  }) {
    _initAsync();
  }

  Future<void> _initAsync() async {
    if (_isInit) return;
    await _ensureSoundsDir();
    await _initTts();
    _isInit = true;
  }

  /// Resolve platform-safe sounds cache directory.
  /// - On Android / iOS: Always use app sandbox storage (ApplicationSupportDirectory / CacheDirectory)
  /// - On Desktop / Windows: Prefer 'data_download/english-sounds' if 'data_download' exists, else sandbox
  Future<String> _ensureSoundsDir() async {
    if (_resolvedSoundsDir != null) return _resolvedSoundsDir!;

    if (customSoundsDir != null && customSoundsDir!.isNotEmpty) {
      final dir = Directory(customSoundsDir!);
      if (!dir.existsSync()) {
        try {
          dir.createSync(recursive: true);
        } catch (_) {}
      }
      _resolvedSoundsDir = dir.path;
      return _resolvedSoundsDir!;
    }

    // Android: 优先放公共 Download/english/sounds (与词库同一父目录，便于管理)，
    // 没有写权限或不可写时退回应用沙盒
    final publicDir = await _tryPublicSoundsDir();
    if (publicDir != null) {
      _resolvedSoundsDir = publicDir;
      return publicDir;
    }

    // Platform-specific logic:
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      // In Android, must use sandbox directory to avoid permission denied
      try {
        final supportDir = await getApplicationSupportDirectory();
        final dir = Directory('${supportDir.path}/english-sounds');
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
        _resolvedSoundsDir = dir.path;
        return _resolvedSoundsDir!;
      } catch (e) {
        debugPrint('Failed to getApplicationSupportDirectory, fallback to temp: $e');
        final tempDir = Directory.systemTemp;
        final dir = Directory('${tempDir.path}/english-sounds');
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
        _resolvedSoundsDir = dir.path;
        return _resolvedSoundsDir!;
      }
    }

    // Windows / Desktop dev environment:
    try {
      final devDir = Directory('data_download/english-sounds');
      if (Directory('data_download').existsSync()) {
        if (!devDir.existsSync()) {
          devDir.createSync(recursive: true);
        }
        _resolvedSoundsDir = devDir.path;
        return _resolvedSoundsDir!;
      }
    } catch (_) {}

    // Fallback for desktop when data_download does not exist:
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${appDocDir.path}/english-sounds');
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      _resolvedSoundsDir = dir.path;
      return _resolvedSoundsDir!;
    } catch (_) {
      final tempDir = Directory.systemTemp;
      _resolvedSoundsDir = '${tempDir.path}/english-sounds';
      return _resolvedSoundsDir!;
    }
  }

  /// 逐个尝试 Download/english/sounds，返回第一个真正可写的目录；非 Android 返回 null
  Future<String?> _tryPublicSoundsDir() async {
    for (final base in await StoragePermissionService.getPublicAppDirectories()) {
      try {
        final dir = Directory('$base/sounds');
        if (!dir.existsSync()) dir.createSync(recursive: true);
        final probe = File('${dir.path}/.write_test');
        probe.writeAsStringSync('ok', flush: true);
        probe.deleteSync();
        return dir.path;
      } catch (_) {
        // 无权限或目录不存在，试下一个
      }
    }
    return null;
  }

  /// 旧版本缓存在应用沙盒 english-sounds 里，升级后仍要能读到
  Future<File?> _legacyCachedFile(String fileName) async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return null;
    try {
      final supportDir = await getApplicationSupportDirectory();
      final f = File('${supportDir.path}/english-sounds/$fileName');
      if (f.existsSync() && f.lengthSync() > 0) return f;
    } catch (_) {}
    return null;
  }

  Future<void> _initTts() async {
    try {
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(0.45);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
    } catch (e) {
      debugPrint('TTS init error: $e');
    }
  }

  String getYoudaoAudioUrl(String word, {required String accent}) {
    final type = accent.toLowerCase() == 'uk' ? 1 : 2;
    return 'https://dict.youdao.com/dictvoice?audio=${Uri.encodeComponent(word)}&type=$type';
  }

  Future<String?> getLocalAudioPath(String word, {required String accent}) async {
    final safeWord = word.trim().toLowerCase();
    final ext = '${safeWord}_${accent.toLowerCase()}.mp3';
    final soundsDir = await _ensureSoundsDir();
    final file = File('$soundsDir/$ext');
    if (file.existsSync() && file.lengthSync() > 0) {
      return file.path;
    }
    return (await _legacyCachedFile(ext))?.path;
  }

  /// 4-tier pronunciation pipeline:
  /// 1. MDD binary container (Sound_us_uk.mdd / pack companion .mdd)
  /// 2. Local cached MP3 (platform-safe english-sounds/)
  /// 3. Youdao Web API download & cache
  /// 4. System TTS fallback
  Future<void> playWord(String word, {String accent = 'us'}) async {
    final safeWord = word.trim();
    if (safeWord.isEmpty) return;

    // 1. Check MDD sound bank first!
    if (mdictManager != null) {
      try {
        final audioBytes = await mdictManager!.getAudioBytes(safeWord, accent: accent);
        if (audioBytes != null && audioBytes.isNotEmpty) {
          final tempDir = Directory.systemTemp;
          final isOgg = audioBytes.length >= 4 &&
              audioBytes[0] == 0x4F &&
              audioBytes[1] == 0x67 &&
              audioBytes[2] == 0x67 &&
              audioBytes[3] == 0x53; // OggS
          final ext = isOgg ? 'spx' : 'mp3';
          final tempFile = File('${tempDir.path}/mdd_voice_${safeWord}_$accent.$ext');
          await tempFile.writeAsBytes(audioBytes, flush: true);

          await _audioPlayer.stop();
          await _audioPlayer.setFilePath(tempFile.path);
          await _audioPlayer.play();
          return;
        }
      } catch (e) {
        debugPrint('MDD audio play error: $e');
      }
    }

    // 2. Check local offline file in platform-safe cache directory
    final localPath = await getLocalAudioPath(safeWord, accent: accent);
    if (localPath != null) {
      try {
        await _audioPlayer.stop();
        await _audioPlayer.setFilePath(localPath);
        await _audioPlayer.play();
        return;
      } catch (e) {
        debugPrint('Local audio play error: $e');
      }
    }

    // 3. Fetch from Youdao Web API and cache locally
    final youdaoUrl = getYoudaoAudioUrl(safeWord, accent: accent);
    try {
      final response = await http.get(Uri.parse(youdaoUrl)).timeout(
        const Duration(seconds: 4),
      );

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final soundsDir = await _ensureSoundsDir();
        final targetPath = '$soundsDir/${safeWord.toLowerCase()}_${accent.toLowerCase()}.mp3';
        final file = File(targetPath);
        await file.writeAsBytes(response.bodyBytes);

        await _audioPlayer.stop();
        await _audioPlayer.setFilePath(targetPath);
        await _audioPlayer.play();
        return;
      }
    } catch (e) {
      debugPrint('Youdao fetch audio failed: $e');
    }

    // 4. Fallback to system TTS
    await speakText(safeWord);
  }

  /// Play a `sound://` resource by its exact path inside the dictionary's MDD.
  /// Returns false when the resource is missing or cannot be played, so the
  /// caller can fall back to word-based playback.
  Future<bool> playResource(String path) async {
    final manager = mdictManager;
    if (manager == null) return false;
    try {
      final bytes = await manager.getResourceBytes(path);
      if (bytes == null) return false;
      final isOgg = bytes.length >= 4 &&
          bytes[0] == 0x4F && bytes[1] == 0x67 && bytes[2] == 0x67 && bytes[3] == 0x53;
      final ext = isOgg ? 'spx' : 'mp3';
      final name = path.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_');
      final file = File('${Directory.systemTemp.path}/mdd_res_$name.$ext');
      await file.writeAsBytes(bytes, flush: true);
      await _audioPlayer.stop();
      await _audioPlayer.setFilePath(file.path);
      await _audioPlayer.play();
      return true;
    } catch (e) {
      debugPrint('MDD resource play error: $e');
      return false;
    }
  }

  /// Whether a recorded (non-TTS) pronunciation is available offline: the MDD
  /// sound bank or the local cache.
  Future<bool> hasHumanAudio(String word, {String accent = 'us'}) async {
    final w = word.trim();
    if (w.isEmpty) return false;
    try {
      final bytes = await mdictManager?.getAudioBytes(w, accent: accent);
      if (bytes != null && bytes.isNotEmpty) return true;
    } catch (_) {}
    return await getLocalAudioPath(w, accent: accent) != null;
  }

  Future<void> speakText(String text) async {
    try {
      await _flutterTts.stop();
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('TTS speak error: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
    } catch (_) {}
    try {
      await _flutterTts.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    try {
      await _audioPlayer.dispose();
    } catch (_) {}
    try {
      await _flutterTts.stop();
    } catch (_) {}
  }
}
