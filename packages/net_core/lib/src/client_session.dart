import 'dart:async';
import 'dart:math';

import 'package:game_core/game_core.dart';

import 'messages.dart';
import 'player_view.dart';
import 'scheduler.dart';
import 'transport.dart';

enum ClientPhase { connecting, lobby, playing, rejected, hostLost, ended }

/// Oyuncu telefonundaki oturum: hakemden gelen durumu tutar, komutları gönderir.
class ClientSession {
  final ClientTransport transport;
  final Scheduler scheduler;
  final PlayerInfo me;
  final Duration hostWait;

  ClientPhase phase = ClientPhase.connecting;
  LobbyMsg? lobby;
  PlayerView? view;
  final List<ChatMsg> chat = [];
  VoteStartMsg? activeVote;
  VoteResultMsg? lastVoteResult;
  MoveResultMsg? lastMoveResult;
  JoinRejectCode? rejectCode;
  bool endedByHostLoss = false;

  DateTime? _viewAt;
  Cancelable? _hostTimer;
  final _changes = StreamController<void>.broadcast(sync: true);
  late final StreamSubscription<ClientEvent> _sub;

  ClientSession({
    required this.transport,
    required this.scheduler,
    required this.me,
    this.hostWait = const Duration(minutes: 2),
  }) {
    _sub = transport.events.listen(_onEvent);
    if (transport.isUp) _sendHello();
  }

  Stream<void> get changes => _changes.stream;

  /// Hakemin bildirdiği kalan süreden, durum alındığından beri geçen süre düşülür.
  int get remainingMs {
    final v = view;
    final at = _viewAt;
    if (v == null || at == null) return 0;
    return max(0, v.remainingMs - scheduler.now().difference(at).inMilliseconds);
  }

  void submitMove(Map<Pos, Tile> placements) => _send(MoveMsg(placements));
  void swapAll() => _send(const SwapAllMsg());
  void sendChat(String text) => _send(ChatMsg(me.id, text));
  void proposeWord(String word) => _send(ProposeWordMsg(word));

  void vote(bool yes) {
    final v = activeVote;
    if (v == null) return;
    _send(VoteMsg(v.voteId, yes));
  }

  void dispose() {
    _sub.cancel();
    _hostTimer?.cancel();
    _changes.close();
  }

  // ---------------------------------------------------------------------------

  void _sendHello() => _send(Hello(me));

  void _send(NetMessage m) => transport.send(encodeMessage(m));

  void _onEvent(ClientEvent e) {
    switch (e) {
      case LinkUp():
        _sendHello();
      case LinkDown():
        _onLinkDown();
      case ClientReceived(:final message):
        final m = decodeMessage(message);
        if (m != null) _onMessage(m);
    }
  }

  void _onLinkDown() {
    // Hakemle bağ koptu: açık oylamanın sonucu bu bağlantıdan gelmeyecek.
    final hadVote = activeVote != null;
    activeVote = null;
    switch (phase) {
      case ClientPhase.playing:
        phase = ClientPhase.hostLost;
        _hostTimer?.cancel();
        _hostTimer = scheduler.after(hostWait, () {
          _hostTimer = null;
          phase = ClientPhase.ended;
          endedByHostLoss = true;
          _notify();
        });
      case ClientPhase.lobby:
        phase = ClientPhase.connecting;
      default:
        if (!hadVote) return;
    }
    _notify();
  }

  void _onMessage(NetMessage m) {
    switch (m) {
      case Welcome():
        _hostTimer?.cancel();
        _hostTimer = null;
        phase = view != null && !view!.finished ? ClientPhase.playing : ClientPhase.lobby;
      case LobbyMsg():
        lobby = m;
      case StateMsg(view: final v):
        _hostTimer?.cancel();
        _hostTimer = null;
        view = v;
        _viewAt = scheduler.now();
        phase = v.finished ? ClientPhase.ended : ClientPhase.playing;
      case JoinRejected(:final code):
        rejectCode = code;
        phase = ClientPhase.rejected;
      case MoveResultMsg():
        lastMoveResult = m;
      case VoteStartMsg(:final proposerId):
        if (proposerId != me.id) activeVote = m;
      case VoteResultMsg():
        activeVote = null;
        lastVoteResult = m;
      case ChatMsg():
        chat.add(m);
      case PingMsg():
        _send(const PongMsg());
      default:
        return;
    }
    _notify();
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }
}
