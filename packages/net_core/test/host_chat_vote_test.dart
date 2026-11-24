import 'package:game_core/game_core.dart';
import 'package:net_core/net_core.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

Harness voteHarness() => Harness(dictionary: Dictionary({'AT': 1, 'KALEM': 2}));

/// Sıradaki oyuncu A'nın altına T olmayan bir harf koyar → "A?" sözlükte yok.
(TestClient, String) rejectedWord(Harness h, List<TestClient> cs) {
  final cur = h.current(cs);
  final letter = cur.last<StateMsg>().view.myHand.firstWhere((l) => l != 'T');
  cur.send(MoveMsg({const Pos(6, 4): Tile(letter)}));
  final word = 'A$letter';
  expect(cur.last<MoveResultMsg>().reasons, [UnknownWords([word])]);
  return (cur, word);
}

List<TestClient> others(List<TestClient> cs, TestClient me) => cs.where((c) => c != me).toList();

void main() {
  group('sohbet', () {
    test('kırpma, boş mesaj, 120 karakter sınırı', () {
      final h = Harness();
      final cs = h.startWith(3);
      cs[1].send(const ChatMsg('sahte', '  selam  '));
      for (final c in cs) {
        expect(c.last<ChatMsg>(), const ChatMsg('p2', 'selam'));
      }
      cs[0].send(const ChatMsg('', '   '));
      expect(cs[2].all<ChatMsg>(), hasLength(1));
      cs[0].send(ChatMsg('', 'ş' * 130));
      expect(cs[2].last<ChatMsg>().text, 'ş' * 120);
    });

    test('emoji ortadan bölünmez', () {
      final h = Harness();
      final cs = h.startWith(2);
      cs[0].send(ChatMsg('', '${'a' * 119}😀😀'));
      expect(cs[1].last<ChatMsg>().text, '${'a' * 119}😀');
    });

    test('lobide sohbet çalışır', () {
      final h = Harness();
      final a = h.join('p1');
      final b = h.join('p2');
      a.send(const ChatMsg('', 'hazır mısınız'));
      expect(b.last<ChatMsg>(), const ChatMsg('p1', 'hazır mısınız'));
    });
  });

  group('oylama', () {
    test('iki evet: kabul, öneri listesine girer', () {
      final h = voteHarness();
      final cs = h.startWith(3);
      final (cur, word) = rejectedWord(h, cs);
      cur.send(ProposeWordMsg(word));
      final voters = others(cs, cur);
      for (final v in voters) {
        expect(v.last<VoteStartMsg>(), VoteStartMsg('v1', word, cur.id, 15000));
      }
      for (final v in voters) {
        v.send(const VoteMsg('v1', true));
      }
      for (final c in cs) {
        expect(c.last<VoteResultMsg>(), VoteResultMsg('v1', word, true));
      }
      expect(h.host.suggestions, [word]);
      expect(h.suggested, [word]);
    });

    test('kabul edilen öneri hemen kaydedilir', () {
      final h = voteHarness();
      final cs = h.startWith(3);
      final (cur, word) = rejectedWord(h, cs);
      cur.send(ProposeWordMsg(word));
      final saved = h.persistCount;
      for (final v in others(cs, cur)) {
        v.send(const VoteMsg('v1', true));
      }
      expect(h.persistCount, saved + 1);
      expect(h.lastSnapshot!['suggestions'], [word]);
    });

    test('bir evet bir hayır: ret', () {
      final h = voteHarness();
      final cs = h.startWith(3);
      final (cur, word) = rejectedWord(h, cs);
      cur.send(ProposeWordMsg(word));
      final voters = others(cs, cur);
      voters[0].send(const VoteMsg('v1', true));
      voters[1].send(const VoteMsg('v1', false));
      expect(cur.last<VoteResultMsg>(), VoteResultMsg('v1', word, false));
      expect(h.host.suggestions, isEmpty);
    });

    test('süre dolarsa oy vermeyen hayır sayılır', () {
      final h = voteHarness();
      final cs = h.startWith(3);
      final (cur, word) = rejectedWord(h, cs);
      cur.send(ProposeWordMsg(word));
      others(cs, cur)[0].send(const VoteMsg('v1', true));
      expect(cur.all<VoteResultMsg>(), isEmpty);
      h.sched.advance(const Duration(seconds: 15));
      expect(cur.last<VoteResultMsg>(), VoteResultMsg('v1', word, false));
    });

    test('listede olmayan kelime ve ikinci öneri oylama başlatmaz', () {
      final h = voteHarness();
      final cs = h.startWith(3);
      final (cur, word) = rejectedWord(h, cs);
      cur.send(const ProposeWordMsg('UYDURMA'));
      expect(others(cs, cur)[0].all<VoteStartMsg>(), isEmpty);
      cur.send(ProposeWordMsg(word));
      cur.send(ProposeWordMsg(word));
      expect(others(cs, cur)[0].all<VoteStartMsg>(), hasLength(1));
    });

    test('sırası olmayan oyuncu öneremez', () {
      final h = voteHarness();
      final cs = h.startWith(3);
      final (cur, word) = rejectedWord(h, cs);
      final other = others(cs, cur)[0];
      other.send(ProposeWordMsg(word));
      expect(cur.all<VoteStartMsg>(), isEmpty);
    });

    test('oylama sırasında kopan oy veren hayır sayılır', () {
      final h = voteHarness();
      final cs = h.startWith(3);
      final (cur, word) = rejectedWord(h, cs);
      cur.send(ProposeWordMsg(word));
      final voters = others(cs, cur);
      h.hub.drop(voters[0].link);
      voters[1].send(const VoteMsg('v1', true));
      expect(cur.last<VoteResultMsg>(), VoteResultMsg('v1', word, false));
    });

    test('oy veren yoksa hemen ret', () {
      final h = voteHarness();
      final cs = h.startWith(2);
      final (cur, word) = rejectedWord(h, cs);
      h.hub.drop(others(cs, cur)[0].link);
      cur.send(ProposeWordMsg(word));
      expect(cur.last<VoteResultMsg>().accepted, isFalse);
    });
  });
}
