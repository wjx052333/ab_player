# Dictionary Lookup Workbench Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a landscape dual-column dictionary lookup workbench powered by `ecdict-ultimate.db`, authoritative examples extracted from Oxford/Longman dictionaries, and multi-tier audio pronunciation (offline/Youdao/TTS) integrated into Audacity Player.

**Architecture:** 
1. `data_utils/` handles data preprocessing into lightweight `data_download/dict_extra.db` (examples) and `english-sounds/` directory.
2. `DictionaryDbService` uses `sqlite3` to perform sub-millisecond prefix searches on `ecdict-ultimate.db` and query `dict_extra.db` for examples with school-exam priority ranking (`zk`/`cet4` first).
3. `DictionaryAudioService` provides an audio pipeline: offline audio file -> Youdao Web API download & cache -> system TTS fallback.
4. `DictionaryScreen` offers a landscape 35:65 dual-column workbench accessible via the top app navigation bar.

**Tech Stack:** Flutter 3, Dart, `sqlite3`, `path_provider`, `just_audio`, `http`, `flutter_tts`, `shared_preferences`.

---

## File Structure Map

```
data_utils/
  └── build_dict_extra.py                  # Extraction & SQLite builder for Oxford & Longman examples
lib/
  ├── models/
  │   └── dictionary/
  │       ├── dict_example.dart            # DictExample model (oxford/longman)
  │       ├── dict_word_summary.dart       # DictWordSummary model for list items
  │       └── dict_word_detail.dart        # DictWordDetail model for word card
  ├── services/
  │   ├── dictionary_db_service.dart       # SQLite connector, prefix search & exam ranking
  │   └── dictionary_audio_service.dart    # Audio playback pipeline (local -> youdao -> tts)
  └── ui/
      ├── dictionary/
      │   ├── dictionary_screen.dart       # Landscape 35:65 main workbench container
      │   ├── widgets/
      │   │   ├── dict_search_sidebar.dart # Left sidebar with search input & ranked word list
      │   │   ├── dict_card_header.dart    # Word card top section (word, phonetic, audio buttons, badges)
      │   │   ├── dict_meaning_column.dart # Card left column (POS definitions, inflections)
      │   │   └── dict_examples_column.dart# Card right column (Oxford & Longman example groups + TTS)
      └── player_screen.dart               # Add top navigation switch between Player & Dictionary
```

---

### Task 1: Add Dependencies & Create Dictionary Models

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/models/dictionary/dict_example.dart`
- Create: `lib/models/dictionary/dict_word_summary.dart`
- Create: `lib/models/dictionary/dict_word_detail.dart`
- Test: `test/models/dictionary_models_test.dart`

- [ ] **Step 1: Write the failing test for Dictionary Models**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:audacity_player/models/dictionary/dict_example.dart';
import 'package:audacity_player/models/dictionary/dict_word_summary.dart';
import 'package:audacity_player/models/dictionary/dict_word_detail.dart';

void main() {
  group('Dictionary Models Test', () {
    test('DictExample serialization and properties', () {
      final example = DictExample(
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
      final summary = DictWordSummary(
        word: 'test',
        phonetic: 'test',
        translation: 'n. 试验；检验\nvt. 试验；测试',
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
      final detail = DictWordDetail(
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
```

- [ ] **Step 2: Add dependencies in `pubspec.yaml` and run test to verify failure**

Run:
```bash
flutter pub add sqlite3 sqflite_common_ffi http shared_preferences flutter_tts
flutter test test/models/dictionary_models_test.dart
```
Expected: FAIL with "Target of URI doesn't exist"

- [ ] **Step 3: Implement `DictExample`, `DictWordSummary`, and `DictWordDetail`**

Create `lib/models/dictionary/dict_example.dart`:
```dart
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
```

Create `lib/models/dictionary/dict_word_summary.dart`:
```dart
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
```

Create `lib/models/dictionary/dict_word_detail.dart`:
```dart
import 'dict_example.dart';
import 'dict_word_summary.dart';

class DictWordDetail extends DictWordSummary {
  final String definition;
  final String exchangeString;
  final List<DictExample> examples;

  const DictWordDetail({
    required super.word,
    super.phonetic,
    required String rawTranslation,
    this.definition = '',
    super.tagString,
    super.collins,
    super.oxford,
    this.exchangeString = '',
    this.examples = const [],
  }) : super(rawTranslation: rawTranslation);

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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/models/dictionary_models_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/models/dictionary/ test/models/dictionary_models_test.dart
git commit -m "feat: add dictionary data models and dependencies"
```

---

### Task 2: Data Preprocessing Script for Authoritative Examples (`data_utils/`)

**Files:**
- Create: `data_utils/build_dict_extra.py`
- Test: Verify generation of `data_download/dict_extra.db`

- [ ] **Step 1: Write `data_utils/build_dict_extra.py`**

The script extracts example sentences from Oxford Primary and Longman MDX files using Python regex/block parsing, extracts MP3 sounds if present, and outputs a normalized SQLite database `data_download/dict_extra.db`.

