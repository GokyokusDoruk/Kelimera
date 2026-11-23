import 'dart:math';

import 'package:game_core/game_core.dart';
import 'package:test/test.dart';

final dict = Dictionary({'KALEM': 2, 'AT': 1, 'KA': 1, 'TA': 1});

GameEngine engine([int seed = 1]) =>
    GameEngine(dictionary: dict, letters: LetterTable.initial(), random: Random(seed));

List<PlayerInfo> infos(int n) =>
    [for (var i = 1; i <= n; i++) PlayerInfo(id: 'p$i', name: 'Oyuncu $i', avatar: i)];

PlayerState ps(String id, List<String> hand,
        {int score = 0, int best = 0, PlayerStatus status = PlayerStatus.connected}) =>
    PlayerState(
        info: PlayerInfo(id: id, name: id, avatar: 0),
        score: score,
        hand: hand,
        status: status,
        bestMove: best);

const hand = ['T', 'A', 'E', 'K', 'L', 'M', 'N', 'R'];

GameState manual(List<PlayerState> players, {int turnIndex = 0, int round = 1}) => GameState(
      board: Board.empty().placeStartWord('KALEM'),
      players: players,
      round: round,
      turnIndex: turnIndex,
      usedWords: {'KALEM'},
      startWord: 'KALEM',
      finished: false,
    );

GameState three() => manual([ps('p1', hand), ps('p2', hand), ps('p3', hand)]);

List<RejectReason> rejected(MoveOutcome o) => (o as MoveRejected).reasons;
GameState accepted(MoveOutcome o) => (o as MoveAccepted).state;

