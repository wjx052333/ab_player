import 'package:flutter_test/flutter_test.dart';
import 'package:audacity_player/models/repeat_state.dart';

void main() {
  group('RepeatState Tests', () {
    test('初始状态应为未设置且无 A-B 点', () {
      final state = RepeatState.initial();
      expect(state.pointA, isNull);
      expect(state.pointB, isNull);
      expect(state.isActive, isFalse);
      expect(state.pauseSeconds, 0);
      expect(state.remainingLoops, -1); // -1 代表无限
    });

    test('设置 A 和 B 点且校验最小间隔 200ms', () {
      final state = RepeatState.initial()
          .setPointA(const Duration(seconds: 2))
          .setPointB(const Duration(milliseconds: 2100)); // 只有 100ms 间隔

      expect(state.isValidInterval, isFalse);

      final validState = state.setPointB(const Duration(seconds: 4));
      expect(validState.isValidInterval, isTrue);
      expect(validState.duration, const Duration(seconds: 2));
    });

    test('如果 B 小于 A，应能正确纠正为有序区间', () {
      final state = RepeatState.fromRange(
        const Duration(seconds: 5),
        const Duration(seconds: 2),
      );
      expect(state.pointA, const Duration(seconds: 2));
      expect(state.pointB, const Duration(seconds: 5));
    });
  });
}
