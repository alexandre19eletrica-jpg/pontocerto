import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';

class AccountantFocusXmlSyncResult {
  const AccountantFocusXmlSyncResult({
    required this.documentType,
    required this.documentsFetched,
    required this.xmlCaptured,
    required this.lastVersion,
    required this.ultimoNsu,
  });

  final String documentType;
  final int documentsFetched;
  final int xmlCaptured;
  final int lastVersion;
  final String ultimoNsu;

  String get label =>
      documentType == 'nfse_nacional' ? 'NFS-e nacional' : 'NF-e';
}

class AccountantFocusXmlService {
  AccountantFocusXmlService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  Future<AccountantFocusXmlSyncResult> sync({
    required String documentType,
  }) async {
    final callable = _functions.httpsCallable(
      'fiscalSyncFocusIncomingDocuments',
    );
    final response = await callable.call(<String, dynamic>{
      'documentType': documentType,
    });
    final data = Map<String, dynamic>.from(response.data as Map);
    return AccountantFocusXmlSyncResult(
      documentType: data['documentType']?.toString() ?? documentType,
      documentsFetched: (data['documentsFetched'] as num?)?.toInt() ?? 0,
      xmlCaptured: (data['xmlCaptured'] as num?)?.toInt() ?? 0,
      lastVersion: (data['lastVersion'] as num?)?.toInt() ?? 0,
      ultimoNsu: data['ultimoNsu']?.toString() ?? '',
    );
  }

  Future<({String filename, Uint8List bytes})> downloadXml({
    required String documentId,
  }) async {
    final callable = _functions.httpsCallable('fiscalDownloadImportedXml');
    final response = await callable.call(<String, dynamic>{
      'documentId': documentId,
    });
    final data = Map<String, dynamic>.from(response.data as Map);
    final base64 = data['base64']?.toString() ?? '';
    return (
      filename: data['fileName']?.toString() ?? '$documentId.xml',
      bytes: Uint8List.fromList(base64Decode(base64)),
    );
  }
}
