import 'dart:async';
import 'dart:math';

import 'package:game_core/game_core.dart';

import 'host_config.dart';
import 'messages.dart';
import 'player_view.dart';
import 'scheduler.dart';
import 'transport.dart';

/// Hakem: oyunun tek doğru kaynağı. Taşıyıcıdan gelen mesajları işler,
/// her oyuncuya kendi görünümünü gönderir.
class GameHost {
  final HostTransport transport;
  final GameEngine engine;
  final Scheduler scheduler;
  final Random random;
  final HostConfig config;
  final String hostPlayerId;
  String _roomCode;

  final List<PlayerInfo> _lobby = [];
  final Map<String, String> _connToPlayer = {};
  final Map<String, String> _playerConn = {};
  final List<String> _suggestions = [];
  GameState? _state;
  DateTime? _deadline;
  Cancelable? _turnTimer;
  late final StreamSubscription<HostEvent> _sub;

  void Function(Map<String, dynamic> snapshot)? onPersist;
  void Function(String word)? onSuggestion;

  GameHost({
    required this.transport,
    required this.engine,
    required this.scheduler,
    required this.random,
    required this.hostPlayerId,
    this.config = const HostConfig(),
  }) : _roomCode = random.nextInt(10000).toString().padLeft(4, '0') {
    _sub = transport.events.listen(_onEvent);
  }

  factory GameHost.restore({
    required Map<String, dynamic> snapshot,
    required HostTransport transport,
    required GameEngine engine,
    required Scheduler scheduler,
    required Random random,
    HostConfig config = const HostConfig(),
  }) {
    final h = GameHost(
      transport: transport,
      engine: engine,
      scheduler: scheduler,
      random: random,
      hostPlayerId: snapshot['hostPlayerId'] as String,
      config: config,
    );
    h._roomCode = snapshot['roomCode'] as String;
    h._lobby.addAll([
      for (final p in (snapshot['lobby'] as List).cast<Map<String, dynamic>>()) PlayerInfo.fromJson(p),
    ]);
    h._suggestions.addAll(List<String>.from(snapshot['suggestions'] as List));
    final state = snapshot['state'];
    if (state != null) h._restoreState(GameState.fromJson(state as Map<String, dynamic>));
    return h;
  }

  String get roomCode => _roomCode;
  List<PlayerInfo> get lobbyPlayers => List.unmodifiable(_lobby);
  GameState? get state => _state;
  List<String> get suggestions => List.unmodifiable(_suggestions);

  Map<String, dynamic> toJson() => {
        'roomCode': _roomCode,
        'hostPlayerId': hostPlayerId,
        'lobby': [for (final p in _lobby) p.toJson()],
        'state': _state?.toJson(),
        'suggestions': _suggestions,
      };

  void startGame() {
    if (_state != null) throw StateError('Oyun zaten başladı');
    if (_lobby.length < 2) throw StateError('En az 2 oyuncu gerekir');
    _apply(engine.start(_lobby));
  }

  void dispose() {
    _sub.cancel();
    _turnTimer?.cancel();
  }

  // --- olaylar ---------------------------------------------------------------

  void _onEvent(HostEvent e) {
    switch (e) {
      case ClientJoined():
        break;
      case ClientLeft(:final connId):
        _onLeft(connId);
      case HostReceived(:final connId, :final message):
        final m = decodeMessage(message);
        if (m == null) return;
        if (m is Hello) {
          _onHello(connId, m);
          return;
        }
        final playerId = _connToPlayer[connId];
        if (playerId != null) _onMessage(playerId, m);
    }
  }

  void _onHello(String connId, Hello h) {
    if (h.protocol != protocolVersion) {
      _sendTo(connId, const JoinRejected(JoinRejectCode.versionMismatch));
      return;
    }
    final id = h.player.id;
    final s = _state;
    if (s == null) {
      final i = _lobby.indexWhere((p) => p.id == id);
      if (i < 0) {
        if (_lobby.length >= config.maxPlayers) {
          _sendTo(connId, const JoinRejected(JoinRejectCode.roomFull));
          return;
        }
        _lobby.add(h.player);
      } else {
        _lobby[i] = h.player;
      }
      _bind(connId, id);
      _sendTo(connId, Welcome(id));
      _broadcast(_lobbyMsg());
      return;
    }

    final p = s.players.where((p) => p.id == id).firstOrNull;
    if (p == null) {
      _sendTo(connId, const JoinRejected(JoinRejectCode.gameStarted));
      return;
    }
    _rejoin(connId, p);
  }

