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
  final String? customJs;
  final int totalEntries;

  final MDictReader mdxReader;
  /// All companion .mdd readers. Large dictionaries (e.g. OALD) split their
  /// resources over `name.mdd`, `name.1.mdd`, `name.2.mdd`, ...
  final List<MDictReader> mddReaders;
  bool isEnabled;

  bool get hasResources => mddReaders.isNotEmpty;

  MDictDictionaryPack({
    required this.id,
    required this.title,
    required this.mdxPath,
    this.mddPath,
    this.cssPath,
    this.customCss,
    this.customJs,
    required this.totalEntries,
    required this.mdxReader,
    this.mddReaders = const [],
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

    final mddReaders = <MDictReader>[];
    final resolvedMddPath = mddPath ?? _findCompanionFile(mdxPath, '.mdd');
    if (resolvedMddPath != null && File(resolvedMddPath).existsSync()) {
      for (final path in [resolvedMddPath, ..._findSplitMdds(resolvedMddPath)]) {
        try {
          mddReaders.add(await MDictReader.open(path));
        } catch (_) {}
      }
    }

    String? cssContent;
    final resolvedCssPath = cssPath ?? _findCompanionFile(mdxPath, '.css');
    if (resolvedCssPath != null && File(resolvedCssPath).existsSync()) {
      try {
        cssContent = await File(resolvedCssPath).readAsString();
      } catch (_) {}
    }

    // jQuery (if shipped next to the dictionary) must run before the dictionary script.
    final jsParts = <String>[];
    final jsPaths = [
      ..._findJqueryFiles(mdxPath),
      ?_findCompanionFile(mdxPath, '.js'),
    ];
    for (final path in jsPaths.toSet()) {
      try {
        jsParts.add(await File(path).readAsString());
      } catch (_) {}
    }
    final jsContent = jsParts.isEmpty ? null : jsParts.join('\n;\n');

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
      customJs: jsContent,
      totalEntries: mdxReader.numEntries,
      mdxReader: mdxReader,
      mddReaders: mddReaders,
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

  /// `name.mdd` -> sibling `name.1.mdd`, `name.2.mdd`, ... in numeric order.
  static List<String> _findSplitMdds(String mddPath) {
    final base = mddPath.substring(0, mddPath.length - '.mdd'.length);
    final fileName = base.split(RegExp(r'[\\/]')).last;
    final pattern = RegExp('^${RegExp.escape(fileName)}\\.(\\d+)\\.mdd\$', caseSensitive: false);
    final found = <int, String>{};
    try {
      for (final entity in File(mddPath).parent.listSync()) {
        if (entity is! File) continue;
        final m = pattern.firstMatch(entity.uri.pathSegments.last);
        if (m != null) found[int.parse(m.group(1)!)] = entity.path;
      }
    } catch (_) {}
    return [for (final k in found.keys.toList()..sort()) found[k]!];
  }

  static List<String> _findJqueryFiles(String mdxPath) {
    try {
      return [
        for (final e in File(mdxPath).parent.listSync())
          if (e is File && RegExp(r'jquery[^/\\]*\.js$', caseSensitive: false).hasMatch(e.path)) e.path,
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Look up definition HTML in this dictionary
  Future<String?> lookupDefinition(String word) async {
    if (!isEnabled) return null;
    return mdxReader.lookup(word);
  }

  /// Look up companion resource (audio / image)
  Future<Uint8List?> lookupResource(String resourcePath) async {
    for (final reader in mddReaders) {
      final bytes = await reader.lookupResource(resourcePath);
      if (bytes != null && bytes.isNotEmpty) return bytes;
    }
    return null;
  }

  /// Close and dispose file handles
  Future<void> dispose() async {
    await mdxReader.dispose();
    for (final reader in mddReaders) {
      await reader.dispose();
    }
  }
}
