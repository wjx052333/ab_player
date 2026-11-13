import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import '../../../services/mdict/mdict_dictionary_pack.dart';
import '../../../services/mdict/mdict_manager_service.dart';

/// Shared state between the top-bar chips and the slide-out panel: which
/// dictionary panel is open and whether each dictionary has the current word.
class DictPanelController extends ChangeNotifier {
  String? _openPackId;
  Map<String, bool> _hasEntry = const {};

  String? get openPackId => _openPackId;

  /// pack id -> has an entry for the current word. Missing = not looked up yet.
  Map<String, bool> get hasEntry => _hasEntry;

  void open(String packId) {
    if (_openPackId == packId) return;
    _openPackId = packId;
    notifyListeners();
  }

  void close() {
    if (_openPackId == null) return;
    _openPackId = null;
    notifyListeners();
  }

  void toggle(String packId) => _openPackId == packId ? close() : open(packId);

  void setHasEntry(Map<String, bool> value) {
    if (mapEquals(_hasEntry, value)) return;
    _hasEntry = value;
    // May be called from initState; listeners must not rebuild mid-build.
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
    } else {
      notifyListeners();
    }
  }
}

/// Row of dictionary chips for the top bar. Scrolls horizontally; when chips
/// are cut off at an edge it shows a fade with a "drag" hint so the user knows
/// more dictionaries are reachable.
class DictPackChipBar extends StatefulWidget {
  final MDictManagerService managerService;
  final DictPanelController controller;

  const DictPackChipBar({super.key, required this.managerService, required this.controller});

  @override
  State<DictPackChipBar> createState() => _DictPackChipBarState();
}

class _DictPackChipBarState extends State<DictPackChipBar> {
  final ScrollController _scroll = ScrollController();
  bool _moreLeft = false;
  bool _moreRight = false;

  @override
  void initState() {
    super.initState();
    widget.managerService.addListener(_changed);
    widget.controller.addListener(_changed);
  }

  @override
  void dispose() {
    widget.managerService.removeListener(_changed);
    widget.controller.removeListener(_changed);
    _scroll.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _updateEdges() {
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    final left = p.pixels > 1;
    final right = p.pixels < p.maxScrollExtent - 1;
    if (left != _moreLeft || right != _moreRight) {
      setState(() {
        _moreLeft = left;
        _moreRight = right;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final packs = widget.managerService.activePacks;
    if (packs.isEmpty) return const SizedBox.shrink();
    // Layout is only known after the list is built.
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateEdges());

    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _updateEdges());
        return false;
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (_) {
              _updateEdges();
              return false;
            },
            child: ListView.separated(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              itemCount: packs.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, i) => _buildChip(packs[i]),
            ),
          ),
          if (_moreLeft) const Align(alignment: Alignment.centerLeft, child: _EdgeHint(left: true)),
          if (_moreRight) const Align(alignment: Alignment.centerRight, child: _EdgeHint(left: false)),
        ],
      ),
    );
  }

  Widget _buildChip(MDictDictionaryPack pack) {
    final controller = widget.controller;
    final loaded = controller.hasEntry.containsKey(pack.id);
    final hasDef = controller.hasEntry[pack.id] ?? false;
    final selected = controller.openPackId == pack.id;
    final muted = loaded && !hasDef;

    return Center(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => controller.toggle(pack.id),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF2C3E50) : const Color(0xFF262626),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? const Color(0xFF3AAFA9) : const Color(0xFF333333)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasDef)
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 5),
                  decoration: const BoxDecoration(color: Color(0xFF2ECC71), shape: BoxShape.circle),
                ),
              Flexible(
                child: Text(
                  pack.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: muted ? Colors.white30 : (selected ? const Color(0xFF3AAFA9) : Colors.white70),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EdgeHint extends StatelessWidget {
  final bool left;
  const _EdgeHint({required this.left});

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF101010);
    return IgnorePointer(
      child: Container(
        height: double.infinity,
        padding: EdgeInsets.only(left: left ? 0 : 14, right: left ? 14 : 0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: left ? Alignment.centerLeft : Alignment.centerRight,
            end: left ? Alignment.centerRight : Alignment.centerLeft,
            colors: const [bg, Color(0x00101010)],
            stops: const [0.5, 1],
          ),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (left) const Icon(Icons.chevron_left, size: 16, color: Color(0xFF3AAFA9)),
              if (!left) ...const [
                Text('拖动查看更多', style: TextStyle(color: Color(0xFF3AAFA9), fontSize: 10)),
                Icon(Icons.chevron_right, size: 16, color: Color(0xFF3AAFA9)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
