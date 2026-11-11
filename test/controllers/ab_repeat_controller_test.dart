import 'package:flutter_test/flutter_test.dart';
import 'package:audacity_player/controllers/ab_repeat_controller.dart';

void main() {
  group('AbRepeatController Tests', () {
    late AbRepeatController controller;
    Duration? seekTarget;
    bool pauseCalled = false;
    bool resumeCalled = false;

    setUp(() {
      seekTarget = null;
      pauseCalled = false;
      resumeCalled = false;
      controller = AbRepeatController(
        onSeekRequest: (d) async => seekTarget = d,
        onPauseRequest: () async => pauseCalled = true,
        onResumeRequest: () async => resumeCalled = true,
      );
    });

    test('标定 A 点与 B 点后应进入激活状态', () {
      controller.markPointA(const Duration(seconds: 1));
      expect(controller.state.pointA, const Duration(seconds: 1));
      expect(controller.state.isActive, isFalse);

      controller.markPointB(const Duration(seconds: 3));
      expect(controller.state.pointB, const Duration(seconds: 3));
      expect(controller.state.isActive, isTrue);
    });

    test('到达 B 点时应触发 Seek 回 A 点', () async {
      controller.markPointA(const Duration(seconds: 1));
      controller.markPointB(const Duration(seconds: 3));

      // 模拟未到 B 点
      controller.onPositionChanged(const Duration(seconds: 2));
      expect(seekTarget, isNull);

      // 模拟到达 B 点 (无停顿)
      controller.onPositionChanged(const Duration(seconds: 3, milliseconds: 50));
      expect(seekTarget, const Duration(seconds: 1));
    });

    test('步进微调 A 点与 B 点', () {
      controller.markPointA(const Duration(seconds: 2));
      controller.markPointB(const Duration(seconds: 5));

      controller.nudgeA(-100); // A - 0.1s => 1.9s
      expect(controller.state.pointA, const Duration(milliseconds: 1900));

      controller.nudgeB(100); // B + 0.1s => 5.1s
      expect(controller.state.pointB, const Duration(milliseconds: 5100));
    });
  });
}
