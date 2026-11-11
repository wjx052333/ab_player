import 'package:flutter_test/flutter_test.dart';
import 'package:audacity_player/main.dart';

void main() {
  testWidgets('AudacityPlayerApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AudacityPlayerApp());
    expect(find.text('未选择音频'), findsOneWidget);
    expect(find.text('设为 A 点'), findsOneWidget);
    expect(find.text('设为 B 点'), findsOneWidget);
  });
}
