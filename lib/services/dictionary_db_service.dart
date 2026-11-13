import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';
import '../models/dictionary/dict_example.dart';
import '../models/dictionary/dict_word_detail.dart';
import '../models/dictionary/dict_word_summary.dart';
import 'storage_permission_service.dart';

class DictionaryDbService {
  Database? _ecdictDb;
  Database? _extraDb;
  String? _resolvedEcdictPath;
  String? _resolvedExtraPath;

  bool get isReady => _ecdictDb != null;
  String? get resolvedEcdictPath => _resolvedEcdictPath;
  String? get resolvedExtraPath => _resolvedExtraPath;

  static const String _prefKeyCustomEcdict = 'custom_ecdict_path';
  static const String _prefKeyCustomExtra = 'custom_extra_path';

  Future<bool> initialize({
    String? customEcdictPath,
    String? customExtraPath,
  }) async {
    dispose();

    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {}

    final targetEcdict = customEcdictPath ?? prefs?.getString(_prefKeyCustomEcdict);
    final targetExtra = customExtraPath ?? prefs?.getString(_prefKeyCustomExtra);

    final ecdictFile = await _resolveFile(targetEcdict, 'ecdict-ultimate.db');
    if (ecdictFile != null && ecdictFile.existsSync()) {
      _resolvedEcdictPath = ecdictFile.path;
      _ecdictDb = sqlite3.open(ecdictFile.path, mode: OpenMode.readOnly);
      if (prefs != null) {
        await prefs.setString(_prefKeyCustomEcdict, ecdictFile.path);
      }
    }

    final extraFile = await _resolveFile(targetExtra, 'dict_extra.db');
    if (extraFile != null && extraFile.existsSync()) {
      _resolvedExtraPath = extraFile.path;
      _extraDb = sqlite3.open(extraFile.path, mode: OpenMode.readOnly);
      if (prefs != null) {
        await prefs.setString(_prefKeyCustomExtra, extraFile.path);
      }
    }

    return isReady;
  }

  Future<File?> _resolveFile(String? preferredPath, String defaultFileName) async {
    // 0. Preferred / previously selected file
    if (preferredPath != null && preferredPath.isNotEmpty) {
      final f = File(preferredPath);
      if (f.existsSync()) return f;
    }

    // 1. Desktop / Windows dev relative directory (data_download/...)
    if (!kIsWeb && !Platform.isAndroid && !Platform.isIOS) {
      final relFile = File('data_download/$defaultFileName');
      if (relFile.existsSync()) return relFile;
    }

    // 2. Android & cross-platform: Scan canonical public download and storage directories
    try {
      final searchDirs = await StoragePermissionService.getSearchDirectories();
      for (final dirPath in searchDirs) {
        final f = File('$dirPath/$defaultFileName');
        if (f.existsSync()) return f;
      }
    } catch (e) {
      debugPrint('Error searching candidate directories in DictionaryDbService: $e');
    }

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
      debugPrint('Dictionary search error: $e');
      return [];
    }
  }

  Future<DictWordDetail?> getWordDetail(String word) async {
    final db = _ecdictDb;
    if (db == null) return null;

    final q = word.trim();
    if (q.isEmpty) return null;

    try {
      final results = db.select(
        'SELECT * FROM stardict WHERE word = ? COLLATE NOCASE LIMIT 1;',
        [q],
      );

      if (results.isEmpty) return null;

      final row = results.first;
      final actualWord = row['word'] as String? ?? q;

      final examples = await _fetchExamples(actualWord);

      return DictWordDetail(
        word: actualWord,
        phonetic: row['phonetic'] as String? ?? '',
        rawTranslation: row['translation'] as String? ?? '',
        definition: row['definition'] as String? ?? '',
        tagString: row['tag'] as String? ?? '',
        collins: (row['collins'] as int?) ?? 0,
        oxford: (row['oxford'] as int?) ?? 0,
        exchangeString: row['exchange'] as String? ?? '',
        examples: examples,
      );
    } catch (e) {
      debugPrint('Dictionary getWordDetail error: $e');
      return null;
    }
  }

  Future<List<DictExample>> _fetchExamples(String word) async {
    final db = _extraDb;
    if (db == null) return [];

    final list = <DictExample>[];

    try {
      final rows = db.select(
        'SELECT source, en_text, cn_text, order_index FROM examples WHERE word = ? COLLATE NOCASE ORDER BY order_index ASC LIMIT 10;',
        [word],
      );
      for (final r in rows) {
        list.add(DictExample(
          source: r['source'] as String? ?? 'oxford',
          enText: r['en_text'] as String? ?? '',
          cnText: r['cn_text'] as String?,
          orderIndex: (r['order_index'] as int?) ?? 0,
        ));
      }
    } catch (e) {
      debugPrint('Failed to query dict_extra.db: $e');
    }

    return list;
  }

  void dispose() {
    _ecdictDb?.close();
    _ecdictDb = null;
    _extraDb?.close();
    _extraDb = null;
    _resolvedEcdictPath = null;
    _resolvedExtraPath = null;
  }
}
