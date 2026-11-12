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
