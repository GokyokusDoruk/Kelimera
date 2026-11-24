import 'dart:convert';

import 'package:game_core/game_core.dart';

import 'player_view.dart';

const int protocolVersion = 1;

enum JoinRejectCode { roomFull, gameStarted, versionMismatch, playerLeft }

bool _listEq<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _mapEq<K, V>(Map<K, V> a, Map<K, V> b) {
  if (a.length != b.length) return false;
  for (final e in a.entries) {
    if (!b.containsKey(e.key) || b[e.key] != e.value) return false;
  }
  return true;
}

sealed class NetMessage {
  const NetMessage();
  String get type;
  Map<String, dynamic> fields();
}

class Hello extends NetMessage {
  final PlayerInfo player;
  final int protocol;
  const Hello(this.player, {this.protocol = protocolVersion});
  @override
  String get type => 'hello';
  @override
  Map<String, dynamic> fields() => {'player': player.toJson(), 'protocol': protocol};
  @override
  bool operator ==(Object o) => o is Hello && o.player == player && o.protocol == protocol;
  @override
  int get hashCode => Object.hash(player, protocol);
}

class Welcome extends NetMessage {
  final String playerId;
  const Welcome(this.playerId);
  @override
  String get type => 'welcome';
  @override
  Map<String, dynamic> fields() => {'playerId': playerId};
  @override
  bool operator ==(Object o) => o is Welcome && o.playerId == playerId;
  @override
  int get hashCode => playerId.hashCode;
}

class JoinRejected extends NetMessage {
  final JoinRejectCode code;
  const JoinRejected(this.code);
  @override
  String get type => 'joinRejected';
  @override
  Map<String, dynamic> fields() => {'code': code.name};
  @override
  bool operator ==(Object o) => o is JoinRejected && o.code == code;
  @override
  int get hashCode => code.hashCode;
}

class LobbyMsg extends NetMessage {
  final String roomCode;
  final String hostId;
  final List<PlayerInfo> players;
  const LobbyMsg(this.roomCode, this.hostId, this.players);
  @override
  String get type => 'lobby';
  @override
  Map<String, dynamic> fields() => {
        'roomCode': roomCode,
        'hostId': hostId,
        'players': [for (final p in players) p.toJson()],
      };
  @override
  bool operator ==(Object o) =>
      o is LobbyMsg && o.roomCode == roomCode && o.hostId == hostId && _listEq(o.players, players);
  @override
  int get hashCode => Object.hash(roomCode, hostId, Object.hashAll(players));
}

class StateMsg extends NetMessage {
  final PlayerView view;
  const StateMsg(this.view);
  @override
  String get type => 'state';
  @override
  Map<String, dynamic> fields() => {'view': view.toJson()};
  @override
  bool operator ==(Object o) => o is StateMsg && o.view == view;
  @override
  int get hashCode => view.hashCode;
}

class MoveMsg extends NetMessage {
  final Map<Pos, Tile> placements;
  const MoveMsg(this.placements);
  @override
  String get type => 'move';
  @override
  Map<String, dynamic> fields() => {
        'placements': [
          for (final e in placements.entries)
            {'r': e.key.row, 'c': e.key.col, 'l': e.value.letter, 'j': e.value.isJoker},
        ],
      };
  @override
  bool operator ==(Object o) => o is MoveMsg && _mapEq(o.placements, placements);
  @override
  int get hashCode => Object.hashAllUnordered(placements.entries.map((e) => Object.hash(e.key, e.value)));
}

class SwapAllMsg extends NetMessage {
  const SwapAllMsg();
  @override
  String get type => 'swapAll';
  @override
  Map<String, dynamic> fields() => {};
  @override
  bool operator ==(Object o) => o is SwapAllMsg;
  @override
  int get hashCode => 11;
}

class MoveResultMsg extends NetMessage {
  final bool accepted;
  final int points;
  final List<RejectReason> reasons;
  const MoveResultMsg(this.accepted, this.points, this.reasons);
  @override
  String get type => 'moveResult';
  @override
  Map<String, dynamic> fields() => {
        'accepted': accepted,
        'points': points,
        'reasons': [for (final r in reasons) rejectReasonToJson(r)],
      };
  @override
  bool operator ==(Object o) =>
      o is MoveResultMsg && o.accepted == accepted && o.points == points && _listEq(o.reasons, reasons);
  @override
  int get hashCode => Object.hash(accepted, points, Object.hashAll(reasons));
  @override
  String toString() => 'MoveResultMsg($accepted, $points, $reasons)';
}

class ProposeWordMsg extends NetMessage {
  final String word;
  const ProposeWordMsg(this.word);
  @override
  String get type => 'proposeWord';
  @override
  Map<String, dynamic> fields() => {'word': word};
  @override
  bool operator ==(Object o) => o is ProposeWordMsg && o.word == word;
  @override
  int get hashCode => word.hashCode;
}

class VoteStartMsg extends NetMessage {
  final String voteId;
  final String word;
  final String proposerId;
  final int durationMs;
  const VoteStartMsg(this.voteId, this.word, this.proposerId, this.durationMs);
  @override
  String get type => 'voteStart';
  @override
  Map<String, dynamic> fields() =>
      {'voteId': voteId, 'word': word, 'proposerId': proposerId, 'durationMs': durationMs};
  @override
  bool operator ==(Object o) =>
      o is VoteStartMsg &&
      o.voteId == voteId &&
      o.word == word &&
      o.proposerId == proposerId &&
      o.durationMs == durationMs;
  @override
  int get hashCode => Object.hash(voteId, word, proposerId, durationMs);
}

