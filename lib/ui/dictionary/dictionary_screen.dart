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
import 'widgets/dict_pack_chip_bar.dart';
import 'widgets/dict_pack_panel_host.dart';

class DictionaryScreen extends StatefulWidget {
  final DictionaryDbService dbService;
  final DictionaryAudioService audioService;
  final MDictManagerService? mdictManager;

  /// Shared with the top-bar chips so they can open the slide-out panel.
  final DictPanelController? panelController;

  const DictionaryScreen({
    super.key,
    required this.dbService,
    required this.audioService,
    this.mdictManager,
    this.panelController,
  });

  @override
  State<DictionaryScreen> createState() => DictionaryScreenState();
}

class DictionaryScreenState extends State<DictionaryScreen> with WidgetsBindingObserver {
  late final MDictManagerService _mdictManager;
  bool _ownsMdictManager = false;

  List<DictWordSummary> _matchedWords = [];
  DictWordDetail? _currentDetail;
  bool _hasUsAudio = true;
  bool _hasUkAudio = true;
  String _selectedWord = '';
  bool _isLoading = false;

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
    if (granted && (!widget.dbService.isReady || !_mdictManager.isInitialized)) {
      await _initDictionary();
    }
  }

  Future<void> _checkPermissionAndInit() async {
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
    final hasUs = await widget.audioService.hasHumanAudio(word, accent: 'us');
    final hasUk = await widget.audioService.hasHumanAudio(word, accent: 'uk');
    if (mounted) {
      setState(() {
        _hasUsAudio = hasUs;
        _hasUkAudio = hasUk;
        _currentDetail = detail;
        _isLoading = false;
      });
    }
  }

  void openPackManager() {
    showDialog(
      context: context,
      builder: (context) => DictPackManagerDialog(
        managerService: _mdictManager,
        dbService: widget.dbService,
        onDbChanged: () {
          if (mounted) setState(() {});
          _onSearch(_selectedWord.isNotEmpty ? _selectedWord : 'test');
        },
      ),
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
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: SafeArea(
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
                  : DictPackPanelHost(
                      managerService: _mdictManager,
                      targetWord: _currentDetail!.word,
                      controller: widget.panelController,
                      onSearchWord: (w) {
                        _onSearch(w);
                        _loadWordDetail(w);
                      },
                      onPlayAudioScheme: (soundUrl) async {
                        // Recorded audio only (exact MDD path, e.g. Longman
                        // hwd/ame/1/test1.mp3); entries without audio stay silent.
                        await widget.audioService.playResource(soundUrl);
                      },
                      child: Column(
                        children: [
                          // Top Word Header: word, phonetics, audio, tags, collins stars
                          DictCardHeader(
                            detail: _currentDetail!,
                            hasUsAudio: _hasUsAudio,
                            hasUkAudio: _hasUkAudio,
                            onPlayTts: () => widget.audioService.speakText(_currentDetail!.word),
                            onPlayUs: () => widget.audioService.playWord(
                              _currentDetail!.word,
                              accent: 'us',
                            ),
                            onPlayUk: () => widget.audioService.playWord(
                              _currentDetail!.word,
                              accent: 'uk',
                            ),
                          ),
                          // ECDICT quick reference fills the card; dictionaries open as a side panel.
                          Expanded(child: DictMeaningColumn(detail: _currentDetail!)),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
