import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audacity_player/services/mdict/mdict_manager_service.dart';
import 'package:audacity_player/ui/dictionary/widgets/dict_tabs_column.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('DictTabsColumn mounts and displays tabs properly', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final manager = MDictManagerService();
    // Do not run background auto-discovery during test to avoid long file scanning
    // Test with empty active packs first
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DictTabsColumn(
          managerService: manager,
          targetWord: 'test',
          onSearchWord: (_) {},
          onPlayAudioScheme: (_) {},
        ),
      ),
    ));

    await tester.pump();

    // Verify widget mounts and shows empty prompt / management button
    expect(find.byType(DictTabsColumn), findsOneWidget);
    expect(find.text('未挂载任何外部权威 MDX 词典'), findsOneWidget);

    manager.dispose();
  });
}
