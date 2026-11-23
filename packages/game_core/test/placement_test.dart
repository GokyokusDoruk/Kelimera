import 'package:game_core/game_core.dart';
import 'package:test/test.dart';

final base = Board.empty().placeStartWord('KALEM'); // (5,3)..(5,7)

Map<Pos, Tile> t(Map<(int, int), String> m) =>
    {for (final e in m.entries) Pos(e.key.$1, e.key.$2): Tile(e.value)};

List<String> texts(PlacementResult r) =>
    (r as PlacementOk).words.map((w) => '${w.isMain ? '*' : ''}${w.text}').toList();

PlacementError err(Board b, Map<Pos, Tile> p) => (analyzePlacement(b, p) as PlacementFailed).error;

void main() {
  test('hatalar', () {
    expect(err(base, {}), PlacementError.empty);
    expect(err(base, t({(5, 3): 'A'})), PlacementError.occupied);
    expect(err(base, t({(6, 4): 'T', (7, 5): 'A'})), PlacementError.notInLine);
    expect(err(base, t({(6, 4): 'T', (8, 4): 'A'})), PlacementError.gap);
    expect(err(base, t({(0, 0): 'A', (0, 1): 'T'})), PlacementError.notConnected);
    expect(err(base, t({(11, 0): 'A'})), PlacementError.outOfBounds);
  });

  test('tek başına duran tek harf bağlı değil', () {
    expect(err(base, t({(0, 0): 'A'})), PlacementError.notConnected);
  });

  test('dikey kelime mevcut harfle', () {
    expect(texts(analyzePlacement(base, t({(6, 4): 'T'}))), ['*AT']);
  });

  test('boşluğu mevcut harf dolduruyor', () {
    expect(texts(analyzePlacement(base, t({(4, 5): 'O', (6, 5): 'A'}))), ['*OLA']);
  });

  test('tek harf iki kelime: eşit uzunlukta yatay ana', () {
    final b = base.withTiles({Pos(4, 6): const Tile('O')});
    expect(texts(analyzePlacement(b, t({(4, 5): 'T'}))), ['*TO', 'TL']);
  });

  test('tek harf iki kelime: uzun olan ana', () {
    // (6,5)'e harf: dikey L+X = 2 harf; yatayda (6,6)(6,7) dolu → 3 harf
    final b = base.withTiles({Pos(6, 6): const Tile('A'), Pos(6, 7): const Tile('L')});
    expect(texts(analyzePlacement(b, t({(6, 5): 'E'}))), ['*EAL', 'LE']);
  });

  test('ana kelime ve yan kelimeler', () {
    final r = texts(analyzePlacement(base, t({(6, 3): 'A', (6, 4): 'T'})));
    expect(r.first, '*AT');
    expect(r.skip(1).toSet(), {'KA', 'AT'});
  });

  test('kelimeyi uzatma (yatay, mevcut kelimenin sonuna)', () {
    expect(texts(analyzePlacement(base, t({(5, 8): 'L', (5, 9): 'İ', (5, 10): 'K'}))),
        ['*KALEMLİK']);
  });

  test('kenarda kelime', () {
    final b = Board.empty().withTiles({Pos(5, 10): const Tile('A')});
    expect(texts(analyzePlacement(b, t({(6, 10): 'T'}))), ['*AT']);
  });

  test('ana kelimenin pozisyonları sırayla', () {
    final r = analyzePlacement(base, t({(6, 4): 'T'})) as PlacementOk;
    expect(r.words.single.positions, [Pos(5, 4), Pos(6, 4)]);
  });
}
