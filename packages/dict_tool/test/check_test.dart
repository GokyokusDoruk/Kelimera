import 'package:dict_tool/check.dart';
import 'package:dict_tool/dict_entry.dart';
import 'package:test/test.dart';

DictEntry e(String w, {String pos = 'isim', int d = 2, String src = 'kelimera'}) =>
    DictEntry(word: w, pos: pos, difficulty: d, source: src);

void main() {
  test('hatalar', () {
    final r = checkEntries([
      e('kalem'),
      e('kalem'),
      e('x'),
      e('kalem1'),
      e('defter', d: 6),
      e('koş', pos: 'fiil'),
      e('masa', pos: 'nesne'),
      e('silgi', src: 'tdk'),
    ]);
    expect(r.ok, isFalse);
    for (final w in ['kalem', 'x', 'kalem1', 'defter', 'koş', 'masa', 'silgi']) {
      expect(r.errors.where((m) => m.contains(w)), isNotEmpty, reason: w);
    }
    expect(r.errors.length, 7);
  });

  test('çekim eki şüphesi uyarıdır, fiil muaf', () {
    final r = checkEntries([e('kalemler'), e('koşmak', pos: 'fiil'), e('kâğıt')]);
    expect(r.ok, isTrue);
    expect(r.warnings.length, 1);
    expect(r.warnings.single, contains('kalemler'));
  });

  test('temiz liste mesaj üretmez', () {
    final r = checkEntries([e('kalem'), e('koşmak', pos: 'fiil')]);
    expect(r.errors, isEmpty);
    expect(r.warnings, isEmpty);
  });
}
