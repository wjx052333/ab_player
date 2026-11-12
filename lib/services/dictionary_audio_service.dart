import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'mdict/mdict_manager_service.dart';

class DictionaryAudioService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();
  final MDictManagerService? mdictManager;
  String _soundsDir = 'data_download/english-sounds';

  DictionaryAudioService({
    this.mdictManager,
    String? customSoundsDir,
  }) {
    if (customSoundsDir != null) {
      _soundsDir = customSoundsDir;
    }
    _ensureSoundsDirExists();
    _initTts();
  }

  void _ensureSoundsDirExists() {
    final dir = Directory(_soundsDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
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

  String? getLocalAudioPath(String word, {required String accent}) {
    final safeWord = word.trim().toLowerCase();
    final ext = '${safeWord}_${accent.toLowerCase()}.mp3';
    final file = File('$_soundsDir/$ext');
    if (file.existsSync() && file.lengthSync() > 0) {
      return file.path;
    }
    return null;
  }

  /// 4-tier pronunciation pipeline:
  /// 1. MDD binary container (Sound_us_uk.mdd / pack companion .mdd)
  /// 2. Local cached MP3 (english-sounds/)
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

    // 2. Check local offline file
    final localPath = getLocalAudioPath(safeWord, accent: accent);
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
        final targetPath = '$_soundsDir/${safeWord.toLowerCase()}_${accent.toLowerCase()}.mp3';
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
