import 'dart:io';
import 'dart:ui' as ui;

import 'package:audacity_player/services/mdict/mdict_dictionary_pack.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

const _dir = 'data_download/LongmanDictionaryOfContemporaryEnglish6thEnEn';
const _base = '$_dir/LongmanDictionaryOfContemporaryEnglish6thEnEn';

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    final f = File(p);
    if (f.existsSync()) {
      loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    }
  }
  await loader.load();
}

Future<void> _snapshot(WidgetTester tester, GlobalKey key, String out) async {
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File(out).writeAsBytesSync(data!.buffer.asUint8List());
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final available = File('$_base.mdx').existsSync();

  testWidgets('render Longman entry as the app does today', (tester) async {
    await _loadFont('TestFont', [
      'C:/Windows/Fonts/arial.ttf',
      'C:/Windows/Fonts/msyh.ttc',
    ]);

    late MDictDictionaryPack pack;
    String? html;
    await tester.runAsync(() async {
      pack = await MDictDictionaryPack.open(mdxPath: '$_base.mdx', mddPath: '$_base.mdd');
      html = await pack.lookupDefinition('test');
    });
    expect(html, isNotNull);

    // Same transformation as DictTabsColumn._cleanHtml
    var cleaned = html!
        .replaceAll(RegExp(r'color="#0+"', caseSensitive: false), 'color="#E0E0E0"');
    final css = pack.customCss;
    if (css != null && css.isNotEmpty) cleaned = '<style>$css</style>$cleaned';

    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF141414),
        body: RepaintBoundary(
          key: key,
          child: Container(
            color: const Color(0xFF141414),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: HtmlWidget(
                cleaned,
                buildAsync: false,
                textStyle: const TextStyle(
                  color: Color(0xFFE0E0E0),
                  fontSize: 13,
                  height: 1.4,
                  fontFamily: 'TestFont',
                ),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await _snapshot(tester, key, 'build/render/longman_before.png');
    await tester.runAsync(() => pack.dispose());
  }, skip: !available);
}
