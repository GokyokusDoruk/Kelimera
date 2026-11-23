import 'package:game_core/game_core.dart';
import 'package:test/test.dart';

void main() {
  test('trUpper Türkçe kurala uyar', () {
    expect(trUpper('ılık'), 'ILIK');
    expect(trUpper('iğne'), 'İĞNE');
    expect(trUpper('kâğıt'), 'KAĞIT');
    expect(trUpper('şûra'), 'ŞURA');
    expect(trUpper('KALEM'), 'KALEM');
  });

  test('alfabe 29 harf, sesli harfler', () {
    expect(trAlphabet.length, 29);
    expect(isVowel('İ'), isTrue);
    expect(isVowel('I'), isTrue);
    expect(isVowel('K'), isFalse);
    expect(isAlphabetLetter('Q'), isFalse);
    expect(isAlphabetLetter('Ğ'), isTrue);
  });
}
