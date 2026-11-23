import 'board.dart';

const int totalRounds = 5;

enum PlayerStatus { connected, disconnected, left }

bool _listEq<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

class PlayerInfo {
  final String id;
  final String name;
  final int avatar;
  const PlayerInfo({required this.id, required this.name, required this.avatar});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'avatar': avatar};

  factory PlayerInfo.fromJson(Map<String, dynamic> j) =>
      PlayerInfo(id: j['id'] as String, name: j['name'] as String, avatar: j['avatar'] as int);

  @override
  bool operator ==(Object other) =>
      other is PlayerInfo && other.id == id && other.name == name && other.avatar == avatar;

  @override
  int get hashCode => Object.hash(id, name, avatar);
}

class PlayerState {
  final PlayerInfo info;
  final int score;
  final List<String> hand;
  final PlayerStatus status;
  final int bestMove;

  const PlayerState({
    required this.info,
    required this.score,
    required this.hand,
    required this.status,
    required this.bestMove,
  });

  String get id => info.id;

  PlayerState copyWith({int? score, List<String>? hand, PlayerStatus? status, int? bestMove}) =>
      PlayerState(
        info: info,
        score: score ?? this.score,
        hand: hand ?? this.hand,
        status: status ?? this.status,
        bestMove: bestMove ?? this.bestMove,
      );

  Map<String, dynamic> toJson() => {
        'info': info.toJson(),
        'score': score,
        'hand': hand,
        'status': status.name,
        'bestMove': bestMove,
      };

  factory PlayerState.fromJson(Map<String, dynamic> j) => PlayerState(
        info: PlayerInfo.fromJson(j['info'] as Map<String, dynamic>),
        score: j['score'] as int,
        hand: List<String>.from(j['hand'] as List),
        status: PlayerStatus.values.byName(j['status'] as String),
        bestMove: j['bestMove'] as int,
      );

  @override
  bool operator ==(Object other) =>
      other is PlayerState &&
      other.info == info &&
      other.score == score &&
      _listEq(other.hand, hand) &&
      other.status == status &&
      other.bestMove == bestMove;

  @override
  int get hashCode => Object.hash(info, score, Object.hashAll(hand), status, bestMove);
}

class GameState {
  final Board board;

  /// Oturma sırasıyla.
  final List<PlayerState> players;

  /// 1..[totalRounds].
  final int round;
  final int turnIndex;
  final Set<String> usedWords;
  final String startWord;
  final bool finished;

  const GameState({
    required this.board,
    required this.players,
    required this.round,
    required this.turnIndex,
    required this.usedWords,
    required this.startWord,
    required this.finished,
  });

  PlayerState get current => players[turnIndex];

  GameState copyWith({
    Board? board,
    List<PlayerState>? players,
    int? round,
    int? turnIndex,
    Set<String>? usedWords,
    bool? finished,
  }) =>
      GameState(
        board: board ?? this.board,
        players: players ?? this.players,
        round: round ?? this.round,
        turnIndex: turnIndex ?? this.turnIndex,
        usedWords: usedWords ?? this.usedWords,
        startWord: startWord,
        finished: finished ?? this.finished,
      );

  Map<String, dynamic> toJson() => {
        'board': [
          for (final e in board.tiles.entries)
            {'r': e.key.row, 'c': e.key.col, 'l': e.value.letter, 'j': e.value.isJoker},
        ],
        'players': [for (final p in players) p.toJson()],
        'round': round,
        'turnIndex': turnIndex,
        'usedWords': usedWords.toList()..sort(),
        'startWord': startWord,
        'finished': finished,
      };

  factory GameState.fromJson(Map<String, dynamic> j) => GameState(
        board: Board.empty().withTiles({
          for (final t in (j['board'] as List).cast<Map<String, dynamic>>())
            Pos(t['r'] as int, t['c'] as int): Tile(t['l'] as String, isJoker: t['j'] as bool),
        }),
        players: [
          for (final p in (j['players'] as List).cast<Map<String, dynamic>>())
            PlayerState.fromJson(p),
        ],
        round: j['round'] as int,
        turnIndex: j['turnIndex'] as int,
        usedWords: Set<String>.from(j['usedWords'] as List),
        startWord: j['startWord'] as String,
        finished: j['finished'] as bool,
      );

  @override
  bool operator ==(Object other) =>
      other is GameState &&
      other.board == board &&
      _listEq(other.players, players) &&
      other.round == round &&
      other.turnIndex == turnIndex &&
      other.usedWords.length == usedWords.length &&
      other.usedWords.containsAll(usedWords) &&
      other.startWord == startWord &&
      other.finished == finished;

  @override
  int get hashCode => Object.hash(board, Object.hashAll(players), round, turnIndex,
      Object.hashAllUnordered(usedWords), startWord, finished);
}
