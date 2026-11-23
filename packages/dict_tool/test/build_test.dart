import 'dart:convert';

import 'package:dict_tool/build.dart';
import 'package:dict_tool/dict_entry.dart';
import 'package:game_core/game_core.dart';
import 'package:test/test.dart';

DictEntry e(String w, String pos, int d) =>
    DictEntry(word: w, pos: pos, difficulty: d, source: 'kelimera');

void main() {
  final c = buildDictionary([
    e('koşmak', 'fiil', 3),
    e('koş', 'isim', 2),
    e('gelmek', 'fiil', 1),
    e('kalem', 'isim', 2),
    e('kâğıt', 'isim', 2),
    e('demek', 'fiil', 1),
  ]);

  test('kelimeler büyük harf, fiil kökleri eklenir, çakışmada küçük zorluk', () {
    expect(c.words, {
      'KOŞMAK': 3,
      'KOŞ': 2,
      'GELMEK': 1,
      'GEL': 1,
      'KALEM': 2,
      'KAĞIT': 2,
      'DEMEK': 1,
      'DE': 1,
    });
  });

  test('derlenmiş metin Dictionary.parse ile okunur', () {
    final d = Dictionary.parse(c.toText());
    expect(d.contains('GEL'), isTrue);
    expect(d.difficultyOf('KOŞMAK'), 3);
    expect(c.toText().split('\n').first, 'DE\t1');
  });

  test('harf puanları 29 harf, en sık harf 1 puan, grup boyutları', () {
    expect(c.points.keys.toSet(), trAlphabet.toSet());
    final most = c.letterCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    expect(c.points[most], 1);
    final sizes = <int, int>{};
    for (final p in c.points.values) {
      sizes[p] = (sizes[p] ?? 0) + 1;
    }
    expect(sizes, {1: 7, 2: 7, 3: 5, 4: 3, 5: 4, 7: 2, 10: 1});
  });

  test('harf tablosu JSON LetterTable ile okunur, hiç geçmeyen harfin ağırlığı 1', () {
    final t = LetterTable.fromJson(jsonDecode(c.letterTableJson()) as Map<String, dynamic>);
    expect(t.weights['J'], 1);
    expect(t.weights['K'], c.letterCounts['K']);
  });
}
