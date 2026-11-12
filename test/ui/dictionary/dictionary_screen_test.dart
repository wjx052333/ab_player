import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:audacity_player/services/dictionary_db_service.dart';
import 'package:audacity_player/services/dictionary_audio_service.dart';
import 'package:audacity_player/ui/dictionary/dictionary_screen.dart';

void main() {
  testWidgets('DictionaryScreen mounts properly in landscape', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final dbService = DictionaryDbService();
    final audioService = DictionaryAudioService();

    await tester.pumpWidget(MaterialApp(
      home: DictionaryScreen(
        dbService: dbService,
        audioService: audioService,
      ),
    ));

    expect(find.byType(DictionaryScreen), findsOneWidget);
  });
}
