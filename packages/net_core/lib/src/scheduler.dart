import 'dart:async';

abstract interface class Cancelable {
  void cancel();
}

/// Bütün saat okumaları ve zamanlayıcılar bu arayüzden geçer.
abstract interface class Scheduler {
  DateTime now();
  Cancelable after(Duration delay, void Function() callback);
}

class _TimerHandle implements Cancelable {
  final Timer _timer;
  _TimerHandle(this._timer);
  @override
  void cancel() => _timer.cancel();
}

/// Gerçek saat ve `Timer` ile çalışan zamanlayıcı.
class SystemScheduler implements Scheduler {
  const SystemScheduler();

  @override
  DateTime now() => DateTime.now();

  @override
  Cancelable after(Duration delay, void Function() callback) =>
      _TimerHandle(Timer(delay, callback));
}
