import 'package:game_core/game_core.dart';
import 'package:net_core/net_core.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

TestClient byId(List<TestClient> cs, String id) => cs.firstWhere((c) => c.id == id);

void main() {
  test('kopan oyuncu 2 dk içinde aynı eliyle döner', () {
    final h = Harness();
    final cs = h.startWith(3);
    final p2 = byId(cs, 'p2');
    final hand = h.player('p2').hand;
    h.hub.drop(p2.link);
    expect(h.player('p2').status, PlayerStatus.disconnected);

    h.sched.advance(const Duration(minutes: 1));
    final before = p2.all<StateMsg>().length;
    h.hub.reconnect(p2.link);
    p2.hello();
    expect(h.player('p2').status, PlayerStatus.connected);
    expect(h.player('p2').hand, hand);
    expect(p2.all<StateMsg>().length, greaterThan(before));
    expect(p2.last<StateMsg>().view.myHand, hand);
    h.sched.advance(const Duration(minutes: 2));
    expect(h.player('p2').status, PlayerStatus.connected);
  });

  test('2 dk dolunca ayrılır, sonra geri dönemez', () {
    final h = Harness();
    final cs = h.startWith(3);
    final p3 = byId(cs, 'p3');
    h.hub.drop(p3.link);
    h.sched.advance(const Duration(minutes: 2));
    expect(h.player('p3').status, PlayerStatus.left);
    h.hub.reconnect(p3.link);
    p3.hello();
    expect(p3.last<JoinRejected>(), const JoinRejected(JoinRejectCode.playerLeft));
  });

  test('sırası gelmişken kopan oyuncunun sırası hemen geçer', () {
    final h = Harness();
    final cs = h.startWith(3);
    final cur = h.current(cs);
    h.hub.drop(cur.link);
    expect(h.state.current.id, isNot(cur.id));
  });

  test('eski bağlantının kopması oyuncuyu düşürmez, mesajlar yeni bağlantıya gider', () {
    final h = Harness();
    final cs = h.startWith(3);
    final oldP2 = byId(cs, 'p2');
    final newP2 = TestClient('p2', h.hub.connect());
    newP2.hello();
    h.hub.drop(oldP2.link);
    expect(h.player('p2').status, PlayerStatus.connected);

    final oldCount = oldP2.inbox.length;
    final newCount = newP2.inbox.length;
    h.sched.advance(const Duration(seconds: 46)); // sıra değişir → durum yayını
    expect(oldP2.inbox.length, oldCount);
    expect(newP2.inbox.length, greaterThan(newCount));
  });

  test('geri yükleme: uzak oyuncular kopuk sayılır, dönen devam eder, dönmeyen ayrılır', () {
    final h = Harness();
    h.startWith(3);
    final p2Hand = h.player('p2').hand;
    final round = h.state.round;

    final h2 = Harness.restored(h, h.engine);
    final st = h2.host.state!;
    expect(st.players.firstWhere((p) => p.id == 'p1').status, PlayerStatus.connected);
    expect(st.players.firstWhere((p) => p.id == 'p2').status, PlayerStatus.disconnected);
    expect(st.players.firstWhere((p) => p.id == 'p3').status, PlayerStatus.disconnected);
    expect(st.round, round);
    expect(h2.host.roomCode, h.host.roomCode);

    final p2 = h2.join('p2');
    expect(h2.player('p2').status, PlayerStatus.connected);
    expect(p2.last<StateMsg>().view.myHand, p2Hand);
    h2.sched.advance(const Duration(minutes: 2));
    expect(h2.player('p3').status, PlayerStatus.left);
  });
}
