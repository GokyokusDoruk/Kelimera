import 'package:game_core/game_core.dart';
import 'package:net_core/net_core.dart';
import 'package:net_core/testing.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

ClientSession session(Harness h, String id, [MemoryClient? link]) => ClientSession(
      transport: link ?? h.hub.connect(),
      scheduler: h.sched,
      me: PlayerInfo(id: id, name: id, avatar: 1),
    );

ClientSession currentOf(Harness h, List<ClientSession> ss) =>
    ss.firstWhere((s) => s.me.id == h.state.current.id);

void main() {
  test('katılım → lobi, başlangıç → oyun, kalan süre yerel sayılır', () {
    final h = Harness();
    final a = session(h, 'p1');
    expect(a.phase, ClientPhase.lobby);
    expect(a.lobby!.players, hasLength(1));
    final b = session(h, 'p2');
    expect(a.lobby!.players, hasLength(2));
    var changes = 0;
    a.changes.listen((_) => changes++);
    h.host.startGame();
    expect(changes, greaterThan(0));
    for (final s in [a, b]) {
      expect(s.phase, ClientPhase.playing);
      expect(s.view!.myHand, hasLength(8));
    }
    h.sched.advance(const Duration(seconds: 10));
    expect(a.remainingMs, 35000);
  });

  test('hamle sonucu gelir', () {
    final h = Harness();
    final ss = [session(h, 'p1'), session(h, 'p2')];
    h.host.startGame();
    final cur = currentOf(h, ss);
    cur.submitMove({const Pos(6, 4): Tile(cur.view!.myHand.first)});
    expect(cur.lastMoveResult!.accepted, isTrue);
  });

  test('hakem kaybolursa 2 dk bekler, sonra biter', () {
    final h = Harness();
    final link = h.hub.connect();
    final a = session(h, 'p1', link);
    session(h, 'p2');
    h.host.startGame();
    h.hub.drop(link);
    expect(a.phase, ClientPhase.hostLost);
    h.sched.advance(const Duration(minutes: 1, seconds: 59));
    expect(a.phase, ClientPhase.hostLost);
    h.sched.advance(const Duration(seconds: 1));
    expect(a.phase, ClientPhase.ended);
    expect(a.endedByHostLoss, isTrue);
  });

  test('hakem 2 dk içinde dönerse oyun sürer', () {
    final h = Harness();
    final link = h.hub.connect();
    final a = session(h, 'p1', link);
    session(h, 'p2');
    h.host.startGame();
    h.hub.drop(link);
    h.sched.advance(const Duration(minutes: 1));
    h.hub.reconnect(link);
    expect(a.phase, ClientPhase.playing);
    h.sched.advance(const Duration(minutes: 2));
    expect(a.endedByHostLoss, isFalse);
  });

  test('lobide kopma connecting durumuna döner', () {
    final h = Harness();
    final link = h.hub.connect();
    final a = session(h, 'p1', link);
    h.hub.drop(link);
    expect(a.phase, ClientPhase.connecting);
  });

  test('ret: oyun başladıktan sonra katılan', () {
    final h = Harness();
    session(h, 'p1');
    session(h, 'p2');
    h.host.startGame();
    final late = session(h, 'p9');
    expect(late.phase, ClientPhase.rejected);
    expect(late.rejectCode, JoinRejectCode.gameStarted);
  });

  test('oylama: önerende oylama görünmez, diğerleri oy verir, sohbet gelir', () {
    final h = Harness(dictionary: Dictionary({'AT': 1, 'KALEM': 2}));
    final ss = [session(h, 'p1'), session(h, 'p2'), session(h, 'p3')];
    h.host.startGame();
    final cur = currentOf(h, ss);
    final letter = cur.view!.myHand.firstWhere((l) => l != 'T');
    cur.submitMove({const Pos(6, 4): Tile(letter)});
    expect(cur.lastMoveResult!.accepted, isFalse);
    cur.proposeWord('A$letter');
    expect(cur.activeVote, isNull);
    final voters = ss.where((s) => s != cur).toList();
    for (final v in voters) {
      expect(v.activeVote!.word, 'A$letter');
      v.vote(true);
    }
    for (final s in ss) {
      expect(s.activeVote, isNull);
      expect(s.lastVoteResult!.accepted, isTrue);
    }
    voters[0].vote(true); // oylama yokken etkisiz
    cur.sendChat('teşekkürler');
    expect(voters[1].chat.last, ChatMsg(cur.me.id, 'teşekkürler'));
  });

  test('hakem kaybolunca açık oylama kapanır', () {
    final h = Harness(dictionary: Dictionary({'AT': 1, 'KALEM': 2}));
    final links = [h.hub.connect(), h.hub.connect(), h.hub.connect()];
    final ss = [for (var i = 0; i < 3; i++) session(h, 'p${i + 1}', links[i])];
    h.host.startGame();
    final cur = currentOf(h, ss);
    final letter = cur.view!.myHand.firstWhere((l) => l != 'T');
    cur.submitMove({const Pos(6, 4): Tile(letter)});
    cur.proposeWord('A$letter');
    final voter = ss.firstWhere((s) => s != cur);
    expect(voter.activeVote, isNotNull);
    h.hub.drop(links[ss.indexOf(voter)]);
    expect(voter.activeVote, isNull);
  });

  test('oyun bitince ended', () {
    final h = Harness();
    final a = session(h, 'p1');
    session(h, 'p2');
    h.host.startGame();
    for (var i = 0; i < 10; i++) {
      h.sched.advance(const Duration(milliseconds: 45500));
    }
    expect(a.phase, ClientPhase.ended);
    expect(a.endedByHostLoss, isFalse);
    expect(a.view!.winners, isNotEmpty);
  });
}