void main() {
  group('start', () {
    test('4 oyuncu', () {
      final s = engine().start(infos(4));
      expect(s.players.map((p) => p.id).toSet(), {'p1', 'p2', 'p3', 'p4'});
      for (final p in s.players) {
        expect(p.hand.length, 8);
        expect(p.score, 0);
        expect(p.status, PlayerStatus.connected);
      }
      expect(s.round, 1);
      expect(s.turnIndex, 0);
      expect(s.startWord, 'KALEM');
      expect(s.board.at(Pos(5, 3))!.letter, 'K');
      expect(s.usedWords, {'KALEM'});
      expect(s.finished, isFalse);
    });

    test('1 ve 5 oyuncu reddedilir', () {
      expect(() => engine().start(infos(1)), throwsArgumentError);
      expect(() => engine().start(infos(5)), throwsArgumentError);
    });

    test('oturma sırası karıştırılır', () {
      final orders = {
        for (var seed = 0; seed < 20; seed++)
          engine(seed).start(infos(4)).players.map((p) => p.id).join(),
      };
      expect(orders.length, greaterThan(1));
    });
  });

  group('pickStartWord', () {
    test('5-7 harf, zorluk 1-3', () {
      final d = Dictionary({'AT': 1, 'KALEM': 2, 'KALEMLİKLER': 1, 'ÇEKMECE': 4});
      expect(pickStartWord(d, Random(1)), 'KALEM');
    });
    test('uygun kelime yoksa StateError', () {
      expect(() => pickStartWord(Dictionary({'AT': 1}), Random(1)), throwsStateError);
    });
  });

  group('submitMove', () {
    test('sırası olmayan oyuncu', () {
      expect(rejected(engine().submitMove(three(), 'p2', {Pos(6, 4): const Tile('T')})),
          [const NotYourTurn()]);
    });

    test('elde olmayan harf', () {
      expect(rejected(engine().submitMove(three(), 'p1', {Pos(6, 4): const Tile('Z')})),
          [const NotInHand()]);
    });

    test('alfabe dışı harf', () {
      expect(rejected(engine().submitMove(three(), 'p1', {Pos(6, 4): const Tile('Q')})),
          [const InvalidLetter()]);
    });

    test('elde joker yokken joker taş', () {
      expect(
          rejected(engine()
              .submitMove(three(), 'p1', {Pos(6, 4): const Tile('T', isJoker: true)})),
          [const NotInHand()]);
    });

    test('jokerle hamle kabul edilir, joker elden düşer', () {
      final s = manual([ps('p1', ['*', 'B', 'C', 'D', 'E', 'F', 'G', 'H']), ps('p2', hand)]);
      final o = engine().submitMove(s, 'p1', {Pos(6, 4): const Tile('T', isJoker: true)});
      final next = accepted(o);
      expect((o as MoveAccepted).score.total, 1);
      expect(next.players[0].hand.take(7), ['B', 'C', 'D', 'E', 'F', 'G', 'H']);
    });

    test('kabul edilen hamle', () {
      final o = engine().submitMove(three(), 'p1', {Pos(6, 4): const Tile('T')});
      final s = accepted(o);
      expect(s.board.at(Pos(6, 4)), const Tile('T'));
      expect(s.players[0].hand.length, 8);
      expect(s.players[0].hand.take(7), ['A', 'E', 'K', 'L', 'M', 'N', 'R']);
      expect(s.players[0].score, 5);
      expect(s.players[0].bestMove, 5);
      expect(s.usedWords, containsAll(['KALEM', 'AT']));
      expect(s.turnIndex, 1);
    });

    test('sözlükte olmayan kelime reddedilir', () {
      expect(rejected(engine().submitMove(three(), 'p1', {Pos(6, 4): const Tile('E')})),
          [const UnknownWords(['AE'])]);
    });

    test('bitmiş oyunda hamle', () {
      final s = three().copyWith(finished: true);
      expect(rejected(engine().submitMove(s, 'p1', {Pos(6, 4): const Tile('T')})),
          [const GameFinished()]);
    });
  });

  group('swapAll', () {
    test('eli yeniler, puan aynı, sıra ilerler', () {
      final s = engine(7).swapAll(three(), 'p1');
      expect(s.players[0].hand, isNot(hand));
      expect(s.players[0].hand.length, 8);
      expect(s.players[0].score, 0);
      expect(s.turnIndex, 1);
    });
    test('sırası olmayan oyuncu için durum değişmez', () {
      final s = three();
      expect(engine().swapAll(s, 'p2'), s);
    });
  });

  group('tur ve bitiş', () {
    test('2 oyuncu: 9 timeout → 5. tur, 10 → bitti', () {
      final e = engine();
      var s = manual([ps('p1', hand), ps('p2', hand)]);
      for (var i = 0; i < 9; i++) {
        s = e.timeout(s);
      }
      expect(s.round, 5);
      expect(s.turnIndex, 1);
      expect(s.finished, isFalse);
      s = e.timeout(s);
      expect(s.finished, isTrue);
    });

    test('timeout eli değiştirmez', () {
      expect(engine().timeout(three()).players[0].hand, hand);
    });

    test('kopan oyuncunun sırası atlanır', () {
      final s = manual([
        ps('p1', hand),
        ps('p2', hand, status: PlayerStatus.disconnected),
        ps('p3', hand),
      ]);
      expect(engine().timeout(s).turnIndex, 2);
    });

    test('sırası gelmişken kopan oyuncu hemen atlanır', () {
      final s = engine().setStatus(three(), 'p1', PlayerStatus.disconnected);
      expect(s.turnIndex, 1);
      expect(s.players[0].status, PlayerStatus.disconnected);
    });

    test('sırası olmayan oyuncunun kopması sırayı değiştirmez', () {
      final s = engine().setStatus(three(), 'p3', PlayerStatus.disconnected);
      expect(s.turnIndex, 0);
    });

    test('herkes koparsa oyun bitmez, bekler; biri dönünce sıra ona geçer', () {
      final e = engine();
      var s = manual([ps('p1', hand), ps('p2', hand)]);
      s = e.setStatus(s, 'p2', PlayerStatus.disconnected);
      s = e.setStatus(s, 'p1', PlayerStatus.disconnected);
      expect(s.finished, isFalse);
      expect(s.round, 1);
      expect(e.timeout(s), s);
      s = e.setStatus(s, 'p2', PlayerStatus.connected);
      expect(s.finished, isFalse);
      expect(s.current.id, 'p2');
      expect(s.round, 1);
    });

    test('bitmiş oyunda durum değişmez, kazanan listesi sabit kalır', () {
      final s = manual([ps('p1', hand, score: 10), ps('p2', hand, score: 5)])
          .copyWith(finished: true);
      final after = engine().setStatus(s, 'p1', PlayerStatus.left);
      expect(after, s);
      expect(winnerIds(after), ['p1']);
    });

    test('ayrılan oyuncu geri bağlanamaz', () {
      final e = engine();
      var s = e.setStatus(three(), 'p3', PlayerStatus.left);
      s = e.setStatus(s, 'p3', PlayerStatus.connected);
      expect(s.players[2].status, PlayerStatus.left);
    });

    test('tek kişi kalırsa oyun biter', () {
      final e = engine();
      var s = e.setStatus(three(), 'p2', PlayerStatus.left);
      expect(s.finished, isFalse);
      s = e.setStatus(s, 'p3', PlayerStatus.left);
      expect(s.finished, isTrue);
    });
  });

  group('winnerIds', () {
    test('en yüksek puan, eşitlikte en iyi hamle', () {
      final s = manual([
        ps('p1', hand, score: 10, best: 6),
        ps('p2', hand, score: 10, best: 4),
        ps('p3', hand, score: 5, best: 5),
      ]);
      expect(winnerIds(s), ['p1']);
    });
    test('tam beraberlik', () {
      final s = manual([
        ps('p1', hand, score: 10, best: 6),
        ps('p2', hand, score: 10, best: 6),
      ]);
      expect(winnerIds(s), ['p1', 'p2']);
    });
    test('ayrılan oyuncu kazanamaz', () {
      final s = manual([
        ps('p1', hand, score: 30, best: 20, status: PlayerStatus.left),
        ps('p2', hand, score: 10, best: 6),
      ]);
      expect(winnerIds(s), ['p2']);
    });
  });
}
