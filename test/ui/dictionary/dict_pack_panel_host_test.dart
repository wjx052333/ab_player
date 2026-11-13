import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audacity_player/services/mdict/mdict_manager_service.dart';
import 'package:audacity_player/ui/dictionary/widgets/dict_pack_chip_bar.dart';
import 'package:audacity_player/ui/dictionary/widgets/dict_pack_panel_host.dart';

const _longman = 'data_download/LongmanDictionaryOfContemporaryEnglish6thEnEn/'
    'LongmanDictionaryOfContemporaryEnglish6thEnEn.mdx';

/// Top-bar chips and the host share one controller, as in PlayerScreen.
Widget _host(
  MDictManagerService manager, {
  DictPanelBodyBuilder? body,
  double chipBarWidth = 400,
}) {
  final controller = DictPanelController();
  return MaterialApp(
    home: Scaffold(
      body: Column(
        children: [
          SizedBox(
            height: 32,
            width: chipBarWidth,
            child: DictPackChipBar(managerService: manager, controller: controller),
          ),
          Expanded(
            child: DictPackPanelHost(
              managerService: manager,
              controller: controller,
              targetWord: 'test',
              onSearchWord: (_) {},
              onPlayAudioScheme: (_) {},
              panelBodyBuilder: body,
              child: const Center(child: Text('ECDICT-BODY')),
            ),
          ),
        ],
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows no chips when no dictionary is mounted', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final manager = MDictManagerService();

    await tester.pumpWidget(_host(manager));
    await tester.pump();

    expect(find.text('ECDICT-BODY'), findsOneWidget);
    expect(find.byType(InkWell), findsNothing);
    expect(tester.takeException(), isNull);
    manager.dispose();
  });

  group('with the local Longman dictionary', () {
    final available = File(_longman).existsSync();

    Future<MDictManagerService> mounted(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final manager = MDictManagerService();
      await tester.runAsync(() => manager.addPackFromFile(_longman, saveToPrefs: false));
      return manager;
    }

    /// Real file IO only advances inside runAsync, so poll until [finder] shows up.
    Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
      for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(finder, findsOneWidget);
    }

    testWidgets('chip opens a panel as large as the card; close button and chip toggle close it',
        (tester) async {
      tester.view.physicalSize = const Size(700, 340);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final manager = await mounted(tester);
      await tester.pumpWidget(_host(manager, body: (_, _, _) => const Text('PANEL-BODY')));
      await tester.pump();

      expect(find.text('PANEL-BODY'), findsNothing);
      final chip = find.textContaining('Longman').first;
      expect(chip, findsOneWidget);

      await tester.tap(chip);
      await pumpUntilFound(tester, find.text('PANEL-BODY'));
      await tester.pump(const Duration(milliseconds: 400));
      final panelRect = tester.getRect(find.byKey(const ValueKey('dict-pack-panel')));
      final hostRect = tester.getRect(find.byType(DictPackPanelHost));
      expect(panelRect.width, closeTo(hostRect.width, 1.0));
      expect(panelRect.right, closeTo(hostRect.right, 1.0));

      // Close button
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
      expect(find.text('PANEL-BODY'), findsNothing);

      // Tapping the selected chip again closes it too.
      await tester.tap(chip);
      await pumpUntilFound(tester, find.text('PANEL-BODY'));
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(find.text('PANEL-BODY'), findsNothing);

      expect(tester.takeException(), isNull);
      manager.dispose();
    }, skip: !available);

    testWidgets('shows a drag hint when chips do not fit the bar', (tester) async {
      tester.view.physicalSize = const Size(700, 340);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final manager = await mounted(tester);
      await tester.pumpWidget(_host(manager, chipBarWidth: 80));
      await tester.pump();
      await tester.pump();

      expect(find.text('拖动查看更多'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(_host(manager, chipBarWidth: 400));
      await tester.pump();
      await tester.pump();
      expect(find.text('拖动查看更多'), findsNothing);
      // Not disposing the manager: a lookup may still be in flight on its files.
    }, skip: !available);
  });
}
