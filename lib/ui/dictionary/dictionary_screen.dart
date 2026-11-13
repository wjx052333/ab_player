import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../models/dictionary/dict_word_detail.dart';
import '../../models/dictionary/dict_word_summary.dart';
import '../../services/dictionary_audio_service.dart';
import '../../services/dictionary_db_service.dart';
import '../../services/mdict/mdict_manager_service.dart';
import '../../services/storage_permission_service.dart';
import 'widgets/dict_card_header.dart';
import 'widgets/dict_meaning_column.dart';
import 'widgets/dict_pack_manager_dialog.dart';
import 'widgets/dict_search_sidebar.dart';
import 'widgets/dict_tabs_column.dart';

class DictionaryScreen extends StatefulWidget {
  final DictionaryDbService dbService;
  final DictionaryAudioService audioService;
  final MDictManagerService? mdictManager;

  const DictionaryScreen({
    super.key,
    required this.dbService,
    required this.audioService,
    this.mdictManager,
  });

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> with WidgetsBindingObserver {
  late final MDictManagerService _mdictManager;
  bool _ownsMdictManager = false;

  List<DictWordSummary> _matchedWords = [];
  DictWordDetail? _currentDetail;
  String _selectedWord = '';
  bool _isLoading = false;
  bool _hasStoragePermission = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.mdictManager != null) {
      _mdictManager = widget.mdictManager!;
    } else {
      _mdictManager = MDictManagerService();
      _ownsMdictManager = true;
    }
    _checkPermissionAndInit();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _onAppResumed();
    }
  }

  Future<void> _onAppResumed() async {
    final granted = await StoragePermissionService.isStoragePermissionGranted();
    if (mounted) {
      setState(() => _hasStoragePermission = granted);
    }
    if (granted && (!widget.dbService.isReady || !_mdictManager.isInitialized)) {
      await _initDictionary();
    }
  }

  Future<void> _checkPermissionAndInit() async {
    final granted = await StoragePermissionService.isStoragePermissionGranted();
    if (mounted) {
      setState(() => _hasStoragePermission = granted);
    }
    await _initDictionary();
  }

  Future<void> _initDictionary() async {
    if (!_mdictManager.isInitialized) {
      await _mdictManager.initialize();
    }
    if (!widget.dbService.isReady) {
      if (mounted) setState(() => _isLoading = true);
      await widget.dbService.initialize();
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
    if (!mounted) return;

    setState(() {
      _matchedWords = words;
    });

    if (words.isNotEmpty && !_matchedWords.any((w) => w.word.toLowerCase() == _selectedWord.toLowerCase())) {
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
      if (mounted) {
        setState(() => _isLoading = false);
      }
      _onSearch('test');
    }
  }

  void _showPermissionRationaleDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF222222),
        title: const Row(
          children: [
            Icon(Icons.folder_special, color: Color(0xFF3AAFA9)),
            SizedBox(width: 8),
            Text('需要所有文件访问权限', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: const Text(
          '为了能够自动读取公共下载目录 (/Download) 和外置卡中的离线词典数据库 (ecdict-ultimate.db) 以及 MDX/MDD 大词典，请允许应用访问外部存储文件。',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3AAFA9),
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              StoragePermissionService.requestStoragePermission();
            },
            child: const Text('去授权'),
          ),
        ],
      ),
    );
  }

  void _openPackManager() {
    showDialog(
      context: context,
      builder: (context) => DictPackManagerDialog(managerService: _mdictManager),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_ownsMdictManager) {
      _mdictManager.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAndroid = !kIsWeb && Platform.isAndroid;
    final needsPermission = isAndroid && !_hasStoragePermission;

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
                        ? 'ECDICT 词库就绪 (340万词汇)'
                        : '未检测到 ecdict-ultimate.db',
                    style: TextStyle(
                      color: widget.dbService.isReady ? Colors.white70 : Colors.orange,
                      fontSize: 11,
                    ),
                  ),
                  if (needsPermission) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _showPermissionRationaleDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.orange.withValues(alpha: 0.6)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.lock_open, size: 12, color: Colors.orange),
                            SizedBox(width: 4),
                            Text('缺少文件权限，点此授权', style: TextStyle(color: Colors.orange, fontSize: 10)),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 14),
                  AnimatedBuilder(
                    animation: _mdictManager,
                    builder: (context, _) {
                      final packCount = _mdictManager.activePacks.length;
                      return Row(
                        children: [
                          const Icon(Icons.library_books, size: 14, color: Color(0xFF3AAFA9)),
                          const SizedBox(width: 4),
                          Text(
                            '外部 MDX 词库: 已挂载 $packCount 套',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      );
                    },
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: _openPackManager,
                    child: const Row(
                      children: [
                        Icon(Icons.tune, size: 14, color: Color(0xFF3AAFA9)),
                        SizedBox(width: 4),
                        Text('管理词库', style: TextStyle(color: Color(0xFF3AAFA9), fontSize: 11)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: _pickCustomDb,
                    child: const Row(
                      children: [
                        Icon(Icons.folder_open, size: 14, color: Color(0xFF3AAFA9)),
                        SizedBox(width: 4),
                        Text('指定基础词库', style: TextStyle(color: Color(0xFF3AAFA9), fontSize: 11)),
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
                        onWordSelected: (word) {
                          _loadWordDetail(word);
                        },
                        onClearQuery: () {
                          setState(() {
                            _matchedWords = [];
                          });
                        },
                      ),
                    ),
                  ),
                  // Right card details (65%)
                  Expanded(
                    flex: 65,
                    child: _currentDetail == null
                        ? Center(
                            child: _isLoading
                                ? const CircularProgressIndicator(color: Color(0xFF3AAFA9))
                                : const Text(
                                    '请从左侧列表选择单词查看详解',
                                    style: TextStyle(color: Colors.white38, fontSize: 13),
                                  ),
                          )
                        : Column(
                            children: [
                              // Top Word Header: word, phonetics, audio, tags, collins stars
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
                              // Sub-column body: 45% ECDICT meanings + 55% MDict Expandable Tabs
                              Expanded(
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 45,
                                      child: DictMeaningColumn(detail: _currentDetail!),
                                    ),
                                    Expanded(
                                      flex: 55,
                                      child: DictTabsColumn(
                                        managerService: _mdictManager,
                                        targetWord: _currentDetail!.word,
                                        onSearchWord: (w) {
                                          _onSearch(w);
                                          _loadWordDetail(w);
                                        },
                                        onPlayAudioScheme: (soundUrl) {
                                          final clean = soundUrl.replaceAll('audio/', '').replaceAll('.mp3', '').replaceAll('.spx', '');
                                          widget.audioService.playWord(clean);
                                        },
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
