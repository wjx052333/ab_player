import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

class DictionaryAudioService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();
  String _soundsDir = 'data_download/english-sounds';

  DictionaryAudioService({String? customSoundsDir}) {
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

  Future<void> playWord(String word, {String accent = 'us'}) async {
    final safeWord = word.trim();
    if (safeWord.isEmpty) return;

    // 1. Check local offline file
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

    // 2. Fetch from Youdao Web API and cache locally
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

    // 3. Fallback to system TTS
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

  void dispose() {
    try {
      _audioPlayer.dispose();
    } catch (_) {}
    try {
      _flutterTts.stop();
    } catch (_) {}
  }
}
