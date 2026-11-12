import 'package:flutter/material.dart';
import '../../../models/dictionary/dict_word_detail.dart';

class DictMeaningColumn extends StatelessWidget {
  final DictWordDetail detail;

  const DictMeaningColumn({super.key, required this.detail});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: Color(0xFF181818),
        border: Border(right: BorderSide(color: Color(0xFF2A2A2A))),
      ),
      child: ListView(
        children: [
          const Text(
            '【中文核心释义】',
            style: TextStyle(
              color: Color(0xFF3AAFA9),
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...detail.translationLines.map((line) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF222222),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  line,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            );
          }),
          if (detail.exchanges.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              '【词形变化】',
              style: TextStyle(
                color: Color(0xFFF4D03F),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: detail.exchanges.entries.map((entry) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2C),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${entry.key}: ${entry.value}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                );
              }).toList(),
            ),
          ],
          if (detail.definition.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              '【英文释义】',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              detail.definition,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
