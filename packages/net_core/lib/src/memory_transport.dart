import 'dart:async';
import 'dart:collection';

import 'transport.dart';

/// Bellek içi hakem taşıyıcısı: testlerde ve hakemin kendi oyuncusu için.
///
/// Bütün teslimatlar tek bir kuyruktan sırayla ve senkron yapılır: bir olay
/// işleyicisinin içinden gönderilen mesaj, o işleyici döndükten hemen sonra
/// (aynı çağrı içinde) teslim edilir. Böylece iç içe yayın yüzünden olaylar
/// mikro göreve ertelenmez.
class MemoryHub implements HostTransport {
  final _events = StreamController<HostEvent>.broadcast(sync: true);
  final Map<String, MemoryClient> _byConn = {};
  final List<(String, String)> _sentLog = [];
  final Queue<void Function()> _queue = Queue();
  bool _draining = false;
  int _next = 1;

  @override
  Stream<HostEvent> get events => _events.stream;

  /// Hakemin her `send` çağrısının kaydı (bağlantı kopuk olsa bile).
  List<(String connId, String message)> get sentLog => List.unmodifiable(_sentLog);

  MemoryClient connect() {
    final c = MemoryClient._(this);
    _attach(c);
    return c;
  }

  void drop(MemoryClient c) {
    if (!c._up) return;
    final connId = c._connId;
    _byConn.remove(connId);
    c._up = false;
    _deliver(() => _events.add(ClientLeft(connId)));
    _deliver(() => c._events.add(const LinkDown()));
  }

  void reconnect(MemoryClient c) {
    drop(c);
    _attach(c);
  }

  void _attach(MemoryClient c) {
    final connId = 'm${_next++}';
    c._connId = connId;
    c._up = true;
    _byConn[connId] = c;
    _deliver(() => _events.add(ClientJoined(connId)));
    _deliver(() => c._events.add(const LinkUp()));
  }

  @override
  void send(String connId, String message) {
    _sentLog.add((connId, message));
    final c = _byConn[connId];
    if (c != null) _deliver(() => c._events.add(ClientReceived(message)));
  }

  void _deliver(void Function() fn) {
    _queue.add(fn);
    if (_draining) return;
    _draining = true;
    try {
      while (_queue.isNotEmpty) {
        _queue.removeFirst()();
      }
    } finally {
      _draining = false;
    }
  }
}

class MemoryClient implements ClientTransport {
  final MemoryHub _hub;
  final _events = StreamController<ClientEvent>.broadcast(sync: true);
  String _connId = '';
  bool _up = false;

  MemoryClient._(this._hub);

  String get connId => _connId;

  @override
  bool get isUp => _up;

  @override
  Stream<ClientEvent> get events => _events.stream;

  @override
  void send(String message) {
    if (!_up) return;
    final connId = _connId;
    _hub._deliver(() => _hub._events.add(HostReceived(connId, message)));
  }
}
