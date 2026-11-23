# Plan 1 — `game_core` ve Sözlük Araçları Uygulama Planı

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Kelimera'nın bütün oyun kurallarını Flutter'a ve ağa bağımlı olmayan, saf Dart ile yazılmış ve testlerle doğrulanmış bir pakette (`game_core`) toplamak. Ayrıca AlphaRing kelimelerinden ilk sözlüğü ve harf tablosunu üreten araçları (`dict_tool`) yazmak.

**Architecture:** İki paket olacak:
- `packages/game_core`: Değişmez (immutable) veri tipleri ve saf fonksiyonlar. Tahta, harf çekme, yerleştirme analizi, puanlama, hamle değerlendirme ve tur durum makinesi (`GameEngine`) burada. Zaman bilgisi dışarıdan verilir, motor saat tutmaz. Süre dolduğunda hakem `timeout()` çağırır.
- `packages/dict_tool`: Komut satırı aracı. `dictionary/kelimeler.tsv` dosyasını okur, denetler ve derler. Derleme çıktısı uygulamaya gömülecek `sozluk.txt` ve `harf_tablosu.json` dosyalarıdır.

**Tech Stack:** Dart 3 (`sdk: ^3.6.0`), `package:test`, `package:lints`. Dart, Flutter SDK ile birlikte gelir.

**Spec:** `docs/superpowers/specs/2026-11-23-kelimera-design.md`

**Sonraki planlar (bu planın dışında):**
- Plan 2: `net_core` (protokol, hakem mantığı, `FakeTransport`).
- Plan 3: BLE deneme projesi ve taşıyıcılar.
- Plan 4: Flutter arayüzü.
- Plan 5: Sözlüğün genişletilmesi.

## Global Constraints

- Lisanslı içerik kullanılmayacak. Bu kural sözlük, sıklık verisi ve harf puanları için de geçerli. Sözlüğün tek kaynağı AlphaRing'in kendi içeriği ve projede yazılan kelimeler.
- Alfabe 29 harf: `A B C Ç D E F G Ğ H I İ J K L M N O Ö P R S Ş T U Ü V Y Z`. Joker `*` ile gösterilir.
- Büyük harfe çevirme Türkçe kurala göre yapılır: `i→İ`, `ı→I`. Şapkalı harfler düz harfe çevrilir: `â→A`, `î→İ`, `û→U`.
- Tahta 11x11. Bir elde 8 harf bulunur. Her hamlede yaklaşık %2 ihtimalle joker çıkar. Her elde en az 2 sesli ve en az 3 sessiz harf olur.
- En kısa kelime 2 harf. Çekimli halleri geçersiz. Fiillerde hem mastar hem kök geçerli.
- Puanlama:
  - Taban puan yalnızca ana kelimeye verilir.
  - Uzunluk puanı `max(0, uzunluk − 3) × 2`.
  - Nadirlik puanı zorluk derecesine göre: 1→0, 2→2, 3→4, 4→7, 5→10.
  - 8 harfin hepsini kullanana +40 bonus.
  - Joker 0 puan.
- Oyun 5 büyük turda biter. Tekrar yasağı yalnızca ana kelimeye uygulanır.
- `game_core` içinde `dart:io` ve Flutter importu olmayacak.
- Kod tanımlayıcıları İngilizce, kullanıcıya görünen metinler Türkçe olacak.
- Her commit mesajı şu satırla biter: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`

## Review Focus

Spesifikasyonun açıkça yazmadığı ama kullanıcıyı en çok etkileyecek beş durum. Her birinin testi ilgili göreve eklendi:

1. **Az harf çekilen hamleden sonra el garantisi:** Örneğin oyuncu tek harf kullandı ve elinde kalan 7 harfin hepsi sessiz. Çekilecek tek harf sesli olmalı. Garanti tam karşılanamıyorsa çekiliş elden geldiğince iyi sonuç vermeli; asla hata vermemeli ya da sonsuz döngüye girmemeli. (Görev 4)
2. **Türkçe I/İ dönüşümü:** `ılık` → `ILIK`, `iğne` → `İĞNE`, `kâğıt` → `KAĞIT`. Bu dönüşüm hem içe aktarmada hem sözlükte aramada doğru çalışmalı. (Görev 1 ve Görev 11)
3. **Harfi seçilmemiş ya da geçersiz harfli joker:** Hamle çökmeden ve "geçersiz harf" nedeniyle reddedilmeli. (Görev 9)
4. **Aynı anda iki kelime oluşturan tek harf:** Bu durumda uzun olan kelime, uzunluklar eşitse yatay olan kelime ana kelime sayılmalı. Mevcut harflerle doldurulan boşluklar da doğru işlenmeli. (Görev 5)
5. **Sırası gelen oyuncunun kopması ya da oyunda tek kişi kalması:** Kopan oyuncunun sırası hemen geçilmeli. Bir kişi kalırsa oyun bitmeli. Oyundan ayrılan oyuncu kazanan olmamalı. Puanlar eşitse beraberlik kuralı uygulanmalı. (Görev 9)

---

## Dosya Yapısı

```
packages/game_core/
  pubspec.yaml
  analysis_options.yaml
  lib/game_core.dart                 dışa açılan API (export)
  lib/src/letters.dart               alfabe, sesli harfler, trUpper
  lib/src/board.dart                 Pos, Tile, Premium, premiumAt, Board
  lib/src/dictionary.dart            Dictionary
  lib/src/letter_table.dart          LetterTable (puan ve ağırlık)
  lib/src/letter_drawer.dart         LetterDrawer (el doldurma)
  lib/src/placement.dart             analyzePlacement, FormedWord, PlacementError
  lib/src/scoring.dart               scoreMove, MoveScore
  lib/src/move_evaluation.dart       evaluateMove, RejectReason
  lib/src/game_state.dart            PlayerState, GameState, JSON
  lib/src/game_engine.dart           GameEngine, MoveOutcome, winnerIds
  test/...                           her lib dosyası için bir test dosyası
