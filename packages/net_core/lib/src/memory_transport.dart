import 'dart:async';

import 'transport.dart';

/// Bellek içi hakem taşıyıcısı: testlerde ve hakemin kendi oyuncusu için.
/// Bütün olaylar senkron teslim edilir.
class MemoryHub implements HostTransport {
  final _events = StreamController<HostEvent>.broadcast(sync: true);
  final Map<String, MemoryClient> _byConn = {};
  final List<(String, String)> _sentLog = [];
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
    _byConn.remove(c._connId);
    c._up = false;
    _events.add(ClientLeft(c._connId));
    c._events.add(const LinkDown());
  }

  void reconnect(MemoryClient c) {
    drop(c);
    _attach(c);
  }

  void _attach(MemoryClient c) {
    c._connId = 'm${_next++}';
    c._up = true;
    _byConn[c._connId] = c;
    _events.add(ClientJoined(c._connId));
    c._events.add(const LinkUp());
  }

  @override
  void send(String connId, String message) {
    _sentLog.add((connId, message));
    _byConn[connId]?._events.add(ClientReceived(message));
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
    _hub._events.add(HostReceived(_connId, message));
  }
}
