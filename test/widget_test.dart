import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:audacity_player/main.dart';

void main() {
  testWidgets('AudacityPlayerApp landscape smoke and anti-overflow test', (WidgetTester tester) async {
    FlutterErrorDetails? overflowDetails;
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.toString().contains('overflowed')) {
        overflowDetails = details;
      }
      originalOnError?.call(details);
    };

    // 测试极限小屏横屏设备 (例如 640 x 360)
    tester.view.physicalSize = const Size(640, 360);
    tester.view.devicePixelRatio = 1.0;

    addTearDown(() {
      FlutterError.onError = originalOnError;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const AudacityPlayerApp());

    expect(find.text('打开音频'), findsOneWidget);
    expect(find.text('设A点'), findsOneWidget);
    expect(find.text('设B点'), findsOneWidget);
    expect(find.text('清除'), findsOneWidget);

    // 极限小屏横屏下也不应有任何溢出
    expect(overflowDetails, isNull);
  });
}
