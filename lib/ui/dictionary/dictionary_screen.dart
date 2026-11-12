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
