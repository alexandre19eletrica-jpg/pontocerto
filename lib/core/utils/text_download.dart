import 'text_download_stub.dart'
    if (dart.library.html) 'text_download_web.dart';

Future<void> saveTextFile({
  required String filename,
  required String content,
  required String mimeType,
}) {
  return saveTextFileImpl(
    filename: filename,
    content: content,
    mimeType: mimeType,
  );
}
