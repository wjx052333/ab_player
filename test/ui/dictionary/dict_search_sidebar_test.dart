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
}
