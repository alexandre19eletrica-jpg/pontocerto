import 'dart:typed_data';

Future<void> openPdfBytesImpl({
  required Uint8List bytes,
  required String filename,
}) async {
  throw UnsupportedError('Saida de PDF nao suportada nesta plataforma.');
}

Future<void> sharePdfBytesImpl({
  required Uint8List bytes,
  required String filename,
}) async {
  throw UnsupportedError('Compartilhamento de PDF nao suportado nesta plataforma.');
}
