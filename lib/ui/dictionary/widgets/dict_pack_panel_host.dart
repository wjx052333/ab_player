import 'package:flutter/material.dart';
import '../../../services/mdict/mdict_dictionary_pack.dart';
import '../../../services/mdict/mdict_manager_service.dart';
import 'dict_pack_chip_bar.dart';
import 'mdict_web_view.dart';

typedef DictPanelBodyBuilder = Widget Function(
  BuildContext context,
  MDictDictionaryPack pack,
  String html,
);

/// Wraps the word card body; when a dictionary chip (in the top bar, driven by
/// [controller]) is tapped, a WebView panel slides in from the right over [child].
class DictPackPanelHost extends StatefulWidget {
  final MDictManagerService managerService;
  final String targetWord;
  final Widget child;
  final ValueChanged<String> onSearchWord;
  final ValueChanged<String> onPlayAudioScheme;
  final DictPanelController? controller;

  /// Fraction of the host width covered by the open panel. 1.0 = as large as
  /// the word card, so the dictionary content has the full card to show.
  final double panelWidthFactor;

  /// Overrides the WebView body (used by tests, which have no platform view).
  final DictPanelBodyBuilder? panelBodyBuilder;

  const DictPackPanelHost({
    super.key,
    required this.managerService,
    required this.targetWord,
    required this.child,
    required this.onSearchWord,
    required this.onPlayAudioScheme,
    this.controller,
    this.panelWidthFactor = 1.0,
    this.panelBodyBuilder,
  });

  @override
  State<DictPackPanelHost> createState() => _DictPackPanelHostState();
}

class _DictPackPanelHostState extends State<DictPackPanelHost> {
  static const panelKey = ValueKey('dict-pack-panel');
  static const _slide = Duration(milliseconds: 220);

  final Map<String, String?> _definitionCache = {};
  late DictPanelController _ctl;
  bool _ownsCtl = false;
  bool _isLoading = false;

  String? get _openPackId => _ctl.openPackId;

  @override
  void initState() {
    super.initState();
    _attachController();
    _loadDefinitions();
    widget.managerService.addListener(_onPacksChanged);
  }

  void _attachController() {
    _ownsCtl = widget.controller == null;
    _ctl = widget.controller ?? DictPanelController();
    _ctl.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant DictPackPanelHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _ctl.removeListener(_onControllerChanged);
      if (_ownsCtl) _ctl.dispose();
      _attachController();
    }
    if (oldWidget.targetWord != widget.targetWord) _loadDefinitions();
  }

  void _onPacksChanged() {
    final ids = widget.managerService.activePacks.map((p) => p.id);
    if (_openPackId != null && !ids.contains(_openPackId)) _ctl.close();
    _loadDefinitions();
    if (mounted) setState(() {});
  }

  Future<void> _loadDefinitions() async {
    final word = widget.targetWord.trim();
    if (word.isEmpty) return;

    setState(() => _isLoading = true);
    for (final pack in widget.managerService.activePacks) {
      final key = '${pack.id}_$word';
      if (_definitionCache.containsKey(key)) continue;
      try {
        _definitionCache[key] = await pack.lookupDefinition(word);
      } catch (_) {
        _definitionCache[key] = null;
      }
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
    _publishAvailability(word);
  }

  void _publishAvailability(String word) {
    _ctl.setHasEntry({
      for (final pack in widget.managerService.activePacks)
        if (_definitionCache.containsKey('${pack.id}_$word'))
          pack.id: (_definitionCache['${pack.id}_$word'] ?? '').isNotEmpty,
    });
  }

  String? _definitionOf(MDictDictionaryPack pack) =>
      _definitionCache['${pack.id}_${widget.targetWord.trim()}'];

  void _close() => _ctl.close();

  @override
  void dispose() {
    widget.managerService.removeListener(_onPacksChanged);
    _ctl.removeListener(_onControllerChanged);
    if (_ownsCtl) _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final packs = widget.managerService.activePacks;
    final isOpen = _openPackId != null;

    return PopScope(
      canPop: !isOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && isOpen) _close();
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final panelWidth = constraints.maxWidth * widget.panelWidthFactor;
          return ClipRect(
            child: Stack(
              children: [
                Positioned.fill(
                  child: widget.child,
                ),
                // Scrim: tapping the uncovered card area closes the panel.
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: !isOpen,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _close,
                      child: AnimatedOpacity(
                        duration: _slide,
                        opacity: isOpen ? 1 : 0,
                        child: const ColoredBox(color: Color(0x66000000)),
                      ),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: _slide,
                  curve: Curves.easeOutCubic,
                  top: 0,
                  bottom: 0,
                  width: panelWidth,
                  right: isOpen ? 0 : -panelWidth,
                  child: isOpen ? _buildPanel(packs) : const SizedBox.shrink(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPanel(List<MDictDictionaryPack> packs) {
    final pack = packs.where((p) => p.id == _openPackId).firstOrNull;
    if (pack == null) return const SizedBox.shrink();
    final def = _definitionOf(pack);

    Widget body;
    if (_isLoading && def == null) {
      body = const Center(
        child: CircularProgressIndicator(color: Color(0xFF3AAFA9), strokeWidth: 2),
      );
    } else if (def == null || def.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '《${pack.title}》未收录单词 "${widget.targetWord}"',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ),
      );
    } else if (widget.panelBodyBuilder != null) {
      body = widget.panelBodyBuilder!(context, pack, def);
    } else {
      body = MDictWebView(
        key: ValueKey('${pack.id}_${widget.targetWord}'),
        pack: pack,
        html: def,
        onSoundUrl: widget.onPlayAudioScheme,
        onEntryUrl: widget.onSearchWord,
      );
    }

    return Material(
      key: panelKey,
      color: const Color(0xFF141414),
      elevation: 12,
      child: Column(
        children: [
          Container(
            height: 40,
            padding: const EdgeInsets.only(left: 12, right: 4),
            decoration: const BoxDecoration(
              color: Color(0xFF1E1E1E),
              border: Border(bottom: BorderSide(color: Color(0xFF2A2A2A))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    pack.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF3AAFA9),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  icon: const Icon(Icons.close, size: 18, color: Colors.white54),
                  onPressed: _close,
                ),
              ],
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}
