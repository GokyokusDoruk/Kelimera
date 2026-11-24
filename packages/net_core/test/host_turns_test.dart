import 'package:game_core/game_core.dart';
import 'package:net_core/net_core.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

const turn = Duration(seconds: 45);
const grace = Duration(milliseconds: 500);

/// Sıradaki oyuncunun elindeki ilk harfi KALEM'deki A'nın altına (6,4) koyan hamle.
MoveMsg validMove(TestClient c) =>
    MoveMsg({const Pos(6, 4): Tile(c.last<StateMsg>().view.myHand.first)});

void main() {
  test('başlangıçta kalan süre 45 sn', () {
    final h = Harness();
    final cs = h.startWith(2);
    expect(cs[0].last<StateMsg>().view.remainingMs, 45000);
  });

  test('kabul edilen hamle: sonuç, yeni durum, sıra değişir', () {
    final h = Harness();
    final cs = h.startWith(2);
    final cur = h.current(cs);
    cur.send(validMove(cur));
    final r = cur.last<MoveResultMsg>();
    expect(r.accepted, isTrue);
    expect(r.points, greaterThan(0));
    for (final c in cs) {
      expect(c.last<StateMsg>().view.currentPlayerId, isNot(cur.id));
      expect(c.last<StateMsg>().view.board.at(const Pos(6, 4)), isNotNull);
    }
    expect(h.persistCount, 2);
  });

  test('sırası olmayan oyuncu reddedilir', () {
    final h = Harness();
    final cs = h.startWith(2);
    final other = cs.firstWhere((c) => c.id != h.state.current.id);
    other.send(validMove(other));
    expect(other.last<MoveResultMsg>(), const MoveResultMsg(false, 0, [NotYourTurn()]));
  });

  test('süre: 45 sn + 500 ms payından sonra sıra geçer', () {
    final h = Harness();
    final cs = h.startWith(2);
    final first = h.state.current.id;
    h.sched.advance(turn);
    expect(h.state.current.id, first);
    h.sched.advance(grace);
    expect(h.state.current.id, isNot(first));
    expect(cs[0].last<StateMsg>().view.remainingMs, 45000);
  });

  test('pay içinde gelen hamle kabul, paydan sonra gelen reddedilir', () {
    final h = Harness();
    final cs = h.startWith(2);
    h.sched.advance(turn + const Duration(milliseconds: 499));
    final cur = h.current(cs);
    expect(cur.last<StateMsg>().view.myHand, isNotEmpty);
    cur.send(validMove(cur));
    expect(cur.last<MoveResultMsg>().accepted, isTrue);

    final h2 = Harness();
    final cs2 = h2.startWith(2);
    final late = h2.current(cs2);
    h2.sched.advance(turn + grace);
    late.send(validMove(late));
    expect(late.last<MoveResultMsg>(), const MoveResultMsg(false, 0, [NotYourTurn()]));
  });

  test('reddedilen hamle süreyi sıfırlamaz', () {
    final h = Harness();
    final cs = h.startWith(2);
    final first = h.state.current.id;
    h.sched.advance(const Duration(seconds: 30));
    h.current(cs).send(const MoveMsg({}));
    expect(h.current(cs).last<MoveResultMsg>().accepted, isFalse);
    h.sched.advance(const Duration(seconds: 15, milliseconds: 499));
    expect(h.state.current.id, first);
    h.sched.advance(const Duration(milliseconds: 1));
    expect(h.state.current.id, isNot(first));
  });

  test('hepsini yenile: sıra geçer, puan değişmez', () {
    final h = Harness();
    final cs = h.startWith(2);
    final cur = h.current(cs);
    final before = cur.last<StateMsg>().view.myHand;
    cur.send(const SwapAllMsg());
    expect(h.state.current.id, isNot(cur.id));
    expect(h.player(cur.id).score, 0);
    expect(cur.last<StateMsg>().view.myHand, isNot(before));
  });

  test('sırası olmayan hepsini yenile: NotYourTurn', () {
    final h = Harness();
    final cs = h.startWith(2);
    final other = cs.firstWhere((c) => c.id != h.state.current.id);
    other.send(const SwapAllMsg());
    expect(other.last<MoveResultMsg>(), const MoveResultMsg(false, 0, [NotYourTurn()]));
  });

  test('10 süre dolması oyunu bitirir, sonra mesaj gelmez', () {
    final h = Harness();
    final cs = h.startWith(2);
    for (var i = 0; i < 10; i++) {
      h.sched.advance(turn + grace);
    }
    expect(cs[0].last<StateMsg>().view.finished, isTrue);
    expect(cs[0].last<StateMsg>().view.winners, isNotEmpty);
    final count = cs[0].inbox.length;
    h.sched.advance(const Duration(minutes: 1));
    expect(cs[0].inbox.length, count);
  });
}
