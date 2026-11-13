import 'dart:io';

import 'package:audacity_player/services/mdict/mdict_dictionary_pack.dart';
import 'package:audacity_player/services/mdict/mdict_html_page_builder.dart';
import 'package:flutter_test/flutter_test.dart';

const _base = 'data_download/LongmanDictionaryOfContemporaryEnglish6thEnEn/'
    'LongmanDictionaryOfContemporaryEnglish6thEnEn';

/// Exports the exact page the WebView receives so it can be opened in a
/// desktop browser: `build/render/longman_page.html`.
void main() {
  test('export Longman page', () async {
    final pack = await MDictDictionaryPack.open(mdxPath: '$_base.mdx', mddPath: '$_base.mdd');
    final html = await pack.lookupDefinition('test');
    final page = await MDictHtmlPageBuilder.build(
      html: html!,
      css: pack.customCss,
      js: pack.customJs,
      resolveResource: pack.lookupResource,
    );
    Directory('build/render').createSync(recursive: true);
    File('build/render/longman_page.html').writeAsStringSync(page);
    await pack.dispose();
    expect(page, contains('d8018d6852bc49e3b3e655364cf1439c'));
    expect(page, contains('data:image/png;base64'));
    expect(page, isNot(contains('.css">')));
  }, skip: !File('$_base.mdx').existsSync());
}
