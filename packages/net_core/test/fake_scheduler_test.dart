import 'package:net_core/testing.dart';
import 'package:test/test.dart';

void main() {
  test('advance vadesi gelenleri sırayla çalıştırır', () {
    final s = FakeScheduler();
    final log = <String>[];
    s.after(const Duration(seconds: 2), () => log.add('b'));
    s.after(const Duration(seconds: 1), () {
      log.add('a');
      s.after(const Duration(milliseconds: 500), () => log.add('a2'));
    });
    final c = s.after(const Duration(seconds: 3), () => log.add('iptal'));
    c.cancel();
    s.advance(const Duration(seconds: 2));
    expect(log, ['a', 'a2', 'b']);
    expect(s.pendingCount, 0);
    expect(s.now(), DateTime(2026, 1, 1).add(const Duration(seconds: 2)));
  });

  test('eşit vadede kayıt sırası, pencere dışındaki bekler', () {
    final s = FakeScheduler();
    final log = <int>[];
    s.after(const Duration(seconds: 1), () => log.add(1));
    s.after(const Duration(seconds: 1), () => log.add(2));
    s.after(const Duration(seconds: 5), () => log.add(3));
    s.advance(const Duration(seconds: 1));
    expect(log, [1, 2]);
    expect(s.pendingCount, 1);
  });
}
