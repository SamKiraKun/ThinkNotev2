import 'dart:async';

class Debouncer {
  Debouncer(this.delay);

  final Duration delay;
  Timer? _timer;
  Future<void> Function()? _pendingAction;

  void run(Future<void> Function() action) {
    _pendingAction = action;
    _timer?.cancel();
    _timer = Timer(delay, () async {
      final callback = _pendingAction;
      _pendingAction = null;
      if (callback != null) {
        await callback();
      }
    });
  }

  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    final callback = _pendingAction;
    _pendingAction = null;
    if (callback != null) {
      await callback();
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _pendingAction = null;
  }
}
