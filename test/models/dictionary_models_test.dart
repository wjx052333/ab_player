import 'package:flutter_test/flutter_test.dart';
import 'package:audacity_player/models/dictionary/dict_example.dart';
import 'package:audacity_player/models/dictionary/dict_word_summary.dart';
import 'package:audacity_player/models/dictionary/dict_word_detail.dart';

void main() {
  group('Dictionary Models Test', () {
    test('DictExample serialization and properties', () {
      const example = DictExample(
        source: 'oxford',
        enText: 'This is a test.',
        cnText: '这是一次测试。',
        orderIndex: 0,
      );
      expect(example.source, 'oxford');
      expect(example.enText, 'This is a test.');
      expect(example.cnText, '这是一次测试。');
      expect(example.toMap(), {
        'source': 'oxford',
        'enText': 'This is a test.',
        'cnText': '这是一次测试。',
        'orderIndex': 0,
      });
    });

    test('DictWordSummary parses tags and brief translation', () {
      const summary = DictWordSummary(
        word: 'test',
        phonetic: 'test',
        rawTranslation: 'n. 试验；检验\nvt. 试验；测试',
        tagString: 'zk gk cet4 cet6',
        collins: 5,
        oxford: 1,
      );
      expect(summary.word, 'test');
      expect(summary.briefTranslation, 'n. 试验；检验');
      expect(summary.tags, contains('zk'));
      expect(summary.tags, contains('cet4'));
      expect(summary.collins, 5);
    });

    test('DictWordDetail parses exchange and structures translations', () {
      const detail = DictWordDetail(
        word: 'test',
        phonetic: 'test',
        rawTranslation: 'n. 试验；检验\nvt. 试验；测试',
        definition: 'n. any standardized procedure for measuring...',
        tagString: 'zk cet4',
        collins: 5,
        oxford: 1,
        exchangeString: 'p:tested/d:tested/i:testing/3:tests/s:tests',
        examples: [
          DictExample(source: 'oxford', enText: 'Easy test.', cnText: '简单的测试。'),
        ],
      );
      expect(detail.translationLines.length, 2);
      expect(detail.exchanges['过去式'], 'tested');
      expect(detail.exchanges['现在分词'], 'testing');
      expect(detail.exchanges['第三人称单数'], 'tests');
      expect(detail.examples.length, 1);
    });
  });
}
