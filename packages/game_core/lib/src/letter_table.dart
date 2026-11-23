import 'board.dart';
import 'letters.dart';

/// Harf puanları ve çekiliş ağırlıkları.
class LetterTable {
  final Map<String, int> points;
  final Map<String, num> weights;

  const LetterTable({required this.points, required this.weights});

  /// Spesifikasyon §5.3'teki başlangıç puanları; bütün ağırlıklar 1.
  factory LetterTable.initial() {
    const groups = {
      1: 'A E İ N R L K',
      2: 'I D M T S Y U',
      3: 'B O Ü Ş Z',
      4: 'G Ç H',
      5: 'C Ğ V P',
      7: 'Ö F',
      10: 'J',
    };
    return LetterTable(
      points: {
        for (final e in groups.entries)
          for (final l in e.value.split(' ')) l: e.key,
      },
      weights: {for (final l in trAlphabet) l: 1},
    );
  }

  factory LetterTable.fromJson(Map<String, dynamic> json) => LetterTable(
        points: (json['points'] as Map).map((k, v) => MapEntry(k as String, (v as num).toInt())),
        weights: (json['weights'] as Map).map((k, v) => MapEntry(k as String, v as num)),
      );

  int pointsOf(Tile t) => t.isJoker ? 0 : (points[t.letter] ?? 0);
}
