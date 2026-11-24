import 'dart:convert';
import 'dart:typed_data';

import 'package:net_core/net_core.dart';
import 'package:test/test.dart';

void main() {
  test('böl ve birleştir, Türkçe metin', () {
    final payload = Uint8List.fromList(utf8.encode('İĞNE ş' * 50));
    final frames = encodeFrames(7, payload, 20);
    expect(frames.every((f) => f.length <= 20), isTrue);
    expect(frames.first.sublist(0, 4), [0, 7, 0, frames.length]);
    final a = FrameAssembler();
    Uint8List? out;
    for (final f in frames) {
      out = a.add(f);
    }
    expect(utf8.decode(out!), 'İĞNE ş' * 50);
  });

  test('yarım mesaj yeni mesajla atılır, tekrar eden parça yok sayılır', () {
    final a = FrameAssembler();
    final m1 = encodeFrames(1, Uint8List(40), 20);
    final m2 = encodeFrames(2, Uint8List.fromList([1, 2, 3]), 20);
    expect(a.add(m1[0]), isNull);
    expect(a.add(m2[0]), [1, 2, 3]);
    final m3 = encodeFrames(3, Uint8List(30), 20);
    expect(a.add(m3[0]), isNull);
    expect(a.add(m3[0]), isNull);
    expect(a.add(m3[1]), hasLength(30));
  });

  test('sınırlar', () {
    expect(encodeFrames(1, Uint8List(0), 20), hasLength(1));
    expect(FrameAssembler().add(encodeFrames(1, Uint8List(0), 20).single), isEmpty);
    expect(() => encodeFrames(1, Uint8List(10), 4), throwsArgumentError);
    expect(() => encodeFrames(1, Uint8List(256), 5), throwsArgumentError);
    expect(() => FrameAssembler().add(Uint8List(3)), throwsFormatException);
  });

  test('büyük mesaj kimliği 16 bite sarılır', () {
    final f = encodeFrames(0x1FFFF, Uint8List(1), 20).single;
    expect(f.sublist(0, 2), [0xFF, 0xFF]);
  });
}
