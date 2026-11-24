import 'package:net_core/net_core.dart';
import 'package:net_core/testing.dart';
import 'package:test/test.dart';

String describe(Object e) => switch (e) {
      ClientJoined(:final connId) => 'joined $connId',
      ClientLeft(:final connId) => 'left $connId',
      HostReceived(:final connId, :final message) => 'recv $connId $message',
      LinkUp() => 'up',
      LinkDown() => 'down',
      ClientReceived(:final message) => 'got $message',
      _ => '?',
    };

void main() {
  test('MemoryHub bağlanma, iki yönlü mesaj, kopma, yeniden bağlanma', () {
    final hub = MemoryHub();
    final hostLog = <String>[];
    hub.events.listen((e) => hostLog.add(describe(e)));

    final c = hub.connect();
    final clientLog = <String>[];
    c.events.listen((e) => clientLog.add(describe(e)));
    // connect olayları dinleyici eklenmeden önce yayınlanır; istemci durumu isUp ile okunur
    expect(c.isUp, isTrue);
    expect(c.connId, 'm1');

    c.send('x');
    hub.send('m1', 'y');
    expect(hostLog, ['joined m1', 'recv m1 x']);
    expect(clientLog, ['got y']);
    expect(hub.sentLog, [('m1', 'y')]);

    hub.drop(c);
    expect(c.isUp, isFalse);
    c.send('kayıp');
    hub.send('m1', 'kayıp');
    expect(hostLog.last, 'left m1');
    expect(clientLog.last, 'down');
    expect(clientLog.where((l) => l.contains('kayıp')), isEmpty);

    hub.reconnect(c);
    expect(c.connId, 'm2');
    expect(clientLog.last, 'up');
    expect(hostLog.last, 'joined m2');
  });

  test('MergedHostTransport önek ekler ve doğru parçaya yönlendirir', () {
    final a = MemoryHub();
    final b = MemoryHub();
    final merged = MergedHostTransport({'a': a, 'b': b});
    final log = <String>[];
    merged.events.listen((e) => log.add(describe(e)));

    final cb = b.connect();
    final ca = a.connect();
    final gotA = <String>[];
    final gotB = <String>[];
    ca.events.listen((e) => gotA.add(describe(e)));
    cb.events.listen((e) => gotB.add(describe(e)));

    cb.send('merhaba');
    merged.send('b:m1', 'cevap');
    merged.send('yok:m1', 'kaybolur');
    expect(log, ['joined b:m1', 'joined a:m1', 'recv b:m1 merhaba']);
    expect(gotB, ['got cevap']);
    expect(gotA, isEmpty);
  });
}