packages/dict_tool/
  pubspec.yaml                       (path ile game_core bağımlılığı)
  lib/dict_entry.dart                DictEntry, parseTsv, toTsv
  lib/import_alpharing.dart          importAlpharing
  lib/check.dart                     checkEntries, CheckReport
  lib/build.dart                     buildDictionary, CompiledDictionary
  bin/dict.dart                      import | check | build alt komutları
  test/...
dictionary/
  kelimeler.tsv                      kaynak sözlük (elle düzenlenir)
  build/sozluk.txt                   derleme çıktısı
  build/harf_tablosu.json            derleme çıktısı
```

---

### Görev 0: Ortam hazırlığı

Bu görev kod içermez. Buradaki adımları **kullanıcı yapar ya da onaylar.** Bu adımlar tamamlanmadan Görev 1'e geçilmez.

- [ ] **Adım 1: Git kimliği.** `git config --global user.name` ve `git config --global user.email` komutları boş çıkmamalı.
- [ ] **Adım 2: Flutter SDK'yı kur.** Bunun için `git clone https://github.com/flutter/flutter.git -b stable C:\src\flutter` komutunu çalıştır ve `C:\src\flutter\bin` klasörünü kullanıcı PATH'ine ekle. Yeni bir terminal açıp `dart --version` komutunu çalıştır, çıktıda `Dart SDK version: 3.` görünmeli. Android Studio ve Android SDK Plan 3'e kadar gerekli değil.
- [ ] **Adım 3: Tasarım belgesini ve bu planı commit et.**

```bash
git add docs/
git commit -m "docs: Kelimera tasarım belgesi ve Plan 1"
```

---

### Görev 1: `game_core` iskeleti ve harfler

**Files:**
- Create: `packages/game_core/pubspec.yaml`, `analysis_options.yaml`, `lib/game_core.dart`, `lib/src/letters.dart`
- Test: `packages/game_core/test/letters_test.dart`

**Interfaces:**
- Produces:
  - `const List<String> trAlphabet` (29 harf, yukarıdaki sırayla)
  - `const String jokerSymbol = '*'`
  - `bool isVowel(String letter)`: `AEIİOÖUÜ`
  - `bool isAlphabetLetter(String letter)`
  - `String trUpper(String s)`

- [ ] **Adım 1:** `packages/game_core` klasöründe `dart create -t package game_core` ile paketi oluştur. `pubspec.yaml` içinde `sdk: ^3.6.0` tanımla. Bağımlılıkları `dart pub add --dev test lints` ile ekle. Şablonla gelen örnek dosyaları sil.
- [ ] **Adım 2: Başarısız testi yaz**

```dart
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
```

- [ ] **Adım 3:** `dart test test/letters_test.dart` → FAIL (tanımlar yok)
- [ ] **Adım 4:** `letters.dart`'ı yaz. `trUpper` önce `i→İ`, `ı→I`, `â→A`, `î→İ`, `û→U` eşlemesini uygulamalı, sonra `toUpperCase()` çağırmalı. `lib/game_core.dart` dosyası her `src` dosyasını dışa açmalı (export).
- [ ] **Adım 5:** `dart test` → PASS. `dart analyze` → No issues.
- [ ] **Adım 6: Commit** `feat(game_core): paket iskeleti ve Türkçe harf yardımcıları`

---

### Görev 2: Tahta, karolar ve çarpanlar

**Files:**
- Create: `lib/src/board.dart`
- Test: `test/board_test.dart`

**Interfaces:**
- Produces:
  - `const int boardSize = 11`
  - `class Pos { final int row, col; }`: 0 tabanlı, `==` ve `hashCode` tanımlı, `bool get inBounds`
  - `class Tile { final String letter; final bool isJoker; }`: `letter` her zaman alfabeden bir harftir. Joker için oyuncunun seçtiği harf yazılır.
  - `enum Premium { none, h2, h3, k2, k3, k4 }`
  - `Premium premiumAt(Pos p)`
  - `class Board`: değişmez. `Board.empty()`, `Tile? at(Pos p)`, `Board withTiles(Map<Pos, Tile> tiles)`, `Map<Pos, Tile> get tiles`, `bool get isEmpty`
  - `Board placeStartWord(String word)`: Kelimeyi 5. satıra yatay yerleştirir. Başlangıç sütunu `(11 − uzunluk) ~/ 2`.

Çarpanların yerleri, 0 tabanlı (satır, sütun) olarak:
```
k4: (0,0) (0,10) (10,0) (10,10)
k3: (0,5) (5,0) (5,10) (10,5)
k2: (1,1) (1,9) (9,1) (9,9) (3,3) (3,7) (7,3) (7,7)
h3: (0,3) (0,7) (3,0) (3,10) (7,0) (7,10) (10,3) (10,7)
h2: (2,4) (2,6) (4,2) (4,4) (4,6) (4,8) (6,2) (6,4) (6,6) (6,8) (8,4) (8,6)
```

