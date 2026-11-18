import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:audacity_player/main.dart';

void main() {
  testWidgets('AudacityPlayerApp landscape smoke and gesture mode switcher test', (WidgetTester tester) async {
    FlutterErrorDetails? overflowDetails;
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.toString().contains('overflowed')) {
        overflowDetails = details;
      }
      originalOnError?.call(details);
    };

    // 测试极限小屏横屏设备 (640 x 360，且包含底部虚拟按键边距 48dp)
    tester.view.physicalSize = const Size(640, 360);
    tester.view.padding = const FakeViewPadding(bottom: 48.0);
    tester.view.devicePixelRatio = 1.0;

    addTearDown(() {
      FlutterError.onError = originalOnError;
      tester.view.resetPhysicalSize();
      tester.view.resetPadding();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const AudacityPlayerApp());

    // 验证核心组件均正常渲染
    expect(find.text('打开音频'), findsOneWidget);
    expect(find.text('设A点'), findsOneWidget);
    expect(find.text('设B点'), findsOneWidget);
    expect(find.text('清除'), findsOneWidget);

    // 验证模式切换按钮已移除，三段式手势无需频繁切换
    expect(find.byTooltip('拖动'), findsNothing);
    expect(find.byTooltip('划选'), findsNothing);

    // 确保绝对没有任何 RenderFlex 溢出
    expect(overflowDetails, isNull);
  });

  testWidgets('App allows switching between Player and Dictionary tabs', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const AudacityPlayerApp());
    await tester.pump();

    expect(find.text('🎧 播放器'), findsOneWidget);
    expect(find.text('📖 词典'), findsOneWidget);

    // Switch to dictionary tab
    await tester.tap(find.text('📖 词典'));
    await tester.pump();

    expect(find.textContaining('输入英文查词'), findsOneWidget);

    // Switch back to player tab
    await tester.tap(find.text('🎧 播放器'));
    await tester.pump();

    expect(find.text('打开音频'), findsOneWidget);
  });
}
