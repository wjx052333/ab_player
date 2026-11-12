import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:audacity_player/services/dictionary_audio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (MethodCall methodCall) async {
        return 1;
      },
    );
  });

  group('DictionaryAudioService Test', () {
    late DictionaryAudioService service;

    setUp(() {
      service = DictionaryAudioService();
    });

    tearDown(() {
      service.dispose();
    });

    test('builds correct Youdao voice URL', () {
      final usUrl = service.getYoudaoAudioUrl('test', accent: 'us');
      final ukUrl = service.getYoudaoAudioUrl('test', accent: 'uk');
      expect(usUrl, 'https://dict.youdao.com/dictvoice?audio=test&type=2');
      expect(ukUrl, 'https://dict.youdao.com/dictvoice?audio=test&type=1');
    });

    test('resolves local audio path if cached in english-sounds', () {
      final dir = Directory('data_download/english-sounds');
      if (!dir.existsSync()) dir.createSync(recursive: true);

      final dummyFile = File('data_download/english-sounds/dummy_test_us.mp3');
      dummyFile.writeAsStringSync('dummy');

      final localPath = service.getLocalAudioPath('dummy_test', accent: 'us');
      expect(localPath, isNotNull);
      expect(File(localPath!).existsSync(), true);

      dummyFile.deleteSync();
    });
  });
}