- [ ] **Adım 1: Başarısız testi yaz**

```dart
test('çarpan sayıları ve simetri', () {
  final counts = <Premium, int>{};
  for (var r = 0; r < 11; r++) {
    for (var c = 0; c < 11; c++) {
      final p = premiumAt(Pos(r, c));
      counts[p] = (counts[p] ?? 0) + 1;
      expect(premiumAt(Pos(c, r)), p);        // köşegene göre simetri
      expect(premiumAt(Pos(r, 10 - c)), p);   // dikey eksene göre simetri
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
```

- [ ] **Adım 2:** `dart test test/board_test.dart` → FAIL
- [ ] **Adım 3:** `board.dart`'ı yaz.
- [ ] **Adım 4:** `dart test` → PASS
- [ ] **Adım 5: Commit** `feat(game_core): tahta, karo ve çarpan deseni`

---

### Görev 3: Sözlük

**Files:**
- Create: `lib/src/dictionary.dart`
- Test: `test/dictionary_test.dart`

**Interfaces:**
- Produces: `class Dictionary`
  - `Dictionary(Map<String, int> difficulties)`: Anahtarlar büyük harfli kelimeler, değerler 1-5 arası zorluk.
  - `factory Dictionary.parse(String compiled)`: Her satır `KELİME<TAB>zorluk` biçiminde. Boş satırlar atlanır.
  - `bool contains(String word)`
  - `int difficultyOf(String word)`: Kelime sözlükte yoksa `ArgumentError` fırlatır.
  - `Iterable<String> get words`

- [ ] **Adım 1: Başarısız testi yaz**

```dart
test('parse ve arama', () {
  final d = Dictionary.parse('KALEM\t2\nGEL\t1\n\nKALEMLİK\t3\n');
  expect(d.contains('KALEM'), isTrue);
  expect(d.contains('KALEMİ'), isFalse);
  expect(d.difficultyOf('KALEMLİK'), 3);
  expect(d.words.length, 3);
  expect(() => d.difficultyOf('YOK'), throwsArgumentError);
});
```

- [ ] **Adım 2:** FAIL → **Adım 3:** uygula → **Adım 4:** PASS
- [ ] **Adım 5: Commit** `feat(game_core): Dictionary`

---

### Görev 4: Harf tablosu ve harf çekme

**Files:**
- Create: `lib/src/letter_table.dart`, `lib/src/letter_drawer.dart`
- Test: `test/letter_drawer_test.dart`

**Interfaces:**
- Produces:
  - `class LetterTable`
    - `const LetterTable({required Map<String, int> points, required Map<String, num> weights})`
    - `final Map<String, int> points`
    - `final Map<String, num> weights`
    - `int pointsOf(Tile t)`: joker için 0, diğerleri için `points[letter]`
    - `factory LetterTable.initial()`: Puanlar spesifikasyonun §5.3 tablosundan alınır, bütün ağırlıklar 1.
    - `factory LetterTable.fromJson(Map<String, dynamic> json)`: `{"points": {...}, "weights": {...}}`
  - `class LetterDrawer`
    - `LetterDrawer(LetterTable table, Random random, {double jokerChance = 0.02})`
    - `List<String> newHand()`
    - `List<String> refill(List<String> hand)`: Eli 8 harfe tamamlar. Joker `'*'` ile gösterilir.
  - `const int handSize = 8`

**Çekiliş algoritması.** Spesifikasyon bu algoritmayı belirlemediği için burada tanımlanıyor. Eksik her yer için şu sırayla çalışır:
1. Açıkları hesapla: `vNeed = max(0, 2 − sesli sayısı)`, `cNeed = max(0, 3 − sessiz sayısı)`, `slots = kalan boş yer`.
2. `jokerChance` ihtimaliyle joker çek. Joker hangi açık büyükse ondan düşülür, eşitlikte sesli açığından.
3. Joker çıkmadıysa: `vNeed + cNeed >= slots` ise açığı büyük olan gruptan çek (eşitlikte sesli grubundan). Aksi halde bütün alfabeden çek.
4. Bütün çekilişler ağırlığa göre rastgele yapılır.

Bu algoritmada mevcut harfler hiçbir zaman atılmaz. Garanti tam karşılanamıyorsa çekiliş elden geldiğince açığı kapatır.

- [ ] **Adım 1: Başarısız testi yaz**

```dart
LetterTable consonantHeavy() => LetterTable(
    points: LetterTable.initial().points,
    weights: {for (final l in trAlphabet) l: isVowel(l) ? 1 : 1000});

test('yeni el 8 harf, ≥2 sesli, ≥3 sessiz', () {
  final d = LetterDrawer(consonantHeavy(), Random(1), jokerChance: 0);
  for (var i = 0; i < 500; i++) {
    final h = d.newHand();
    expect(h.length, 8);
    expect(h.where(isVowel).length, greaterThanOrEqualTo(2));
    expect(h.where((l) => !isVowel(l)).length, greaterThanOrEqualTo(3));
  }
});
test('7 sessizli eli tamamlarken tek çekiliş sesli olur', () {
  final d = LetterDrawer(consonantHeavy(), Random(2), jokerChance: 0);
  final h = d.refill(['B', 'C', 'D', 'F', 'G', 'H', 'K']);
  expect(h.length, 8);
  expect(h.take(7), ['B', 'C', 'D', 'F', 'G', 'H', 'K']);
  expect(isVowel(h.last), isTrue);
});
test('joker şansı 0 ise joker çıkmaz, 1 ise el tümüyle joker', () {
  expect(LetterDrawer(LetterTable.initial(), Random(3), jokerChance: 0)
      .newHand().contains('*'), isFalse);
  expect(LetterDrawer(LetterTable.initial(), Random(3), jokerChance: 1)
      .newHand(), List.filled(8, '*'));
});
test('dolu el değişmez', () {
  final d = LetterDrawer(LetterTable.initial(), Random(4));
  final h = ['A', 'E', 'K', 'L', 'M', 'N', 'R', 'T'];
  expect(d.refill(h), h);
});
test('joker 0 puan', () {
  expect(LetterTable.initial().pointsOf(const Tile('J', isJoker: true)), 0);
  expect(LetterTable.initial().pointsOf(const Tile('J')), 10);
});
```

