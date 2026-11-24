import 'scheduler.dart';

class _Entry implements Cancelable {
  final DateTime due;
  final int seq;
  final void Function() callback;
  bool cancelled = false;
  _Entry(this.due, this.seq, this.callback);

  @override
  void cancel() => cancelled = true;
}

/// Testler için elle ilerletilen zamanlayıcı.
class FakeScheduler implements Scheduler {
  DateTime _now;
  int _seq = 0;
  final List<_Entry> _entries = [];

  FakeScheduler([DateTime? start]) : _now = start ?? DateTime(2026, 1, 1);

  @override
  DateTime now() => _now;

  @override
  Cancelable after(Duration delay, void Function() callback) {
    final e = _Entry(_now.add(delay), _seq++, callback);
    _entries.add(e);
    return e;
  }

  int get pendingCount => _entries.where((e) => !e.cancelled).length;

  /// Zamanı [d] kadar ilerletir; vadesi gelenleri (vade, sonra kayıt sırasıyla) çalıştırır.
  void advance(Duration d) {
    final target = _now.add(d);
    while (true) {
      _entries.removeWhere((e) => e.cancelled);
      final due = _entries.where((e) => !e.due.isAfter(target)).toList()
        ..sort((a, b) {
          final c = a.due.compareTo(b.due);
          return c != 0 ? c : a.seq.compareTo(b.seq);
        });
      if (due.isEmpty) break;
      final next = due.first;
      _entries.remove(next);
      _now = next.due;
      next.callback();
    }
    _now = target;
  }
}
