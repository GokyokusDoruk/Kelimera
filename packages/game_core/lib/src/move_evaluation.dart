import 'board.dart';
import 'dictionary.dart';
import 'letter_table.dart';
import 'placement.dart';
import 'scoring.dart';

/// Bir hamlenin reddedilme nedeni.
sealed class RejectReason {
  const RejectReason();
}

class NotYourTurn extends RejectReason {
  const NotYourTurn();
  @override
  bool operator ==(Object other) => other is NotYourTurn;
  @override
  int get hashCode => 1;
}

class GameFinished extends RejectReason {
  const GameFinished();
  @override
  bool operator ==(Object other) => other is GameFinished;
  @override
  int get hashCode => 2;
}

class NotInHand extends RejectReason {
  const NotInHand();
  @override
  bool operator ==(Object other) => other is NotInHand;
  @override
  int get hashCode => 3;
}

class InvalidLetter extends RejectReason {
  const InvalidLetter();
  @override
  bool operator ==(Object other) => other is InvalidLetter;
  @override
  int get hashCode => 4;
}

class PlacementInvalid extends RejectReason {
  final PlacementError error;
  const PlacementInvalid(this.error);
  @override
  bool operator ==(Object other) => other is PlacementInvalid && other.error == error;
  @override
  int get hashCode => Object.hash(5, error);
  @override
  String toString() => 'PlacementInvalid($error)';
}

class UnknownWords extends RejectReason {
  final List<String> words;
  const UnknownWords(this.words);
  @override
  bool operator ==(Object other) {
    if (other is! UnknownWords || other.words.length != words.length) return false;
    for (var i = 0; i < words.length; i++) {
      if (other.words[i] != words[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(words);
  @override
  String toString() => 'UnknownWords($words)';
}

class WordAlreadyUsed extends RejectReason {
  final String word;
  const WordAlreadyUsed(this.word);
  @override
  bool operator ==(Object other) => other is WordAlreadyUsed && other.word == word;
  @override
  int get hashCode => Object.hash(7, word);
  @override
  String toString() => 'WordAlreadyUsed($word)';
}

sealed class MoveEvaluation {
  const MoveEvaluation();
}

class MoveValid extends MoveEvaluation {
  final List<FormedWord> words;
  final MoveScore score;
  const MoveValid(this.words, this.score);
}

class MoveInvalid extends MoveEvaluation {
  final List<RejectReason> reasons;
  const MoveInvalid(this.reasons);
}

/// Yerleştirme, sözlük ve tekrar yasağı kontrolü; geçerliyse puanı hesaplar.
MoveEvaluation evaluateMove({
  required Board board,
  required Map<Pos, Tile> placements,
  required Dictionary dictionary,
  required LetterTable letters,
  required Set<String> usedWords,
}) {
  final placement = analyzePlacement(board, placements);
  final List<FormedWord> words;
  switch (placement) {
    case PlacementFailed(:final error):
      return MoveInvalid([PlacementInvalid(error)]);
    case PlacementOk(words: final w):
      words = w;
  }

  final reasons = <RejectReason>[];
  final unknown = [
    for (final w in words)
      if (!dictionary.contains(w.text)) w.text,
  ];
  if (unknown.isNotEmpty) reasons.add(UnknownWords(unknown));
  final main = words.firstWhere((w) => w.isMain);
  if (usedWords.contains(main.text)) reasons.add(WordAlreadyUsed(main.text));
  if (reasons.isNotEmpty) return MoveInvalid(reasons);

  return MoveValid(words, scoreMove(board, placements, words, dictionary, letters));
}
