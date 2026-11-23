const int boardSize = 11;

/// Tahtadaki bir kare (0 tabanlı).
class Pos {
  final int row;
  final int col;
  const Pos(this.row, this.col);

  bool get inBounds => row >= 0 && row < boardSize && col >= 0 && col < boardSize;

  Pos operator +(Pos o) => Pos(row + o.row, col + o.col);
  Pos operator -(Pos o) => Pos(row - o.row, col - o.col);

  @override
  bool operator ==(Object other) => other is Pos && other.row == row && other.col == col;

  @override
  int get hashCode => row * 31 + col;

  @override
  String toString() => '($row,$col)';
}

/// Tahtadaki bir taş. Joker için [letter] oyuncunun seçtiği harftir.
class Tile {
  final String letter;
  final bool isJoker;
  const Tile(this.letter, {this.isJoker = false});

  @override
  bool operator ==(Object other) =>
      other is Tile && other.letter == letter && other.isJoker == isJoker;

  @override
  int get hashCode => Object.hash(letter, isJoker);

  @override
  String toString() => isJoker ? '$letter*' : letter;
}

enum Premium { none, h2, h3, k2, k3, k4 }

final Map<Pos, Premium> _premiums = () {
  final m = <Pos, Premium>{};
  void put(Premium p, List<(int, int)> cells) {
    for (final (r, c) in cells) {
      m[Pos(r, c)] = p;
    }
  }

  put(Premium.k4, [(0, 0), (0, 10), (10, 0), (10, 10)]);
  put(Premium.k3, [(0, 5), (5, 0), (5, 10), (10, 5)]);
  put(Premium.k2, [(1, 1), (1, 9), (9, 1), (9, 9), (3, 3), (3, 7), (7, 3), (7, 7)]);
  put(Premium.h3, [(0, 3), (0, 7), (3, 0), (3, 10), (7, 0), (7, 10), (10, 3), (10, 7)]);
  put(Premium.h2, [
    (2, 4), (2, 6), (4, 2), (4, 4), (4, 6), (4, 8), //
    (6, 2), (6, 4), (6, 6), (6, 8), (8, 4), (8, 6),
  ]);
  return m;
}();

Premium premiumAt(Pos p) => _premiums[p] ?? Premium.none;

/// Değişmez tahta.
class Board {
  final Map<Pos, Tile> _tiles;
  const Board._(this._tiles);

  factory Board.empty() => const Board._({});

  Tile? at(Pos p) => _tiles[p];

  Map<Pos, Tile> get tiles => Map.unmodifiable(_tiles);

  bool get isEmpty => _tiles.isEmpty;

  Board withTiles(Map<Pos, Tile> tiles) => Board._({..._tiles, ...tiles});

  /// Kelimeyi 5. satıra yatay ve ortalanmış yerleştirir.
  Board placeStartWord(String word) {
    final letters = word.split('');
    final start = (boardSize - letters.length) ~/ 2;
    return withTiles({
      for (var i = 0; i < letters.length; i++) Pos(5, start + i): Tile(letters[i]),
    });
  }

  @override
  bool operator ==(Object other) {
    if (other is! Board || other._tiles.length != _tiles.length) return false;
    for (final e in _tiles.entries) {
      if (other._tiles[e.key] != e.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAllUnordered(_tiles.entries.map((e) => Object.hash(e.key, e.value)));
}
