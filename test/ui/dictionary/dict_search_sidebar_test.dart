import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:audacity_player/models/dictionary/dict_word_summary.dart';
import 'package:audacity_player/ui/dictionary/widgets/dict_search_sidebar.dart';

void main() {
  testWidgets('DictSearchSidebar triggers search on input and selects word', (tester) async {
    String searchedQuery = '';
    String selectedWord = '';

    final words = [
      const DictWordSummary(
        word: 'test',
        phonetic: 'test',
        rawTranslation: 'n. 试验',
        tagString: 'zk cet4',
      ),
      const DictWordSummary(
        word: 'text',
        phonetic: 'tekst',
        rawTranslation: 'n. 文本',
        tagString: 'zk',
      ),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DictSearchSidebar(
          words: words,
          selectedWord: 'test',
          onQueryChanged: (q) => searchedQuery = q,
          onWordSelected: (w) => selectedWord = w,
          onClearQuery: () {},
        ),
      ),
    ));

    expect(find.text('test'), findsOneWidget);
    expect(find.text('text'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'apple');
    await tester.pump(const Duration(milliseconds: 300));
    expect(searchedQuery, 'apple');

    await tester.tap(find.text('text'));
    expect(selectedWord, 'text');
  });

  testWidgets('DictSearchSidebar does not overflow with very long word and phonetic', (tester) async {
    tester.view.physicalSize = const Size(260, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const words = [
      DictWordSummary(
        word: 'pneumonoultramicroscopicsilicovolcanoconiosis',
        phonetic: 'njuːmənəʊʌltrəmaɪkrəˈskɒpɪksɪlɪkəʊvɒlˌkeɪnəʊˌkɒnɪˈəʊsɪs',
        rawTranslation: 'n. 肺尘埃沉着病',
      ),
      DictWordSummary(word: 'a-very-long-word-without-phonetic-in-narrow-sidebar'),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DictSearchSidebar(
          words: words,
          selectedWord: '',
          onQueryChanged: (_) {},
          onWordSelected: (_) {},
          onClearQuery: () {},
        ),
      ),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
