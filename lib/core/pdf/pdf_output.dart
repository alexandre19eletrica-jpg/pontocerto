import 'dart:typed_data';

import 'pdf_output_stub.dart'
    if (dart.library.html) 'pdf_output_web.dart'
    if (dart.library.io) 'pdf_output_native.dart';

Future<void> openPdfBytes({
  required Uint8List bytes,
  required String filename,
}) {
  return openPdfBytesImpl(bytes: bytes, filename: filename);
}

Future<void> sharePdfBytes({
  required Uint8List bytes,
  required String filename,
}) {
  return sharePdfBytesImpl(bytes: bytes, filename: filename);
}
