import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../services/dictionary_db_service.dart';
import '../../../services/mdict/mdict_manager_service.dart';
import '../../../services/storage_permission_service.dart';

class DictPackManagerDialog extends StatefulWidget {
  final MDictManagerService managerService;
  final DictionaryDbService dbService;
  final VoidCallback? onDbChanged;

  const DictPackManagerDialog({
    super.key,
    required this.managerService,
    required this.dbService,
    this.onDbChanged,
  });

  @override
  State<DictPackManagerDialog> createState() => _DictPackManagerDialogState();
}

class _DictPackManagerDialogState extends State<DictPackManagerDialog> {
  bool _isLoading = false;
  bool _hasStoragePermission = true;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final granted = await StoragePermissionService.isStoragePermissionGranted();
    if (mounted) {
      setState(() => _hasStoragePermission = granted);
    }
  }

  Future<void> _pickExternalMdx() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final lower = path.toLowerCase();
        if (!lower.endsWith('.mdx') && !lower.endsWith('.mdd')) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('请选择以 .mdx 或 .mdd 结尾的词典文件')),
            );
          }
          return;
        }

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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选取词典文件失败: $e')),
        );
      }
    }
  }

  Future<void> _pickCustomEcdictDb() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        setState(() => _isLoading = true);
        await widget.dbService.initialize(customEcdictPath: path);
        if (mounted) {
          setState(() => _isLoading = false);
          widget.onDbChanged?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.dbService.isReady
                    ? '已成功连接基础词库: ${path.split(Platform.pathSeparator).last}'
                    : '指定的文件无效或无法连接',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选取数据库文件失败: $e')),
        );
      }
    }
  }

  void _requestStoragePermission() {
    StoragePermissionService.requestStoragePermission();
  }

  @override
  Widget build(BuildContext context) {
    final packs = widget.managerService.packs;
    final isAndroid = !kIsWeb && Platform.isAndroid;
    final needsPermission = isAndroid && !_hasStoragePermission;

    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        width: 640,
        height: (MediaQuery.of(context).size.height - 48).clamp(240.0, 480.0),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部标题
            Row(
              children: [
                const Icon(Icons.tune, color: Color(0xFF3AAFA9), size: 20),
                const SizedBox(width: 8),
                const Text(
                  '词典与词库管理',
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

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            // 权限警示卡片 (若未获权限)
            if (needsPermission) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, color: Colors.orange, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '缺少“所有文件访问权限”，无法自动读取公共 Download 目录中的词库。',
                        style: TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: const Size(60, 28),
                      ),
                      onPressed: _requestStoragePermission,
                      child: const Text('去授权', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],

            // 1. 基础词库状态区 (ECDICT)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF242424),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF333333)),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.dbService.isReady ? Icons.check_circle : Icons.warning_amber,
                    color: widget.dbService.isReady ? const Color(0xFF3AAFA9) : Colors.orange,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.dbService.isReady ? 'ECDICT 升学考点库 (已连接)' : '未检测到 ecdict-ultimate.db',
                          style: TextStyle(
                            color: widget.dbService.isReady ? Colors.white : Colors.orange,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.dbService.resolvedEcdictPath ?? '支持将数据库放至 Download/ 目录或点击右侧手动选取',
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _pickCustomEcdictDb,
                    icon: const Icon(Icons.folder_open, size: 14),
                    label: Text(widget.dbService.isReady ? '重新指定' : '手动指定'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF3AAFA9),
                      side: const BorderSide(color: Color(0xFF3AAFA9)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: const Size(80, 30),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            const Row(
              children: [
                Icon(Icons.library_books, color: Color(0xFF3AAFA9), size: 16),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '外部权威词典 (MDX / MDD 容器，长按拖动可排序)：',
                    style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 2. 外部 MDX 词典列表
            packs.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        '当前未挂载外部 MDX 词典\n可将牛津/朗文等放入公共 Download 目录，或点击下方添加',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white38, fontSize: 12, height: 1.5),
                      ),
                    ),
                  )
                : ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
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
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),
            // 底部按钮栏
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