- [ ] **Adım 2:** FAIL → **Adım 3:** uygula → **Adım 4:** PASS
- [ ] **Adım 5: Commit** `feat(game_core): harf tablosu ve garantili harf çekme`

---

### Görev 5: Yerleştirme analizi

**Files:**
- Create: `lib/src/placement.dart`
- Test: `test/placement_test.dart`

**Interfaces:**
- Consumes: `Board`, `Pos`, `Tile` (Görev 2)
- Produces:
  - `enum PlacementError { empty, outOfBounds, occupied, notInLine, gap, notConnected }`
  - `class FormedWord { final String text; final List<Pos> positions; final bool isMain; }`
  - `sealed class PlacementResult`: `PlacementOk(List<FormedWord> words)` ya da `PlacementFailed(PlacementError error)`
  - `PlacementResult analyzePlacement(Board board, Map<Pos, Tile> placements)`

**Kurallar:**
- Hamlede en az 1 harf olmalı, harfler tahtanın içinde ve boş karelerde bulunmalı.
- Bütün harfler tek bir satırda ya da tek bir sütunda olmalı. İlk ve son harf arasındaki her kare ya yeni konan bir harfle ya da tahtada zaten bulunan bir harfle dolu olmalı.
- Ana kelime, harflerin dizildiği yönde, iki uca kadar uzanan dolu dizidir. Tek harf konduysa iki yöndeki dizinin uzun olanı ana kelime sayılır, uzunluklar eşitse yatay olan.
- Ana kelimeye ek olarak, konan her harfin dik yönde oluşturduğu 2 ve daha uzun diziler yan kelimedir.
- Hamle, oluşan kelimelerden en az biri tahtada zaten bulunan bir harfi içerdiğinde bağlanmış sayılır. Aksi halde `notConnected` hatası verilir.
- Tek harf konduğunda hiçbir dizi 2 harfe ulaşmıyorsa sonuç yine `notConnected` olur.
- Kelimeler soldan sağa ya da yukarıdan aşağıya okunur.

- [ ] **Adım 1: Başarısız testi yaz**

```dart
final base = Board.empty().placeStartWord('KALEM'); // (5,3)..(5,7)
Map<Pos, Tile> t(Map<(int, int), String> m) =>
    {for (final e in m.entries) Pos(e.key.$1, e.key.$2): Tile(e.value)};
List<String> texts(PlacementResult r) =>
    (r as PlacementOk).words.map((w) => '${w.isMain ? '*' : ''}${w.text}').toList();

test('hatalar', () {
  expect((analyzePlacement(base, {}) as PlacementFailed).error, PlacementError.empty);
  expect((analyzePlacement(base, t({(5, 3): 'A'})) as PlacementFailed).error,
      PlacementError.occupied);
  expect((analyzePlacement(base, t({(6, 4): 'T', (7, 5): 'A'})) as PlacementFailed).error,
      PlacementError.notInLine);
  expect((analyzePlacement(base, t({(6, 4): 'T', (8, 4): 'A'})) as PlacementFailed).error,
      PlacementError.gap);
  expect((analyzePlacement(base, t({(0, 0): 'A', (0, 1): 'T'})) as PlacementFailed).error,
      PlacementError.notConnected);
  expect((analyzePlacement(base, t({(11, 0): 'A'})) as PlacementFailed).error,
      PlacementError.outOfBounds);
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
test('ana kelime ve yan kelimeler', () {
  // KALEM'in altına yatay olarak "AT" yaz: (6,3)A (6,4)T → yan kelimeler KA ve AT
  final r = texts(analyzePlacement(base, t({(6, 3): 'A', (6, 4): 'T'})));
  expect(r.first, '*AT');
  expect(r.skip(1).toSet(), {'KA', 'AT'});
});
test('kenarda kelime', () {
  final b = Board.empty().withTiles({Pos(5, 10): const Tile('A')});
  expect(texts(analyzePlacement(b, t({(6, 10): 'T'}))), ['*AT']);
});
```

- [ ] **Adım 2:** FAIL → **Adım 3:** uygula → **Adım 4:** PASS
- [ ] **Adım 5: Commit** `feat(game_core): yerleştirme analizi ve oluşan kelimeler`

---

### Görev 6: Puanlama

**Files:**
- Create: `lib/src/scoring.dart`
- Test: `test/scoring_test.dart`

**Interfaces:**
- Consumes: `FormedWord` (Görev 5), `LetterTable` (Görev 4), `Dictionary` (Görev 3), `premiumAt` (Görev 2)
- Produces:
  - `class WordScore { final String word; final int points; }`
  - `class MoveScore { final List<WordScore> words; final int basePoints; final int bingoBonus; int get total; }`
  - `MoveScore scoreMove(Board board, Map<Pos, Tile> placements, List<FormedWord> words, Dictionary dict, LetterTable letters)`
  - Sabitler: `bingoBonus = 40`, `rarityPoints = [0, 2, 4, 7, 10]`, `int lengthPoints(int len) => max(0, len - 3) * 2`

