import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pontocerto/core/media/mobile_upload_optimizer.dart';

class FirebaseMediaUpload {
  static Future<String> uploadXFileWithBucketFallback({
    required String caminhoStorage,
    required XFile source,
    required String contentType,
  }) async {
    final referencias = _refsStorageComFallback(caminhoStorage);
    final erros = <String>[];
    final prepared = await MobileUploadOptimizer.prepareXFileImage(
      file: source,
      contentType: contentType,
    );
    final bytes = prepared.bytes;

    for (final refStorage in referencias) {
      try {
        await refStorage.putData(
          bytes,
          SettableMetadata(contentType: contentType),
        );
        await refStorage.getMetadata();
        return await refStorage.getDownloadURL();
      } on FirebaseException catch (e) {
        final detalhe = (e.message ?? '').trim();
        erros.add(
          '${refStorage.bucket}:${e.code}${detalhe.isEmpty ? '' : '($detalhe)'}',
        );
      }
    }

    throw FirebaseException(
      plugin: 'firebase_storage',
      code: 'upload-failed',
      message: 'Falha upload [$caminhoStorage] -> ${erros.join(' | ')}',
    );
  }

  static List<Reference> _refsStorageComFallback(String path) {
    final base = FirebaseStorage.instance;
    final refs = <Reference>[base.ref(path)];
    for (final bucket in _bucketCandidates(base.bucket)) {
      refs.add(FirebaseStorage.instanceFor(bucket: 'gs://$bucket').ref(path));
    }
    final vistos = <String>{};
    final unicos = <Reference>[];
    for (final ref in refs) {
      final chave = '${ref.bucket}/${ref.fullPath}';
      if (vistos.add(chave)) unicos.add(ref);
    }
    return unicos;
  }

  static List<String> _bucketCandidates(String defaultBucket) {
    final buckets = <String>{defaultBucket};
    if (defaultBucket.endsWith('.firebasestorage.app')) {
      buckets.add(
        defaultBucket.replaceFirst('.firebasestorage.app', '.appspot.com'),
      );
    } else if (defaultBucket.endsWith('.appspot.com')) {
      buckets.add(
        defaultBucket.replaceFirst('.appspot.com', '.firebasestorage.app'),
      );
    }
    return buckets.toList();
  }
}
