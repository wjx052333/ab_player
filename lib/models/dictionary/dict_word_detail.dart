import 'dict_example.dart';
import 'dict_word_summary.dart';

class DictWordDetail extends DictWordSummary {
  final String definition;
  final String exchangeString;
  final List<DictExample> examples;

  const DictWordDetail({
    required super.word,
    super.phonetic,
    required super.rawTranslation,
    this.definition = '',
    super.tagString,
    super.collins,
    super.oxford,
    this.exchangeString = '',
    this.examples = const [],
  });

  List<String> get translationLines => rawTranslation
      .split(RegExp(r'[\r\n]+'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  Map<String, String> get exchanges {
    final result = <String, String>{};
    if (exchangeString.isEmpty) return result;

    final parts = exchangeString.split('/');
    for (final part in parts) {
      final kv = part.split(':');
      if (kv.length == 2) {
        final key = kv[0].trim();
        final val = kv[1].trim();
        switch (key) {
          case 'p':
            result['过去式'] = val;
            break;
          case 'd':
            result['过去分词'] = val;
            break;
          case 'i':
            result['现在分词'] = val;
            break;
          case '3':
            result['第三人称单数'] = val;
            break;
          case 's':
            result['复数'] = val;
            break;
          case 'r':
            result['比较级'] = val;
            break;
          case 't':
            result['最高级'] = val;
            break;
          case '0':
            result['原型'] = val;
            break;
          case '1':
            result['变形原型'] = val;
            break;
        }
      }
    }
    return result;
  }

  factory DictWordDetail.fromRow(
    Map<String, dynamic> row, {
    List<DictExample> examples = const [],
  }) {
    return DictWordDetail(
      word: row['word'] as String? ?? '',
      phonetic: row['phonetic'] as String? ?? '',
      rawTranslation: row['translation'] as String? ?? '',
      definition: row['definition'] as String? ?? '',
      tagString: row['tag'] as String? ?? '',
      collins: (row['collins'] as int?) ?? 0,
      oxford: (row['oxford'] as int?) ?? 0,
      exchangeString: row['exchange'] as String? ?? '',
      examples: examples,
    );
  }
}
