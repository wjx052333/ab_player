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

  /// 公共 Download 下存放词库/数据库的子目录名，避免把文件散放在 Download 根目录
  static const String appSubDir = 'english';

  /// Android 公共存储中的 Download/english 候选目录 (主存储在前，外置 SD 卡在后)；
  /// 非 Android 平台返回空列表
  static Future<List<String>> getPublicAppDirectories() async {
    if (kIsWeb || !Platform.isAndroid) return [];
    final dirs = <String>{};

    // 1. 调用原生 MethodChannel 解析真实系统目录
    try {
      final List<dynamic>? nativePaths =
          await _channel.invokeMethod<List<dynamic>>('getPublicStoragePaths');
      if (nativePaths != null) {
        for (final p in nativePaths) {
          // 原生返回的是 Download 目录本身，这里只取其下的 english 子目录
          if (p is String && p.isNotEmpty && p.endsWith('Download')) {
            dirs.add('$p/$appSubDir');
          }
        }
      }
    } catch (e) {
      debugPrint('getPublicStoragePaths error: $e');
    }

    // 2. 静态常见路径兜底兼容
    dirs.add('/storage/emulated/0/Download/$appSubDir');
    dirs.add('/sdcard/Download/$appSubDir');
    return dirs.toList();
  }

  /// 获取跨机型兼容的全部潜在候选目录 (公共存储只认 Download/english 子目录)：
  /// 1. [getPublicAppDirectories] 的 Download/english 目录
  /// 2. path_provider 的下载目录/english、应用沙盒文档与支持目录
  static Future<List<String>> getSearchDirectories() async {
    final dirs = <String>{...await getPublicAppDirectories()};

    // path_provider 标准路径（跨平台/沙盒兼容）
    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) dirs.add('${downloads.path}/$appSubDir');
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
