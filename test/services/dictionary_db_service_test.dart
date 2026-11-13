import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:audacity_player/services/dictionary_db_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DictionaryDbService Test', () {
    late DictionaryDbService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = DictionaryDbService();
    });

    tearDown(() {
      service.dispose();
    });

    test('searchWords returns results prioritized by zk and cet4 tags', () async {
      // Connect to existing data_download/ecdict-ultimate.db
      const ecdictPath = 'data_download/ecdict-ultimate.db';
      const extraPath = 'data_download/dict_extra.db';

      if (!File(ecdictPath).existsSync()) {
        return; // skip if running in CI without large db
      }

      await service.initialize(customEcdictPath: ecdictPath, customExtraPath: extraPath);

      final results = await service.searchWords('app', limit: 20);
      expect(results.isNotEmpty, true);

      // 'apple' has zk tag, so it should rank high near the top
      final words = results.map((e) => e.word.toLowerCase()).toList();
      expect(words.contains('apple'), true);
      expect(words.indexOf('apple'), lessThan(5));
    });

    test('persists custom path in SharedPreferences upon initialize', () async {
      const ecdictPath = 'data_download/ecdict-ultimate.db';
      if (!File(ecdictPath).existsSync()) return;

      await service.initialize(customEcdictPath: ecdictPath);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('custom_ecdict_path'), ecdictPath);

      // Test subsequent initialization without explicit path restores saved path
      final newService = DictionaryDbService();
      final ready = await newService.initialize();
      expect(ready, isTrue);
      expect(newService.resolvedEcdictPath, ecdictPath);
      newService.dispose();
    });

    test('getWordDetail fetches word metadata and examples from dict_extra.db', () async {
      const ecdictPath = 'data_download/ecdict-ultimate.db';
      const extraPath = 'data_download/dict_extra.db';

      if (!File(ecdictPath).existsSync()) return;

      await service.initialize(customEcdictPath: ecdictPath, customExtraPath: extraPath);

      final detail = await service.getWordDetail('test');
      expect(detail, isNotNull);
      expect(detail!.word.toLowerCase(), 'test');
      expect(detail.phonetic, isNotEmpty);
      expect(detail.translationLines, isNotEmpty);
      expect(detail.examples.length, greaterThanOrEqualTo(2));
      expect(detail.examples.any((e) => e.source == 'oxford'), true);
      expect(detail.examples.any((e) => e.source == 'longman'), true);
    });
  });
}
