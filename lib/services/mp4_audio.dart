import 'dart:typed_data';

/// Inspect tracks rather than the ftyp brand: Android MediaMuxer writes isom/
/// mp42 AAC recordings, while M4A-branded files can also contain video.
bool isAudioOnlyMp4(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  var audio = false, video = false, valid = true, ftyp = false;
  void boxes(int start, int end, int depth) {
    if (depth > 4) {
      valid = false;
      return;
    }
    var offset = start;
    while (offset < end && valid) {
      if (end - offset < 8) {
        valid = false;
        return;
      }
      var size = data.getUint32(offset);
      var header = 8;
      if (size == 1) {
        if (end - offset < 16) {
          valid = false;
          return;
        }
        size = data.getUint64(offset + 8);
        header = 16;
      } else if (size == 0) {
        size = end - offset;
      }
      if (size < header || size > end - offset) {
        valid = false;
        return;
      }
      final type = String.fromCharCodes(bytes.sublist(offset + 4, offset + 8));
      final body = offset + header, limit = offset + size;
      if (depth == 0 && type == 'ftyp' && size >= header + 8) ftyp = true;
      if (type == 'moov' || type == 'trak' || type == 'mdia') {
        boxes(body, limit, depth + 1);
      } else if (type == 'hdlr' && depth == 3) {
        if (limit - body < 12) {
          valid = false;
          return;
        }
        final handler = String.fromCharCodes(
          bytes.sublist(body + 8, body + 12),
        );
        audio |= handler == 'soun';
        video |= handler == 'vide';
      }
      offset = limit;
    }
  }

  boxes(0, bytes.length, 0);
  return valid && ftyp && audio && !video;
}
