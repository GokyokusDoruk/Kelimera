import 'package:game_core/game_core.dart';
import 'package:test/test.dart';

void main() {
  test('çarpan sayıları ve simetri', () {
    final counts = <Premium, int>{};
    for (var r = 0; r < boardSize; r++) {
      for (var c = 0; c < boardSize; c++) {
        final p = premiumAt(Pos(r, c));
        counts[p] = (counts[p] ?? 0) + 1;
        expect(premiumAt(Pos(c, r)), p, reason: 'köşegen ($r,$c)');
        expect(premiumAt(Pos(r, 10 - c)), p, reason: 'dikey eksen ($r,$c)');
      }
    }
    expect(counts[Premium.k4], 4);
    expect(counts[Premium.k3], 4);
    expect(counts[Premium.k2], 8);
    expect(counts[Premium.h3], 8);
    expect(counts[Premium.h2], 12);
    expect(premiumAt(Pos(5, 5)), Premium.none);
  });

  test('başlangıç kelimesi ortalanır', () {
    final b = Board.empty().placeStartWord('KALEMİ'); // 6 harf
    expect(b.at(Pos(5, 2))!.letter, 'K');
    expect(b.at(Pos(5, 7))!.letter, 'İ');
    expect(b.at(Pos(5, 8)), isNull);
    final b5 = Board.empty().placeStartWord('KALEM');
    expect(b5.at(Pos(5, 3))!.letter, 'K');
  });

  test('withTiles yeni tahta döner, eskisi değişmez', () {
    final a = Board.empty();
    final b = a.withTiles({Pos(0, 0): const Tile('A')});
    expect(a.isEmpty, isTrue);
    expect(b.at(Pos(0, 0))!.letter, 'A');
  });

  test('Pos değer eşitliği ve sınırlar', () {
    expect(Pos(1, 2), Pos(1, 2));
    expect({Pos(1, 2)}.contains(Pos(1, 2)), isTrue);
    expect(Pos(0, 10).inBounds, isTrue);
    expect(Pos(11, 0).inBounds, isFalse);
    expect(Pos(-1, 0).inBounds, isFalse);
  });
}
