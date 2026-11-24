# Plan 2 — `net_core` Uygulama Planı

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hakem telefon ile oyuncu telefonları arasındaki bütün oyun trafiğini, BLE'den bağımsız ve saf Dart bir pakette (`net_core`) toplamak. Paket şunları içerecek: mesaj protokolü, hakem mantığı (`GameHost`), oyuncu oturumu (`ClientSession`), parçalama (framing) ve bellek içi taşıyıcı.

**Architecture:**
- **Taşıyıcı katmanı:** `GameHost` ve `ClientSession` yalnızca metin mesajı taşıyan iki arayüz görür: `HostTransport` ve `ClientTransport`. Plan 3'te BLE bu arayüzlerin arkasına takılacak. Bu planda ise taşıyıcı olarak bellek içi `MemoryHub` kullanılacak.
- **Zaman:** Bütün zamanlayıcılar bir `Scheduler` arayüzünden geçer. Testlerde `FakeScheduler` kullanılır; böylece 45 saniyelik süreler, 500 ms'lik süre payı, 2 dakikalık yeniden bağlanma penceresi ve 15 saniyelik oylama gerçekten beklenmeden test edilir.
- **Kurallar:** Oyun kuralları `game_core` paketindeki `GameEngine`'den gelir. Hakem tek doğru kaynaktır ve her oyuncuya o oyuncuya özel bir `PlayerView` gönderir.

**Tech Stack:** Dart 3 (`sdk: ^3.6.0`), `package:test`, `package:lints`, `game_core` (path bağımlılığı). Başka bağımlılık eklenmez.

**Spec:** `docs/superpowers/specs/2026-11-23-kelimera-design.md`. Bu plan özellikle şu bölümleri karşılıyor: §5.4 (süre ve süre payı), §5.8 (oylama), §5.9 (sohbet), §5.10 (bağlantı kopması), §7.2 (hakem modeli), §7.3 (protokol), §7.4 (parçalama), §9 (`net_core` testleri).

## Global Constraints

- `net_core` içinde `dart:io` ve Flutter import edilmez. Saat bilgisi yalnızca `Scheduler` üzerinden okunur, `DateTime.now()` ve `Timer` doğrudan kullanılmaz. Tek istisna `SystemScheduler` sınıfıdır.
- Hamle süresi 45 sn, süre payı 500 ms, yeniden bağlanma penceresi 2 dk, oylama süresi 15 sn.
- Sohbet mesajı en fazla 120 karakter, oyuncu sayısı en fazla 4, `protocolVersion = 1`.
- Hakem her oyuncuya yalnızca **o oyuncunun kendi elini** gönderir. Hiçbir mesaj başka bir oyuncunun elini içeremez.
- Oyun başladıktan sonra odaya yeni oyuncu katılamaz. Yalnızca oyunda olan ve "ayrıldı" sayılmamış oyuncular geri bağlanabilir.
- Oylama kelimeyi o oyunda geçerli yapmaz. Çoğunluk "evet" derse kelime yalnızca öneri listesine eklenir.
- Her commit mesajı şu satırla biter: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`

## Review Focus

1. **Süre sınırındaki hamle:** Süre doldu ama 500 ms'lik pay içinde gelen hamle kabul edilir. Paydan sonra gelen hamle `NotYourTurn` alır, çünkü o noktada sıra zaten geçmiştir. (Görev 7)
2. **Aynı oyuncu iki bağlantıyla görünürse:** Oyuncu yeniden bağlandığında eski bağlantı henüz kopmamış olabilir. Bu durumda mesajlar en son bağlantıya gider; eski bağlantının kopması oyuncuyu "koptu" saymaz. (Görev 8)
3. **Bozuk ya da bilinmeyen mesaj:** Hakem ve istemci çökmez, mesajı yok sayar. Ayrıca `Hello` göndermemiş bir bağlantıdan gelen mesajlar da yok sayılır. (Görev 3 ve Görev 6)
4. **Sohbet sınırları:** Boş ya da yalnızca boşluktan oluşan mesaj gönderilmez. 120 karakteri aşan mesaj kırpılır. Lobide sohbet de çalışır. (Görev 9)
5. **Oylama sırasında oyuncunun kopması ya da ikinci bir öneri:** Kopan oyuncunun oyu "hayır" sayılır. Aynı anda yalnızca bir oylama yapılabilir. (Görev 9)

---

## Dosya Yapısı

```
packages/net_core/
  pubspec.yaml                         game_core: {path: ../game_core}
  lib/net_core.dart                    dışa açık API
  lib/testing.dart                     FakeScheduler ve MemoryHub'ı dışa açar (Plan 4 testleri de kullanır)
  lib/src/scheduler.dart               Scheduler, Cancelable, SystemScheduler
  lib/src/fake_scheduler.dart          FakeScheduler
  lib/src/framing.dart                 encodeFrames, FrameAssembler
  lib/src/messages.dart                NetMessage alt sınıfları, encodeMessage/decodeMessage, ret nedeni kodlayıcıları
  lib/src/player_view.dart             PublicPlayer, PlayerView, viewFor
  lib/src/transport.dart               HostTransport, ClientTransport, olaylar, MergedHostTransport
  lib/src/memory_transport.dart        MemoryHub, MemoryClient
  lib/src/host_config.dart             HostConfig
  lib/src/game_host.dart               GameHost
  lib/src/client_session.dart          ClientSession
  test/...
