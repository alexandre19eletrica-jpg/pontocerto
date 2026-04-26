import 'dart:typed_data';

import 'bytes_download_stub.dart'
    if (dart.library.html) 'bytes_download_web.dart';

Future<void> saveBytesFile({
  required String filename,
  required Uint8List bytes,
  required String mimeType,
}) {
  return saveBytesFileImpl(
    filename: filename,
    bytes: bytes,
    mimeType: mimeType,
  );
}
