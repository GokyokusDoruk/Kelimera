import 'dart:async';
import 'dart:collection';

sealed class HostEvent {
  const HostEvent();
}

class ClientJoined extends HostEvent {
  final String connId;
  const ClientJoined(this.connId);
}

class ClientLeft extends HostEvent {
  final String connId;
  const ClientLeft(this.connId);
}

class HostReceived extends HostEvent {
  final String connId;
  final String message;
  const HostReceived(this.connId, this.message);
}

/// Hakem tarafı taşıyıcı. Bilinmeyen [connId]'ye gönderilen mesaj sessizce atılır.
abstract interface class HostTransport {
  Stream<HostEvent> get events;
  void send(String connId, String message);
}

sealed class ClientEvent {
  const ClientEvent();
}

class LinkUp extends ClientEvent {
  const LinkUp();
}

class LinkDown extends ClientEvent {
  const LinkDown();
}

class ClientReceived extends ClientEvent {
  final String message;
  const ClientReceived(this.message);
}

/// İstemci tarafı taşıyıcı.
abstract interface class ClientTransport {
  Stream<ClientEvent> get events;

  /// Bağlantı şu an açık mı (dinleyici `LinkUp`'tan sonra eklendiyse durumu buradan okur).
  bool get isUp;
  void send(String message);
}

/// Birden çok hakem taşıyıcısını tek taşıyıcı gibi gösterir; connId'lere `<anahtar>:` öneki ekler.
///
/// Olaylar bir kuyruktan sırayla yayınlanır: bir olay işlenirken bir parçadan gelen
/// yeni olay (örneğin hakemin kendi oyuncusunun senkron cevabı) kuyruğa girer ve
/// mevcut olay bittikten sonra aynı çağrı içinde yayınlanır.
class MergedHostTransport implements HostTransport {
  final Map<String, HostTransport> parts;
  final _controller = StreamController<HostEvent>.broadcast(sync: true);
  final Queue<HostEvent> _queue = Queue();
  bool _draining = false;

  MergedHostTransport(this.parts) {
    for (final e in parts.entries) {
      final p = '${e.key}:';
      e.value.events.listen((ev) => _emit(switch (ev) {
            ClientJoined(:final connId) => ClientJoined('$p$connId'),
            ClientLeft(:final connId) => ClientLeft('$p$connId'),
            HostReceived(:final connId, :final message) => HostReceived('$p$connId', message),
          }));
    }
  }

  void _emit(HostEvent e) {
    _queue.add(e);
    if (_draining) return;
    _draining = true;
    try {
      while (_queue.isNotEmpty) {
        _controller.add(_queue.removeFirst());
      }
    } finally {
      _draining = false;
    }
  }

  @override
  Stream<HostEvent> get events => _controller.stream;

  @override
  void send(String connId, String message) {
    final i = connId.indexOf(':');
    if (i < 0) return;
    parts[connId.substring(0, i)]?.send(connId.substring(i + 1), message);
  }
}
