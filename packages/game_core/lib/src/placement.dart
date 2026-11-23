import 'board.dart';

enum PlacementError { empty, outOfBounds, occupied, notInLine, gap, notConnected }

/// Bir hamlede oluşan kelime. Pozisyonlar soldan sağa / yukarıdan aşağıya.
class FormedWord {
  final String text;
  final List<Pos> positions;
  final bool isMain;
  const FormedWord(this.text, this.positions, {required this.isMain});

  @override
  String toString() => '${isMain ? '*' : ''}$text';
}

sealed class PlacementResult {
  const PlacementResult();
}

class PlacementOk extends PlacementResult {
  final List<FormedWord> words;
  const PlacementOk(this.words);
}

class PlacementFailed extends PlacementResult {
  final PlacementError error;
  const PlacementFailed(this.error);
}

const Pos _right = Pos(0, 1);
const Pos _down = Pos(1, 0);

/// Yerleştirmeyi kurallara göre inceler ve oluşan kelimeleri çıkarır.
/// Ana kelime her zaman listenin ilk elemanıdır.
PlacementResult analyzePlacement(Board board, Map<Pos, Tile> placements) {
  if (placements.isEmpty) return const PlacementFailed(PlacementError.empty);
  if (placements.keys.any((p) => !p.inBounds)) {
    return const PlacementFailed(PlacementError.outOfBounds);
  }
  if (placements.keys.any((p) => board.at(p) != null)) {
    return const PlacementFailed(PlacementError.occupied);
  }

  Tile? tileAt(Pos p) => placements[p] ?? board.at(p);
  final positions = placements.keys.toList();

  List<Pos> run(Pos start, Pos dir) {
    var p = start;
    while (tileAt(p - dir) != null) {
      p = p - dir;
    }
    final out = <Pos>[];
    while (tileAt(p) != null) {
      out.add(p);
      p = p + dir;
    }
    return out;
  }

  FormedWord word(List<Pos> ps, {required bool isMain}) =>
      FormedWord(ps.map((p) => tileAt(p)!.letter).join(), ps, isMain: isMain);

  final List<FormedWord> words;
  if (positions.length == 1) {
    final p = positions.single;
    final h = run(p, _right);
    final v = run(p, _down);
    if (h.length < 2 && v.length < 2) {
      return const PlacementFailed(PlacementError.notConnected);
    }
    final hMain = h.length >= v.length;
    final main = hMain ? h : v;
    final other = hMain ? v : h;
    words = [
      word(main, isMain: true),
      if (other.length >= 2) word(other, isMain: false),
    ];
  } else {
    final sameRow = positions.every((p) => p.row == positions.first.row);
    final sameCol = positions.every((p) => p.col == positions.first.col);
    if (!sameRow && !sameCol) return const PlacementFailed(PlacementError.notInLine);
    final dir = sameRow ? _right : _down;
    final cross = sameRow ? _down : _right;

    positions.sort((a, b) => sameRow ? a.col - b.col : a.row - b.row);
    for (var p = positions.first; p != positions.last; p = p + dir) {
      if (tileAt(p) == null) return const PlacementFailed(PlacementError.gap);
    }

    words = [
      word(run(positions.first, dir), isMain: true),
      for (final p in positions)
        if (run(p, cross) case final ps when ps.length >= 2) word(ps, isMain: false),
    ];
  }

  final connected = words.any((w) => w.positions.any((p) => board.at(p) != null));
  if (!connected) return const PlacementFailed(PlacementError.notConnected);
  return PlacementOk(words);
}
