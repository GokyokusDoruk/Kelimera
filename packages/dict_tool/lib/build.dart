import 'dart:convert';
import 'dart:math';

import 'package:game_core/game_core.dart';

import 'dict_entry.dart';

/// Harfler sıklığa göre çoktan aza dizilip bu gruplara bölünür (spec §5.3 biçimi).
const List<(int size, int points)> pointBuckets = [
  (7, 1), (7, 2), (5, 3), (3, 4), (4, 5), (2, 7), (1, 10), //
];

class CompiledDictionary {
  final Map<String, int> words;
  final Map<String, int> letterCounts;
  final Map<String, int> points;
  const CompiledDictionary(this.words, this.letterCounts, this.points);

  /// `KELİME<TAB>zorluk` satırları, sıralı.
  String toText() {
    final keys = words.keys.toList()..sort();
    return '${keys.map((k) => '$k\t${words[k]}').join('\n')}\n';
  }

  String letterTableJson() => const JsonEncoder.withIndent('  ').convert({
        'points': {for (final l in trAlphabet) l: points[l]},
        'weights': {for (final l in trAlphabet) l: max(1, letterCounts[l] ?? 0)},
      });
}

CompiledDictionary buildDictionary(List<DictEntry> entries) {
  final words = <String, int>{};
  void put(String w, int d) => words[w] = min(words[w] ?? d, d);

  for (final e in entries) {
    final upper = trUpper(e.word);
    put(upper, e.difficulty);
    if (e.pos == 'fiil' && (upper.endsWith('MAK') || upper.endsWith('MEK'))) {
      final root = upper.substring(0, upper.length - 3);
      if (root.length >= 2) put(root, e.difficulty);
    }
  }

  final counts = {for (final l in trAlphabet) l: 0};
  for (final w in words.keys) {
    for (final ch in w.split('')) {
      if (counts.containsKey(ch)) counts[ch] = counts[ch]! + 1;
    }
  }

  final ranked = List<String>.of(trAlphabet)
    ..sort((a, b) {
      final c = counts[b]!.compareTo(counts[a]!);
      return c != 0 ? c : trAlphabet.indexOf(a).compareTo(trAlphabet.indexOf(b));
    });
  final points = <String, int>{};
  var i = 0;
  for (final (size, pts) in pointBuckets) {
    for (var k = 0; k < size; k++) {
      points[ranked[i++]] = pts;
    }
  }
  return CompiledDictionary(words, counts, points);
}
