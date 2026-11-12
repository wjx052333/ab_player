import 'package:flutter/material.dart';
import '../../../models/dictionary/dict_word_detail.dart';

class DictCardHeader extends StatelessWidget {
  final DictWordDetail detail;
  final VoidCallback onPlayUs;
  final VoidCallback onPlayUk;

  const DictCardHeader({
    super.key,
    required this.detail,
    required this.onPlayUs,
    required this.onPlayUk,
  });

  String _formatTag(String tag) {
    switch (tag.toLowerCase()) {
      case 'zk': return '中考';
      case 'gk': return '高考';
      case 'cet4': return '四级';
      case 'cet6': return '六级';
      case 'ky': return '考研';
      case 'ielts': return '雅思';
      case 'toefl': return '托福';
      case 'gre': return 'GRE';
      default: return tag.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        border: Border(bottom: BorderSide(color: Color(0xFF2C2C2C))),
      ),
      child: Row(
        children: [
          Text(
            detail.word,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 12),
          if (detail.phonetic.isNotEmpty)
            Text(
              '/${detail.phonetic}/',
              style: const TextStyle(
                color: Color(0xFF3AAFA9),
                fontSize: 16,
                fontFamily: 'monospace',
              ),
            ),
          const SizedBox(width: 16),
          // Audio buttons
          _buildAudioChip(label: 'US 🔊', onTap: onPlayUs),
          const SizedBox(width: 8),
          _buildAudioChip(label: 'UK 🔊', onTap: onPlayUk),
          const Spacer(),
          // Exam badges
          Wrap(
            spacing: 6,
            children: detail.tags.map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF2B3A42),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF3AAFA9).withValues(alpha: 0.4)),
                ),
                child: Text(
                  _formatTag(tag),
                  style: const TextStyle(color: Color(0xFFDEF2F1), fontSize: 11),
                ),
              );
            }).toList(),
          ),
          if (detail.collins > 0) ...[
            const SizedBox(width: 10),
            Row(
              children: List.generate(
                detail.collins,
                (_) => const Icon(Icons.star, size: 14, color: Color(0xFFF4D03F)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAudioChip({required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF2C3E50),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF3AAFA9).withValues(alpha: 0.5)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF3AAFA9),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
