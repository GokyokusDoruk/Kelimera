import 'dart:convert';

import 'package:dict_tool/dict_entry.dart';
import 'package:dict_tool/import_alpharing.dart';
import 'package:test/test.dart';

void main() {
  test('TSV gidiş-dönüş, sıralı ve başlıklı', () {
    final entries = [
      const DictEntry(word: 'kalem', pos: 'isim', difficulty: 2, source: 'alpharing'),
      const DictEntry(word: 'ahtapot', pos: 'isim', difficulty: 3, source: 'kelimera'),
    ];
    final tsv = toTsv(entries);
    expect(tsv.split('\n').first, 'kelime\ttür\tzorluk\tkaynak');
    expect(tsv.split('\n')[1].startsWith('ahtapot'), isTrue);
    expect(parseTsv(tsv), [entries[1], entries[0]]);
  });

  test('parseTsv Windows satır sonlarını ve boş satırları kabul eder', () {
    final e = parseTsv('kelime\ttür\tzorluk\tkaynak\r\nkalem\tisim\t2\talpharing\r\n\r\n');
    expect(e.single.word, 'kalem');
  });

  test('AlphaRing içe aktarma', () {
    final json = jsonEncode([
      {'lang': 'tr', 'answer': 'ahtapot', 'pos': 'noun', 'difficulty': 'medium'},
      {'lang': 'tr', 'answer': 'ılık', 'pos': 'adjective', 'difficulty': 'easy'},
      {'lang': 'tr', 'answer': 'koşmak', 'pos': 'verb', 'difficulty': 'hard'},
      {'lang': 'tr', 'answer': 'iç bahçe', 'pos': 'noun', 'difficulty': 'easy'},
      {'lang': 'tr', 'answer': 'ahtapot', 'pos': 'noun', 'difficulty': 'hard'},
    ]);
    final r = importAlpharing(json);
    expect(r.entries, [
      const DictEntry(word: 'ahtapot', pos: 'isim', difficulty: 3, source: 'alpharing'),
      const DictEntry(word: 'ılık', pos: 'sıfat', difficulty: 2, source: 'alpharing'),
      const DictEntry(word: 'koşmak', pos: 'fiil', difficulty: 4, source: 'alpharing'),
    ]);
    expect(r.skipped, ['iç bahçe']);
  });
}
