import 'dart:math';

import 'board.dart';
import 'dictionary.dart';
import 'game_state.dart';
import 'letter_drawer.dart';
import 'letter_table.dart';
import 'letters.dart';
import 'move_evaluation.dart';
import 'scoring.dart';

sealed class MoveOutcome {
  const MoveOutcome();
}

class MoveAccepted extends MoveOutcome {
  final GameState state;
  final MoveScore score;
  const MoveAccepted(this.state, this.score);
}

class MoveRejected extends MoveOutcome {
  final List<RejectReason> reasons;
  const MoveRejected(this.reasons);
}

/// 5-7 harfli, zorluğu 1-3 olan rastgele bir başlangıç kelimesi.
String pickStartWord(Dictionary d, Random r) {
  final candidates = [
    for (final w in d.words)
      if (w.length >= 5 && w.length <= 7 && d.difficultyOf(w) <= 3) w,
  ]..sort();
  if (candidates.isEmpty) throw StateError('Başlangıç kelimesi için uygun kelime yok');
  return candidates[r.nextInt(candidates.length)];
}

/// Kazananlar: ayrılmamış oyuncular arasında en yüksek puan,
/// eşitlikte en yüksek tek hamle; o da eşitse hepsi.
List<String> winnerIds(GameState s) {
  final candidates = s.players.where((p) => p.status != PlayerStatus.left).toList();
  if (candidates.isEmpty) return const [];
  final top = candidates.map((p) => p.score).reduce(max);
  final byScore = candidates.where((p) => p.score == top).toList();
  final best = byScore.map((p) => p.bestMove).reduce(max);
  return [for (final p in byScore) if (p.bestMove == best) p.id];
}

/// Saf oyun durum makinesi. Saat tutmaz; süre dolunca [timeout] çağrılır.
class GameEngine {
  final Dictionary dictionary;
  final LetterTable letters;
  final Random random;
  final LetterDrawer _drawer;

  GameEngine({
    required this.dictionary,
    required this.letters,
    required this.random,
    double jokerChance = 0.02,
  }) : _drawer = LetterDrawer(letters, random, jokerChance: jokerChance);

  GameState start(List<PlayerInfo> players) {
    if (players.length < 2 || players.length > 4) {
      throw ArgumentError.value(players.length, 'players', '2-4 oyuncu gerekir');
    }
    final order = List<PlayerInfo>.of(players)..shuffle(random);
    final word = pickStartWord(dictionary, random);
    return GameState(
      board: Board.empty().placeStartWord(word),
      players: [
        for (final info in order)
          PlayerState(
            info: info,
            score: 0,
            hand: _drawer.newHand(),
            status: PlayerStatus.connected,
            bestMove: 0,
          ),
      ],
      round: 1,
      turnIndex: 0,
      usedWords: {word},
      startWord: word,
      finished: false,
    );
  }

  MoveOutcome submitMove(GameState s, String playerId, Map<Pos, Tile> placements) {
    if (s.finished) return const MoveRejected([GameFinished()]);
    if (s.current.id != playerId) return const MoveRejected([NotYourTurn()]);
    if (placements.values.any((t) => !isAlphabetLetter(t.letter))) {
      return const MoveRejected([InvalidLetter()]);
    }
    final remaining = _consume(s.current.hand, placements.values);
    if (remaining == null) return const MoveRejected([NotInHand()]);

    final eval = evaluateMove(
      board: s.board,
      placements: placements,
      dictionary: dictionary,
      letters: letters,
      usedWords: s.usedWords,
    );
    switch (eval) {
      case MoveInvalid(:final reasons):
        return MoveRejected(reasons);
      case MoveValid(:final words, :final score):
        final main = words.firstWhere((w) => w.isMain);
        final me = s.current;
        final updated = me.copyWith(
          hand: _drawer.refill(remaining),
          score: me.score + score.total,
          bestMove: max(me.bestMove, score.total),
        );
        final next = s.copyWith(
          board: s.board.withTiles(placements),
          players: _replace(s.players, s.turnIndex, updated),
          usedWords: {...s.usedWords, main.text},
        );
        return MoveAccepted(_advance(next), score);
    }
  }

  GameState swapAll(GameState s, String playerId) {
    if (s.finished || s.current.id != playerId) return s;
    final updated = s.current.copyWith(hand: _drawer.newHand());
    return _advance(s.copyWith(players: _replace(s.players, s.turnIndex, updated)));
  }

  GameState timeout(GameState s) => s.finished ? s : _advance(s);

  GameState setStatus(GameState s, String playerId, PlayerStatus status) {
    final i = s.players.indexWhere((p) => p.id == playerId);
    if (i < 0) throw ArgumentError.value(playerId, 'playerId', 'Oyuncu yok');
    // Bitmiş oyunda sonuç sabit kalır; ayrılan oyuncu geri dönemez (spec §5.10).
    if (s.finished || s.players[i].status == PlayerStatus.left) return s;
    final next = s.copyWith(players: _replace(s.players, i, s.players[i].copyWith(status: status)));
    if (_activeCount(next) < 2) return next.copyWith(finished: true);
    final currentAway = next.current.status != PlayerStatus.connected;
    if (currentAway && (i == s.turnIndex || status == PlayerStatus.connected)) {
      return _advance(next);
    }
    return next;
  }

  /// Sırayı ilerletir; bağlı olmayan oyuncuları atlar; 5. tur bitince oyunu bitirir.
  /// Bağlı hiç oyuncu yoksa durum değişmez: oyun geri dönen birini bekler.
  GameState _advance(GameState s) {
    if (_activeCount(s) < 2) return s.copyWith(finished: true);
    if (s.players.every((p) => p.status != PlayerStatus.connected)) return s;
    var round = s.round;
    var idx = s.turnIndex;
    while (true) {
      idx++;
      if (idx >= s.players.length) {
        idx = 0;
        round++;
      }
      if (round > totalRounds) return s.copyWith(finished: true);
      if (s.players[idx].status == PlayerStatus.connected) {
        return s.copyWith(round: round, turnIndex: idx);
      }
    }
  }

  static int _activeCount(GameState s) =>
      s.players.where((p) => p.status != PlayerStatus.left).length;

  static List<PlayerState> _replace(List<PlayerState> list, int i, PlayerState p) =>
      [for (var k = 0; k < list.length; k++) k == i ? p : list[k]];

  /// Taşları elden düşer; karşılanamazsa null.
  static List<String>? _consume(List<String> hand, Iterable<Tile> tiles) {
    final rest = List<String>.of(hand);
    for (final t in tiles) {
      if (!rest.remove(t.isJoker ? jokerSymbol : t.letter)) return null;
    }
    return rest;
  }
}
