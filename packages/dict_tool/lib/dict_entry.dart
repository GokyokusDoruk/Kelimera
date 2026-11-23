/// Kaynak sözlükteki (`dictionary/kelimeler.tsv`) bir kayıt.
class DictEntry {
  /// Türkçe küçük harflerle, yazıldığı gibi.
  final String word;

  /// isim, fiil, sıfat, zarf, zamir, ünlem, bağlaç, edat
  final String pos;

  /// 1 (en yaygın) - 5 (en nadir)
  final int difficulty;

  /// alpharing | kelimera
  final String source;

  const DictEntry({
    required this.word,
    required this.pos,
    required this.difficulty,
    required this.source,
  });

  @override
  bool operator ==(Object other) =>
      other is DictEntry &&
      other.word == word &&
      other.pos == pos &&
      other.difficulty == difficulty &&
      other.source == source;

  @override
  int get hashCode => Object.hash(word, pos, difficulty, source);

  @override
  String toString() => '$word/$pos/$difficulty/$source';
}

const String tsvHeader = 'kelime\ttür\tzorluk\tkaynak';

/// İlk satır başlıktır ve atlanır.
List<DictEntry> parseTsv(String text) {
  final out = <DictEntry>[];
  final lines = text.split('\n');
  for (var i = 1; i < lines.length; i++) {
    final line = lines[i].trimRight();
    if (line.isEmpty) continue;
    final f = line.split('\t');
    if (f.length != 4) throw FormatException('Satır ${i + 1}: 4 alan beklenirdi', line);
    out.add(DictEntry(word: f[0], pos: f[1], difficulty: int.parse(f[2]), source: f[3]));
  }
  return out;
}

/// Kelimeye göre sıralı TSV, sonunda yeni satır.
String toTsv(List<DictEntry> entries) {
  final sorted = List<DictEntry>.of(entries)..sort((a, b) => a.word.compareTo(b.word));
  final b = StringBuffer('$tsvHeader\n');
  for (final e in sorted) {
    b.write('${e.word}\t${e.pos}\t${e.difficulty}\t${e.source}\n');
  }
  return b.toString();
}
