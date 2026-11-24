import 'dart:math';

import 'package:game_core/game_core.dart';
import 'package:net_core/net_core.dart';
import 'package:net_core/testing.dart';

/// Alfabedeki bütün 2 harfli birleşimler + başlangıç kelimesi KALEM.
Dictionary twoLetterDictionary() => Dictionary({
      for (final a in trAlphabet)
        for (final b in trAlphabet) '$a$b': 1,
      'KALEM': 2,
    });

class TestClient {
  final String id;
  final MemoryClient link;
  final List<NetMessage> inbox = [];

  TestClient(this.id, this.link) {
    link.events.listen((e) {
      if (e is ClientReceived) {
        final m = decodeMessage(e.message);
        if (m != null) inbox.add(m);
      }
    });
  }

  void send(NetMessage m) => link.send(encodeMessage(m));

  List<T> all<T>() => inbox.whereType<T>().toList();
  T last<T>() => inbox.whereType<T>().last;
  void hello({int protocol = protocolVersion}) =>
      send(Hello(PlayerInfo(id: id, name: id, avatar: 0), protocol: protocol));
}

class Harness {
  final MemoryHub hub = MemoryHub();
  final FakeScheduler sched = FakeScheduler();
  late final GameEngine engine;
  late GameHost host;
  int persistCount = 0;
  Map<String, dynamic>? lastSnapshot;
  final List<String> suggested = [];

  Harness({Dictionary? dictionary, int seed = 1}) {
    engine = GameEngine(
      dictionary: dictionary ?? twoLetterDictionary(),
      letters: LetterTable.initial(),
      random: Random(seed),
      jokerChance: 0,
    );
    host = GameHost(
      transport: hub,
      engine: engine,
      scheduler: sched,
      random: Random(seed),
      hostPlayerId: 'p1',
    );
    _wire();
  }

  void _wire() {
    host.onPersist = (s) {
      persistCount++;
      lastSnapshot = s;
    };
    host.onSuggestion = suggested.add;
  }

  /// Hakemi kaydedilmiş durumdan, yeni bir hub üzerinde yeniden kurar.
  Harness.restored(Harness old, this.engine) {
    host = GameHost.restore(
      snapshot: old.host.toJson(),
      transport: hub,
      engine: engine,
      scheduler: sched,
      random: Random(2),
    );
    _wire();
  }

  TestClient join(String id, {int protocol = protocolVersion}) {
    final c = TestClient(id, hub.connect());
    c.hello(protocol: protocol);
    return c;
  }

  /// p1..pn katılır ve oyun başlar.
  List<TestClient> startWith(int n) {
    final clients = [for (var i = 1; i <= n; i++) join('p$i')];
    host.startGame();
    return clients;
  }

  GameState get state => host.state!;

  TestClient current(List<TestClient> clients) =>
      clients.firstWhere((c) => c.id == state.current.id);

  PlayerState player(String id) => state.players.firstWhere((p) => p.id == id);
}