**Hesaplama:**
- Harf ve kelime çarpanları yalnızca `placements` içindeki karelerde uygulanır. Bir kelimedeki birden fazla kelime çarpanı birbiriyle çarpılır.
- `basePoints` ana kelimeye verilir: `lengthPoints(uzunluk) + rarityPoints[zorluk − 1]`.
- `placements.length == 8` ise 8 harf bonusu eklenir.

- [ ] **Adım 1: Başarısız testi yaz**

```dart
final dict = Dictionary({'AT': 1, 'AŞK': 2, 'AEEEEEEEE': 1});
final lt = LetterTable.initial();
final base = Board.empty().placeStartWord('KALEM'); // A (5,4)'te

MoveScore score(Board b, Map<Pos, Tile> p) =>
    scoreMove(b, p, (analyzePlacement(b, p) as PlacementOk).words, dict, lt);

test('H2 karesindeki harf', () {
  // T (6,4)'te H2: A1 + T2×2 = 5, taban 0
  expect(score(base, {Pos(6, 4): const Tile('T')}).total, 5);
});
test('K2 kelime çarpanı ve nadirlik', () {
  // (3,3) K2'ye A, (4,3)'e Ş, K (5,3)'te hazır: (1+3+1)×2 = 10, nadirlik zorluk 2 → 2
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
```

- [ ] **Adım 2:** FAIL → **Adım 3:** uygula → **Adım 4:** PASS
- [ ] **Adım 5: Commit** `feat(game_core): puanlama`

---

### Görev 7: Hamle değerlendirme

**Files:**
- Create: `lib/src/move_evaluation.dart`
- Test: `test/move_evaluation_test.dart`

**Interfaces:**
- Consumes: `analyzePlacement`, `scoreMove`
- Produces:
  - `sealed class RejectReason` ve alt sınıfları:
    - `NotYourTurn()`
    - `GameFinished()`
    - `NotInHand()`
    - `InvalidLetter()`
    - `PlacementInvalid(PlacementError error)`
    - `UnknownWords(List<String> words)`
    - `WordAlreadyUsed(String word)`
    - Hepsinde değer eşitliği (`==`) tanımlı.
  - `sealed class MoveEvaluation`: `MoveValid(List<FormedWord> words, MoveScore score)` ya da `MoveInvalid(List<RejectReason> reasons)`
  - `MoveEvaluation evaluateMove({required Board board, required Map<Pos, Tile> placements, required Dictionary dictionary, required LetterTable letters, required Set<String> usedWords})`

**Kurallar:**
- Yerleştirme hatası varsa yalnızca `[PlacementInvalid]` döner.
- Yerleştirme geçerliyse:
  - Sözlükte olmayan bütün kelimeler tek bir `UnknownWords` nedeninde, oluşma sırasıyla toplanır.
  - Ana kelime `usedWords` içindeyse `WordAlreadyUsed` eklenir.
- İki neden aynı anda dönebilir. Oylama ekranı `UnknownWords` nedenine bakarak açılacak.

- [ ] **Adım 1: Başarısız testi yaz**

```dart
final dict = Dictionary({'AT': 1, 'KA': 1, 'KALEM': 2});
final base = Board.empty().placeStartWord('KALEM');
MoveEvaluation ev(Map<Pos, Tile> p, {Set<String> used = const {}}) => evaluateMove(
    board: base, placements: p, dictionary: dict,
    letters: LetterTable.initial(), usedWords: used);

test('geçerli', () => expect(ev({Pos(6, 4): const Tile('T')}), isA<MoveValid>()));
test('bilinmeyen ana ve yan kelime', () {
  // (6,3)A (6,4)Z → ana kelime AZ (yok), yan kelimeler KA (var) ve AZ (yok)
  final r = ev({Pos(6, 3): const Tile('A'), Pos(6, 4): const Tile('Z')}) as MoveInvalid;
  expect(r.reasons, [UnknownWords(['AZ', 'AZ'])]);
});
test('kullanılmış ana kelime', () {
  final r = ev({Pos(6, 4): const Tile('T')}, used: {'AT'}) as MoveInvalid;
  expect(r.reasons, [WordAlreadyUsed('AT')]);
});
test('yerleştirme hatası tek neden', () {
  final r = ev({}) as MoveInvalid;
  expect(r.reasons, [PlacementInvalid(PlacementError.empty)]);
});
```

- [ ] **Adım 2:** FAIL → **Adım 3:** uygula → **Adım 4:** PASS
- [ ] **Adım 5: Commit** `feat(game_core): hamle değerlendirme ve ret nedenleri`

---

### Görev 8: Oyun durumu ve JSON

**Files:**
- Create: `lib/src/game_state.dart`
- Test: `test/game_state_test.dart`

**Interfaces:**
- Produces:
  - `enum PlayerStatus { connected, disconnected, left }`
  - `class PlayerInfo { final String id; final String name; final int avatar; }`
  - `class PlayerState { PlayerInfo info; int score; List<String> hand; PlayerStatus status; int bestMove; }`
  - `class GameState`
    - Alanlar: `Board board; List<PlayerState> players` (oturma sırasıyla), `int round` (1-5), `int turnIndex`, `Set<String> usedWords`, `String startWord`, `bool finished`
    - `PlayerState get current`
    - `GameState copyWith(...)`
    - `Map<String, dynamic> toJson()`, `factory GameState.fromJson(Map<String, dynamic>)`
  - `const int totalRounds = 5`
  - Bütün sınıflar değişmez ve değer eşitliği (`==`) tanımlı. Bu sayede JSON gidiş-dönüş testi yapılabilir.

