import 'package:game_core/game_core.dart';
import 'package:net_core/net_core.dart';
import 'package:test/test.dart';

import 'support/samples.dart';

void main() {
  final samples = <NetMessage>[
    const Hello(PlayerInfo(id: 'p1', name: 'Ayşe', avatar: 3), protocol: 1),
    const Welcome('p1'),
    const JoinRejected(JoinRejectCode.roomFull),
    const LobbyMsg('4821', 'p1', [PlayerInfo(id: 'p1', name: 'Ayşe', avatar: 3)]),
    StateMsg(sampleView()),
    MoveMsg({const Pos(6, 4): const Tile('T'), const Pos(6, 5): const Tile('İ', isJoker: true)}),
    const SwapAllMsg(),
    const MoveResultMsg(false, 0, [
      UnknownWords(['AZ']),
      PlacementInvalid(PlacementError.gap),
      WordAlreadyUsed('AT'),
      NotYourTurn(),
      GameFinished(),
      NotInHand(),
      InvalidLetter(),
    ]),
    const MoveResultMsg(true, 24, []),
    const ProposeWordMsg('ÇİLEK'),
    const VoteStartMsg('v1', 'ÇİLEK', 'p1', 15000),
    const VoteMsg('v1', true),
    const VoteResultMsg('v1', 'ÇİLEK', true),
    const ChatMsg('p2', 'merhaba 👋'),
    const PingMsg(),
    const PongMsg(),
  ];

  test('her mesaj gidiş-dönüş', () {
    for (final m in samples) {
      expect(decodeMessage(encodeMessage(m)), m, reason: m.runtimeType.toString());
    }
  });

  test('bozuk girdi null döner', () {
    expect(decodeMessage('{'), isNull);
    expect(decodeMessage('{"t":"uzaylı"}'), isNull);
    expect(decodeMessage('{"t":"welcome"}'), isNull);
    expect(decodeMessage('[1,2]'), isNull);
    expect(decodeMessage('{"t":"move","placements":"x"}'), isNull);
    expect(decodeMessage('{"t":"moveResult","accepted":false,"points":0,"reasons":[{"code":"?"}]}'),
        isNull);
  });

  test('protocolVersion 1', () => expect(protocolVersion, 1));
}
