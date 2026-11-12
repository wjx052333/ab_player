class DictWordSummary {
  final String word;
  final String phonetic;
  final String rawTranslation;
  final String tagString;
  final int collins;
  final int oxford;

  const DictWordSummary({
    required this.word,
    this.phonetic = '',
    this.rawTranslation = '',
    this.tagString = '',
    this.collins = 0,
    this.oxford = 0,
  });

  List<String> get tags => tagString
      .split(' ')
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();

  String get briefTranslation {
    final lines = rawTranslation.split(RegExp(r'[\r\n]+'));
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return '';
  }

  factory DictWordSummary.fromRow(Map<String, dynamic> row) {
    return DictWordSummary(
      word: row['word'] as String? ?? '',
      phonetic: row['phonetic'] as String? ?? '',
      rawTranslation: row['translation'] as String? ?? '',
      tagString: row['tag'] as String? ?? '',
      collins: (row['collins'] as int?) ?? 0,
      oxford: (row['oxford'] as int?) ?? 0,
    );
  }
}