- [ ] **Adım 1: Başarısız testi yaz.** Testte `round: 3`, jokerli bir karo, `status: disconnected` ve `usedWords: {'AT'}` içeren bir durum kurulmalı. Ardından şu kontrol yapılmalı: `expect(GameState.fromJson(jsonDecode(jsonEncode(s.toJson()))), s)`.
- [ ] **Adım 2:** FAIL → **Adım 3:** uygula → **Adım 4:** PASS
- [ ] **Adım 5: Commit** `feat(game_core): oyun durumu ve JSON`

---

### Görev 9: Oyun motoru

**Files:**
- Create: `lib/src/game_engine.dart`
- Test: `test/game_engine_test.dart`

**Interfaces:**
- Consumes: Görev 2-8'deki tipler
- Produces:
  - `class GameEngine`
    - `GameEngine({required Dictionary dictionary, required LetterTable letters, required Random random, double jokerChance = 0.02})`
    - `GameState start(List<PlayerInfo> players)`: 2-4 oyuncu kabul eder, aksi halde `ArgumentError` fırlatır. Oturma sırasını rastgele karıştırır. Başlangıç kelimesini seçip tahtaya yerleştirir ve `usedWords` içine ekler. Her oyuncuya `newHand()` ile el dağıtır.
    - `MoveOutcome submitMove(GameState s, String playerId, Map<Pos, Tile> placements)`
    - `GameState swapAll(GameState s, String playerId)`: Oyuncunun elini tamamen yeniler, sırayı ilerletir, puan vermez.
    - `GameState timeout(GameState s)`: Sırayı ilerletir, oyuncunun eli değişmez.
    - `GameState setStatus(GameState s, String playerId, PlayerStatus status)`
  - `String pickStartWord(Dictionary d, Random r)`: Uzunluğu 5-7 ve zorluğu 1-3 olan kelimeler arasından rastgele seçer. Uygun kelime yoksa `StateError` fırlatır.
  - `sealed class MoveOutcome`: `MoveAccepted(GameState state, MoveScore score)` ya da `MoveRejected(List<RejectReason> reasons)`
  - `List<String> winnerIds(GameState s)`

**Kurallar:**
- **Hamle kontrolü:**
  - Oyun bitmişse `GameFinished`.
  - Sıra oyuncuda değilse `NotYourTurn`.
  - Karonun harfi alfabede yoksa `InvalidLetter`.
  - Konan harfler oyuncunun elinden karşılanamıyorsa `NotInHand`. Joker karolar eldeki `'*'` sembollerinden düşülür.
  - Ardından `evaluateMove` çalıştırılır.
- **Kabul edilen hamle:** Taşlar tahtaya konur. Kullanılan harfler elden çıkarılır ve el `refill` ile tamamlanır. Puan ve `bestMove` güncellenir, ana kelime `usedWords` içine eklenir, sıra ilerler.
- **Sırayı ilerletme:**
  - `turnIndex + 1`. Sıra başa dönerse `round + 1`. `round > 5` olursa `finished` olur.
  - Yeni sıradaki oyuncunun durumu `connected` değilse sırası hemen geçilir.
  - Durumu `left` olmayan oyuncu sayısı 2'nin altına düşerse oyun hemen biter.
- **`setStatus`:** Oyuncu sırası gelmişken kopar (`disconnected`) ya da ayrılırsa (`left`), sırası hemen ilerletilir.
- **`winnerIds`:** `left` olmayan oyuncular arasında en yüksek puanlı olanları döner. Puanlar eşitse en yüksek `bestMove` değerine sahip olanlar kalır. O da eşitse birden fazla id döner.

- [ ] **Adım 1: Başarısız testleri yaz.** Testlerde 2 harfli kelimelerle küçük bir sözlük ve sabit `Random(seed)` kullanılır:
  - `start`: 4 oyuncu, her elde 8 harf, `round == 1`, tahta başlangıç kelimesini içeriyor, `usedWords` içinde başlangıç kelimesi var. 1 oyuncu ve 5 oyuncu için `ArgumentError`.
  - Sırası olmayan oyuncu → `[NotYourTurn()]`.
  - Elde olmayan harf → `[NotInHand()]`. `Tile('Q')` → `[InvalidLetter()]`. Elde `'*'` varken `Tile('T', isJoker: true)` kabul edilir.
  - Kabul edilen hamleden sonra: el yine 8 harf, puan arttı, `turnIndex` ilerledi, ana kelime `usedWords` içinde.
  - `swapAll`: El değişti (sabit seed ile), puan aynı, sıra ilerledi.
  - 2 oyuncu, 10 `timeout` sonra `finished == true`. 9 `timeout` sonra `round == 5`.
  - 3 oyuncuda sıradaki oyuncu `disconnected` olursa `timeout` çağrısı onu atlar.
  - 3 oyuncuda ikisi `left` olursa → `finished`.
  - `winnerIds`: puanlar `[10, 10, 5]`, `bestMove` değerleri `[6, 4, 5]` → ilk oyuncu. `bestMove` değerleri de eşitse → iki id. En yüksek puanlı oyuncu `left` ise o atlanır.
