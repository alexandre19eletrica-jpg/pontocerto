import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class LocalMediaStore {
  static Future<File> savePickedFile({
    required XFile source,
    required String folder,
    required String filePrefix,
  }) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final targetDir = Directory('${docsDir.path}/$folder');
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final extension = _extensionFrom(source);
    final targetPath = '${targetDir.path}/$filePrefix$extension';
    final targetFile = File(targetPath);

    try {
      final sourceFile = File(source.path);
      if (await sourceFile.exists()) {
        return sourceFile.copy(targetPath);
      }
    } catch (_) {
      // Se o path vier inacessivel (content://), salva via bytes.
    }

    final bytes = await source.readAsBytes();
    return targetFile.writeAsBytes(bytes, flush: true);
  }

  static String _extensionFrom(XFile file) {
    final byName = _extractExtension(file.name);
    if (byName.isNotEmpty) return byName;
    return _extractExtension(file.path);
  }

  static String _extractExtension(String value) {
    final sanitized = value.split('?').first;
    final idx = sanitized.lastIndexOf('.');
    if (idx < 0 || idx == sanitized.length - 1) return '';
    return sanitized.substring(idx);
  }
}
