import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audacity_player/services/mdict/mdict_manager_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MDictManagerService Tests', () {
    late MDictManagerService manager;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      manager = MDictManagerService();
    });

    tearDown(() {
      manager.dispose();
    });

    test('Initializes and discovers default packs in data_download', () async {
      await manager.initialize();

      expect(manager.isInitialized, true);
      // If data_download exists locally, Oxford and Longman should be auto-loaded
      if (File('data_download/oxfordPrimary/oxfordPrimary.mdx').existsSync()) {
        expect(manager.packs.isNotEmpty, true);
        final oxford = manager.packs.firstWhere((p) => p.id == 'oxfordPrimary');
        expect(oxford.totalEntries, greaterThan(4000));

        final def = await oxford.lookupDefinition('test');
        expect(def, isNotNull);
        expect(def!.contains('test'), true);
      }
    });

    test('Extracts audio from Sound_us_uk.mdd', () async {
      await manager.initialize();
      if (!File('data_download/Sound_us_uk/Sound_us_uk.mdd').existsSync()) return;

      final usAudio = await manager.getAudioBytes('test', accent: 'us');
      expect(usAudio, isNotNull);
      expect(usAudio!.length, greaterThan(100));

      final ukAudio = await manager.getAudioBytes('test', accent: 'uk');
      expect(ukAudio, isNotNull);
      expect(ukAudio!.length, greaterThan(100));
    });
  });
}
