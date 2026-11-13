import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:audacity_player/models/dictionary/dict_example.dart';
import 'package:audacity_player/models/dictionary/dict_word_detail.dart';
import 'package:audacity_player/ui/dictionary/widgets/dict_card_header.dart';
import 'package:audacity_player/ui/dictionary/widgets/dict_meaning_column.dart';
import 'package:audacity_player/ui/dictionary/widgets/dict_examples_column.dart';

void main() {
  const sampleDetail = DictWordDetail(
    word: 'test',
    phonetic: 'test',
    rawTranslation: 'n. 试验；检验\nvt. 试验；测试',
    definition: 'n. any standardized procedure for measuring...',
    tagString: 'zk cet4',
    collins: 5,
    oxford: 1,
    exchangeString: 'p:tested/s:tests',
    examples: [
      DictExample(source: 'oxford', enText: 'This test is easy.', cnText: '测试简单。'),
      DictExample(source: 'longman', enText: 'A clinical test.', cnText: '临床试验。'),
    ],
  );

  testWidgets('DictCardHeader renders word, tags and audio buttons', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DictCardHeader(
          detail: sampleDetail,
          onPlayUs: () {},
          onPlayUk: () {},
        ),
      ),
    ));

    expect(find.text('test'), findsOneWidget);
    expect(find.text('/test/'), findsOneWidget);
    expect(find.text('中考'), findsOneWidget);
    expect(find.text('四级'), findsNothing); // 只显示最低一级
    expect(find.text('US 🔊'), findsOneWidget);
    expect(find.text('UK 🔊'), findsOneWidget);
  });

  testWidgets('DictCardHeader shows only a TTS chip when no recorded audio exists', (tester) async {
    var tts = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DictCardHeader(
          detail: sampleDetail,
          hasUsAudio: false,
          hasUkAudio: false,
          onPlayTts: () => tts++,
          onPlayUs: () {},
          onPlayUk: () {},
        ),
      ),
    ));

    expect(find.text('US 🔊'), findsNothing);
    expect(find.text('UK 🔊'), findsNothing);
    await tester.tap(find.text('TTS 🔊'));
    expect(tts, 1);
  });

  testWidgets('DictCardHeader keeps a long word on one line while the right side has room', (tester) async {
    tester.view.physicalSize = const Size(900, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Future<double> headerHeight(String word) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: DictCardHeader(
              detail: DictWordDetail(
                word: word,
                phonetic: '',
                rawTranslation: '',
                definition: '',
                tagString: 'zk',
                collins: 0,
                oxford: 0,
                exchangeString: '',
                examples: const [],
              ),
              onPlayUs: () {},
              onPlayUk: () {},
            ),
          ),
        ),
      ));
      return tester.getSize(find.byType(DictCardHeader)).height;
    }

    final short = await headerHeight('without a bean');
    final long = await headerHeight('without a blink of qualm');
    expect(long, short, reason: 'long word wrapped although the card is wide enough');
    expect(tester.takeException(), isNull);
  });

  testWidgets('DictMeaningColumn renders translations and inflections', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: DictMeaningColumn(detail: sampleDetail),
      ),
    ));

    expect(find.text('n. 试验；检验'), findsOneWidget);
    expect(find.text('vt. 试验；测试'), findsOneWidget);
    expect(find.text('过去式: tested'), findsOneWidget);
  });

  testWidgets('DictExamplesColumn renders Oxford and Longman example cards', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DictExamplesColumn(
          examples: sampleDetail.examples,
          targetWord: 'test',
          onSpeak: (_) {},
        ),
      ),
    ));

    expect(find.byType(RichText), findsWidgets);
    expect(find.text('测试简单。'), findsOneWidget);
    expect(find.text('临床试验。'), findsOneWidget);
    expect(find.text('📘 牛津初阶例句'), findsOneWidget);
    expect(find.text('📙 朗文当代例句'), findsOneWidget);
  });

  testWidgets('DictCardHeader does not overflow at narrow landscape card width', (tester) async {
    tester.view.physicalSize = const Size(404, 300);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DictCardHeader(
          detail: sampleDetail,
          onPlayUs: () {},
          onPlayUk: () {},
        ),
      ),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
