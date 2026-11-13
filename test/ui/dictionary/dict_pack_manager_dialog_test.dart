import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audacity_player/services/dictionary_db_service.dart';
import 'package:audacity_player/services/mdict/mdict_manager_service.dart';
import 'package:audacity_player/ui/dictionary/widgets/dict_pack_manager_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Logical landscape sizes of typical phones (short side is the height).
  const sizes = <Size>[Size(800, 360), Size(740, 340), Size(640, 300)];

  for (final size in sizes) {
    testWidgets('DictPackManagerDialog has no overflow at ${size.width}x${size.height}',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final manager = MDictManagerService();
      final db = DictionaryDbService();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DictPackManagerDialog(managerService: manager, dbService: db),
        ),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('添加 MDX / MDD 词典文件'), findsOneWidget);

      manager.dispose();
    });
  }
}