- [ ] **Adım 2:** FAIL → **Adım 3:** uygula → **Adım 4:** PASS
- [ ] **Adım 5: Commit** `feat(game_core): oyun motoru (sıra, tur, bitiş, kazanan)`

---

### Görev 10: Botlarla dayanıklılık testi

**Files:**
- Test: `packages/game_core/test/soak_test.dart`

- [ ] **Adım 1: Testi yaz.**
  - **Sözlük:** Alfabedeki bütün 2 harfli birleşimlerden oluşur (29×29 kelime, hepsinin zorluğu 1), ayrıca başlangıç kelimesi olarak `KALEM` eklenir.
  - **Bot:** Her hamlede rastgele şunlardan birini yapar:
    - %60: Tahtadaki rastgele bir harfin boş komşusuna elinden tek harf koymayı dener. Reddedilirse `timeout` çağırır.
    - %20: `swapAll`
    - %10: `timeout`
    - %10: Rastgele bir oyuncunun durumunu değiştirir.
  - **Oyun sayısı:** 2, 3 ve 4 oyunculu toplam 2.000 oyun, seed 0-1999.
  - **Her adımda kontrol edilecek değişmezler:**
    - Bütün eller 8 harf.
    - Puanlar hiçbir zaman azalmıyor.
    - Tahtadaki taş sayısı hiç azalmıyor.
    - `fromJson(toJson(s)) == s`.
    - Oyun en fazla `oyuncu sayısı × 5` sıra ilerlemesinde bitiyor.
- [ ] **Adım 2:** `dart test test/soak_test.dart` → PASS. Bir hata çıkarsa ilgili görevin testine kalıcı bir test olarak eklenir.
- [ ] **Adım 3: Commit** `test(game_core): bot dayanıklılık testi`

---

### Görev 11: `dict_tool` — TSV ve AlphaRing'den içe aktarma

**Files:**
- Create: `packages/dict_tool/pubspec.yaml` (`game_core: {path: ../game_core}`), `lib/dict_entry.dart`, `lib/import_alpharing.dart`
- Test: `test/dict_entry_test.dart`, `test/import_alpharing_test.dart`

**Interfaces:**
- Produces:
  - `class DictEntry { final String word; final String pos; final int difficulty; final String source; }`
    - `word`: Türkçe küçük harflerle, yazıldığı gibi.
    - `pos`: `isim`, `fiil`, `sıfat`, `zarf`, `zamir`, `ünlem`, `bağlaç` ya da `edat`.
    - `source`: `alpharing` ya da `kelimera`.
  - `List<DictEntry> parseTsv(String text)`: İlk satır başlıktır ve atlanır.
  - `String toTsv(List<DictEntry> entries)`: Başlık `kelime\ttür\tzorluk\tkaynak`. Kayıtlar kelimeye göre sıralanır.
  - `({List<DictEntry> entries, List<String> skipped}) importAlpharing(String turkishPoolJson)`
    - Tür eşlemesi: `noun→isim`, `verb→fiil`, `adjective→sıfat`, `adverb→zarf`.
    - Zorluk eşlemesi: `easy→2`, `medium→3`, `hard→4`.
    - İçinde boşluk ya da alfabe dışı karakter bulunan cevaplar `skipped` listesine konur.
    - Aynı kelime birden fazla kez geçiyorsa ilk kayıt alınır.

- [ ] **Adım 1: Başarısız testleri yaz.**
  - TSV gidiş-dönüş testi.
  - `importAlpharing` için `ahtapot`/`medium`/`noun`, `ılık`/`easy`/`adjective`, `koşmak`/`hard`/`verb` ve `iç bahçe` içeren küçük bir JSON. Beklenen sonuç: 3 kayıt, `iç bahçe` atlanmış, `ılık` kelimesinin zorluğu 2.
- [ ] **Adım 2:** FAIL → **Adım 3:** uygula → **Adım 4:** PASS
- [ ] **Adım 5: Commit** `feat(dict_tool): TSV ve AlphaRing içe aktarma`

---

### Görev 12: `dict_tool` — denetim

**Files:**
- Create: `lib/check.dart`
- Test: `test/check_test.dart`

**Interfaces:**
- Produces:
  - `class CheckReport { final List<String> errors; final List<String> warnings; bool get ok => errors.isEmpty; }`
  - `CheckReport checkEntries(List<DictEntry> entries)`

**Hatalar:**
- Tekrar eden kelime.
- Küçük harf Türkçe alfabesi ve `âîû` dışında bir karakter.
- 2 harften kısa kelime.
- 1-5 aralığı dışında zorluk.
- Bilinmeyen tür ya da kaynak.
- `fiil` türündeki bir kelimenin `-mak` ya da `-mek` ile bitmemesi.

**Uyarı (çekim eki şüphesi):** Kelime `lar, ler, ları, leri, dı, di, du, dü, tı, ti, tu, tü, yor, mış, miş, muş, müş` eklerinden biriyle bitiyorsa uyarı verilir. `fiil` türündeki kelimeler bu kontrolden muaftır.

Her mesajda ilgili kelime geçmelidir.

- [ ] **Adım 1: Başarısız testi yaz.**
  - Beklenen hatalar: `kalem` iki kez, `x`, `kalem1`, zorluğu 6 olan bir kayıt, `koş` (fiil).
  - Beklenen uyarı: `kalemler`.
  - `koşmak` (fiil) için hiçbir mesaj çıkmamalı.
