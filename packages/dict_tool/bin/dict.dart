import 'dart:convert';
import 'dart:io';

import 'package:dict_tool/build.dart';
import 'package:dict_tool/check.dart';
import 'package:dict_tool/dict_entry.dart';
import 'package:dict_tool/import_alpharing.dart';

const usage = '''
Kullanım:
  dart run bin/dict.dart import <turkishPool.json>   AlphaRing kelimelerini kelimeler.tsv'ye ekler
  dart run bin/dict.dart check                       kelimeler.tsv'yi denetler
  dart run bin/dict.dart build                       denetler ve dictionary/build/ altına derler
''';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.write(usage);
    exit(64);
  }
  final dictDir = _findDictionaryDir();
  final tsvFile = File('${dictDir.path}/kelimeler.tsv');

  switch (args.first) {
    case 'import' when args.length == 2:
      final r = importAlpharing(await File(args[1]).readAsString());
      final existing = tsvFile.existsSync() ? parseTsv(await tsvFile.readAsString()) : <DictEntry>[];
      final known = {for (final e in existing) e.word};
      final added = r.entries.where((e) => !known.contains(e.word)).toList();
      await tsvFile.writeAsString(toTsv([...existing, ...added]));
      stdout.writeln('Eklenen: ${added.length}, mevcut: ${existing.length}, '
          'atlanan: ${r.skipped.length}');
      for (final s in r.skipped) {
        stdout.writeln('  atlandı: $s');
      }
    case 'check':
      final report = checkEntries(parseTsv(await tsvFile.readAsString()));
      _print(report);
      exit(report.ok ? 0 : 1);
    case 'build':
      final entries = parseTsv(await tsvFile.readAsString());
      final report = checkEntries(entries);
      _print(report);
      if (!report.ok) exit(1);
      final c = buildDictionary(entries);
      final out = Directory('${dictDir.path}/build')..createSync(recursive: true);
      await File('${out.path}/sozluk.txt').writeAsString(c.toText());
      await File('${out.path}/harf_tablosu.json').writeAsString('${c.letterTableJson()}\n');
      stdout.writeln('sozluk.txt: ${c.words.length} kelime');
      stdout.writeln('Harf puanları: ${jsonEncode(c.points)}');
    default:
      stderr.write(usage);
      exit(64);
  }
}

void _print(CheckReport r) {
  for (final e in r.errors) {
    stdout.writeln('HATA   $e');
  }
  for (final w in r.warnings) {
    stdout.writeln('UYARI  $w');
  }
  stdout.writeln('${r.errors.length} hata, ${r.warnings.length} uyarı');
}

/// Çalışma klasöründen yukarı çıkarak repo kökündeki `dictionary/` klasörünü bulur.
Directory _findDictionaryDir() {
  var dir = Directory.current.absolute;
  while (true) {
    if (Directory('${dir.path}/.git').existsSync()) {
      return Directory('${dir.path}/dictionary')..createSync();
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      stderr.writeln('Repo kökü bulunamadı');
      exit(1);
    }
    dir = parent;
  }
}
