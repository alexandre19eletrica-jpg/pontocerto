import 'dart:typed_data';

import 'package:pontocerto/core/utils/bytes_download.dart';

Future<void> openPdfBytesImpl({
  required Uint8List bytes,
  required String filename,
}) {
  return saveBytesFile(
    filename: filename,
    bytes: bytes,
    mimeType: 'application/pdf',
  );
}

Future<void> sharePdfBytesImpl({
  required Uint8List bytes,
  required String filename,
}) {
  return openPdfBytesImpl(bytes: bytes, filename: filename);
}
