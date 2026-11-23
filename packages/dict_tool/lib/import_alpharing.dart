import 'dart:convert';

import 'dict_entry.dart';

const _posMap = {'noun': 'isim', 'verb': 'fiil', 'adjective': 'sıfat', 'adverb': 'zarf'};
const _difficultyMap = {'easy': 2, 'medium': 3, 'hard': 4};
final _wordPattern = RegExp(r'^[abcçdefgğhıijklmnoöprsştuüvyzâîû]+$');

/// AlphaRing `turkishPool.json` dosyasından kayıtları alır.
/// Boşluklu ya da alfabe dışı karakterli cevaplar `skipped` listesine düşer.
({List<DictEntry> entries, List<String> skipped}) importAlpharing(String turkishPoolJson) {
  final items = (jsonDecode(turkishPoolJson) as List).cast<Map<String, dynamic>>();
  final entries = <DictEntry>[];
  final skipped = <String>[];
  final seen = <String>{};
  for (final item in items) {
    final word = (item['answer'] as String).trim();
    if (!_wordPattern.hasMatch(word)) {
      skipped.add(word);
      continue;
    }
    if (!seen.add(word)) continue;
    final pos = _posMap[item['pos']];
    final difficulty = _difficultyMap[item['difficulty']];
    if (pos == null || difficulty == null) {
      skipped.add(word);
      continue;
    }
    entries.add(DictEntry(word: word, pos: pos, difficulty: difficulty, source: 'alpharing'));
  }
  return (entries: entries, skipped: skipped);
}
