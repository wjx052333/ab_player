import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'mdict_dictionary_pack.dart';
import 'mdict_reader.dart';

/// Central manager for dynamically loaded MDX/MDD dictionary packs and dedicated audio bank.
class MDictManagerService extends ChangeNotifier {
  final List<MDictDictionaryPack> _packs = [];
  MDictReader? _dedicatedAudioMdd;
  bool _isInitialized = false;

  List<MDictDictionaryPack> get packs => List.unmodifiable(_packs);
  List<MDictDictionaryPack> get activePacks => _packs.where((p) => p.isEnabled).toList();
  bool get isInitialized => _isInitialized;

  /// Initialize and auto-discover dictionaries in local folders and user saved paths.
  Future<void> initialize() async {
    if (_isInitialized) return;

    // 1. Auto-discover dedicated Sound_us_uk.mdd
    await _initDedicatedAudioMdd();

    // 2. Discover built-in or default local dictionaries in data_download
    await _discoverDefaultPacks();

    // 3. Load user-added dictionary paths from SharedPreferences
    await _loadSavedUserPacks();

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _initDedicatedAudioMdd() async {
    final candidatePaths = [
      'data_download/Sound_us_uk/Sound_us_uk.mdd',
      'data_download/Sound_us_uk/sound.mdd',
      'data_download/Sound_us_uk.mdd',
    ];

    for (final p in candidatePaths) {
      final f = File(p);
      if (f.existsSync()) {
        try {
          _dedicatedAudioMdd = await MDictReader.open(f.path);
          debugPrint('MDictManagerService: Dedicated sound bank loaded from ${f.path}');
          break;
        } catch (e) {
          debugPrint('Failed to open audio MDD: $e');
        }
      }
    }
  }

  Future<void> _discoverDefaultPacks() async {
    final defaults = [
      {
        'mdx': 'data_download/oxfordPrimary/oxfordPrimary.mdx',
        'title': '📘 牛津初阶',
      },
      {
        'mdx': 'data_download/LongmanDictionaryOfContemporaryEnglish6thEnEn/LongmanDictionaryOfContemporaryEnglish6thEnEn.mdx',
        'title': '📙 朗文当代 6th',
      },
    ];

    for (final item in defaults) {
      final path = item['mdx']!;
      final title = item['title'];
      if (File(path).existsSync()) {
        await addPackFromFile(path, customTitle: title, saveToPrefs: false);
      }
    }
  }

  Future<void> _loadSavedUserPacks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPaths = prefs.getStringList('mdict_user_packs') ?? [];
      for (final p in savedPaths) {
        if (File(p).existsSync() && !_packs.any((pack) => pack.mdxPath == p)) {
          await addPackFromFile(p, saveToPrefs: false);
        }
      }
    } catch (e) {
      debugPrint('Failed to load saved user packs: $e');
    }
  }

  Future<void> _persistPacks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userPaths = _packs.map((p) => p.mdxPath).toList();
      await prefs.setStringList('mdict_user_packs', userPaths);
    } catch (e) {
      debugPrint('Failed to persist packs: $e');
    }
  }

  /// Add a dictionary pack dynamically from an .mdx file path.
  Future<MDictDictionaryPack?> addPackFromFile(
    String mdxPath, {
    String? mddPath,
    String? cssPath,
    String? customTitle,
    bool saveToPrefs = true,
  }) async {
    if (!File(mdxPath).existsSync()) return null;

    // Avoid duplicates
    final existingIdx = _packs.indexWhere((p) => p.mdxPath == mdxPath);
    if (existingIdx != -1) {
      return _packs[existingIdx];
    }

    try {
      final pack = await MDictDictionaryPack.open(
        mdxPath: mdxPath,
        mddPath: mddPath,
        cssPath: cssPath,
        customTitle: customTitle,
      );
      _packs.add(pack);
      if (saveToPrefs) {
        await _persistPacks();
      }
      notifyListeners();
      return pack;
    } catch (e) {
      debugPrint('Failed to add pack from $mdxPath: $e');
      return null;
    }
  }

  /// Toggle enabled state of a pack.
  void togglePack(String id, bool isEnabled) {
    final idx = _packs.indexWhere((p) => p.id == id);
    if (idx != -1) {
      _packs[idx].isEnabled = isEnabled;
      notifyListeners();
    }
  }

  /// Remove and dispose a pack.
  Future<void> removePack(String id) async {
    final idx = _packs.indexWhere((p) => p.id == id);
    if (idx != -1) {
      final pack = _packs.removeAt(idx);
      await pack.dispose();
      await _persistPacks();
      notifyListeners();
    }
  }

  /// Reorder packs.
  Future<void> reorderPacks(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _packs.removeAt(oldIndex);
    _packs.insert(newIndex, item);
    await _persistPacks();
    notifyListeners();
  }

  /// Look up audio pronunciation bytes for a word from dedicated sound bank or active companion MDDs.
  Future<Uint8List?> getAudioBytes(String word, {String accent = 'us'}) async {
    final safeWord = word.trim().toLowerCase();
    final isUk = accent.toLowerCase() == 'uk';

    // Patterns for Sound_us_uk.mdd: \word.spx, \word_Uk.spx
    final candidates = isUk
        ? [
            '\\${safeWord}_uk.spx',
            '\\${safeWord}_uk.mp3',
            '\\$safeWord.spx',
            '\\$safeWord.mp3',
          ]
        : [
            '\\$safeWord.spx',
            '\\$safeWord.mp3',
            '\\${safeWord}_us.spx',
            '\\${safeWord}_us.mp3',
          ];

    // 1. Check dedicated audio MDD first
    final audioMdd = _dedicatedAudioMdd;
    if (audioMdd != null) {
      for (final key in candidates) {
        final bytes = await audioMdd.lookupResource(key);
        if (bytes != null && bytes.isNotEmpty) {
          return bytes;
        }
      }
    }

    // 2. Check each loaded dictionary pack's companion .mdd
    for (final pack in activePacks) {
      if (pack.mddReader != null) {
        for (final key in candidates) {
          final bytes = await pack.lookupResource(key);
          if (bytes != null && bytes.isNotEmpty) {
            return bytes;
          }
        }
      }
    }

    return null;
  }

  @override
  void dispose() {
    for (final p in _packs) {
      p.dispose();
    }
    _packs.clear();
    _dedicatedAudioMdd?.dispose();
    super.dispose();
  }
}
