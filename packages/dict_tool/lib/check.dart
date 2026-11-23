import 'dict_entry.dart';

class CheckReport {
  final List<String> errors;
  final List<String> warnings;
  const CheckReport(this.errors, this.warnings);
  bool get ok => errors.isEmpty;
}

const validPos = {'isim', 'fiil', 'sıfat', 'zarf', 'zamir', 'ünlem', 'bağlaç', 'edat'};
const validSources = {'alpharing', 'kelimera'};
final _letters = RegExp(r'^[abcçdefgğhıijklmnoöprsştuüvyzâîû]+$');
final _inflection = RegExp(
    r'(lar|ler|ları|leri|dı|di|du|dü|tı|ti|tu|tü|yor|mış|miş|muş|müş)$');

/// Her kayıt için en fazla bir hata (ilk bozulan kural) üretir; tekrarlar ayrıca raporlanır.
CheckReport checkEntries(List<DictEntry> entries) {
  final errors = <String>[];
  final warnings = <String>[];
  final seen = <String>{};

  for (final e in entries) {
    final w = e.word;
    if (!seen.add(w)) {
      errors.add('$w: tekrar eden kelime');
      continue;
    }
    final error = switch (e) {
      _ when !_letters.hasMatch(w) => 'alfabe dışı karakter',
      _ when w.length < 2 => '2 harften kısa',
      _ when e.difficulty < 1 || e.difficulty > 5 => 'zorluk 1-5 olmalı (${e.difficulty})',
      _ when !validPos.contains(e.pos) => 'bilinmeyen tür (${e.pos})',
      _ when !validSources.contains(e.source) => 'bilinmeyen kaynak (${e.source})',
      _ when e.pos == 'fiil' && !(w.endsWith('mak') || w.endsWith('mek')) =>
        'fiil mastar halinde olmalı (-mak/-mek)',
      _ => null,
    };
    if (error != null) {
      errors.add('$w: $error');
      continue;
    }
    if (e.pos != 'fiil' && _inflection.hasMatch(w)) {
      warnings.add('$w: çekim eki şüphesi');
    }
  }
  return CheckReport(errors, warnings);
}
