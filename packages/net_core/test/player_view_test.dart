import 'dart:convert';

import 'package:game_core/game_core.dart';
import 'package:net_core/net_core.dart';
import 'package:test/test.dart';

import 'support/samples.dart';

void main() {
  test('kendi eli var, başkasınınki yok', () {
    final v = viewFor(sampleState(), 'p1', remainingMs: 30000);
    expect(v.myHand, ['A', '*', 'K', 'L', 'M', 'N', 'R', 'İ']);
    expect(v.players.map((p) => p.handCount), [8, 8]);
    expect(v.currentPlayerId, 'p1');
    expect(v.round, 3);
    expect(v.players[1].status, PlayerStatus.disconnected);
    final json = jsonEncode(v.toJson());
    expect(json.contains('"Ğ"'), isFalse);
    expect(json.contains('"Ç"'), isFalse);
  });

  test('JSON gidiş-dönüş ve kazananlar', () {
    final v = viewFor(sampleState().copyWith(finished: true), 'p2', remainingMs: 0);
    expect(PlayerView.fromJson(jsonDecode(jsonEncode(v.toJson())) as Map<String, dynamic>), v);
    expect(v.winners, ['p1']);
    expect(v.myHand, ['B', 'C', 'Ç', 'D', 'E', 'F', 'G', 'Ğ']);
  });

  test('oyun bitmeden kazanan yok, oyunda olmayanın eli boş', () {
    expect(sampleView().winners, isEmpty);
    expect(viewFor(sampleState(), 'yabancı', remainingMs: 0).myHand, isEmpty);
  });
}
