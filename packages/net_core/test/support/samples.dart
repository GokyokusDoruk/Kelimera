import 'package:game_core/game_core.dart';
import 'package:net_core/net_core.dart';

GameState sampleState() => GameState(
      board: Board.empty()
          .placeStartWord('KALEM')
          .withTiles({const Pos(6, 4): const Tile('T', isJoker: true)}),
      players: const [
        PlayerState(
          info: PlayerInfo(id: 'p1', name: 'Ayşe', avatar: 3),
          score: 12,
          hand: ['A', '*', 'K', 'L', 'M', 'N', 'R', 'İ'],
          status: PlayerStatus.connected,
          bestMove: 12,
        ),
        PlayerState(
          info: PlayerInfo(id: 'p2', name: 'Can', avatar: 7),
          score: 0,
          hand: ['B', 'C', 'Ç', 'D', 'E', 'F', 'G', 'Ğ'],
          status: PlayerStatus.disconnected,
          bestMove: 0,
        ),
      ],
      round: 3,
      turnIndex: 0,
      usedWords: const {'KALEM', 'AT'},
      startWord: 'KALEM',
      finished: false,
    );

PlayerView sampleView() => viewFor(sampleState(), 'p1', remainingMs: 30000);
