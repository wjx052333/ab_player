import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../services/mdict/mdict_manager_service.dart';

class DictPackManagerDialog extends StatefulWidget {
  final MDictManagerService managerService;

  const DictPackManagerDialog({super.key, required this.managerService});

  @override
  State<DictPackManagerDialog> createState() => _DictPackManagerDialogState();
}

class _DictPackManagerDialogState extends State<DictPackManagerDialog> {
  Future<void> _pickExternalMdx() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mdx'],
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      final pack = await widget.managerService.addPackFromFile(path);
      if (mounted) {
        setState(() {});
        if (pack != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('成功挂载词典: ${pack.title} (${pack.totalEntries} 词条)')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final packs = widget.managerService.packs;

    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        width: 580,
        height: 420,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.menu_book, color: Color(0xFF3AAFA9), size: 20),
                const SizedBox(width: 8),
                const Text(
                  '词库管理 (MDX / MDD 容器)',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '支持随时添加任意外部 .mdx/.mdd 权威词典，拖拽可调整 Tab 显示顺序：',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: packs.isEmpty
                  ? const Center(
                      child: Text('当前未挂载任何外部 MDX 词典', style: TextStyle(color: Colors.white38)),
                    )
                  : ReorderableListView.builder(
                      itemCount: packs.length,
                      onReorder: (oldIndex, newIndex) {
                        widget.managerService.reorderPacks(oldIndex, newIndex);
                        setState(() {});
                      },
                      itemBuilder: (context, index) {
                        final pack = packs[index];
                        return Container(
                          key: ValueKey(pack.id),
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF282828),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF333333)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.drag_indicator, color: Colors.white38, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      pack.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '收录 ${pack.totalEntries} 词条 ${pack.mddPath != null ? "• 带配套 MDD" : ""}',
                                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: pack.isEnabled,
                                activeThumbColor: const Color(0xFF3AAFA9),
                                onChanged: (val) {
                                  widget.managerService.togglePack(pack.id, val);
                                  setState(() {});
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                onPressed: () async {
                                  await widget.managerService.removePack(pack.id);
                                  setState(() {});
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _pickExternalMdx,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('添加 MDX / MDD 词典文件'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2C3E50),
                    foregroundColor: const Color(0xFF3AAFA9),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('完成', style: TextStyle(color: Colors.white70)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
