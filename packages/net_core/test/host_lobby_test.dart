import 'package:net_core/net_core.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

void main() {
  test('katılım: Welcome ve lobi, 4 haneli oda kodu', () {
    final h = Harness();
    final a = h.join('p1');
    final b = h.join('p2');
    expect(a.last<Welcome>(), const Welcome('p1'));
    expect(b.last<Welcome>(), const Welcome('p2'));
    final lobby = a.last<LobbyMsg>();
    expect(lobby.players.map((p) => p.id), ['p1', 'p2']);
    expect(lobby.hostId, 'p1');
    expect(lobby.roomCode, matches(RegExp(r'^\d{4}$')));
    expect(h.host.roomCode, lobby.roomCode);
  });

  test('beşinci oyuncu reddedilir', () {
    final h = Harness();
    for (var i = 1; i <= 4; i++) {
      h.join('p$i');
    }
    final e = h.join('p5');
    expect(e.last<JoinRejected>(), const JoinRejected(JoinRejectCode.roomFull));
    expect(h.host.lobbyPlayers, hasLength(4));
  });

  test('protokol uyuşmazlığı reddedilir', () {
    final h = Harness();
    final c = h.join('p1', protocol: 2);
    expect(c.last<JoinRejected>(), const JoinRejected(JoinRejectCode.versionMismatch));
    expect(h.host.lobbyPlayers, isEmpty);
  });

  test('lobide kopan oyuncu çıkar', () {
    final h = Harness();
    final a = h.join('p1');
    final b = h.join('p2');
    h.hub.drop(b.link);
    expect(a.last<LobbyMsg>().players.map((p) => p.id), ['p1']);
  });

  test('startGame: tek oyuncuyla hata, iki oyuncuyla durum dağıtılır', () {
    final h = Harness();
    final a = h.join('p1');
    expect(h.host.startGame, throwsStateError);
    final b = h.join('p2');
    h.host.startGame();
    expect(a.last<StateMsg>().view.myHand, hasLength(8));
    expect(b.last<StateMsg>().view.myHand, hasLength(8));
    expect(h.persistCount, 1);
    expect(h.host.startGame, throwsStateError);
  });

  test('oyun başladıktan sonra yeni oyuncu alınmaz', () {
    final h = Harness();
    h.startWith(2);
    final c = h.join('p9');
    expect(c.last<JoinRejected>(), const JoinRejected(JoinRejectCode.gameStarted));
  });

  test('Hello göndermemiş bağlantı ve bozuk mesaj yok sayılır', () {
    final h = Harness();
    h.startWith(2);
    final before = h.state;
    final anon = h.hub.connect();
    anon.send(encodeMessage(const SwapAllMsg()));
    anon.send('{bozuk');
    expect(identical(h.state, before), isTrue);
  });
}
