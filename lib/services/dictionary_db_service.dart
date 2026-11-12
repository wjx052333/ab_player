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
  String? get resolvedExtraPath => _resolvedExtraPath;

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
