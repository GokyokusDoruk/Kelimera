import 'package:game_core/game_core.dart';
import 'package:test/test.dart';

final dict = Dictionary({'AT': 1, 'AŞK': 2, 'AEEEEEEEE': 1, 'KA': 1, 'KAT': 5});
final lt = LetterTable.initial();
final base = Board.empty().placeStartWord('KALEM'); // A (5,4)'te

MoveScore score(Board b, Map<Pos, Tile> p) =>
    scoreMove(b, p, (analyzePlacement(b, p) as PlacementOk).words, dict, lt);

void main() {
  test('H2 karesindeki harf', () {
    // T (6,4)'te H2: A1 + T2×2 = 5, taban 0
    expect(score(base, {Pos(6, 4): const Tile('T')}).total, 5);
  });

  test('K2 kelime çarpanı ve nadirlik', () {
    // (3,3) K2'ye A, (4,3)'e Ş, K (5,3)'te hazır: (1+3+1)×2 = 10, zorluk 2 → 2
    final s = score(base, {Pos(3, 3): const Tile('A'), Pos(4, 3): const Tile('Ş')});
    expect(s.words.single.points, 10);
    expect(s.basePoints, 2);
    expect(s.total, 12);
  });

  test('joker 0 puan, harf çarpanı etkisiz', () {
    expect(score(base, {Pos(6, 4): const Tile('T', isJoker: true)}).total, 1);
  });

  test('8 harf bonusu ve uzunluk puanı', () {
    final b = Board.empty().withTiles({Pos(5, 1): const Tile('A')});
    final p = {for (var c = 2; c <= 9; c++) Pos(5, c): const Tile('E')};
    final s = score(b, p); // 9 + uzunluk (9−3)×2 = 12 + 40
    expect(s.bingoBonus, 40);
    expect(s.total, 61);
  });

  test('yan kelimeler ayrıca puan getirir, taban yalnız ana kelimeye', () {
    // (6,3)A (6,4)T → ana AT [A1 + T2×2(H2)] = 5; yan KA [K1 + A1] = 2; yan AT [A1 + T2×2] = 5
    final s = score(base, {Pos(6, 3): const Tile('A'), Pos(6, 4): const Tile('T')});
    expect(s.words.map((w) => w.points), [5, 2, 5]);
    expect(s.basePoints, 0);
    expect(s.total, 12);
  });

  test('çarpanlar yalnız yeni konan karede işler', () {
    // T önceden (6,4) H2 karesine konmuş; bu hamlede yalnız (5,4)'teki A yeni sayılıyor.
    final b = base.withTiles({Pos(6, 4): const Tile('T')});
    final words = [
      FormedWord('AT', [Pos(5, 4), Pos(6, 4)], isMain: true),
    ];
    final s = scoreMove(b, {Pos(5, 4): const Tile('A')}, words, dict, lt);
    expect(s.words.single.points, 3); // A1 + T2 (H2 eski taşta işlemez)
  });

  test('lengthPoints ve rarityPoints', () {
    expect(lengthPoints(2), 0);
    expect(lengthPoints(3), 0);
    expect(lengthPoints(5), 4);
    expect(rarityPoints, [0, 2, 4, 7, 10]);
    expect(bingoBonus, 40);
  });
}
