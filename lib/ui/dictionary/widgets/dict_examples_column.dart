import 'package:flutter/material.dart';
import '../../../models/dictionary/dict_example.dart';

class DictExamplesColumn extends StatelessWidget {
  final List<DictExample> examples;
  final String targetWord;
  final ValueChanged<String> onSpeak;

  const DictExamplesColumn({
    super.key,
    required this.examples,
    required this.targetWord,
    required this.onSpeak,
  });

  @override
  Widget build(BuildContext context) {
    if (examples.isEmpty) {
      return Container(
        color: const Color(0xFF141414),
        child: const Center(
          child: Text(
            '暂无权威例句',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ),
      );
    }

    final oxfordExamples = examples.where((e) => e.source == 'oxford').toList();
    final longmanExamples = examples.where((e) => e.source == 'longman').toList();
    final otherExamples = examples.where((e) => e.source != 'oxford' && e.source != 'longman').toList();

    return Container(
      color: const Color(0xFF141414),
      padding: const EdgeInsets.all(14),
      child: ListView(
        children: [
          if (oxfordExamples.isNotEmpty) ...[
            _buildSectionHeader('📘 牛津初阶例句', const Color(0xFF3498DB)),
            ...oxfordExamples.map((e) => _buildExampleCard(e)),
            const SizedBox(height: 12),
          ],
          if (longmanExamples.isNotEmpty) ...[
            _buildSectionHeader('📙 朗文当代例句', const Color(0xFFE67E22)),
            ...longmanExamples.map((e) => _buildExampleCard(e)),
            const SizedBox(height: 12),
          ],
          if (otherExamples.isNotEmpty) ...[
            _buildSectionHeader('📖 精选例句', const Color(0xFF3AAFA9)),
            ...otherExamples.map((e) => _buildExampleCard(e)),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(width: 3, height: 14, color: accentColor),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              color: accentColor,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExampleCard(DictExample example) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF282828)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => onSpeak(example.enText),
                child: const Padding(
                  padding: EdgeInsets.only(top: 2, right: 6),
                  child: Icon(Icons.volume_up, size: 16, color: Color(0xFF3AAFA9)),
                ),
              ),
              Expanded(
                child: _buildHighlightedText(example.enText, targetWord),
              ),
            ],
          ),
          if (example.cnText != null && example.cnText!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 22),
              child: Text(
                example.cnText!,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHighlightedText(String text, String highlightWord) {
    final spans = <TextSpan>[];
    if (highlightWord.isEmpty) {
      return Text(text, style: const TextStyle(color: Colors.white, fontSize: 13));
    }

    final lowerText = text.toLowerCase();
    final lowerWord = highlightWord.toLowerCase();
    int start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerWord, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }
      spans.add(TextSpan(
        text: text.substring(index, index + lowerWord.length),
        style: const TextStyle(
          color: Color(0xFFF4D03F),
          fontWeight: FontWeight.bold,
        ),
      ));
      start = index + lowerWord.length;
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.35),
        children: spans,
      ),
    );
  }
}
