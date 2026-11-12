import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:audacity_player/services/mdict/mdict_crypto.dart';
import 'package:audacity_player/services/mdict/mdict_reader.dart';

void main() {
  group('MDict Native Dart Reader Tests', () {
    test('MDictCrypto ripemd128 computes correct hash', () {
      final input = Uint8List.fromList('abc'.codeUnits);
      final hash = MDictCrypto.ripemd128(input);
      expect(hash.length, 16);
      final hex = hash.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      expect(hex, 'c14a12199c66e4ba84636b0f69144c77');
    });

    test('Reads oxfordPrimary.mdx and looks up words', () async {
      const mdxPath = 'data_download/oxfordPrimary/oxfordPrimary.mdx';
      if (!File(mdxPath).existsSync()) return;

      final reader = await MDictReader.open(mdxPath);
      expect(reader.header.engineVersion, 2.0);
      expect(reader.numEntries, greaterThan(4000));

      final html = await reader.lookup('test');
      expect(html, isNotNull);
      expect(html!.contains('test'), true);

      final appleHtml = await reader.lookup('apple');
      expect(appleHtml, isNotNull);
      expect(appleHtml!.contains('apple'), true);

      await reader.dispose();
    });

    test('Reads Sound_us_uk.mdd and extracts sound resources', () async {
      const mddPath = 'data_download/Sound_us_uk/Sound_us_uk.mdd';
      if (!File(mddPath).existsSync()) return;

      final reader = await MDictReader.open(mddPath);
      expect(reader.isMdd, true);
      expect(reader.numEntries, greaterThan(200000));

      final testSound = await reader.lookupResource(r'\test.spx');
      expect(testSound, isNotNull);
      expect(testSound!.length, greaterThan(100));

      await reader.dispose();
    });
  });
}