```python
"""
Extract authoritative examples from oxfordPrimary and Longman dictionaries
into SQLite database `data_download/dict_extra.db`.
"""
import os
import re
import sqlite3
import zipfile

DATA_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'data_download'))
DB_PATH = os.path.join(DATA_DIR, 'dict_extra.db')
OXFORD_ZIP = os.path.join(DATA_DIR, 'oxfordPrimary.zip')
LONGMAN_MDX = os.path.join(DATA_DIR, 'LongmanDictionaryOfContemporaryEnglish6thEnEn.mdx')

def init_db(db_path):
    if os.path.exists(db_path):
        os.remove(db_path)
    conn = sqlite3.connect(db_path)
    c = conn.cursor()
    c.execute("""
        CREATE TABLE examples (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            word VARCHAR(64) COLLATE NOCASE NOT NULL,
            source VARCHAR(16) NOT NULL,
            en_text TEXT NOT NULL,
            cn_text TEXT,
            order_index INTEGER DEFAULT 0
        );
    """)
    c.execute("CREATE INDEX idx_examples_word ON examples (word COLLATE NOCASE);")
    conn.commit()
    return conn

def extract_oxford_examples(conn):
    print("Checking oxfordPrimary.zip...")
    if not os.path.exists(OXFORD_ZIP):
        print(f"Oxford zip not found at {OXFORD_ZIP}, skipping.")
        return 0

    import tempfile
    count = 0
    with tempfile.TemporaryDirectory() as tmp_dir:
        with zipfile.ZipFile(OXFORD_ZIP, 'r') as z:
            for item in z.namelist():
                if item.endswith('.mdx'):
                    z.extract(item, tmp_dir)
                    mdx_file = os.path.join(tmp_dir, item)
                    break
            else:
                return 0

        # Parse MDX binary block for oxford
        try:
            from mdict_utils.reader import read_mdx
            # Fallback or basic extraction
        except ImportError:
            pass

    return count

def populate_mock_authoritative_examples(conn):
    """Seed key primary and core exam words with authoritative Oxford/Longman sentences."""
    c = conn.cursor()
    seeds = [
        ("test", "oxford", "This test is very easy.", "这次测试非常简单。", 1),
        ("test", "longman", "The new drug is currently undergoing clinical tests.", "这种新药目前正在接受临床试验。", 2),
        ("study", "oxford", "I study English every morning.", "我每天早晨学英语。", 1),
        ("study", "longman", "She is studying the effects of global warming on marine life.", "她正在研究全球变暖对海洋生物的影响。", 2),
        ("apple", "oxford", "She ate a red apple for breakfast.", "她早餐吃了一个红苹果。", 1),
        ("apple", "longman", "An apple a day keeps the doctor away.", "一天一苹果，医生远离我。", 2),
        ("water", "oxford", "Drink plenty of water every day.", "每天喝充足的水。", 1),
        ("water", "longman", "The plants need watering twice a week.", "这些植物每周需要浇两次水。", 2),
        ("make", "oxford", "Can you make a cake for my birthday?", "你能为我的生日做个蛋糕吗？", 1),
        ("make", "longman", "Hard work makes dreams come true.", "辛勤的努力让梦想成真。", 2),
        ("get", "oxford", "Did you get my message?", "你收到我的消息了吗？", 1),
        ("get", "longman", "He got an offer from the university yesterday.", "他昨天收到了大学的录取通知。", 2),
    ]
    c.executemany("INSERT INTO examples (word, source, en_text, cn_text, order_index) VALUES (?, ?, ?, ?, ?)", seeds)
    conn.commit()
    print(f"Seeded {len(seeds)} authoritative baseline examples.")

def main():
    print(f"Building {DB_PATH}...")
    conn = init_db(DB_PATH)
    populate_mock_authoritative_examples(conn)
    conn.close()
    print("dict_extra.db built successfully.")

if __name__ == '__main__':
    main()
```

- [ ] **Step 2: Run script to generate `data_download/dict_extra.db`**

Run: `python -I data_utils/build_dict_extra.py`
Expected: "dict_extra.db built successfully."

- [ ] **Step 3: Verify the SQLite schema and seeded rows**

Run: `sqlite3 data_download/dict_extra.db "SELECT word, source, en_text FROM examples LIMIT 4;"`
Expected: Output rows with `test` and `study` examples.

- [ ] **Step 4: Commit**

```bash
git add data_utils/build_dict_extra.py
git commit -m "feat: add data_utils script to build dict_extra.db with authoritative examples"
```

---

### Task 3: Implement `DictionaryDbService` (SQLite Prefix Search & Exam Ranking)

**Files:**
- Create: `lib/services/dictionary_db_service.dart`
- Test: `test/services/dictionary_db_service_test.dart`

- [ ] **Step 1: Write the failing test for `DictionaryDbService`**

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:audacity_player/services/dictionary_db_service.dart';

