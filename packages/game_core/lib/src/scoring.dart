import 'dart:math';

import 'board.dart';
import 'dictionary.dart';
import 'letter_table.dart';
import 'letter_drawer.dart';
import 'placement.dart';

const int bingoBonus = 40;
const List<int> rarityPoints = [0, 2, 4, 7, 10];

int lengthPoints(int len) => max(0, len - 3) * 2;

class WordScore {
  final String word;
  final int points;
  const WordScore(this.word, this.points);

  @override
  bool operator ==(Object other) =>
      other is WordScore && other.word == word && other.points == points;

  @override
  int get hashCode => Object.hash(word, points);
}

class MoveScore {
  final List<WordScore> words;
  final int basePoints;
  final int bingoBonus;
  const MoveScore(this.words, this.basePoints, this.bingoBonus);

  int get total => words.fold(0, (s, w) => s + w.points) + basePoints + bingoBonus;
}

/// Spesifikasyon §5.6. [words] ilk eleman ana kelime olacak şekilde
/// `analyzePlacement` çıktısıdır.
MoveScore scoreMove(Board board, Map<Pos, Tile> placements, List<FormedWord> words,
    Dictionary dict, LetterTable letters) {
  final scores = <WordScore>[];
  for (final w in words) {
    var sum = 0;
    var wordMult = 1;
    for (final p in w.positions) {
      final placed = placements[p];
      final tile = placed ?? board.at(p)!;
      var pts = letters.pointsOf(tile);
      if (placed != null) {
        switch (premiumAt(p)) {
          case Premium.h2:
            pts *= 2;
          case Premium.h3:
            pts *= 3;
          case Premium.k2:
            wordMult *= 2;
          case Premium.k3:
            wordMult *= 3;
          case Premium.k4:
            wordMult *= 4;
          case Premium.none:
            break;
        }
      }
      sum += pts;
    }
    scores.add(WordScore(w.text, sum * wordMult));
  }

  final main = words.firstWhere((w) => w.isMain);
  final base = lengthPoints(main.text.length) + rarityPoints[dict.difficultyOf(main.text) - 1];
  final bonus = placements.length == handSize ? bingoBonus : 0;
  return MoveScore(scores, base, bonus);
}
