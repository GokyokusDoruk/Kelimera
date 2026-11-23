/// Türk alfabesi (29 harf), oyundaki sırasıyla.
const List<String> trAlphabet = [
  'A', 'B', 'C', 'Ç', 'D', 'E', 'F', 'G', 'Ğ', 'H', 'I', 'İ', 'J', 'K', 'L', //
  'M', 'N', 'O', 'Ö', 'P', 'R', 'S', 'Ş', 'T', 'U', 'Ü', 'V', 'Y', 'Z',
];

/// Eldeki joker taşın sembolü.
const String jokerSymbol = '*';

const Set<String> _vowels = {'A', 'E', 'I', 'İ', 'O', 'Ö', 'U', 'Ü'};
final Set<String> _alphabet = trAlphabet.toSet();

bool isVowel(String letter) => _vowels.contains(letter);

bool isAlphabetLetter(String letter) => _alphabet.contains(letter);

const Map<String, String> _upperMap = {
  'i': 'İ',
  'ı': 'I',
  'â': 'A',
  'Â': 'A',
  'î': 'İ',
  'Î': 'İ',
  'û': 'U',
  'Û': 'U',
};

/// Türkçe kurala göre büyük harfe çevirir: i→İ, ı→I; şapkalı harfler düzleşir.
String trUpper(String s) {
  final b = StringBuffer();
  for (final ch in s.split('')) {
    b.write(_upperMap[ch] ?? ch.toUpperCase());
  }
  return b.toString();
}