  /// Oyun sırasında bilinen bir oyuncunun yeniden bağlanması.
  void _rejoin(String connId, PlayerState p) {
    _bind(connId, p.id);
    _sendTo(connId, Welcome(p.id));
    _sendTo(connId, _lobbyMsg());
    _sendState(p.id);
  }

  void _onLeft(String connId) {
    final id = _connToPlayer.remove(connId);
    if (id == null) return; // eski (güncel olmayan) bağlantı ya da kimliksiz
    _playerConn.remove(id);
    if (_state == null) {
      _lobby.removeWhere((p) => p.id == id);
      _broadcast(_lobbyMsg());
    }
  }

  void _onMessage(String playerId, NetMessage m) {
    switch (m) {
      case MoveMsg(:final placements):
        _onMove(playerId, placements);
      case SwapAllMsg():
        _onSwapAll(playerId);
      case PingMsg():
        _sendToPlayer(playerId, const PongMsg());
      default:
        break;
    }
  }

  void _onMove(String playerId, Map<Pos, Tile> placements) {
    final s = _state;
    if (s == null) return;
    switch (engine.submitMove(s, playerId, placements)) {
      case MoveRejected(:final reasons):
        _onRejected(playerId, reasons);
        _sendToPlayer(playerId, MoveResultMsg(false, 0, reasons));
      case MoveAccepted(state: final next, :final score):
        _sendToPlayer(playerId, MoveResultMsg(true, score.total, const []));
        _apply(next);
    }
  }

  void _onSwapAll(String playerId) {
    final s = _state;
    if (s == null) return;
    if (s.finished) {
      _sendToPlayer(playerId, const MoveResultMsg(false, 0, [GameFinished()]));
    } else if (s.current.id != playerId) {
      _sendToPlayer(playerId, const MoveResultMsg(false, 0, [NotYourTurn()]));
    } else {
      _sendToPlayer(playerId, const MoveResultMsg(true, 0, []));
      _apply(engine.swapAll(s, playerId));
    }
  }

  /// Oylama için bu sıradaki reddedilen kelimeleri saklar (Görev 9).
  void _onRejected(String playerId, List<RejectReason> reasons) {}

  void _onTurnTimeout() {
    _turnTimer = null;
    final s = _state;
    if (s == null) return;
    final next = engine.timeout(s);
    if (identical(next, s)) {
      _deadline = null; // bağlı oyuncu yok: oyun bekler
      return;
    }
    _apply(next);
  }

  void _restartTurnTimer() {
    _turnTimer?.cancel();
    _turnTimer = null;
    final s = _state;
    if (s == null || s.finished) {
      _deadline = null;
      return;
    }
    _deadline = scheduler.now().add(config.turnDuration);
    _turnTimer = scheduler.after(config.turnDuration + config.moveGrace, _onTurnTimeout);
  }

  /// Sıra değiştiğinde (yeni tur/sıra ya da bitiş) çağrılır.
  void _onTurnChanged() {
    _restartTurnTimer();
  }

  // --- durum -----------------------------------------------------------------

  void _restoreState(GameState s) {
    _state = s;
  }

  void _apply(GameState next) {
    final prev = _state;
    if (identical(next, prev)) return;
    _state = next;
    final turnChanged = prev == null ||
        prev.round != next.round ||
        prev.turnIndex != next.turnIndex ||
        prev.finished != next.finished;
    if (turnChanged) _onTurnChanged();
    _broadcastState();
    onPersist?.call(toJson());
  }

  int _remainingMs() {
    final d = _deadline;
    if (d == null) return 0;
    return max(0, d.difference(scheduler.now()).inMilliseconds);
  }

  void _sendState(String playerId) {
    final s = _state;
    if (s == null) return;
    _sendToPlayer(playerId, StateMsg(viewFor(s, playerId, remainingMs: _remainingMs())));
  }

  void _broadcastState() {
    for (final id in _playerConn.keys.toList()) {
      _sendState(id);
    }
  }

  // --- gönderim yardımcıları --------------------------------------------------

  LobbyMsg _lobbyMsg() => LobbyMsg(_roomCode, hostPlayerId, List.of(_lobby));

  void _bind(String connId, String playerId) {
    final old = _playerConn[playerId];
    if (old != null) _connToPlayer.remove(old);
    _connToPlayer[connId] = playerId;
    _playerConn[playerId] = connId;
  }

  void _sendTo(String connId, NetMessage m) => transport.send(connId, encodeMessage(m));

  void _sendToPlayer(String playerId, NetMessage m) {
    final c = _playerConn[playerId];
    if (c != null) _sendTo(c, m);
  }

  void _broadcast(NetMessage m) {
    final text = encodeMessage(m);
    for (final c in _playerConn.values.toList()) {
      transport.send(c, text);
    }
  }
}
