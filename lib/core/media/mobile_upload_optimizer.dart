import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class MobileUploadOptimizerException implements Exception {
  MobileUploadOptimizerException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PreparedUploadData {
  const PreparedUploadData({
    required this.bytes,
    required this.fileName,
    required this.contentType,
  });

  final Uint8List bytes;
  final String fileName;
  final String contentType;
}

class MobileUploadOptimizer {
  static const int defaultMobileUploadLimitBytes = 8 * 1024 * 1024;

  static Future<PreparedUploadData> preparePlatformFile({
    required PlatformFile file,
    required String fallbackContentType,
    int mobileMaxBytes = defaultMobileUploadLimitBytes,
  }) async {
    final bytes = await _readPlatformFileBytes(file);
    final fileName = file.name.trim().isEmpty ? 'arquivo' : file.name.trim();
    return _prepareBytes(
      bytes: bytes,
      fileName: fileName,
      contentType: fallbackContentType,
      mobileMaxBytes: mobileMaxBytes,
    );
  }

  static Future<PreparedUploadData> prepareXFileImage({
    required XFile file,
    required String contentType,
    int mobileMaxBytes = defaultMobileUploadLimitBytes,
  }) async {
    final fileName = file.name.trim().isEmpty ? 'imagem.jpg' : file.name.trim();
    final bytes = await file.readAsBytes();
    return _prepareBytes(
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
      mobileMaxBytes: mobileMaxBytes,
    );
  }

  static String maxSizeMessage(int bytes, {String label = 'arquivo'}) {
    final mb = (bytes / (1024 * 1024)).toStringAsFixed(0);
    return 'No app, envie $label de ate $mb MB.';
  }

  static Future<Uint8List> _readPlatformFileBytes(PlatformFile file) async {
    final direct = file.bytes;
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }
    final path = file.path;
    if (path == null || path.isEmpty) {
      throw MobileUploadOptimizerException('Nao foi possivel ler o arquivo selecionado.');
    }
    return File(path).readAsBytes();
  }

  static PreparedUploadData _prepareBytes({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required int mobileMaxBytes,
  }) {
    if (!kIsWeb) {
      if (bytes.length > mobileMaxBytes) {
        throw MobileUploadOptimizerException(maxSizeMessage(mobileMaxBytes));
      }
    }

    return PreparedUploadData(
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
    );
  }
}
