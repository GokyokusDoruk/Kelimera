import 'package:game_core/game_core.dart';
import 'package:test/test.dart';

final dict = Dictionary({'AT': 1, 'KA': 1, 'KALEM': 2});
final base = Board.empty().placeStartWord('KALEM');

MoveEvaluation ev(Map<Pos, Tile> p, {Set<String> used = const {}}) => evaluateMove(
    board: base,
    placements: p,
    dictionary: dict,
    letters: LetterTable.initial(),
    usedWords: used);

void main() {
  test('geçerli', () {
    final r = ev({Pos(6, 4): const Tile('T')}) as MoveValid;
    expect(r.score.total, 5);
    expect(r.words.single.text, 'AT');
  });

  test('bilinmeyen ana ve yan kelime', () {
    // (6,3)A (6,4)Z → ana AZ (yok), yan KA (var), yan AZ (yok)
    final r = ev({Pos(6, 3): const Tile('A'), Pos(6, 4): const Tile('Z')}) as MoveInvalid;
    expect(r.reasons, [UnknownWords(['AZ', 'AZ'])]);
  });

  test('kullanılmış ana kelime', () {
    final r = ev({Pos(6, 4): const Tile('T')}, used: {'AT'}) as MoveInvalid;
    expect(r.reasons, [WordAlreadyUsed('AT')]);
  });

  test('yan kelime tekrar edebilir', () {
    // (6,3)A (6,4)T → ana AT, yanlar KA ve AT. KA daha önce yazılmış olsa da kabul.
    final r = ev({Pos(6, 3): const Tile('A'), Pos(6, 4): const Tile('T')}, used: {'KA'});
    expect(r, isA<MoveValid>());
  });

  test('yerleştirme hatası tek neden', () {
    final r = ev({}) as MoveInvalid;
    expect(r.reasons, [PlacementInvalid(PlacementError.empty)]);
  });
}
