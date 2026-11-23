import 'package:game_core/game_core.dart';
import 'package:test/test.dart';

void main() {
  test('parse ve arama', () {
    final d = Dictionary.parse('KALEM\t2\nGEL\t1\n\nKALEMLİK\t3\n');
    expect(d.contains('KALEM'), isTrue);
    expect(d.contains('KALEMİ'), isFalse);
    expect(d.difficultyOf('KALEMLİK'), 3);
    expect(d.words.length, 3);
    expect(() => d.difficultyOf('YOK'), throwsArgumentError);
  });

  test('Windows satır sonları da okunur', () {
    final d = Dictionary.parse('KALEM\t2\r\nGEL\t1\r\n');
    expect(d.contains('GEL'), isTrue);
    expect(d.difficultyOf('KALEM'), 2);
  });
}