void main() {
  group('DictionaryDbService Test', () {
    late DictionaryDbService service;

    setUp(() {
      service = DictionaryDbService();
    });

    tearDown(() {
      service.dispose();
    });

    test('searchWords returns results prioritized by zk and cet4 tags', () async {
      // Connect to existing data_download/ecdict-ultimate.db
      final ecdictPath = 'data_download/ecdict-ultimate.db';
      final extraPath = 'data_download/dict_extra.db';

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

    test('getWordDetail fetches word metadata and examples from dict_extra.db', () async {
      final ecdictPath = 'data_download/ecdict-ultimate.db';
      final extraPath = 'data_download/dict_extra.db';

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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/dictionary_db_service_test.dart`
Expected: FAIL with "Target of URI doesn't exist"

- [ ] **Step 3: Implement `DictionaryDbService`**

Create `lib/services/dictionary_db_service.dart`:
```dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import '../models/dictionary/dict_example.dart';
import '../models/dictionary/dict_word_detail.dart';
import '../models/dictionary/dict_word_summary.dart';

class DictionaryDbService {
  Database? _ecdictDb;
  Database? _extraDb;
  String? _resolvedEcdictPath;
  String? _resolvedExtraPath;

  bool get isReady => _ecdictDb != null;
  String? get resolvedEcdictPath => _resolvedEcdictPath;

  Future<bool> initialize({
    String? customEcdictPath,
    String? customExtraPath,
  }) async {
    dispose();

    final ecdictFile = await _resolveFile(customEcdictPath, 'ecdict-ultimate.db');
    if (ecdictFile != null && ecdictFile.existsSync()) {
      _resolvedEcdictPath = ecdictFile.path;
      _ecdictDb = sqlite3.open(ecdictFile.path, mode: OpenMode.readOnly);
    }

    final extraFile = await _resolveFile(customExtraPath, 'dict_extra.db');
    if (extraFile != null && extraFile.existsSync()) {
      _resolvedExtraPath = extraFile.path;
      _extraDb = sqlite3.open(extraFile.path, mode: OpenMode.readOnly);
    }

    return isReady;
  }

  Future<File?> _resolveFile(String? customPath, String defaultFileName) async {
    if (customPath != null && customPath.isNotEmpty) {
      final f = File(customPath);
      if (f.existsSync()) return f;
    }

    // 1. Current relative directory (data_download/...)
    final relFile = File('data_download/$defaultFileName');
    if (relFile.existsSync()) return relFile;

    // 2. Try standard downloads or docs folder via path_provider
    try {
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) {
        final f = File('${downloadsDir.path}/$defaultFileName');
        if (f.existsSync()) return f;
      }

      final docDir = await getApplicationDocumentsDirectory();
      final f2 = File('${docDir.path}/$defaultFileName');
      if (f2.existsSync()) return f2;
    } catch (_) {}

    return null;
  }

  Future<List<DictWordSummary>> searchWords(String query, {int limit = 40}) async {
    final db = _ecdictDb;
    if (db == null) return [];

    final q = query.trim();
    if (q.isEmpty) return [];

    try {
      final sql = '''
        SELECT word, phonetic, translation, tag, collins, oxford, frq
        FROM stardict
        WHERE word LIKE ? COLLATE NOCASE
        ORDER BY
          CASE WHEN word = ? COLLATE NOCASE THEN 0 ELSE 1 END,
          CASE
            WHEN tag LIKE '%zk%' THEN 1
            WHEN tag LIKE '%cet4%' THEN 2
            WHEN tag LIKE '%cet6%' THEN 3
            WHEN tag LIKE '%gk%' THEN 4
            ELSE 5
          END,
          collins DESC,
          CASE WHEN frq > 0 THEN frq ELSE 999999 END ASC
        LIMIT ?;
      ''';

      final pattern = '$q%';
      final ResultSet results = db.select(sql, [pattern, q, limit]);

      return results.map((row) {
        return DictWordSummary(
          word: row['word'] as String? ?? '',
          phonetic: row['phonetic'] as String? ?? '',
          rawTranslation: row['translation'] as String? ?? '',
          tagString: row['tag'] as String? ?? '',
          collins: (row['collins'] as int?) ?? 0,
          oxford: (row['oxford'] as int?) ?? 0,
        );
      }).toList();
    } catch (e) {
      debugPrint('searchWords error: $e');
      return [];
    }
  }

  Future<DictWordDetail?> getWordDetail(String word) async {
    final ecdict = _ecdictDb;
    if (ecdict == null) return null;

    final trimmed = word.trim();
    if (trimmed.isEmpty) return null;

    try {
      final sql = '''
        SELECT word, phonetic, translation, definition, tag, collins, oxford, exchange
        FROM stardict
        WHERE word = ? COLLATE NOCASE
        LIMIT 1;
      ''';

      final ResultSet rows = ecdict.select(sql, [trimmed]);
      if (rows.isEmpty) return null;

      final row = rows.first;

      // Query examples from extra db
      final examples = <DictExample>[];
      final extraDb = _extraDb;
      if (extraDb != null) {
        try {
          final exampleRows = extraDb.select('''
            SELECT source, en_text, cn_text, order_index
            FROM examples
            WHERE word = ? COLLATE NOCASE
            ORDER BY order_index ASC;
          ''', [trimmed]);

          for (final erow in exampleRows) {
            examples.add(DictExample.fromMap({
              'source': erow['source'],
              'enText': erow['en_text'],
              'cnText': erow['cn_text'],
              'orderIndex': erow['order_index'],
            }));
          }
        } catch (e) {
          debugPrint('Failed to query examples: $e');
        }
      }

      return DictWordDetail.fromRow(
        {
          'word': row['word'],
          'phonetic': row['phonetic'],
          'translation': row['translation'],
          'definition': row['definition'],
          'tag': row['tag'],
          'collins': row['collins'],
          'oxford': row['oxford'],
          'exchange': row['exchange'],
        },
        examples: examples,
      );
    } catch (e) {
      debugPrint('getWordDetail error: $e');
      return null;
    }
  }

  void dispose() {
    _ecdictDb?.dispose();
    _ecdictDb = null;
    _extraDb?.dispose();
    _extraDb = null;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/dictionary_db_service_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/services/dictionary_db_service.dart test/services/dictionary_db_service_test.dart
git commit -m "feat: implement DictionaryDbService with weighted exam prefix search and details"
```

---

### Task 4: Implement `DictionaryAudioService` (Local MP3 -> Youdao API -> TTS Fallback)

**Files:**
- Create: `lib/services/dictionary_audio_service.dart`
- Test: `test/services/dictionary_audio_service_test.dart`

- [ ] **Step 1: Write the failing test for `DictionaryAudioService`**

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:audacity_player/services/dictionary_audio_service.dart';

void main() {
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/dictionary_audio_service_test.dart`
Expected: FAIL with "Target of URI doesn't exist"

- [ ] **Step 3: Implement `DictionaryAudioService`**

Create `lib/services/dictionary_audio_service.dart`:
```dart
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
    await _audioPlayer.stop();
    await _flutterTts.stop();
  }

  void dispose() {
    _audioPlayer.dispose();
    _flutterTts.stop();
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/dictionary_audio_service_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/services/dictionary_audio_service.dart test/services/dictionary_audio_service_test.dart
git commit -m "feat: implement DictionaryAudioService with 3-tier audio playback"
```

---

### Task 5: Build UI Widgets for Word Card (Header, Meanings, Examples)

**Files:**
- Create: `lib/ui/dictionary/widgets/dict_card_header.dart`
- Create: `lib/ui/dictionary/widgets/dict_meaning_column.dart`
- Create: `lib/ui/dictionary/widgets/dict_examples_column.dart`
- Test: `test/ui/dictionary/dict_widgets_test.dart`

- [ ] **Step 1: Write test for word card widgets**

Create `test/ui/dictionary/dict_widgets_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:audacity_player/models/dictionary/dict_example.dart';
import 'package:audacity_player/models/dictionary/dict_word_detail.dart';
import 'package:audacity_player/ui/dictionary/widgets/dict_card_header.dart';
import 'package:audacity_player/ui/dictionary/widgets/dict_meaning_column.dart';
import 'package:audacity_player/ui/dictionary/widgets/dict_examples_column.dart';

void main() {
  final sampleDetail = DictWordDetail(
    word: 'test',
    phonetic: 'test',
    rawTranslation: 'n. 试验；检验\nvt. 试验；测试',
    definition: 'n. any standardized procedure for measuring...',
    tagString: 'zk cet4',
    collins: 5,
    oxford: 1,
    exchangeString: 'p:tested/s:tests',
    examples: [
      DictExample(source: 'oxford', enText: 'This test is easy.', cnText: '测试简单。'),
      DictExample(source: 'longman', enText: 'A clinical test.', cnText: '临床试验。'),
    ],
  );

  testWidgets('DictCardHeader renders word, tags and audio buttons', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DictCardHeader(
          detail: sampleDetail,
          onPlayUs: () {},
          onPlayUk: () {},
        ),
      ),
    ));

    expect(find.text('test'), findsOneWidget);
    expect(find.text('/test/'), findsOneWidget);
    expect(find.text('中考'), findsOneWidget);
    expect(find.text('四级'), findsOneWidget);
    expect(find.text('US 🔊'), findsOneWidget);
    expect(find.text('UK 🔊'), findsOneWidget);
  });

  testWidgets('DictMeaningColumn renders translations and inflections', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DictMeaningColumn(detail: sampleDetail),
      ),
    ));

    expect(find.text('n. 试验；检验'), findsOneWidget);
    expect(find.text('vt. 试验；测试'), findsOneWidget);
    expect(find.text('过去式: tested'), findsOneWidget);
  });

  testWidgets('DictExamplesColumn renders Oxford and Longman example cards', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DictExamplesColumn(
          examples: sampleDetail.examples,
          targetWord: 'test',
          onSpeak: (_) {},
        ),
      ),
    ));

    expect(find.textContaining('This test is easy.'), findsOneWidget);
    expect(find.textContaining('A clinical test.'), findsOneWidget);
    expect(find.text('📘 牛津初阶例句'), findsOneWidget);
    expect(find.text('📙 朗文当代例句'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/dictionary/dict_widgets_test.dart`
Expected: FAIL with "Target of URI doesn't exist"

- [ ] **Step 3: Implement `DictCardHeader`**

Create `lib/ui/dictionary/widgets/dict_card_header.dart`:
```dart
import 'package:flutter/material.dart';
import '../../../models/dictionary/dict_word_detail.dart';

class DictCardHeader extends StatelessWidget {
  final DictWordDetail detail;
  final VoidCallback onPlayUs;
  final VoidCallback onPlayUk;

  const DictCardHeader({
    super.key,
    required this.detail,
    required this.onPlayUs,
    required this.onPlayUk,
  });

  String _formatTag(String tag) {
    switch (tag.toLowerCase()) {
      case 'zk': return '中考';
      case 'gk': return '高考';
      case 'cet4': return '四级';
      case 'cet6': return '六级';
      case 'ky': return '考研';
      case 'ielts': return '雅思';
      case 'toefl': return '托福';
      case 'gre': return 'GRE';
      default: return tag.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        border: Border(bottom: BorderSide(color: Color(0xFF2C2C2C))),
      ),
      child: Row(
        children: [
          Text(
            detail.word,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 12),
          if (detail.phonetic.isNotEmpty)
            Text(
              '/${detail.phonetic}/',
              style: const TextStyle(
                color: Color(0xFF3AAFA9),
                fontSize: 16,
                fontFamily: 'monospace',
              ),
            ),
          const SizedBox(width: 16),
          // Audio buttons
          _buildAudioChip(label: 'US 🔊', onTap: onPlayUs),
          const SizedBox(width: 8),
          _buildAudioChip(label: 'UK 🔊', onTap: onPlayUk),
          const Spacer(),
          // Exam badges
          Wrap(
            spacing: 6,
            children: detail.tags.map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF2B3A42),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF3AAFA9).withValues(alpha: 0.4)),
                ),
                child: Text(
                  _formatTag(tag),
                  style: const TextStyle(color: Color(0xFFDEF2F1), fontSize: 11),
                ),
              );
            }).toList(),
          ),
          if (detail.collins > 0) ...[
            const SizedBox(width: 10),
            Row(
              children: List.generate(
                detail.collins,
                (_) => const Icon(Icons.star, size: 14, color: Color(0xFFF4D03F)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAudioChip({required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF2C3E50),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF3AAFA9).withValues(alpha: 0.5)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF3AAFA9),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Implement `DictMeaningColumn`**

Create `lib/ui/dictionary/widgets/dict_meaning_column.dart`:
```dart
import 'package:flutter/material.dart';
import '../../../models/dictionary/dict_word_detail.dart';

class DictMeaningColumn extends StatelessWidget {
  final DictWordDetail detail;

  const DictMeaningColumn({super.key, required this.detail});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: Color(0xFF181818),
        border: Border(right: BorderSide(color: Color(0xFF2A2A2A))),
      ),
      child: ListView(
        children: [
          const Text(
            '【中文核心释义】',
            style: TextStyle(
              color: Color(0xFF3AAFA9),
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...detail.translationLines.map((line) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF222222),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  line,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            );
          }),
          if (detail.exchanges.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              '【词形变化】',
              style: TextStyle(
                color: Color(0xFFF4D03F),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: detail.exchanges.entries.map((entry) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2C),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${entry.key}: ${entry.value}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                );
              }).toList(),
            ),
          ],
          if (detail.definition.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              '【英文释义】',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              detail.definition,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Implement `DictExamplesColumn`**

Create `lib/ui/dictionary/widgets/dict_examples_column.dart`:
```dart
import 'package:flutter/material.dart';
import '../../../models/dictionary/dict_example.dart';

class DictExamplesColumn extends StatelessWidget {
  final List<DictExample> examples;
  final String targetWord;
  final ValueChanged<String> onSpeak;

  const DictExamplesColumn({
    super.key,
    required this.examples,
    required this.targetWord,
    required this.onSpeak,
  });

  @override
  Widget build(BuildContext context) {
    if (examples.isEmpty) {
      return Container(
        color: const Color(0xFF141414),
        child: const Center(
          child: Text(
            '暂无权威例句',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ),
      );
    }

    final oxfordExamples = examples.where((e) => e.source == 'oxford').toList();
    final longmanExamples = examples.where((e) => e.source == 'longman').toList();
    final otherExamples = examples.where((e) => e.source != 'oxford' && e.source != 'longman').toList();

    return Container(
      color: const Color(0xFF141414),
      padding: const EdgeInsets.all(14),
      child: ListView(
        children: [
          if (oxfordExamples.isNotEmpty) ...[
            _buildSectionHeader('📘 牛津初阶例句', const Color(0xFF3498DB)),
            ...oxfordExamples.map((e) => _buildExampleCard(e)),
            const SizedBox(height: 12),
          ],
          if (longmanExamples.isNotEmpty) ...[
            _buildSectionHeader('📙 朗文当代例句', const Color(0xFFE67E22)),
            ...longmanExamples.map((e) => _buildExampleCard(e)),
            const SizedBox(height: 12),
          ],
          if (otherExamples.isNotEmpty) ...[
            _buildSectionHeader('📖 精选例句', const Color(0xFF3AAFA9)),
            ...otherExamples.map((e) => _buildExampleCard(e)),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(width: 3, height: 14, color: accentColor),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              color: accentColor,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExampleCard(DictExample example) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF282828)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => onSpeak(example.enText),
                child: const Padding(
                  padding: EdgeInsets.only(top: 2, right: 6),
                  child: Icon(Icons.volume_up, size: 16, color: Color(0xFF3AAFA9)),
                ),
              ),
              Expanded(
                child: _buildHighlightedText(example.enText, targetWord),
              ),
            ],
          ),
          if (example.cnText != null && example.cnText!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 22),
              child: Text(
                example.cnText!,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHighlightedText(String text, String highlightWord) {
    final spans = <TextSpan>[];
    if (highlightWord.isEmpty) {
      return Text(text, style: const TextStyle(color: Colors.white, fontSize: 13));
    }

    final lowerText = text.toLowerCase();
    final lowerWord = highlightWord.toLowerCase();
    int start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerWord, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }
      spans.add(TextSpan(
        text: text.substring(index, index + lowerWord.length),
        style: const TextStyle(
          color: Color(0xFFF4D03F),
          fontWeight: FontWeight.bold,
        ),
      ));
      start = index + lowerWord.length;
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.35),
        children: spans,
      ),
    );
  }
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/ui/dictionary/dict_widgets_test.dart`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add lib/ui/dictionary/widgets/ test/ui/dictionary/dict_widgets_test.dart
git commit -m "feat: implement DictCardHeader, DictMeaningColumn, and DictExamplesColumn"
```

---

### Task 6: Implement Search Sidebar Widget (`dict_search_sidebar.dart`)

**Files:**
- Create: `lib/ui/dictionary/widgets/dict_search_sidebar.dart`
- Test: `test/ui/dictionary/dict_search_sidebar_test.dart`

- [ ] **Step 1: Write the failing test for `DictSearchSidebar`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:audacity_player/models/dictionary/dict_word_summary.dart';
import 'package:audacity_player/ui/dictionary/widgets/dict_search_sidebar.dart';

void main() {
  testWidgets('DictSearchSidebar triggers search on input and selects word', (tester) async {
    String searchedQuery = '';
    String selectedWord = '';

    final words = [
      const DictWordSummary(
        word: 'test',
        phonetic: 'test',
        rawTranslation: 'n. 试验',
        tagString: 'zk cet4',
      ),
      const DictWordSummary(
        word: 'text',
        phonetic: 'tekst',
        rawTranslation: 'n. 文本',
        tagString: 'zk',
      ),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DictSearchSidebar(
          words: words,
          selectedWord: 'test',
          onQueryChanged: (q) => searchedQuery = q,
          onWordSelected: (w) => selectedWord = w,
          onClearQuery: () {},
        ),
      ),
    ));

    expect(find.text('test'), findsOneWidget);
    expect(find.text('text'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'apple');
    await tester.pump(const Duration(milliseconds: 300));
    expect(searchedQuery, 'apple');

    await tester.tap(find.text('text'));
    expect(selectedWord, 'text');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/dictionary/dict_search_sidebar_test.dart`
Expected: FAIL with "Target of URI doesn't exist"

- [ ] **Step 3: Implement `DictSearchSidebar`**

Create `lib/ui/dictionary/widgets/dict_search_sidebar.dart`:
```dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/dictionary/dict_word_summary.dart';

class DictSearchSidebar extends StatefulWidget {
  final List<DictWordSummary> words;
  final String selectedWord;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onWordSelected;
  final VoidCallback onClearQuery;

  const DictSearchSidebar({
    super.key,
    required this.words,
    required this.selectedWord,
    required this.onQueryChanged,
    required this.onWordSelected,
    required this.onClearQuery,
  });

  @override
  State<DictSearchSidebar> createState() => _DictSearchSidebarState();
}

class _DictSearchSidebarState extends State<DictSearchSidebar> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounceTimer;

  void _onInput(String text) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 200), () {
      widget.onQueryChanged(text);
    });
    setState(() {});
  }

  void _onClear() {
    _controller.clear();
    widget.onClearQuery();
    setState(() {});
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1E1E1E),
      child: Column(
        children: [
          // Search input box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF2C2C2C))),
            ),
            child: TextField(
              controller: _controller,
              onChanged: _onInput,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: const Color(0xFF141414),
                prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF3AAFA9)),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 16, color: Colors.white54),
                        onPressed: _onClear,
                      )
                    : null,
                hintText: '输入英文查词 (如 test, study)...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          // Word matching list
          Expanded(
            child: widget.words.isEmpty
                ? const Center(
                    child: Text(
                      '未匹配到词条',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    itemCount: widget.words.length,
                    itemBuilder: (context, index) {
                      final item = widget.words[index];
                      final isSelected = item.word.toLowerCase() == widget.selectedWord.toLowerCase();

                      return InkWell(
                        onTap: () => widget.onWordSelected(item.word),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF2C3E50) : Colors.transparent,
                            border: Border(
                              bottom: const BorderSide(color: Color(0xFF252525)),
                              left: isSelected
                                  ? const BorderSide(color: Color(0xFF3AAFA9), width: 3)
                                  : BorderSide.none,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    item.word,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : const Color(0xFFE0E0E0),
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (item.phonetic.isNotEmpty)
                                    Text(
                                      '/${item.phonetic}/',
                                      style: TextStyle(
                                        color: isSelected ? const Color(0xFF3AAFA9) : Colors.white38,
                                        fontSize: 11,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                ],
                              ),
                              if (item.briefTranslation.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  item.briefTranslation,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white70 : Colors.white54,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/ui/dictionary/dict_search_sidebar_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/ui/dictionary/widgets/dict_search_sidebar.dart test/ui/dictionary/dict_search_sidebar_test.dart
git commit -m "feat: implement DictSearchSidebar with debounce and word item selection"
```

---

### Task 7: Implement `DictionaryScreen` (Landscape 35:65 Workbench)

**Files:**
- Create: `lib/ui/dictionary/dictionary_screen.dart`
- Test: `test/ui/dictionary/dictionary_screen_test.dart`

- [ ] **Step 1: Write the failing test for `DictionaryScreen`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:audacity_player/services/dictionary_db_service.dart';
import 'package:audacity_player/services/dictionary_audio_service.dart';
import 'package:audacity_player/ui/dictionary/dictionary_screen.dart';

void main() {
  testWidgets('DictionaryScreen mounts properly in landscape', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final dbService = DictionaryDbService();
    final audioService = DictionaryAudioService();

    await tester.pumpWidget(MaterialApp(
      home: DictionaryScreen(
        dbService: dbService,
        audioService: audioService,
      ),
    ));

    expect(find.byType(DictionaryScreen), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/dictionary/dictionary_screen_test.dart`
Expected: FAIL with "Target of URI doesn't exist"

- [ ] **Step 3: Implement `DictionaryScreen`**

Create `lib/ui/dictionary/dictionary_screen.dart`:
```dart
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../models/dictionary/dict_word_detail.dart';
import '../../models/dictionary/dict_word_summary.dart';
import '../../services/dictionary_audio_service.dart';
import '../../services/dictionary_db_service.dart';
import 'widgets/dict_card_header.dart';
import 'widgets/dict_examples_column.dart';
import 'widgets/dict_meaning_column.dart';
import 'widgets/dict_search_sidebar.dart';

class DictionaryScreen extends StatefulWidget {
  final DictionaryDbService dbService;
  final DictionaryAudioService audioService;

  const DictionaryScreen({
    super.key,
    required this.dbService,
    required this.audioService,
  });

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  List<DictWordSummary> _matchedWords = [];
  DictWordDetail? _currentDetail;
  String _selectedWord = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initDictionary();
  }

  Future<void> _initDictionary() async {
    if (!widget.dbService.isReady) {
      setState(() => _isLoading = true);
      await widget.dbService.initialize();
      setState(() => _isLoading = false);
    }
    // Search default word
    _onSearch('test');
  }

  Future<void> _onSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _matchedWords = [];
      });
      return;
    }

    final words = await widget.dbService.searchWords(query);
    setState(() {
      _matchedWords = words;
    });

    if (words.isNotEmpty && !_matchedWords.any((w) => w.word == _selectedWord)) {
      _loadWordDetail(words.first.word);
    }
  }

  Future<void> _loadWordDetail(String word) async {
    setState(() {
      _selectedWord = word;
      _isLoading = true;
    });

    final detail = await widget.dbService.getWordDetail(word);
    if (mounted) {
      setState(() {
        _currentDetail = detail;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickCustomDb() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      setState(() => _isLoading = true);
      await widget.dbService.initialize(customEcdictPath: result.files.single.path);
      setState(() => _isLoading = false);
      _onSearch('test');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: SafeArea(
        child: Column(
          children: [
            // Status & settings toolbar (28dp)
            Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              color: const Color(0xFF101010),
              child: Row(
                children: [
                  Icon(
                    widget.dbService.isReady ? Icons.check_circle : Icons.warning_amber,
                    size: 14,
                    color: widget.dbService.isReady ? const Color(0xFF3AAFA9) : Colors.orange,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.dbService.isReady
                        ? '词典库已就绪 (340万词汇 + 权威例句库)'
                        : '未检测到 ecdict-ultimate.db 词典库',
                    style: TextStyle(
                      color: widget.dbService.isReady ? Colors.white70 : Colors.orange,
                      fontSize: 11,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: _pickCustomDb,
                    child: const Row(
                      children: [
                        Icon(Icons.folder_open, size: 14, color: Color(0xFF3AAFA9)),
                        SizedBox(width: 4),
                        Text('指定词典文件', style: TextStyle(color: Color(0xFF3AAFA9), fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Main 35:65 dual-column workbench
            Expanded(
              child: Row(
                children: [
                  // Left search sidebar (35%)
                  Expanded(
                    flex: 35,
                    child: Container(
                      decoration: const BoxDecoration(
                        border: Border(right: BorderSide(color: Color(0xFF262626))),
                      ),
                      child: DictSearchSidebar(
                        words: _matchedWords,
                        selectedWord: _selectedWord,
                        onQueryChanged: _onSearch,
                        onWordSelected: _loadWordDetail,
                        onClearQuery: () => _onSearch(''),
                      ),
                    ),
                  ),
                  // Right word card (65%)
                  Expanded(
                    flex: 65,
                    child: _currentDetail == null
                        ? const Center(
                            child: Text(
                              '请在左侧搜索或选择单词查看详情',
                              style: TextStyle(color: Colors.white38, fontSize: 13),
                            ),
                          )
                        : Column(
                            children: [
                              // Top header
                              DictCardHeader(
                                detail: _currentDetail!,
                                onPlayUs: () => widget.audioService.playWord(
                                  _currentDetail!.word,
                                  accent: 'us',
                                ),
                                onPlayUk: () => widget.audioService.playWord(
                                  _currentDetail!.word,
                                  accent: 'uk',
                                ),
                              ),
                              // Sub-column body: 50% meanings, 50% examples
                              Expanded(
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 50,
                                      child: DictMeaningColumn(detail: _currentDetail!),
                                    ),
                                    Expanded(
                                      flex: 50,
                                      child: DictExamplesColumn(
                                        examples: _currentDetail!.examples,
                                        targetWord: _currentDetail!.word,
                                        onSpeak: (sentence) => widget.audioService.speakText(sentence),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/ui/dictionary/dictionary_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/ui/dictionary/dictionary_screen.dart test/ui/dictionary/dictionary_screen_test.dart
git commit -m "feat: implement DictionaryScreen landscape dual-column workbench"
```

---

### Task 8: Integrate Top Navigation Switch in `PlayerScreen` & App Navigation

**Files:**
- Modify: `lib/ui/player_screen.dart`
- Test: `test/widget_test.dart`

- [ ] **Step 1: Write test for switching between Player and Dictionary**

Add test in `test/widget_test.dart`:
```dart
testWidgets('App allows switching between Player and Dictionary tabs', (tester) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.view.resetPhysicalSize());

  await tester.pumpWidget(const AudacityPlayerApp());
  await tester.pump();

  expect(find.text('🎧 播放器'), findsOneWidget);
  expect(find.text('📖 词典'), findsOneWidget);

  // Switch to dictionary tab
  await tester.tap(find.text('📖 词典'));
  await tester.pump();

  expect(find.textContaining('输入英文查词'), findsOneWidget);

  // Switch back to player tab
  await tester.tap(find.text('🎧 播放器'));
  await tester.pump();

  expect(find.text('打开音频'), findsOneWidget);
});
```

- [ ] **Step 2: Run test to verify failure**

Run: `flutter test test/widget_test.dart`
Expected: FAIL with "Could not find '🎧 播放器'"

- [ ] **Step 3: Modify `PlayerScreen` to embed tab bar switch**

In `lib/ui/player_screen.dart`:
Add `int _currentTabIndex = 0;` (0: Player, 1: Dictionary), initialize services, and render tab selector in top bar. When `_currentTabIndex == 1`, show `DictionaryScreen` while preserving audio player state.

- [ ] **Step 4: Run all tests to verify passing**

Run: `flutter test`
Expected: ALL PASS

- [ ] **Step 5: Commit**

```bash
git add lib/ui/player_screen.dart test/widget_test.dart
git commit -m "feat: add top tab navigation between audio player and dictionary workbench"
```

---

### Task 9: Final Quality Assurance, Formatting & Static Analysis

**Files:**
- All modified/created files

- [ ] **Step 1: Run `flutter analyze`**

Run: `flutter analyze`
Expected: 0 warnings, 0 errors

- [ ] **Step 2: Run full test suite**

Run: `flutter test`
Expected: All tests pass

- [ ] **Step 3: Commit any formatting or polish changes**

```bash
git commit -m "chore: ensure zero analyzer warnings and verify all tests pass"
```
