import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/repeat_state.dart';

class AbRepeatController extends ChangeNotifier {
  final Future<void> Function(Duration) onSeekRequest;
  final Future<void> Function() onPauseRequest;
  final Future<void> Function() onResumeRequest;

  RepeatState _state = RepeatState.initial();
  RepeatState get state => _state;

  Timer? _pauseTimer;
  bool _isHandlingLoop = false;
  Duration _lastPosition = Duration.zero;

  AbRepeatController({
    required this.onSeekRequest,
    required this.onPauseRequest,
    required this.onResumeRequest,
  });

  void markPointA(Duration pos) {
    _state = _state.setPointA(pos);
    _jumpIntoSelectionIfBefore();
    notifyListeners();
  }

  void markPointB(Duration pos) {
    _state = _state.setPointB(pos);
    _jumpIntoSelectionIfBefore();
    notifyListeners();
  }

  void setSelectionRange(Duration p1, Duration p2) {
    _state = RepeatState.fromRange(p1, p2).copyWith(
      pauseSeconds: _state.pauseSeconds,
      remainingLoops: _state.remainingLoops,
      playbackSpeed: _state.playbackSpeed,
    );
    _jumpIntoSelectionIfBefore();
    notifyListeners();
  }

  /// 选区落在当前播放位置之后时立即跳到 A 点，不必等播放到 A 才开始复读
  /// (选区在当前位置之前时，onPositionChanged 本来就会立刻回跳到 A)
  void _jumpIntoSelectionIfBefore() {
    if (!_state.isActive || _state.pointA == null) return;
    final a = _state.pointA!;
    if (_lastPosition >= a) return;
    _lastPosition = a; // 先记下，避免拖动选区时重复 Seek
    onSeekRequest(a);
  }

  void clearSelection() {
    _pauseTimer?.cancel();
    _isHandlingLoop = false;
    _state = _state.copyWith(clearPoints: true, isWaitingInterval: false);
    notifyListeners();
  }

  /// 取消跟读停顿的倒计时，避免切走后计时器又把播放恢复 (不清除 A-B 点)
  void cancelPendingLoop() {
    _pauseTimer?.cancel();
    _isHandlingLoop = false;
    _state = _state.copyWith(isWaitingInterval: false);
    notifyListeners();
  }

  void nudgeA(int offsetMilliseconds) {
    if (_state.pointA == null) return;
    final newA = _state.pointA! + Duration(milliseconds: offsetMilliseconds);
    if (newA.isNegative) return;
    if (_state.pointB != null && newA >= _state.pointB! - const Duration(milliseconds: 200)) return;
    _state = _state.copyWith(pointA: newA);
    notifyListeners();
  }

  void nudgeB(int offsetMilliseconds) {
    if (_state.pointB == null) return;
    final newB = _state.pointB! + Duration(milliseconds: offsetMilliseconds);
    if (_state.pointA != null && newB <= _state.pointA! + const Duration(milliseconds: 200)) return;
    _state = _state.copyWith(pointB: newB);
    notifyListeners();
  }

  void setPauseSeconds(int seconds) {
    _state = _state.copyWith(pauseSeconds: seconds);
    notifyListeners();
  }

  void setRemainingLoops(int count) {
    _state = _state.copyWith(remainingLoops: count);
    notifyListeners();
  }

  void setPlaybackSpeed(double speed) {
    _state = _state.copyWith(playbackSpeed: speed);
    notifyListeners();
  }

  /// 由音频引擎在 positionStream 变化时回调
  void onPositionChanged(Duration currentPosition) {
    _lastPosition = currentPosition;
    if (!_state.isActive || _isHandlingLoop || _state.pointA == null || _state.pointB == null) {
      return;
    }

    if (currentPosition >= _state.pointB!) {
      _triggerLoop();
    }
  }

  Future<void> _triggerLoop() async {
    _isHandlingLoop = true;

    // 检查循环剩余次数
    if (_state.remainingLoops > 0) {
      _state = _state.copyWith(remainingLoops: _state.remainingLoops - 1);
      if (_state.remainingLoops == 0) {
        // 达到上限，停止播放
        await onPauseRequest();
        _isHandlingLoop = false;
        notifyListeners();
        return;
      }
    }

    // 处理跟读停顿
    if (_state.pauseSeconds > 0) {
      _state = _state.copyWith(isWaitingInterval: true);
      notifyListeners();
      await onPauseRequest();

      _pauseTimer?.cancel();
      _pauseTimer = Timer(Duration(seconds: _state.pauseSeconds), () async {
        if (!_state.isActive) {
          _isHandlingLoop = false;
          return;
        }
        await onSeekRequest(_state.pointA!);
        await onResumeRequest();
        _state = _state.copyWith(isWaitingInterval: false);
        _isHandlingLoop = false;
        notifyListeners();
      });
    } else {
      // 0 延迟直接 Seek
      await onSeekRequest(_state.pointA!);
      _isHandlingLoop = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pauseTimer?.cancel();
    super.dispose();
  }
}
