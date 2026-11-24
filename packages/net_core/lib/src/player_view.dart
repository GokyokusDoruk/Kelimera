import 'package:game_core/game_core.dart';

bool _listEq<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

List<Map<String, dynamic>> boardToJson(Board b) => [
      for (final e in b.tiles.entries)
        {'r': e.key.row, 'c': e.key.col, 'l': e.value.letter, 'j': e.value.isJoker},
    ];

Board boardFromJson(List<dynamic> j) => Board.empty().withTiles({
      for (final t in j.cast<Map<String, dynamic>>())
        Pos(t['r'] as int, t['c'] as int): Tile(t['l'] as String, isJoker: t['j'] as bool),
    });

/// Başka bir oyuncunun herkese açık bilgisi (eli yok, yalnız harf sayısı).
class PublicPlayer {
  final PlayerInfo info;
  final int score;
  final PlayerStatus status;
  final int handCount;

  const PublicPlayer({
    required this.info,
    required this.score,
    required this.status,
    required this.handCount,
  });

  String get id => info.id;

  Map<String, dynamic> toJson() =>
      {'info': info.toJson(), 'score': score, 'status': status.name, 'handCount': handCount};

  factory PublicPlayer.fromJson(Map<String, dynamic> j) => PublicPlayer(
        info: PlayerInfo.fromJson(j['info'] as Map<String, dynamic>),
        score: j['score'] as int,
        status: PlayerStatus.values.byName(j['status'] as String),
        handCount: j['handCount'] as int,
      );

  @override
  bool operator ==(Object other) =>
      other is PublicPlayer &&
      other.info == info &&
      other.score == score &&
      other.status == status &&
      other.handCount == handCount;

  @override
  int get hashCode => Object.hash(info, score, status, handCount);
}

/// Hakemin bir oyuncuya gönderdiği durum: yalnız o oyuncunun eli bulunur.
class PlayerView {
  final Board board;
  final List<PublicPlayer> players;
  final String currentPlayerId;
  final int round;
  final List<String> myHand;
  final int remainingMs;
  final Set<String> usedWords;
  final String startWord;
  final bool finished;
  final List<String> winners;

  const PlayerView({
    required this.board,
    required this.players,
    required this.currentPlayerId,
    required this.round,
    required this.myHand,
    required this.remainingMs,
    required this.usedWords,
    required this.startWord,
    required this.finished,
    required this.winners,
  });

  Map<String, dynamic> toJson() => {
        'board': boardToJson(board),
        'players': [for (final p in players) p.toJson()],
        'current': currentPlayerId,
        'round': round,
        'myHand': myHand,
        'remainingMs': remainingMs,
        'usedWords': usedWords.toList()..sort(),
        'startWord': startWord,
        'finished': finished,
        'winners': winners,
      };

  factory PlayerView.fromJson(Map<String, dynamic> j) => PlayerView(
        board: boardFromJson(j['board'] as List),
        players: [
          for (final p in (j['players'] as List).cast<Map<String, dynamic>>())
            PublicPlayer.fromJson(p),
        ],
        currentPlayerId: j['current'] as String,
        round: j['round'] as int,
        myHand: List<String>.from(j['myHand'] as List),
        remainingMs: j['remainingMs'] as int,
        usedWords: Set<String>.from(j['usedWords'] as List),
        startWord: j['startWord'] as String,
        finished: j['finished'] as bool,
        winners: List<String>.from(j['winners'] as List),
      );

  @override
  bool operator ==(Object other) =>
      other is PlayerView &&
      other.board == board &&
      _listEq(other.players, players) &&
      other.currentPlayerId == currentPlayerId &&
      other.round == round &&
      _listEq(other.myHand, myHand) &&
      other.remainingMs == remainingMs &&
      other.usedWords.length == usedWords.length &&
      other.usedWords.containsAll(usedWords) &&
      other.startWord == startWord &&
      other.finished == finished &&
      _listEq(other.winners, winners);

  @override
  int get hashCode => Object.hash(board, Object.hashAll(players), currentPlayerId, round,
      Object.hashAll(myHand), remainingMs, startWord, finished, Object.hashAll(winners));
}

PlayerView viewFor(GameState s, String playerId, {required int remainingMs}) {
  final me = s.players.where((p) => p.id == playerId).firstOrNull;
  return PlayerView(
    board: s.board,
    players: [
      for (final p in s.players)
        PublicPlayer(info: p.info, score: p.score, status: p.status, handCount: p.hand.length),
    ],
    currentPlayerId: s.current.id,
    round: s.round,
    myHand: me == null ? const [] : List.unmodifiable(me.hand),
    remainingMs: remainingMs,
    usedWords: s.usedWords,
    startWord: s.startWord,
    finished: s.finished,
    winners: s.finished ? winnerIds(s) : const [],
  );
}
