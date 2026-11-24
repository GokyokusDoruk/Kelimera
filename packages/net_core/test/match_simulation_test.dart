import 'dart:math';

import 'package:game_core/game_core.dart';
import 'package:net_core/net_core.dart';
import 'package:net_core/testing.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

/// Hakemin her gönderdiği durum mesajını, gönderildiği anda denetleyen sarmalayıcı.
class CheckingTransport implements HostTransport {
  final MemoryHub hub;
  final Map<String, MemoryClient> links;
  GameHost? host;
  int stateMessages = 0;

  CheckingTransport(this.hub, this.links);

  /// Bağlantının güncel connId'sinden oyuncuyu bulur (yeniden bağlanma aynı çağrıda olur).
  String _playerOf(String connId) =>
      links.entries.firstWhere((e) => e.value.isUp && e.value.connId == connId).key;

  @override
  Stream<HostEvent> get events => hub.events;

  @override
  void send(String connId, String message) {
    final m = decodeMessage(message);
    if (m is StateMsg) {
      stateMessages++;
      final id = _playerOf(connId);
      final hand = host!.state!.players.firstWhere((p) => p.id == id).hand;
      expect(m.view.myHand, hand, reason: 'alıcı $id kendi elini almalı');
      expect(message.contains('"hand"'), isFalse, reason: 'ham el alanı sızmamalı');
    }
    hub.send(connId, message);
  }
}

const _dirs = [Pos(0, 1), Pos(0, -1), Pos(1, 0), Pos(-1, 0)];

void playMatch(int seed) {
  final r = Random(seed);
  final n = 2 + seed % 3;
  final hub = MemoryHub();
  final sched = FakeScheduler();
  final links = <String, MemoryClient>{};
  final transport = CheckingTransport(hub, links);
  final host = GameHost(
    transport: transport,
    engine: GameEngine(
      dictionary: twoLetterDictionary(),
      letters: LetterTable.initial(),
      random: Random(seed),
    ),
    scheduler: sched,
    random: Random(seed),
    hostPlayerId: 'p0',
  );
  transport.host = host;

  final sessions = <String, ClientSession>{};
  for (var i = 0; i < n; i++) {
    final id = 'p$i';
    final link = hub.connect();
    links[id] = link;
    sessions[id] = ClientSession(
      transport: link,
      scheduler: sched,
      me: PlayerInfo(id: id, name: id, avatar: i),
    );
  }
  host.startGame();

  final reconnects = <(DateTime, String)>[];
  var steps = 0;
  while (!host.state!.finished) {
    expect(++steps, lessThan(10000), reason: 'seed $seed sonlanmadı');
    final s = host.state!;
    final cur = sessions[s.current.id]!;
    final roll = r.nextInt(100);
    if (roll < 60) {
      final v = cur.view!;
      final tiles = v.board.tiles.keys.toList();
      final target = tiles[r.nextInt(tiles.length)] + _dirs[r.nextInt(4)];
      final pick = v.myHand[r.nextInt(v.myHand.length)];
      final tile = pick == jokerSymbol
          ? Tile(trAlphabet[r.nextInt(trAlphabet.length)], isJoker: true)
          : Tile(pick);
      cur.submitMove({target: tile});
    } else if (roll < 75) {
      cur.swapAll();
    } else if (roll < 85) {
      sched.advance(const Duration(seconds: 46));
    } else if (roll < 95) {
      final candidates = [
        for (final e in links.entries)
          if (e.key != 'p0' && e.value.isUp) e.key,
      ];
      if (candidates.isNotEmpty) {
        final id = candidates[r.nextInt(candidates.length)];
        hub.drop(links[id]!);
        if (r.nextBool()) {
          reconnects.add((sched.now().add(Duration(seconds: r.nextInt(60))), id));
        }
      }
    } else {
      cur.sendChat('selam ${r.nextInt(100)}');
    }
    sched.advance(const Duration(seconds: 1));

    for (final rc in reconnects.where((e) => !e.$1.isAfter(sched.now())).toList()) {
      reconnects.remove(rc);
      final link = links[rc.$2]!;
      hub.reconnect(link);
    }

    // Tutarlılık: bağlı ve oyundaki her oturum hakemin durumunu görür.
    final now = host.state!;
    for (final e in sessions.entries) {
      final sess = e.value;
      if (!links[e.key]!.isUp || sess.phase == ClientPhase.rejected) continue;
      final v = sess.view!;
      final want = viewFor(now, e.key, remainingMs: v.remainingMs);
      final a = v.toJson()..remove('board');
      final b = want.toJson()..remove('board');
      expect(a, b, reason: 'seed $seed ${e.key}');
      expect(v.board, want.board, reason: 'seed $seed ${e.key} tahta');
    }
  }

  final winners = winnerIds(host.state!);
  for (final e in sessions.entries) {
    if (!links[e.key]!.isUp || e.value.phase == ClientPhase.rejected) continue;
    expect(e.value.phase, ClientPhase.ended, reason: 'seed $seed ${e.key}');
    expect(e.value.view!.winners, winners);
  }
  expect(transport.stateMessages, greaterThan(n));
  host.dispose();
}

void main() {
  test('300 maç: gizlilik, tutarlılık, bitiş', () {
    for (var seed = 0; seed < 300; seed++) {
      playMatch(seed);
    }
  });
}
