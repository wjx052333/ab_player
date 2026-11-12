import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import '../../../services/mdict/mdict_manager_service.dart';
import 'dict_pack_manager_dialog.dart';

class DictTabsColumn extends StatefulWidget {
  final MDictManagerService managerService;
  final String targetWord;
  final ValueChanged<String> onSearchWord;
  final ValueChanged<String> onPlayAudioScheme;

  const DictTabsColumn({
    super.key,
    required this.managerService,
    required this.targetWord,
    required this.onSearchWord,
    required this.onPlayAudioScheme,
  });

  @override
  State<DictTabsColumn> createState() => _DictTabsColumnState();
}

class _DictTabsColumnState extends State<DictTabsColumn> with TickerProviderStateMixin {
  TabController? _tabController;
  final Map<String, String?> _definitionCache = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initTabController();
    _loadDefinitions();
    widget.managerService.addListener(_onPacksChanged);
  }

  @override
  void didUpdateWidget(covariant DictTabsColumn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetWord != widget.targetWord) {
      _loadDefinitions();
    }
  }

  void _onPacksChanged() {
    _initTabController();
    _loadDefinitions();
    if (mounted) setState(() {});
  }

  void _initTabController() {
    final activeCount = widget.managerService.activePacks.length;
    final totalTabs = activeCount > 0 ? activeCount : 1;

    final oldIndex = _tabController?.index ?? 0;
    _tabController?.dispose();
    _tabController = TabController(
      length: totalTabs,
      vsync: this,
      initialIndex: (oldIndex < totalTabs) ? oldIndex : 0,
    );
  }

  Future<void> _loadDefinitions() async {
    final word = widget.targetWord.trim();
    if (word.isEmpty) return;

    setState(() => _isLoading = true);
    final activePacks = widget.managerService.activePacks;

    for (final pack in activePacks) {
      final cacheKey = '${pack.id}_$word';
      if (!_definitionCache.containsKey(cacheKey)) {
        try {
          final def = await pack.lookupDefinition(word);
          _definitionCache[cacheKey] = def;
        } catch (_) {
          _definitionCache[cacheKey] = null;
        }
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _openManagerDialog() {
    showDialog(
      context: context,
      builder: (context) => DictPackManagerDialog(managerService: widget.managerService),
    );
  }

  String _cleanHtml(String rawHtml, String? customCss) {
    String html = rawHtml;
    // Replace black font tags for dark mode visibility
    html = html.replaceAll(RegExp(r'color="#0+"', caseSensitive: false), 'color="#E0E0E0"');
    html = html.replaceAll(RegExp(r'color="#000000"', caseSensitive: false), 'color="#E0E0E0"');

    if (customCss != null && customCss.isNotEmpty) {
      return '<style>$customCss</style>$html';
    }
    return html;
  }

  @override
  void dispose() {
    widget.managerService.removeListener(_onPacksChanged);
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activePacks = widget.managerService.activePacks;

    if (activePacks.isEmpty) {
      return Container(
        color: const Color(0xFF141414),
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('未挂载任何外部权威 MDX 词典', style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _openManagerDialog,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('管理/挂载 MDX 词典'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2C3E50),
                  foregroundColor: const Color(0xFF3AAFA9),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: const Color(0xFF141414),
      child: Column(
        children: [
          // Tab bar container
          Container(
            height: 34,
            decoration: const BoxDecoration(
              color: Color(0xFF1E1E1E),
              border: Border(bottom: BorderSide(color: Color(0xFF2A2A2A))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    indicatorColor: const Color(0xFF3AAFA9),
                    indicatorWeight: 2.5,
                    labelColor: const Color(0xFF3AAFA9),
                    unselectedLabelColor: Colors.white60,
                    labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    unselectedLabelStyle: const TextStyle(fontSize: 12),
                    tabs: activePacks.map((pack) {
                      final hasDef = _definitionCache['${pack.id}_${widget.targetWord}'] != null;
                      return Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(pack.title),
                            if (hasDef) ...[
                              const SizedBox(width: 4),
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF2ECC71),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                InkWell(
                  onTap: _openManagerDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.tune, size: 14, color: Color(0xFF3AAFA9)),
                        SizedBox(width: 4),
                        Text('词库管理', style: TextStyle(color: Color(0xFF3AAFA9), fontSize: 11)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Tab views
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF3AAFA9), strokeWidth: 2))
                : TabBarView(
                    controller: _tabController,
                    children: activePacks.map((pack) {
                      final def = _definitionCache['${pack.id}_${widget.targetWord}'];

                      if (def == null || def.isEmpty) {
                        return Center(
                          child: Text(
                            '《${pack.title}》未收录单词 "${widget.targetWord}"',
                            style: const TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                        );
                      }

                      final cleanContent = _cleanHtml(def, pack.customCss);

                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(14),
                        child: HtmlWidget(
                          cleanContent,
                          textStyle: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 13, height: 1.4),
                          onTapUrl: (url) {
                            if (url.startsWith('sound://')) {
                              widget.onPlayAudioScheme(url.substring(8));
                              return true;
                            }
                            if (url.startsWith('entry://')) {
                              final jumpWord = url.substring(8).replaceAll('#', '').trim();
                              widget.onSearchWord(jumpWord);
                              return true;
                            }
                            return false;
                          },
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