class VoteMsg extends NetMessage {
  final String voteId;
  final bool yes;
  const VoteMsg(this.voteId, this.yes);
  @override
  String get type => 'vote';
  @override
  Map<String, dynamic> fields() => {'voteId': voteId, 'yes': yes};
  @override
  bool operator ==(Object o) => o is VoteMsg && o.voteId == voteId && o.yes == yes;
  @override
  int get hashCode => Object.hash(voteId, yes);
}

class VoteResultMsg extends NetMessage {
  final String voteId;
  final String word;
  final bool accepted;
  const VoteResultMsg(this.voteId, this.word, this.accepted);
  @override
  String get type => 'voteResult';
  @override
  Map<String, dynamic> fields() => {'voteId': voteId, 'word': word, 'accepted': accepted};
  @override
  bool operator ==(Object o) =>
      o is VoteResultMsg && o.voteId == voteId && o.word == word && o.accepted == accepted;
  @override
  int get hashCode => Object.hash(voteId, word, accepted);
  @override
  String toString() => 'VoteResultMsg($voteId, $word, $accepted)';
}

class ChatMsg extends NetMessage {
  final String fromId;
  final String text;
  const ChatMsg(this.fromId, this.text);
  @override
  String get type => 'chat';
  @override
  Map<String, dynamic> fields() => {'fromId': fromId, 'text': text};
  @override
  bool operator ==(Object o) => o is ChatMsg && o.fromId == fromId && o.text == text;
  @override
  int get hashCode => Object.hash(fromId, text);
  @override
  String toString() => 'ChatMsg($fromId, $text)';
}

class PingMsg extends NetMessage {
  const PingMsg();
  @override
  String get type => 'ping';
  @override
  Map<String, dynamic> fields() => {};
  @override
  bool operator ==(Object o) => o is PingMsg;
  @override
  int get hashCode => 12;
}

class PongMsg extends NetMessage {
  const PongMsg();
  @override
  String get type => 'pong';
  @override
  Map<String, dynamic> fields() => {};
  @override
  bool operator ==(Object o) => o is PongMsg;
  @override
  int get hashCode => 13;
}

String encodeMessage(NetMessage m) => jsonEncode({'t': m.type, ...m.fields()});

/// Bozuk, bilinmeyen ya da eksik alanlı mesajlar için null döner; asla fırlatmaz.
NetMessage? decodeMessage(String s) {
  try {
    final j = jsonDecode(s);
    if (j is! Map<String, dynamic>) return null;
    return switch (j['t']) {
      'hello' => Hello(PlayerInfo.fromJson(j['player'] as Map<String, dynamic>),
          protocol: j['protocol'] as int),
      'welcome' => Welcome(j['playerId'] as String),
      'joinRejected' => JoinRejected(JoinRejectCode.values.byName(j['code'] as String)),
      'lobby' => LobbyMsg(j['roomCode'] as String, j['hostId'] as String, [
          for (final p in (j['players'] as List).cast<Map<String, dynamic>>()) PlayerInfo.fromJson(p),
        ]),
      'state' => StateMsg(PlayerView.fromJson(j['view'] as Map<String, dynamic>)),
      'move' => MoveMsg({
          for (final t in (j['placements'] as List).cast<Map<String, dynamic>>())
            Pos(t['r'] as int, t['c'] as int): Tile(t['l'] as String, isJoker: t['j'] as bool),
        }),
      'swapAll' => const SwapAllMsg(),
      'moveResult' => MoveResultMsg(j['accepted'] as bool, j['points'] as int, [
          for (final r in (j['reasons'] as List).cast<Map<String, dynamic>>()) rejectReasonFromJson(r),
        ]),
      'proposeWord' => ProposeWordMsg(j['word'] as String),
      'voteStart' => VoteStartMsg(j['voteId'] as String, j['word'] as String,
          j['proposerId'] as String, j['durationMs'] as int),
      'vote' => VoteMsg(j['voteId'] as String, j['yes'] as bool),
      'voteResult' =>
        VoteResultMsg(j['voteId'] as String, j['word'] as String, j['accepted'] as bool),
      'chat' => ChatMsg(j['fromId'] as String, j['text'] as String),
      'ping' => const PingMsg(),
      'pong' => const PongMsg(),
      _ => null,
    };
  } catch (_) {
    return null;
  }
}

Map<String, dynamic> rejectReasonToJson(RejectReason r) => switch (r) {
      NotYourTurn() => {'code': 'notYourTurn'},
      GameFinished() => {'code': 'gameFinished'},
      NotInHand() => {'code': 'notInHand'},
      InvalidLetter() => {'code': 'invalidLetter'},
      PlacementInvalid(:final error) => {'code': 'placement', 'error': error.name},
      UnknownWords(:final words) => {'code': 'unknownWords', 'words': words},
      WordAlreadyUsed(:final word) => {'code': 'wordAlreadyUsed', 'word': word},
    };

/// Bilinmeyen kodda [FormatException] fırlatır.
RejectReason rejectReasonFromJson(Map<String, dynamic> j) => switch (j['code']) {
      'notYourTurn' => const NotYourTurn(),
      'gameFinished' => const GameFinished(),
      'notInHand' => const NotInHand(),
      'invalidLetter' => const InvalidLetter(),
      'placement' => PlacementInvalid(PlacementError.values.byName(j['error'] as String)),
      'unknownWords' => UnknownWords(List<String>.from(j['words'] as List)),
      'wordAlreadyUsed' => WordAlreadyUsed(j['word'] as String),
      _ => throw FormatException('Bilinmeyen ret kodu', j['code']),
    };
