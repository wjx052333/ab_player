class DictExample {
  final String source; // 'oxford' | 'longman'
  final String enText;
  final String? cnText;
  final int orderIndex;

  const DictExample({
    required this.source,
    required this.enText,
    this.cnText,
    this.orderIndex = 0,
  });

  Map<String, dynamic> toMap() => {
    'source': source,
    'enText': enText,
    'cnText': cnText,
    'orderIndex': orderIndex,
  };

  factory DictExample.fromMap(Map<String, dynamic> map) {
    return DictExample(
      source: map['source'] as String? ?? 'oxford',
      enText: map['en_text'] as String? ?? map['enText'] as String? ?? '',
      cnText: map['cn_text'] as String? ?? map['cnText'] as String?,
      orderIndex: (map['order_index'] as int? ?? map['orderIndex'] as int?) ?? 0,
    );
  }
}
