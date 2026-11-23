import 'dart:convert';

import 'package:game_core/game_core.dart';
import 'package:test/test.dart';

GameState sample() => GameState(
      board: Board.empty()
          .placeStartWord('KALEM')
          .withTiles({Pos(6, 4): const Tile('T', isJoker: true)}),
      players: [
        PlayerState(
          info: const PlayerInfo(id: 'p1', name: 'Ayşe', avatar: 3),
          score: 12,
          hand: const ['A', '*', 'K', 'L', 'M', 'N', 'R', 'İ'],
          status: PlayerStatus.connected,
          bestMove: 12,
        ),
        PlayerState(
          info: const PlayerInfo(id: 'p2', name: 'Can', avatar: 7),
          score: 0,
          hand: const ['B', 'C', 'Ç', 'D', 'E', 'F', 'G', 'Ğ'],
          status: PlayerStatus.disconnected,
          bestMove: 0,
        ),
      ],
      round: 3,
      turnIndex: 1,
      usedWords: const {'KALEM', 'AT'},
      startWord: 'KALEM',
      finished: false,
    );

void main() {
  test('JSON gidiş-dönüş', () {
    final s = sample();
    expect(GameState.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>), s);
  });

  test('farklı durumlar eşit değil', () {
    expect(sample().copyWith(round: 4) == sample(), isFalse);
    expect(sample().copyWith(round: 3), sample());
  });

  test('current sıradaki oyuncudur', () {
    expect(sample().current.info.id, 'p2');
  });

  test('totalRounds 5', () => expect(totalRounds, 5));
}
