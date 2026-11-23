import 'dart:convert';
import 'dart:math';

import 'package:game_core/game_core.dart';
import 'package:test/test.dart';

final dict = Dictionary({
  for (final a in trAlphabet)
    for (final b in trAlphabet) '$a$b': 1,
  'KALEM': 2,
});

const _dirs = [Pos(0, 1), Pos(0, -1), Pos(1, 0), Pos(-1, 0)];

void main() {
  test('2.000 bot oyunu kuralları bozmaz', () {
    var acceptedMoves = 0;
    for (var seed = 0; seed < 2000; seed++) {
      final r = Random(seed);
      final e = GameEngine(dictionary: dict, letters: LetterTable.initial(), random: r);
      final n = 2 + seed % 3;
      var s = e.start([for (var i = 0; i < n; i++) PlayerInfo(id: 'p$i', name: 'p$i', avatar: i)]);
      var steps = 0;

      while (!s.finished) {
        final before = s;
        final roll = r.nextInt(100);
        if (roll < 60) {
          final tiles = s.board.tiles.keys.toList();
          final anchor = tiles[r.nextInt(tiles.length)];
          final target = anchor + _dirs[r.nextInt(4)];
          final hand = s.current.hand;
          final pick = hand[r.nextInt(hand.length)];
          final tile = pick == jokerSymbol
              ? Tile(trAlphabet[r.nextInt(trAlphabet.length)], isJoker: true)
              : Tile(pick);
          final o = e.submitMove(s, s.current.id, {target: tile});
          if (o is MoveAccepted) {
            acceptedMoves++;
            expect(o.score.total, greaterThanOrEqualTo(0));
            s = o.state;
          } else {
            s = e.timeout(s);
          }
        } else if (roll < 80) {
          s = e.swapAll(s, s.current.id);
        } else if (roll < 90) {
          s = e.timeout(s);
        } else {
          final p = s.players[r.nextInt(n)];
          final status = PlayerStatus.values[r.nextInt(3)];
          if (p.status != PlayerStatus.left) s = e.setStatus(s, p.id, status);
        }
        steps++;

        for (final p in s.players) {
          expect(p.hand.length, 8, reason: 'seed $seed');
        }
        for (var i = 0; i < n; i++) {
          expect(s.players[i].score, greaterThanOrEqualTo(before.players[i].score));
        }
        expect(s.board.tiles.length, greaterThanOrEqualTo(before.board.tiles.length));
        expect(GameState.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>), s);
        expect(steps, lessThanOrEqualTo(n * totalRounds * 3), reason: 'seed $seed sonlanmadı');
      }
    }
    expect(acceptedMoves, greaterThan(1000));
  });
}