- [ ] **Adım 2:** FAIL → **Adım 3:** uygula → **Adım 4:** PASS
- [ ] **Adım 5: Commit** `feat(dict_tool): sözlük denetimi`

---

### Görev 13: `dict_tool` — derleme, harf tablosu ve komut satırı

**Files:**
- Create: `lib/build.dart`, `bin/dict.dart`
- Test: `test/build_test.dart`

**Interfaces:**
- Consumes: `trUpper`, `trAlphabet` (Görev 1), `DictEntry` (Görev 11), `checkEntries` (Görev 12)
- Produces:
  - `class CompiledDictionary`
    - `final Map<String, int> words`: Büyük harfli kelimeler ve fiil kökleri.
    - `final Map<String, int> letterCounts`
    - `final Map<String, int> points`
    - `String toText()`: `KELİME\tzorluk` satırları, sıralı. Bu çıktı `Dictionary.parse` ile okunabilir.
    - `String letterTableJson()`: `LetterTable.fromJson` ile okunabilir.
  - `CompiledDictionary buildDictionary(List<DictEntry> entries)`
  - Komut satırı: `dart run bin/dict.dart import <turkishPool.json>`, `... check`, `... build`. Komutlar repo kökündeki `dictionary/` klasöründe çalışır. `check` komutu hata bulursa çıkış kodu 1 döner. `build` önce denetim yapar, ardından `dictionary/build/` klasörüne yazar.

**Kurallar:**
- **Fiil kökleri:** `fiil` türündeki bir kelimenin sonundaki `mak`/`mek` silinir. Kalan kök 2 harf veya daha uzunsa sözlüğe eklenir ve mastarın zorluğunu alır. Kök sözlükte zaten varsa iki zorluktan küçük olanı kalır.
- **Harf sayımı:** Derlenmiş sözlükteki (kökler dahil) bütün kelimelerin harfleri sayılır.
- **Harf puanları:** Harfler sayılarına göre çoktan aza sıralanır. Sayılar eşitse `trAlphabet` sırası kullanılır. Sıralamaya göre gruplara puan verilir:

| Grup büyüklüğü | 7 | 7 | 5 | 3 | 4 | 2 | 1 |
|---|---|---|---|---|---|---|---|
| Puan | 1 | 2 | 3 | 4 | 5 | 7 | 10 |

  Bu yapı spesifikasyondaki puan tablosunun biçimiyle aynı, ama değerler kendi sözlüğümüzden hesaplanıyor.
- **Ağırlıklar:** `weights = letterCounts`. Hiç geçmeyen bir harfin ağırlığı 1 olur.

- [ ] **Adım 1: Başarısız testi yaz.**
  - `[koşmak/fiil/3, koş/isim/2, gelmek/fiil/1, kalem/isim/2]` girdisiyle beklenen kelimeler: `KOŞMAK:3, KOŞ:2, GELMEK:1, GEL:1, KALEM:2`.
  - `Dictionary.parse(c.toText())` bu kelimeleri içermeli.
  - `points` 29 harfi içermeli ve en çok geçen harfin puanı 1 olmalı.
  - `LetterTable.fromJson(jsonDecode(c.letterTableJson()))` hata vermeden çalışmalı.
- [ ] **Adım 2:** FAIL → **Adım 3:** uygula → **Adım 4:** PASS
- [ ] **Adım 5: Gerçek veriyle çalıştır**

```bash
cd packages/dict_tool
dart run bin/dict.dart import "C:/Users/Doruk/Documents/AlphaRing-2.0/apps/api/src/seed/turkishPool.json"
dart run bin/dict.dart check
dart run bin/dict.dart build
```

Beklenen sonuç:
- `dictionary/kelimeler.tsv` yaklaşık 2.588 satır, atlanan kelimeler ekrana yazılır.
- `check` sıfır hata verir. Uyarılar listelenir ve kullanıcıya gösterilir.
- `build` sonrası `dictionary/build/sozluk.txt` yaklaşık 2.900 satır (fiil kökleri dahil), `harf_tablosu.json` 29 harf içerir.

- [ ] **Adım 6: Uçtan uca test.** `packages/game_core/test/real_dictionary_test.dart` dosyası `../../dictionary/build/sozluk.txt`'yi okumalı. `pickStartWord` hata vermemeli, `KALEMLİK` ve `GEL` sözlükte bulunmalı. Dosya yoksa test `skip` edilmeli.
- [ ] **Adım 7: Commit** `feat(dict_tool): derleme, fiil kökleri, harf tablosu; ilk sözlük`

---

## Self-Review Notları

- **Spesifikasyonun kapsanması:**
  - §5.1-5.7: Görev 2-9.
  - §5.3 harf puanı ve ağırlıkları: Görev 13.
  - §8: Görev 11-13.
  - §9: Görev 1-10.
  - Spesifikasyonun §5.4'teki 500 ms süre payı, §5.8 oylama, §5.9 profil ve sohbet, §5.10 hakem kopması ve §7 bu planda yok. Bunlar Plan 2-4'e ait.
- **Tip tutarlılığı:** `Tile(letter, isJoker:)`, `Pos(row, col)`, `PlacementOk.words`, `MoveValid.score`, `RejectReason` alt sınıfları ve `PlayerStatus` bütün görevlerde aynı isimlerle kullanıldı.
- **Değer eşitliği:** `UnknownWords` liste içerdiği için `==` karşılaştırmasında liste eşitliği kullanılmalı.
