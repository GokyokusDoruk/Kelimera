import 'dart:math';

import 'package:game_core/game_core.dart';
import 'package:test/test.dart';

LetterTable consonantHeavy() => LetterTable(
      points: LetterTable.initial().points,
      weights: {for (final l in trAlphabet) l: isVowel(l) ? 1 : 1000},
    );

void main() {
  test('yeni el 8 harf, ≥2 sesli, ≥3 sessiz', () {
    final d = LetterDrawer(consonantHeavy(), Random(1), jokerChance: 0);
    for (var i = 0; i < 500; i++) {
      final h = d.newHand();
      expect(h.length, 8);
      expect(h.where(isVowel).length, greaterThanOrEqualTo(2));
      expect(h.where((l) => !isVowel(l)).length, greaterThanOrEqualTo(3));
    }
  });

  test('sesli ağırlıklı tabloda da en az 3 sessiz', () {
    final vowelHeavy = LetterTable(
      points: LetterTable.initial().points,
      weights: {for (final l in trAlphabet) l: isVowel(l) ? 1000 : 1},
    );
    final d = LetterDrawer(vowelHeavy, Random(5), jokerChance: 0);
    for (var i = 0; i < 500; i++) {
      expect(d.newHand().where((l) => !isVowel(l)).length, greaterThanOrEqualTo(3));
    }
  });

  test('7 sessizli eli tamamlarken tek çekiliş sesli olur', () {
    final d = LetterDrawer(consonantHeavy(), Random(2), jokerChance: 0);
    final h = d.refill(['B', 'C', 'D', 'F', 'G', 'H', 'K']);
    expect(h.length, 8);
    expect(h.take(7), ['B', 'C', 'D', 'F', 'G', 'H', 'K']);
    expect(isVowel(h.last), isTrue);
  });

  test('joker şansı 0 ise joker çıkmaz, 1 ise el tümüyle joker', () {
    expect(
        LetterDrawer(LetterTable.initial(), Random(3), jokerChance: 0).newHand().contains('*'),
        isFalse);
    expect(LetterDrawer(LetterTable.initial(), Random(3), jokerChance: 1).newHand(),
        List.filled(8, '*'));
  });

  test('dolu el değişmez', () {
    final d = LetterDrawer(LetterTable.initial(), Random(4));
    final h = ['A', 'E', 'K', 'L', 'M', 'N', 'R', 'T'];
    expect(d.refill(h), h);
  });

  test('joker 0 puan', () {
    expect(LetterTable.initial().pointsOf(const Tile('J', isJoker: true)), 0);
    expect(LetterTable.initial().pointsOf(const Tile('J')), 10);
  });

  test('fromJson', () {
    final t = LetterTable.fromJson({
      'points': {'A': 1, 'B': 3},
      'weights': {'A': 10, 'B': 2},
    });
    expect(t.pointsOf(const Tile('B')), 3);
    expect(t.weights['A'], 10);
  });
}
