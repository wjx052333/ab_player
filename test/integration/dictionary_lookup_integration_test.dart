import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audacity_player/services/dictionary_audio_service.dart';
import 'package:audacity_player/services/dictionary_db_service.dart';
import 'package:audacity_player/services/mdict/mdict_manager_service.dart';

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

  group('端到端本地集成测试 (ECDICT 检索 + MDD 音频提取 + MDX 释义查询)', () {
    late DictionaryDbService dbService;
    late MDictManagerService mdictManager;
    late DictionaryAudioService audioService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      dbService = DictionaryDbService();
      mdictManager = MDictManagerService();
      audioService = DictionaryAudioService(mdictManager: mdictManager);

      await dbService.initialize(
        customEcdictPath: 'data_download/ecdict-ultimate.db',
        customExtraPath: 'data_download/dict_extra.db',
      );
      await mdictManager.initialize();
    });

    tearDown(() async {
      dbService.dispose();
      mdictManager.dispose();
      await audioService.dispose();
    });

    test('完整端到端链路：输入单词 "test"，完成 ECDICT 检索并成功提取 MDD 真人发音', () async {
      const targetWord = 'test';

      // 1. 验证 ECDICT 数据库就绪
      expect(dbService.isReady, true, reason: 'ecdict-ultimate.db 应已成功连接');

      // 2. 从 ecdict-ultimate.db 进行前缀联想与加权搜索
      final searchResults = await dbService.searchWords(targetWord, limit: 10);
      expect(searchResults.isNotEmpty, true, reason: '搜索列表应返回匹配词条');

      final matchedWord = searchResults.first;
      expect(matchedWord.word.toLowerCase(), targetWord);
      expect(matchedWord.phonetic, isNotEmpty);
      expect(matchedWord.briefTranslation, isNotEmpty);
      expect(matchedWord.tags, contains('zk')); // 中考词汇
      expect(matchedWord.tags, contains('cet4')); // 四级词汇
      expect(matchedWord.collins, greaterThan(0)); // 柯林斯星级

      // 3. 从 ecdict-ultimate.db 读取词条完整详情与词形变形
      final detail = await dbService.getWordDetail(targetWord);
      expect(detail, isNotNull);
      expect(detail!.word.toLowerCase(), targetWord);
      expect(detail.translationLines.length, greaterThanOrEqualTo(1));
      expect(detail.exchanges.containsKey('过去式'), true);
      expect(detail.exchanges['过去式'], 'tested');
      expect(detail.exchanges['复数'], 'tests');

      // 4. 从 Sound_us_uk.mdd 提取真实真人美音 (US) 音频字节流
      final usAudioBytes = await mdictManager.getAudioBytes(targetWord, accent: 'us');
      expect(usAudioBytes, isNotNull, reason: '应成功从 Sound_us_uk.mdd 提取美音字节');
      expect(usAudioBytes!.length, greaterThan(500), reason: '音频数据长度应合理');

      // 校验音频文件头（Sound_us_uk.mdd 采用 Ogg Speex 格式，魔数头为 OggS）
      final isOgg = usAudioBytes[0] == 0x4F &&
          usAudioBytes[1] == 0x67 &&
          usAudioBytes[2] == 0x67 &&
          usAudioBytes[3] == 0x53; // 'OggS'
      expect(isOgg, true, reason: '提取的音频数据头部应为合法的 OggS 音频容器格式');

      // 5. 从 Sound_us_uk.mdd 提取真实真人英音 (UK) 音频字节流
      final ukAudioBytes = await mdictManager.getAudioBytes(targetWord, accent: 'uk');
      expect(ukAudioBytes, isNotNull, reason: '应成功从 Sound_us_uk.mdd 提取英音字节');
      expect(ukAudioBytes!.length, greaterThan(500));
      expect(ukAudioBytes[0] == 0x4F && ukAudioBytes[1] == 0x67, true);

      // 6. 验证同时从已挂载的 MDX 权威词典读取释义
      final oxfordPack = mdictManager.packs.where((p) => p.id == 'oxfordPrimary').firstOrNull;
      if (oxfordPack != null) {
        final oxfordHtml = await oxfordPack.lookupDefinition(targetWord);
        expect(oxfordHtml, isNotNull);
        expect(oxfordHtml!.contains('test'), true);
      }

      final longmanPack = mdictManager.packs
          .where((p) => p.id.toLowerCase().contains('longman'))
          .firstOrNull;
      if (longmanPack != null) {
        final longmanHtml = await longmanPack.lookupDefinition(targetWord);
        expect(longmanHtml, isNotNull);
        expect(longmanHtml!.contains('test'), true);
      }
    });

    test('完整端到端链路：输入单词 "apple"，完成考点解析并提取 MDD 发音', () async {
      const targetWord = 'apple';

      // 1. ECDICT 查词与详情
      final detail = await dbService.getWordDetail(targetWord);
      expect(detail, isNotNull);
      expect(detail!.word.toLowerCase(), targetWord);
      expect(detail.phonetic, isNotEmpty);
      expect(detail.translationLines.any((l) => l.contains('苹果')), true);

      // 2. MDD 提取 apple 美音与英音
      final usAudio = await mdictManager.getAudioBytes(targetWord, accent: 'us');
      expect(usAudio, isNotNull);
      expect(usAudio!.length, greaterThan(1000));
      expect(String.fromCharCodes(usAudio.sublist(0, 4)), 'OggS');

      final ukAudio = await mdictManager.getAudioBytes(targetWord, accent: 'uk');
      expect(ukAudio, isNotNull);
      expect(ukAudio!.length, greaterThan(1000));
      expect(String.fromCharCodes(ukAudio.sublist(0, 4)), 'OggS');
    });
  });
}
