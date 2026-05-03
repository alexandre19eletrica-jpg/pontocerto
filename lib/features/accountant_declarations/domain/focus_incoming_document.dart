import 'package:cloud_firestore/cloud_firestore.dart';

class FocusIncomingDocument {
  const FocusIncomingDocument({
    required this.id,
    required this.companyId,
    required this.documentType,
    required this.tipo,
    required this.chave,
    required this.nsu,
    required this.status,
    required this.manifestStatus,
    required this.number,
    required this.series,
    required this.emitente,
    required this.cnpjEmitente,
    required this.destinatario,
    required this.cnpjDestinatario,
    required this.valorTotal,
    required this.dataEmissao,
    required this.receivedAt,
    required this.xmlDisponivel,
    required this.xmlPath,
  });

  final String id;
  final String companyId;
  final String documentType;
  final String tipo;
  final String chave;
  final String nsu;
  final String status;
  final String manifestStatus;
  final String number;
  final String series;
  final String emitente;
  final String cnpjEmitente;
  final String destinatario;
  final String cnpjDestinatario;
  final double? valorTotal;
  final DateTime? dataEmissao;
  final DateTime? receivedAt;
  final bool xmlDisponivel;
  final String xmlPath;

  bool get canDownloadXml => xmlDisponivel && xmlPath.trim().isNotEmpty;

  bool get isNfseNacional => documentType == 'nfse_nacional';

  String get typeLabel =>
      isNfseNacional
          ? 'NFS-e nacional'
          : (tipo == 'NFCE' ? 'NFC-e' : 'NF-e');

  factory FocusIncomingDocument.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    return FocusIncomingDocument(
      id: snapshot.id,
      companyId: data['companyId']?.toString() ?? '',
      documentType: data['documentType']?.toString() ?? 'nfe',
      tipo: data['tipo']?.toString() ?? '',
      chave: data['chave']?.toString() ?? data['accessKey']?.toString() ?? '',
      nsu: data['nsu']?.toString() ?? '',
      status: data['status']?.toString() ?? '',
      manifestStatus: data['manifestStatus']?.toString() ?? '',
      number: data['number']?.toString() ?? '',
      series: data['series']?.toString() ?? '',
      emitente:
          data['emitente']?.toString() ?? data['issuerName']?.toString() ?? '',
      cnpjEmitente:
          data['cnpj_emitente']?.toString() ??
          data['issuerDocument']?.toString() ??
          '',
      destinatario:
          data['destinatario']?.toString() ??
          data['recipientName']?.toString() ??
          '',
      cnpjDestinatario:
          data['cnpj_destinatario']?.toString() ??
          data['recipientDocument']?.toString() ??
          '',
      valorTotal:
          (data['valor_total'] as num?)?.toDouble() ??
          (data['totalValue'] as num?)?.toDouble(),
      dataEmissao: _toDateTime(data['data_emissao'] ?? data['issuedAt']),
      receivedAt: _toDateTime(data['receivedAt']),
      xmlDisponivel:
          data['xml_disponivel'] == true || data['xmlAvailable'] == true,
      xmlPath: data['xml_path']?.toString() ?? '',
    );
  }

  static DateTime? _toDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
