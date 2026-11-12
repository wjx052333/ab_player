import 'dart:io';
import 'dart:typed_data';
import 'mdict_reader.dart';

/// Represents a loaded MDict dictionary pack containing:
/// - .mdx definition reader
/// - optional companion .mdd resource reader (for pictures/audio)
/// - optional .css stylesheet content
class MDictDictionaryPack {
  final String id;
  final String title;
  final String mdxPath;
  final String? mddPath;
  final String? cssPath;
  final String? customCss;
  final int totalEntries;

  final MDictReader mdxReader;
  final MDictReader? mddReader;
  bool isEnabled;

  MDictDictionaryPack({
    required this.id,
    required this.title,
    required this.mdxPath,
    this.mddPath,
    this.cssPath,
    this.customCss,
    required this.totalEntries,
    required this.mdxReader,
    this.mddReader,
    this.isEnabled = true,
  });

  /// Open an MDX pack and optionally pair with matching .mdd and .css files
  static Future<MDictDictionaryPack> open({
    required String mdxPath,
    String? mddPath,
    String? cssPath,
    String? customTitle,
  }) async {
    final mdxReader = await MDictReader.open(mdxPath);

    MDictReader? mddReader;
    final resolvedMddPath = mddPath ?? _findCompanionFile(mdxPath, '.mdd');
    if (resolvedMddPath != null && File(resolvedMddPath).existsSync()) {
      try {
        mddReader = await MDictReader.open(resolvedMddPath);
      } catch (_) {}
    }

    String? cssContent;
    final resolvedCssPath = cssPath ?? _findCompanionFile(mdxPath, '.css');
    if (resolvedCssPath != null && File(resolvedCssPath).existsSync()) {
      try {
        cssContent = await File(resolvedCssPath).readAsString();
      } catch (_) {}
    }

    final id = File(mdxPath).uri.pathSegments.last.replaceAll('.mdx', '');
    String title = customTitle ?? mdxReader.header.title.trim();
    if (title.isEmpty) {
      title = id;
    }

    return MDictDictionaryPack(
      id: id,
      title: title,
      mdxPath: mdxPath,
      mddPath: resolvedMddPath,
      cssPath: resolvedCssPath,
      customCss: cssContent,
      totalEntries: mdxReader.numEntries,
      mdxReader: mdxReader,
      mddReader: mddReader,
      isEnabled: true,
    );
  }

  static String? _findCompanionFile(String mdxPath, String extension) {
    final basePath = mdxPath.substring(0, mdxPath.lastIndexOf('.'));
    final target = '$basePath$extension';
    if (File(target).existsSync()) return target;

    // Check same folder
    final dir = File(mdxPath).parent;
    for (final entity in dir.listSync()) {
      if (entity is File && entity.path.toLowerCase().endsWith(extension)) {
        return entity.path;
      }
    }
    return null;
  }

  /// Look up definition HTML in this dictionary
  Future<String?> lookupDefinition(String word) async {
    if (!isEnabled) return null;
    return mdxReader.lookup(word);
  }

  /// Look up companion resource (audio / image)
  Future<Uint8List?> lookupResource(String resourcePath) async {
    return mddReader?.lookupResource(resourcePath);
  }

  /// Close and dispose file handles
  Future<void> dispose() async {
    await mdxReader.dispose();
    await mddReader?.dispose();
  }
}
