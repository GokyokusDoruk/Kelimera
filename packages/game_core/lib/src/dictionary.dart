/// Büyük harfli kelimeler ve 1-5 zorluk dereceleri.
class Dictionary {
  final Map<String, int> _difficulties;

  Dictionary(Map<String, int> difficulties) : _difficulties = Map.of(difficulties);

  /// Her satır `KELİME<TAB>zorluk`. Boş satırlar atlanır.
  factory Dictionary.parse(String compiled) {
    final m = <String, int>{};
    for (final raw in compiled.split('\n')) {
      final line = raw.trimRight();
      if (line.isEmpty) continue;
      final parts = line.split('\t');
      if (parts.length != 2) {
        throw FormatException('Geçersiz sözlük satırı', line);
      }
      m[parts[0]] = int.parse(parts[1]);
    }
    return Dictionary(m);
  }

  bool contains(String word) => _difficulties.containsKey(word);

  int difficultyOf(String word) {
    final d = _difficulties[word];
    if (d == null) throw ArgumentError.value(word, 'word', 'Sözlükte yok');
    return d;
  }

  Iterable<String> get words => _difficulties.keys;
}
