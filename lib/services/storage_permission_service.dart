import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class StoragePermissionService {
  static const MethodChannel _channel =
      MethodChannel('com.example.audacity_player/storage_permission');

  /// 检查是否拥有全文件管理权限（Android 11+）或读取权限（低版本）
  static Future<bool> isStoragePermissionGranted() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      final bool? granted = await _channel.invokeMethod<bool>('isExternalStorageManager');
      return granted ?? false;
    } catch (e) {
      debugPrint('isStoragePermissionGranted error: $e');
      return false;
    }
  }

  /// 触发跳转到系统“所有文件访问权限”设置页面
  static Future<void> requestStoragePermission() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('requestManageExternalStorage');
    } catch (e) {
      debugPrint('requestManageExternalStorage error: $e');
    }
  }

  /// 获取跨机型兼容的全部潜在候选目录：
  /// 1. 原生 API 返回的标准 Download 目录及外置 SD 卡中的 Download 目录
  /// 2. 常见兼容路径软链接 (/storage/emulated/0/Download, /sdcard/Download)
  /// 3. path_provider 的应用沙盒文档与支持目录
  static Future<List<String>> getSearchDirectories() async {
    final dirs = <String>{};

    if (!kIsWeb && Platform.isAndroid) {
      // 1. 调用原生 MethodChannel 解析真实系统目录
      try {
        final List<dynamic>? nativePaths =
            await _channel.invokeMethod<List<dynamic>>('getPublicStoragePaths');
        if (nativePaths != null) {
          for (final p in nativePaths) {
            if (p is String && p.isNotEmpty) {
              dirs.add(p);
            }
          }
        }
      } catch (e) {
        debugPrint('getPublicStoragePaths error: $e');
      }

      // 2. 静态常见路径兜底兼容
      dirs.add('/storage/emulated/0/Download');
      dirs.add('/sdcard/Download');
      dirs.add('/storage/emulated/0');
      dirs.add('/sdcard');
    }

    // 3. path_provider 标准路径（跨平台/沙盒兼容）
    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) dirs.add(downloads.path);
    } catch (_) {}

    try {
      final docs = await getApplicationDocumentsDirectory();
      dirs.add(docs.path);
    } catch (_) {}

    try {
      final support = await getApplicationSupportDirectory();
      dirs.add(support.path);
    } catch (_) {}

    return dirs.toList();
  }
}
