import 'dart:math';

import 'letter_table.dart';
import 'letters.dart';

const int handSize = 8;
const int _minVowels = 2;
const int _minConsonants = 3;

/// Eli sınırsız, ağırlıklı havuzdan dolduran çekici.
class LetterDrawer {
  final LetterTable table;
  final Random random;
  final double jokerChance;

  late final List<String> _vowelLetters = trAlphabet.where(isVowel).toList();
  late final List<String> _consonantLetters = trAlphabet.where((l) => !isVowel(l)).toList();

  LetterDrawer(this.table, this.random, {this.jokerChance = 0.02});

  List<String> newHand() => refill(const []);

  /// Eli [handSize] harfe tamamlar; mevcut harfler korunur.
  List<String> refill(List<String> hand) {
    final result = List<String>.of(hand);
    while (result.length < handSize) {
      final slots = handSize - result.length;
      final (vNeed, cNeed) = _deficits(result);
      if (jokerChance > 0 && random.nextDouble() < jokerChance) {
        result.add(jokerSymbol);
        continue;
      }
      final List<String> pool;
      if (vNeed + cNeed >= slots && (vNeed > 0 || cNeed > 0)) {
        pool = vNeed >= cNeed ? _vowelLetters : _consonantLetters;
      } else {
        pool = trAlphabet;
      }
      result.add(_weightedPick(pool));
    }
    return result;
  }

  /// Sesli ve sessiz açıkları; jokerler büyük açıktan düşülür (eşitlikte sesli).
  (int, int) _deficits(List<String> hand) {
    var vowels = 0, consonants = 0, jokers = 0;
    for (final l in hand) {
      if (l == jokerSymbol) {
        jokers++;
      } else if (isVowel(l)) {
        vowels++;
      } else {
        consonants++;
      }
    }
    var vNeed = max(0, _minVowels - vowels);
    var cNeed = max(0, _minConsonants - consonants);
    for (var i = 0; i < jokers && (vNeed > 0 || cNeed > 0); i++) {
      if (vNeed >= cNeed) {
        vNeed--;
      } else {
        cNeed--;
      }
    }
    return (vNeed, cNeed);
  }

  String _weightedPick(List<String> pool) {
    num total = 0;
    for (final l in pool) {
      total += table.weights[l] ?? 0;
    }
    if (total <= 0) return pool[random.nextInt(pool.length)];
    var x = random.nextDouble() * total;
    for (final l in pool) {
      x -= table.weights[l] ?? 0;
      if (x < 0) return l;
    }
    return pool.last;
  }
}