```

---

### Görev 1: Paket iskeleti ve zamanlayıcı

**Files:**
- Create: `pubspec.yaml`, `analysis_options.yaml` (game_core'dakinin kopyası), `lib/net_core.dart`, `lib/testing.dart`, `lib/src/scheduler.dart`, `lib/src/fake_scheduler.dart`
- Test: `test/fake_scheduler_test.dart`

**Interfaces:**
- Produces:
  - `abstract interface class Cancelable { void cancel(); }`
  - `abstract interface class Scheduler { DateTime now(); Cancelable after(Duration delay, void Function() callback); }`
  - `class SystemScheduler implements Scheduler`: `DateTime.now()` ve `Timer` kullanır.
  - `class FakeScheduler implements Scheduler`
    - `FakeScheduler([DateTime? start])`: Başlangıç zamanı verilmezse 2026-01-01 kullanılır.
    - `void advance(Duration d)`: Zamanı ilerletir. Bu sürede vadesi gelen geri çağrıları vade sırasıyla, vadeleri eşitse kayıt sırasıyla çalıştırır. Bir geri çağrının içinden kaydedilen ve vadesi pencere içinde kalan yeni geri çağrılar da aynı `advance` çağrısında çalışır.
    - `int get pendingCount`

- [ ] **Adım 1:** `dart create -t package net_core` ile paketi oluştur ve şablon dosyalarını sil. `game_core` bağımlılığını path ile ekle, ardından `dart pub add --dev test lints` çalıştır.
- [ ] **Adım 2: Başarısız testi yaz**

```dart
test('advance vadesi gelenleri sırayla çalıştırır', () {
  final s = FakeScheduler();
  final log = <String>[];
  s.after(const Duration(seconds: 2), () => log.add('b'));
  s.after(const Duration(seconds: 1), () {
    log.add('a');
    s.after(const Duration(milliseconds: 500), () => log.add('a2'));
  });
  final c = s.after(const Duration(seconds: 3), () => log.add('iptal'));
  c.cancel();
  s.advance(const Duration(seconds: 2));
  expect(log, ['a', 'a2', 'b']);
  expect(s.pendingCount, 0);
  expect(s.now(), DateTime(2026, 1, 1).add(const Duration(seconds: 2)));
});
```

- [ ] **Adım 3:** `dart test test/fake_scheduler_test.dart` → FAIL
- [ ] **Adım 4:** Uygula.
- [ ] **Adım 5:** PASS
- [ ] **Adım 6: Commit** `feat(net_core): paket iskeleti ve zamanlayıcı`

---

### Görev 2: Parçalama (framing)

**Files:**
- Create: `lib/src/framing.dart`
- Test: `test/framing_test.dart`

**Interfaces:**
- Produces:
  - `const int frameHeaderSize = 4`
  - `List<Uint8List> encodeFrames(int messageId, Uint8List payload, int maxFrameSize)`
    - Başlık 4 bayttır: `[messageId: uint16 big-endian][index: uint8][total: uint8]`.
    - `maxFrameSize` en az 5 olmalı, aksi halde `ArgumentError`. 255'ten fazla parça gerekirse de `ArgumentError`.
    - Boş payload tek bir parça olarak gönderilir.
  - `class FrameAssembler { Uint8List? add(Uint8List frame); }`
    - Mesajın bütün parçaları gelince birleştirilmiş payload'u döner.
    - Yeni bir `messageId` gelirse yarım kalan mesaj atılır.
    - Aynı parça ikinci kez gelirse yok sayılır.
    - 4 bayttan kısa bir parça `FormatException` fırlatır.

- [ ] **Adım 1: Başarısız testi yaz**

```dart
test('böl ve birleştir, Türkçe metin', () {
  final payload = Uint8List.fromList(utf8.encode('İĞNE ş' * 50));
  final frames = encodeFrames(7, payload, 20);
  expect(frames.every((f) => f.length <= 20), isTrue);
  expect(frames.first.sublist(0, 4), [0, 7, 0, frames.length]);
  final a = FrameAssembler();
  Uint8List? out;
  for (final f in frames) {
    out = a.add(f);
  }
  expect(utf8.decode(out!), 'İĞNE ş' * 50);
});
test('yarım mesaj yeni mesajla atılır, tekrar eden parça yok sayılır', () {
  final a = FrameAssembler();
  final m1 = encodeFrames(1, Uint8List(40), 20);
  final m2 = encodeFrames(2, Uint8List.fromList([1, 2, 3]), 20);
  expect(a.add(m1[0]), isNull);
  expect(a.add(m2[0]), [1, 2, 3]);
  final m3 = encodeFrames(3, Uint8List(30), 20);
  expect(a.add(m3[0]), isNull);
  expect(a.add(m3[0]), isNull);
  expect(a.add(m3[1]), hasLength(30));
});
test('sınırlar', () {
  expect(encodeFrames(1, Uint8List(0), 20), hasLength(1));
  expect(() => encodeFrames(1, Uint8List(10), 4), throwsArgumentError);
  expect(() => encodeFrames(1, Uint8List(256), 5), throwsArgumentError);
  expect(() => FrameAssembler().add(Uint8List(3)), throwsFormatException);
});
```

- [ ] **Adım 2:** FAIL → **Adım 3:** uygula → **Adım 4:** PASS
- [ ] **Adım 5: Commit** `feat(net_core): mesaj parçalama`

---

### Görev 3: Mesajlar ve kodlayıcı

**Files:**
- Create: `lib/src/messages.dart`
- Test: `test/messages_test.dart`

**Interfaces:**
- Consumes: `PlayerInfo`, `Pos`, `Tile`, `RejectReason` ve alt sınıfları, `PlacementError` (game_core). `PlayerView` (Görev 4).
- Produces:
  - `const int protocolVersion = 1`
  - `enum JoinRejectCode { roomFull, gameStarted, versionMismatch, playerLeft }`
  - `sealed class NetMessage`. Bütün alt sınıflar değişmez ve değer eşitliği (`==`) tanımlı:

    | Sınıf | Alanlar | Kim gönderir |
    |---|---|---|
    | `Hello` | `PlayerInfo player, int protocol` | istemci |
    | `Welcome` | `String playerId` | hakem |
    | `JoinRejected` | `JoinRejectCode code` | hakem |
    | `LobbyMsg` | `String roomCode, String hostId, List<PlayerInfo> players` | hakem |
    | `StateMsg` | `PlayerView view` | hakem |
    | `MoveMsg` | `Map<Pos, Tile> placements` | istemci |
    | `SwapAllMsg` | (alan yok) | istemci |
    | `MoveResultMsg` | `bool accepted, int points, List<RejectReason> reasons` | hakem |
    | `ProposeWordMsg` | `String word` | istemci |
    | `VoteStartMsg` | `String voteId, String word, String proposerId, int durationMs` | hakem |
    | `VoteMsg` | `String voteId, bool yes` | istemci |
    | `VoteResultMsg` | `String voteId, String word, bool accepted` | hakem |
    | `ChatMsg` | `String fromId, String text` | ikisi de (istemcinin gönderdiği `fromId` yok sayılır) |
    | `PingMsg` / `PongMsg` | (alan yok) | ikisi de |
  - `String encodeMessage(NetMessage m)`: JSON çıktı, örneğin `{"t":"hello", ...}`.
  - `NetMessage? decodeMessage(String s)`: Bozuk JSON, bilinmeyen `t` değeri ya da eksik alan gelirse `null` döner. Hiçbir durumda istisna fırlatmaz.
  - `Map<String, dynamic> rejectReasonToJson(RejectReason r)` ve `RejectReason rejectReasonFromJson(Map<String, dynamic> j)`
    - Kodlar: `notYourTurn`, `gameFinished`, `notInHand`, `invalidLetter`, `placement` (+`error`: `PlacementError.name`), `unknownWords` (+`words`), `wordAlreadyUsed` (+`word`).

- [ ] **Adım 1: Başarısız testi yaz.** Bu görev `PlayerView`'a ihtiyaç duyar. Bu yüzden önce Görev 4'ü tamamla ya da `StateMsg` testini Görev 4'e kadar ertele. Önerilen sıra: Görev 4'ü önce yap, sonra Görev 3'e dön.

```dart
final samples = <NetMessage>[
  Hello(const PlayerInfo(id: 'p1', name: 'Ayşe', avatar: 3), protocol: 1),
  const Welcome('p1'),
  const JoinRejected(JoinRejectCode.roomFull),
  const LobbyMsg('4821', 'p1', [PlayerInfo(id: 'p1', name: 'Ayşe', avatar: 3)]),
  MoveMsg({const Pos(6, 4): const Tile('T'), const Pos(6, 5): const Tile('İ', isJoker: true)}),
  const SwapAllMsg(),
  const MoveResultMsg(false, 0, [UnknownWords(['AZ']), PlacementInvalid(PlacementError.gap),
      WordAlreadyUsed('AT'), NotYourTurn(), GameFinished(), NotInHand(), InvalidLetter()]),
  const ProposeWordMsg('ÇİLEK'),
  const VoteStartMsg('v1', 'ÇİLEK', 'p1', 15000),
  const VoteMsg('v1', true),
  const VoteResultMsg('v1', 'ÇİLEK', true),
  const ChatMsg('p2', 'merhaba 👋'),
  const PingMsg(),
  const PongMsg(),
];
test('her mesaj gidiş-dönüş', () {
  for (final m in samples) {
    expect(decodeMessage(encodeMessage(m)), m, reason: m.runtimeType.toString());
  }
});
test('bozuk girdi null döner', () {
  expect(decodeMessage('{'), isNull);
  expect(decodeMessage('{"t":"uzaylı"}'), isNull);
  expect(decodeMessage('{"t":"welcome"}'), isNull);
  expect(decodeMessage('[1,2]'), isNull);
});
```

  Bunlara ek olarak `StateMsg` için gidiş-dönüş testi Görev 4'teki `sampleView()` ile yazılır.
- [ ] **Adım 2:** FAIL → **Adım 3:** uygula → **Adım 4:** PASS
- [ ] **Adım 5: Commit** `feat(net_core): protokol mesajları ve kodlayıcı`

---

### Görev 4: Oyuncuya özel durum görünümü

**Files:**
- Create: `lib/src/player_view.dart`
- Test: `test/player_view_test.dart` (`sampleView()` yardımcısı `test/support/samples.dart` dosyasında)

**Interfaces:**
- Consumes: `GameState`, `PlayerState`, `PlayerStatus`, `Board`, `winnerIds` (game_core)
- Produces:
  - `class PublicPlayer`: `PlayerInfo info`, `int score`, `PlayerStatus status`, `int handCount`. JSON ve `==` tanımlı.
  - `class PlayerView`
    - Alanlar: `Board board`, `List<PublicPlayer> players` (oturma sırasıyla), `String currentPlayerId`, `int round`, `List<String> myHand`, `int remainingMs`, `Set<String> usedWords`, `String startWord`, `bool finished`, `List<String> winners`.
    - Yalnızca oyun bittiyse `winners = winnerIds(state)`, aksi halde boş liste.
    - `toJson`, `fromJson` ve `==` tanımlı.
  - `PlayerView viewFor(GameState s, String playerId, {required int remainingMs})`: Oyuncu oyunda yoksa `myHand` boş olur.

- [ ] **Adım 1: Başarısız testi yaz**

```dart
test('kendi eli var, başkasınınki yok', () {
  final s = sampleState(); // p1 eli ['A','*','K','L','M','N','R','İ'], p2 eli ['B','C','Ç','D','E','F','G','Ğ']
  final v = viewFor(s, 'p1', remainingMs: 30000);
  expect(v.myHand, ['A', '*', 'K', 'L', 'M', 'N', 'R', 'İ']);
  expect(v.players.map((p) => p.handCount), [8, 8]);
  final json = jsonEncode(v.toJson());
  expect(json.contains('"Ğ"'), isFalse);
  expect(json.contains('"Ç"'), isFalse);
});
test('JSON gidiş-dönüş ve kazananlar', () {
  final v = viewFor(sampleState().copyWith(finished: true), 'p2', remainingMs: 0);
  expect(PlayerView.fromJson(jsonDecode(jsonEncode(v.toJson())) as Map<String, dynamic>), v);
  expect(v.winners, ['p1']);
});
```

`sampleState()` Plan 1'deki `game_state_test`'in örneğine benzer şekilde kurulur: p1 12 puan, p2 0 puan.
- [ ] **Adım 2:** FAIL → **Adım 3:** uygula → **Adım 4:** PASS
- [ ] **Adım 5: Commit** `feat(net_core): oyuncuya özel durum görünümü`

---

### Görev 5: Taşıyıcı arayüzleri, bellek içi taşıyıcı ve birleştirici

**Files:**
- Create: `lib/src/transport.dart`, `lib/src/memory_transport.dart`
- Test: `test/transport_test.dart`

**Interfaces:**
- Produces:
  - **Hakem tarafı olayları:**
    - `sealed class HostEvent`
    - `ClientJoined(String connId)`
    - `ClientLeft(String connId)`
    - `HostReceived(String connId, String message)`
  - `abstract interface class HostTransport { Stream<HostEvent> get events; void send(String connId, String message); }`. Bilinmeyen bir `connId`'ye gönderilen mesaj sessizce atılır.
  - **İstemci tarafı olayları:**
    - `sealed class ClientEvent`
    - `LinkUp()`
    - `LinkDown()`
    - `ClientReceived(String message)`
  - `abstract interface class ClientTransport { Stream<ClientEvent> get events; void send(String message); }`
  - `class MemoryHub implements HostTransport`
    - `MemoryClient connect()`: Yeni bir `connId` üretir (`m1`, `m2`, ...). Hakem tarafına `ClientJoined`, istemci tarafına `LinkUp` gönderir.
    - `void drop(MemoryClient c)`: Bağlantıyı koparır. Hakem tarafına `ClientLeft`, istemci tarafına `LinkDown` gönderir.
    - `void reconnect(MemoryClient c)`: Aynı istemciye yeni bir `connId` verir ve bağlantı olaylarını yeniden gönderir.
    - `List<(String connId, String message)> get sentLog`: Hakemin her `send` çağrısının kaydı. Gizlilik testleri bunu kullanır.
  - `class MemoryClient implements ClientTransport`: `String get connId`, `bool get isUp`. Kopukken gönderilen mesajlar atılır.
  - Bütün akışlar `StreamController.broadcast(sync: true)` ile kurulur. Bu sayede testler `await` kullanmadan sıralı ve deterministik çalışır.
  - `class MergedHostTransport implements HostTransport`
    - `MergedHostTransport(Map<String, HostTransport> parts)`: Her parçanın `connId` değerinin başına `'<anahtar>:'` öneki eklenir. `send` çağrısı öneke bakarak mesajı doğru parçaya yönlendirir.
    - Plan 4'te BLE hakemi ile hakemin kendi oyuncusu bu sınıfla birleştirilecek.

- [ ] **Adım 1: Başarısız testi yaz.** Test şu davranışları kontrol etmeli:
  - **Bağlanma:** `connect` çağrıldığında hakem `ClientJoined('m1')`, istemci `LinkUp` alır.
  - **İstemciden hakeme:** `client.send('x')` çağrısı hakemde `HostReceived('m1','x')` olarak görünür.
  - **Hakemden istemciye:** `hub.send('m1','y')` çağrısı istemcide `ClientReceived('y')` olarak görünür ve `sentLog` içine `('m1','y')` eklenir.
  - **Kopma:** `drop` sonrası hakem `ClientLeft('m1')`, istemci `LinkDown` alır. Kopuk istemcinin gönderdiği mesaj hakeme ulaşmaz.
  - **Yeniden bağlanma:** `reconnect` sonrası `connId == 'm2'` olur.
  - **`MergedHostTransport`:** İki hub `'a'` ve `'b'` anahtarlarıyla birleştirilir. Olay `'b:m1'` adıyla gelir ve `send('b:m1', ...)` yalnızca `'b'` hub'ının istemcisine ulaşır.
- [ ] **Adım 2:** FAIL → **Adım 3:** uygula → **Adım 4:** PASS
- [ ] **Adım 5: Commit** `feat(net_core): taşıyıcı arayüzleri, MemoryHub, MergedHostTransport`

---

### Görev 6: `GameHost` — lobi ve oyunu başlatma

**Files:**
- Create: `lib/src/host_config.dart`, `lib/src/game_host.dart`
- Test: `test/host_lobby_test.dart`, `test/support/harness.dart`

**Interfaces:**
- Consumes: Görev 1-5. `GameEngine`, `GameState`, `PlayerInfo`, `PlayerStatus` (game_core).
- Produces:
  - `class HostConfig`
    - `const HostConfig({this.turnDuration = const Duration(seconds: 45), this.moveGrace = const Duration(milliseconds: 500), this.reconnectWindow = const Duration(minutes: 2), this.voteDuration = const Duration(seconds: 15), this.chatMaxLength = 120, this.maxPlayers = 4})`
  - `class GameHost`
    - `GameHost({required HostTransport transport, required GameEngine engine, required Scheduler scheduler, required Random random, required String hostPlayerId, HostConfig config = const HostConfig()})`. Oda kodu `random` ile üretilen 4 haneli bir sayıdır (`'0000'` ile `'9999'` arası, başında sıfır olabilir).
    - `String get roomCode`
    - `List<PlayerInfo> get lobbyPlayers`
    - `GameState? get state`
    - `List<String> get suggestions`
    - `void Function(Map<String, dynamic> snapshot)? onPersist`
    - `void Function(String word)? onSuggestion`
    - `void startGame()`: Lobide 2'den az oyuncu varsa ya da oyun zaten başlamışsa `StateError` fırlatır.
    - `Map<String, dynamic> toJson()`
    - `factory GameHost.restore({required Map<String, dynamic> snapshot, required HostTransport transport, required GameEngine engine, required Scheduler scheduler, required Random random, HostConfig config})`
    - `void dispose()`

**Lobi kuralları:**
- **Sürüm kontrolü:** `Hello.protocol != protocolVersion` ise `JoinRejected(versionMismatch)` gönderilir.
- **Yeni oyuncu:** Lobi doluysa (`maxPlayers`) `JoinRejected(roomFull)` gönderilir. Doğru değilse oyuncu lobiye eklenir, bağlantı `connId → playerId` olarak eşlenir, ona `Welcome` gönderilir ve herkese `LobbyMsg` yayınlanır.
- **Aynı oyuncu yeniden gelirse:** Lobide aynı `playerId` ile yeni bir `Hello` gelirse eski eşleme bırakılır ve yeni `connId` kullanılır.
- **Lobide kopma:** `ClientLeft` gelir ve o oyuncunun **güncel** bağlantısı buysa oyuncu lobiden çıkarılır ve `LobbyMsg` yayınlanır. Hakemin kendi oyuncusu (`hostPlayerId`) da aynı yoldan, yani bir `Hello` ile katılır.
- **Oyun başladıktan sonra yeni oyuncu:** Lobide olmayan bir `playerId` ile gelen `Hello` → `JoinRejected(gameStarted)`.
- **`startGame`:** `engine.start(lobbyPlayers)` çağrılır, her oyuncuya kendi `StateMsg`'ı gönderilir, hamle zamanlayıcısı başlatılır (Görev 7) ve `onPersist` çağrılır.
- **Eşlemesi olmayan bağlantı:** `Hello` göndermemiş bir `connId`'den gelen bütün mesajlar ve çözülemeyen mesajlar yok sayılır.

`test/support/harness.dart`:
- `Harness({int players = 2})`: Bir `MemoryHub`, bir `FakeScheduler`, `Random(1)`, küçük bir sözlükle kurulmuş bir `GameEngine` ve bir `GameHost` oluşturur. Sözlükte 2 harfli bütün birleşimler ve `KALEM` bulunur, `jokerChance` değeri 0'dır.
- `TestClient join(String id)`: `MemoryClient` + gelen mesajları çözüp listeleyen `inbox` + `send(NetMessage)`.

- [ ] **Adım 1: Başarısız testleri yaz.** Testler şu senaryoları kapsamalı:
  - **Katılma:** İki istemci katılır. Her biri `Welcome` alır, son `LobbyMsg`'da 2 oyuncu bulunur ve oda kodu 4 haneli bir sayıdır.
  - **Dolu oda:** Beşinci istemci `JoinRejected(roomFull)` alır.
  - **Sürüm uyumsuzluğu:** `protocol: 2` gönderen istemci `JoinRejected(versionMismatch)` alır.
  - **Lobide kopma:** `drop` sonrası `LobbyMsg`'da 1 oyuncu kalır.
  - **Başlatma:** Tek oyuncuyla `startGame` çağrısı `StateError` fırlatır. İki oyuncuyla çağrıldığında her istemci bir `StateMsg` alır, mesajdaki `myHand` 8 harf içerir ve `onPersist` bir kez çağrılır.
  - **Geç katılım:** Oyun başladıktan sonra gelen yeni `playerId` `JoinRejected(gameStarted)` alır.
  - **Kimliksiz bağlantı:** `Hello` göndermemiş bir bağlantıdan gelen `SwapAllMsg` durumu değiştirmez. `decodeMessage` sonucu `null` olan metinler yok sayılır.
- [ ] **Adım 2:** FAIL → **Adım 3:** uygula → **Adım 4:** PASS
- [ ] **Adım 5: Commit** `feat(net_core): GameHost lobi ve başlatma`

---

### Görev 7: `GameHost` — hamleler ve süre

**Files:**
- Modify: `lib/src/game_host.dart`
- Test: `test/host_turns_test.dart`

**Kurallar:**
- **Hamle zamanlayıcısı:** Her yeni sırada `deadline = now + turnDuration` ayarlanır. Zamanlayıcı `deadline + moveGrace` anında çalışır ve `engine.timeout` çağırır.
- **Sıra değişimi:** Sıra her değiştiğinde zamanlayıcı yeniden kurulur. Sıranın değiştiği `(round, turnIndex)` ikilisi ya da `finished` alanı değiştiğinde anlaşılır. Oyun bittiğinde zamanlayıcı iptal edilir.
- **Beklemede zamanlayıcı:** Bağlı oyuncu kalmadığında `engine.timeout` durumu değiştirmez. Bu durumda zamanlayıcı yeniden kurulmaz, oyun bekler.
- **`MoveMsg` ve `SwapAllMsg`:** Gönderenin `playerId`'siyle motora iletilir. Hamlenin sonucu göndericiye `MoveResultMsg` olarak döner. Kabul edilen hamle için `points = score.total`, reddedilen hamle için `points = 0` ve ret nedenleri gönderilir. `SwapAllMsg` için hamle sırası gönderende değilse `MoveResultMsg(false, 0, [NotYourTurn()])` döner.
- **Değişiklik bildirimi:** Kabul edilen her hamleden, `swapAll`'dan ve `timeout`'tan sonra herkese kendi `StateMsg`'ı yayınlanır ve `onPersist` çağrılır.
- **Kalan süre:** `remainingMs = max(0, deadline - now)`.
- **Reddedilen hamle:** Zamanlayıcıya dokunulmaz.

- [ ] **Adım 1: Başarısız testleri yaz.** Testler `Harness` ile 2 oyuncu üzerinde kurulur, sıradaki oyuncu `h.host.state!.current.id` ile bulunur:
  - **Kabul edilen hamle:** Sıradaki oyuncu elindeki bir harfi başlangıç kelimesinin bir harfinin altına koyar, örneğin `KALEM` içindeki A'nın altına (6,4). Sözlük 2 harfli bütün birleşimleri içerdiği için hamle geçerlidir. Oyuncu `MoveResultMsg(accepted: true)` alır, iki istemci de yeni bir `StateMsg` alır ve `currentPlayerId` değişir.
  - **Reddedilen hamle:** Sırası olmayan oyuncu `MoveResultMsg(false, 0, [NotYourTurn()])` alır.
  - **Süre dolması:** `advance(45 sn)` sonrası sıra değişmemiştir. Ardından `advance(500 ms)` sonrası sıra değişir ve yeni `StateMsg`'da `remainingMs == 45000` olur.
  - **Süre payı:** `advance(45 sn + 499 ms)` anında gönderilen hamle kabul edilir. Başka bir oyunda `advance(45 sn + 500 ms)` sonra gönderilen hamle `NotYourTurn` alır.
  - **Reddedilen hamle süreyi sıfırlamaz:** 30 sn sonra reddedilen bir hamle zamanlayıcıyı sıfırlamaz. `advance(15 sn + 500 ms)` sonra sıra değişir.
  - **Hepsini yenile:** `SwapAllMsg` sonrası `currentPlayerId` değişir ve gönderenin puanı aynı kalır.
  - **Oyun sonu:** 2 oyuncunun her biri 5 kez `timeout` yaşarsa (`advance(45,5 sn)` × 10) son `StateMsg`'da `finished == true` olur. Bir sonraki `advance(1 dk)` yeni bir mesaj üretmez.
- [ ] **Adım 2:** FAIL → **Adım 3:** uygula → **Adım 4:** PASS
- [ ] **Adım 5: Commit** `feat(net_core): GameHost hamle ve süre yönetimi`

---

### Görev 8: `GameHost` — kopma, yeniden bağlanma ve geri yükleme

**Files:**
- Modify: `lib/src/game_host.dart`
- Test: `test/host_reconnect_test.dart`

**Kurallar:**
- **Oyun sırasında kopma:** `ClientLeft` gelir ve o oyuncunun **güncel** bağlantısı buysa `engine.setStatus(disconnected)` çağrılır. `reconnectWindow` için bir zamanlayıcı kurulur. Süre dolarsa `engine.setStatus(left)` çağrılır. Her iki durumda da durum yayınlanır ve `onPersist` çağrılır.
- **Eski bağlantının kopması:** Oyuncunun güncel olmayan, eski bir bağlantısı koparsa hiçbir şey yapılmaz.
- **Geri dönüş:** Pencere içinde aynı `playerId` ile `Hello` gelirse kopma zamanlayıcısı iptal edilir. Ardından eşleme güncellenir, `setStatus(connected)` çağrılır, `Welcome` gönderilir ve durum herkese yayınlanır.
- **Ayrılmış oyuncu:** `left` durumundaki bir oyuncu `Hello` gönderirse `JoinRejected(playerLeft)` alır.
- **`toJson()`:** `{ 'roomCode', 'hostPlayerId', 'lobby': [PlayerInfo...], 'state': GameState.toJson() | null, 'suggestions': [...] }`
- **`GameHost.restore`:** Kaydedilmiş durumu yükler. `hostPlayerId` dışındaki ve `left` olmayan bütün oyuncular `disconnected` sayılır ve her biri için yeniden bağlanma penceresi başlatılır. Hamle zamanlayıcısı baştan kurulur.

- [ ] **Adım 1: Başarısız testleri yaz.** Testler 3 oyuncu üzerinde kurulur:
  - **Kopma:** `drop(p2)` sonrası p2'nin durumu `disconnected` olur.
  - **Pencere içinde dönüş:** `advance(1 dk)` sonra `reconnect(p2)` ve yeniden `Hello` gönderilir. p2'nin durumu `connected` olur, eli kopmadan önceki eliyle aynıdır ve `StateMsg` alır.
  - **Pencere dolunca:** `drop(p3)` sonra `advance(2 dk)` → p3 `left` olur. Sonrasında p3'ün gönderdiği `Hello` `JoinRejected(playerLeft)` alır.
  - **Sırası gelmişken kopma:** Sıradaki oyuncu koparsa sıra hemen sonraki oyuncuya geçer.
  - **Eski bağlantı (Review Focus 2):** p2 için ikinci bir `MemoryClient` bağlanıp aynı `Hello`'yu gönderir, ardından birinci bağlantı `drop` edilir. p2 `connected` kalır ve `StateMsg` yalnızca yeni bağlantıya gider (`sentLog` ile kontrol edilir).
  - **Geri yükleme:** `GameHost.restore(snapshot: host.toJson(), ...)` yeni bir hub üzerinde çalıştırılır. Hakem dışındaki oyuncular `disconnected` olur. p2 2 dakika içinde bağlanırsa eli eskisiyle aynıdır. Bağlanmayan p3 2 dakika sonra `left` olur.
- [ ] **Adım 2:** FAIL → **Adım 3:** uygula → **Adım 4:** PASS
- [ ] **Adım 5: Commit** `feat(net_core): kopma, yeniden bağlanma ve geri yükleme`

---

### Görev 9: `GameHost` — sohbet ve oylama

**Files:**
- Modify: `lib/src/game_host.dart`
- Test: `test/host_chat_vote_test.dart`

**Sohbet kuralları:**
- `ChatMsg` gelince metin baştan ve sondan kırpılır. Boş kalırsa yok sayılır.
- `chatMaxLength` karakterden uzunsa ilk 120 karaktere indirilir. Kırpma karakter (rune) bazında yapılır, böylece emojiler bölünmez.
- Herkese `ChatMsg(gönderenin playerId'si, metin)` yayınlanır, gönderen dahil. Sohbet lobide de oyun sırasında da çalışır.

**Oylama kuralları:**
- Hakem her oyuncu için, o oyuncunun **bu sıradaki** son reddedilen hamlesinden gelen `UnknownWords` listesini tutar. Sıra değişince bu liste temizlenir.
- **Öneri kabulü:** `ProposeWordMsg(word)` ancak şu üç koşul birlikte sağlanırsa kabul edilir: kelime bu listede olmalı, o anda başka oylama yapılmıyor olmalı ve gönderen sıradaki oyuncu olmalı. Koşullardan biri sağlanmazsa mesaj yok sayılır.
- **Oy verenler:** Önereni dışarıda bırakan, `connected` durumundaki oyuncular. Oy veren yoksa oylama hemen `accepted: false` sonucuyla biter.
- **Oylamanın başlaması:** Herkese `VoteStartMsg(voteId, word, proposerId, durationMs: 15000)` gönderilir. `voteId` artan bir sayıdır: `'v1'`, `'v2'`, ...
- **Oy toplama:** Yalnızca oy verenlerin ilk oyu sayılır. Herkes oy verdiğinde ya da süre dolduğunda oylama biter. Kabul koşulu `evet × 2 > oy veren sayısı`. Oy vermeyen ya da oylama sırasında kopan oyuncu "hayır" sayılır.
- **Sonuç:** Kabul edilirse kelime `suggestions` listesine eklenir (zaten varsa tekrar eklenmez) ve `onSuggestion` çağrılır. Herkese `VoteResultMsg` gönderilir.
- **Süre:** Oylama hamle zamanlayıcısını durdurmaz.

- [ ] **Adım 1: Başarısız testleri yaz.** Testler 3 oyuncu üzerinde kurulur ve sözlük `{AT, KALEM}` içerir:
  - **Sohbet:** `'  selam  '` metni herkese `'selam'` olarak gider. `'   '` hiç gönderilmez. 130 karakterlik metin 120 karaktere kırpılır. Lobide de sohbet çalışır.
  - **Oylama kabulü:** Sıradaki oyuncu `AZ` oluşturan bir hamle dener ve `UnknownWords(['AZ'])` alır. Ardından `ProposeWordMsg('AZ')` gönderir. Diğer iki oyuncu `VoteStartMsg` alır. İkisi de evet derse `VoteResultMsg(accepted: true)` gelir, `host.suggestions == ['AZ']` olur ve `onSuggestion('AZ')` çağrılır.
  - **Çoğunluk sağlanmazsa:** Bir evet ve bir hayır → `accepted: false`.
  - **Süre dolması:** Bir evet gelir, ardından `advance(15 sn)` → `accepted: false`, çünkü 1 × 2 > 2 değil.
  - **Reddedilen öneriler (Review Focus 5):** Listede olmayan bir kelime ya da oylama sürerken gönderilen ikinci bir öneri `VoteStartMsg` üretmez.
  - **Oylama sırasında kopma (Review Focus 5):** Oy verenlerden biri koparsa ve diğeri evet derse sonuç `accepted: false` olur.
- [ ] **Adım 2:** FAIL → **Adım 3:** uygula → **Adım 4:** PASS
- [ ] **Adım 5: Commit** `feat(net_core): sohbet ve kelime öneri oylaması`

---

### Görev 10: `ClientSession`

**Files:**
- Create: `lib/src/client_session.dart`
- Test: `test/client_session_test.dart`

**Interfaces:**
- Consumes: `ClientTransport`, `Scheduler`, mesajlar, `PlayerView`
- Produces:
  - `enum ClientPhase { connecting, lobby, playing, rejected, hostLost, ended }`
  - `class ClientSession`
    - `ClientSession({required ClientTransport transport, required Scheduler scheduler, required PlayerInfo me, Duration hostWait = const Duration(minutes: 2)})`
    - Durum alanları: `ClientPhase phase`, `LobbyMsg? lobby`, `PlayerView? view`, `List<ChatMsg> chat`, `VoteStartMsg? activeVote`, `VoteResultMsg? lastVoteResult`, `MoveResultMsg? lastMoveResult`, `JoinRejectCode? rejectCode`, `bool endedByHostLoss`
    - `int get remainingMs`: `view.remainingMs - (now - view'in alındığı an)`, en az 0.
    - `Stream<void> get changes`: Her durum değişikliğinde bir olay yayar (senkron yayın).
    - Komutlar: `void submitMove(Map<Pos, Tile> placements)`, `void swapAll()`, `void sendChat(String text)`, `void proposeWord(String word)`, `void vote(bool yes)`. `vote`, o anda bir oylama yoksa hiçbir şey yapmaz.
    - `void dispose()`

**Davranış:**
- **Bağlanma:** `LinkUp` gelince `Hello(me, protocol: protocolVersion)` gönderilir.
- **Gelen mesajlar:**
  - `Welcome` → `phase = lobby`. Durum (`view`) daha önceden varsa `playing`.
  - `LobbyMsg` → `lobby` güncellenir.
  - `StateMsg` → `view` güncellenir ve `phase = playing`. Oyun bittiyse (`view.finished`) `ended`.
  - `JoinRejected` → `phase = rejected`.
  - `VoteStartMsg` → `activeVote` ayarlanır, ancak öneren bu oyuncunun kendisiyse ayarlanmaz.
  - `VoteResultMsg` → `activeVote = null`, `lastVoteResult` ayarlanır.
  - `ChatMsg` → sohbet listesine eklenir.
- **Hakem kaybı:** Oyun sırasında (`playing`) `LinkDown` gelirse `phase = hostLost` olur ve `hostWait` için bir zamanlayıcı kurulur. Süre dolarsa `phase = ended` ve `endedByHostLoss = true`. Süre içinde `LinkUp` gelirse yeniden `Hello` gönderilir ve `Welcome` gelince zamanlayıcı iptal edilir.
- **Lobide kopma:** Lobideyken `LinkDown` gelirse `phase = connecting` olur.

- [ ] **Adım 1: Başarısız testleri yaz.** Testler `MemoryHub` ve gerçek bir `GameHost` ile kurulur:
  - **Katılma:** `connect` → `Hello` gönderilir → `phase == lobby` ve `lobby.players` sayısı 1.
  - **Başlatma:** `startGame` sonrası `phase == playing` ve `view.myHand` 8 harf içerir.
  - **Kalan süre:** `advance(10 sn)` sonra `remainingMs == 35000`.
  - **Hamle sonucu:** `submitMove` sonrası `lastMoveResult` dolar.
  - **Hakem kaybı:** `drop` → `phase == hostLost`. `advance(2 dk)` → `ended` ve `endedByHostLoss == true`.
  - **Hakem geri gelirse:** `drop` sonra `advance(1 dk)` sonra `reconnect` → `phase == playing`. Ardından `advance(2 dk)` sonra da `ended` olmaz.
  - **Ret:** `JoinRejected` alan oturumun `phase` değeri `rejected` olur ve `rejectCode` dolar.
  - **Oylama:** Önerenin kendi oturumunda `activeVote == null`, diğer oyuncularınkinde dolu.
- [ ] **Adım 2:** FAIL → **Adım 3:** uygula → **Adım 4:** PASS
- [ ] **Adım 5: Commit** `feat(net_core): ClientSession`

---

### Görev 11: Uçtan uca maç simülasyonu

**Files:**
- Test: `test/match_simulation_test.dart`

- [ ] **Adım 1: Testi yaz.**
  - **Kurulum:** 2, 3 ve 4 oyunculu toplam 300 maç, seed 0-299. Her maçta bir `MemoryHub`, bir `FakeScheduler`, bir `GameHost` ve her oyuncu için bir `ClientSession` kurulur. Oyunculardan biri hakemin kendisidir (`hostPlayerId`).
  - **Bot döngüsü:** Her adımda sırası gelen oyuncunun **istemci oturumu** yalnızca `view` bilgisine bakarak oynar:
    - %60: Elindeki bir harfi tahtadaki rastgele bir harfin boş komşu karesine koyar (2 harfli sözlük).
    - %15: `swapAll`.
    - %10: Bir şey yapmaz ve süre dolana kadar zaman ilerletilir.
    - %10: Hakem olmayan rastgele bir oyuncu `drop` edilir. Sonra %50 ihtimalle 1 dakika içinde `reconnect` edilir.
    - %5: Sohbet mesajı gönderir.
    - Her adımdan sonra `advance(1 sn)`.
  - **Değişmezler:**
    - **Gizlilik:** `sentLog` içindeki her `StateMsg` yalnızca kendi alıcısının elini içerir. Kontrol yöntemi: mesaj çözülür ve `myHand`, hakemin o andaki `state` bilgisindeki alıcının eliyle karşılaştırılır. Diğer oyuncuların elleri sadece `handCount` olarak görünür.
    - **Tutarlılık:** Her oturumun `view` bilgisi, hakemin durumundan o oyuncu için `viewFor` ile üretilecek görünümle aynıdır. `remainingMs` alanı bu karşılaştırmanın dışında tutulur.
    - **Bitiş:** Maç en fazla 10.000 adımda biter. Bütün bağlı oturumların `phase` değeri `ended` olur ve `view.winners == winnerIds(host.state!)`.
- [ ] **Adım 2:** `dart test test/match_simulation_test.dart` → PASS. Hata çıkarsa ilgili görevin testine kalıcı bir test eklenir.
- [ ] **Adım 3: Commit** `test(net_core): uçtan uca maç simülasyonu`

---

## Self-Review Notları

- **Spesifikasyonun kapsanması:**
  - §5.4: süre payı Görev 7'de.
  - §5.8: oylama Görev 9'da.
  - §5.9: sohbet Görev 9'da.
  - §5.10: oyuncu kopması Görev 8'de, hakem kopması Görev 10'da.
  - §7.2: tam durum gönderimi ve gizlilik Görev 4, 6 ve 11'de. `onPersist` ve `restore` Görev 8'de.
  - §7.3: mesaj tipleri Görev 3'te, sürüm uyumu Görev 6'da.
  - §7.4: parçalama Görev 2'de.
  - §9: `FakeTransport` yerine `MemoryHub` kullanılıyor (Görev 5). Simülasyon Görev 11'de.
- **Bu planda olmayanlar:**
  - BLE reklam yayını ve GATT → Plan 3.
  - Durumun diske yazılması (`onPersist` geri çağrısının dosyaya bağlanması) ve öneri listesinin "Paylaş" düğmesi → Plan 4.
  - Spesifikasyonun §5.1'indeki rastgele oturma sırası `GameEngine.start`'ta zaten var.
- **Görev sırası:** Görev 3'teki `StateMsg` mesajı Görev 4'teki `PlayerView`'a bağımlı. Bu yüzden uygulama sırası 1, 2, 4, 3, 5, ... olmalı.
- **İsim tutarlılığı:** `HostReceived`, `ClientReceived`, `MoveResultMsg(accepted, points, reasons)`, `JoinRejectCode` ve `PlayerView.currentPlayerId` bütün görevlerde aynı isimlerle kullanıldı.
