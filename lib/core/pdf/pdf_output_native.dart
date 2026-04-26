import 'dart:typed_data';

import 'package:printing/printing.dart';

Future<void> openPdfBytesImpl({
  required Uint8List bytes,
  required String filename,
}) {
  return Printing.layoutPdf(onLayout: (_) async => bytes);
}

Future<void> sharePdfBytesImpl({
  required Uint8List bytes,
  required String filename,
}) {
  return Printing.sharePdf(bytes: bytes, filename: filename);
}
