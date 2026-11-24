import 'dart:math';

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

  test('geri yükleme sırayı kaydırmaz; 5. turda oyunu bitirmez', () {
    final h = Harness();
    h.startWith(3);
    // Kaydı elle düzenle: sıra [p1(hakem), p2, p3], 5. tur, sıra p2'de.
    final snap = h.host.toJson();
    final st = GameState.fromJson(snap['state'] as Map<String, dynamic>);
    final ordered = [
      for (final id in ['p1', 'p2', 'p3']) st.players.firstWhere((p) => p.id == id),
    ];
    snap['state'] = st.copyWith(players: ordered, round: 5, turnIndex: 1).toJson();

    final h2 = Harness();
    final restored = GameHost.restore(
      snapshot: snap,
      transport: h2.hub,
      engine: h2.engine,
      scheduler: h2.sched,
      random: Random(3),
    );
    final s = restored.state!;
    expect(s.finished, isFalse);
    expect(s.round, 5);
    expect(s.current.id, 'p2');
    expect(s.players[1].status, PlayerStatus.disconnected);
    // p2 dönmezse sırası yalnızca süre dolunca geçer; kopuk p3 atlanır ve 5. tur biter.
    h2.sched.advance(const Duration(milliseconds: 45499));
    expect(restored.state!.finished, isFalse);
    h2.sched.advance(const Duration(milliseconds: 1));
    expect(restored.state!.finished, isTrue);
  });

  test('bir bağlantı başka oyuncu olarak tanıtılırsa eski oyuncunun durumunu almaz', () {
    final h = Harness();
    final cs = h.startWith(3);
    final p3 = byId(cs, 'p3');
    p3.send(const Hello(PlayerInfo(id: 'p2', name: 'p2', avatar: 0)));
    final before = p3.all<StateMsg>().length;
    h.sched.advance(const Duration(milliseconds: 45500)); // sıra değişir → tek yayın
    expect(p3.all<StateMsg>().length, before + 1);
    expect(p3.last<StateMsg>().view.myHand, h.player('p2').hand);
  });

  test('oyun kopukken biterse geri dönen oyuncu son durumu alır', () {
    final h = Harness();
    final cs = h.startWith(3);
    final p2 = byId(cs, 'p2');
    h.hub.drop(p2.link);
    while (!h.state.finished) {
      h.current(cs).send(const SwapAllMsg()); // 2 dk dolmadan oyunu bitir
    }
    expect(h.player('p2').status, PlayerStatus.disconnected);
    h.hub.reconnect(p2.link);
    p2.hello();
    expect(p2.last<StateMsg>().view.finished, isTrue);
    expect(p2.last<StateMsg>().view.winners, isNotEmpty);
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
