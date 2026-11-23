import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:game_core/game_core.dart';
import 'package:test/test.dart';

final _dictFile = File('../../dictionary/build/sozluk.txt');
final _tableFile = File('../../dictionary/build/harf_tablosu.json');

void main() {
  test('derlenmiş gerçek sözlük oyunda kullanılabilir', () {
    final d = Dictionary.parse(_dictFile.readAsStringSync());
    expect(d.contains('KALEM'), isTrue); // KALEMLİK AlphaRing çekirdeğinde yok (Plan 5'te eklenecek)
    expect(d.contains('GEL'), isTrue);
    expect(d.contains('GELMEK'), isTrue);
    expect(d.contains('KALEMLER'), isFalse);
    final word = pickStartWord(d, Random(1));
    expect(word.length, inInclusiveRange(5, 7));

    final t = LetterTable.fromJson(jsonDecode(_tableFile.readAsStringSync()) as Map<String, dynamic>);
    final e = GameEngine(dictionary: d, letters: t, random: Random(1));
    final s = e.start([
      const PlayerInfo(id: 'a', name: 'A', avatar: 0),
      const PlayerInfo(id: 'b', name: 'B', avatar: 1),
    ]);
    expect(s.players.every((p) => p.hand.length == 8), isTrue);
  }, skip: _dictFile.existsSync() ? false : 'dictionary/build/sozluk.txt yok');
}
