import 'dart:typed_data';

/// Parça başlığı: [messageId: uint16 BE][index: uint8][total: uint8]
const int frameHeaderSize = 4;

List<Uint8List> encodeFrames(int messageId, Uint8List payload, int maxFrameSize) {
  if (maxFrameSize <= frameHeaderSize) {
    throw ArgumentError.value(maxFrameSize, 'maxFrameSize', 'En az ${frameHeaderSize + 1} olmalı');
  }
  final chunk = maxFrameSize - frameHeaderSize;
  final total = payload.isEmpty ? 1 : (payload.length + chunk - 1) ~/ chunk;
  if (total > 255) {
    throw ArgumentError.value(payload.length, 'payload', 'Mesaj 255 parçaya sığmıyor');
  }
  final id = messageId & 0xFFFF;
  return [
    for (var i = 0; i < total; i++)
      () {
        final start = i * chunk;
        final end = (start + chunk) > payload.length ? payload.length : start + chunk;
        final f = Uint8List(frameHeaderSize + (end - start));
        f[0] = id >> 8;
        f[1] = id & 0xFF;
        f[2] = i;
        f[3] = total;
        f.setRange(frameHeaderSize, f.length, payload, start);
        return f;
      }(),
  ];
}

/// Bir bağlantıdan gelen parçaları birleştirir.
class FrameAssembler {
  int? _id;
  int _total = 0;
  final Map<int, Uint8List> _parts = {};

  /// Mesaj tamamlandığında payload'u döner; aksi halde null.
  Uint8List? add(Uint8List frame) {
    if (frame.length < frameHeaderSize) {
      throw const FormatException('Parça başlıktan kısa');
    }
    final id = (frame[0] << 8) | frame[1];
    final index = frame[2];
    final total = frame[3];
    if (total == 0 || index >= total) throw const FormatException('Geçersiz parça başlığı');

    if (_id != id) {
      _id = id;
      _total = total;
      _parts.clear();
    } else if (total != _total) {
      _id = null;
      _parts.clear();
      throw const FormatException('Aynı mesajın parçalarında toplam uyuşmuyor');
    }
    _parts.putIfAbsent(index, () => Uint8List.sublistView(frame, frameHeaderSize));
    if (_parts.length < _total) return null;

    final b = BytesBuilder(copy: false);
    for (var i = 0; i < _total; i++) {
      b.add(_parts[i]!);
    }
    _id = null;
    _parts.clear();
    return b.takeBytes();
  }
}
