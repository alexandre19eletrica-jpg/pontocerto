import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class StandardPdfCompanyInfo {
  const StandardPdfCompanyInfo({
    required this.name,
    this.document = '',
    this.address = '',
    this.secondaryLine = '',
  });

  final String name;
  final String document;
  final String address;
  final String secondaryLine;
}

class StandardPdfField {
  const StandardPdfField(this.label, this.value);

  final String label;
  final String value;
}

class StandardPdfSigner {
  const StandardPdfSigner({
    required this.label,
    required this.name,
    this.details = const <String>[],
  });

  final String label;
  final String name;
  final List<String> details;
}

class StandardPdfDocument {
  static const PdfColor _ink = PdfColor.fromInt(0xFF1F2937);
  static const PdfColor _muted = PdfColor.fromInt(0xFF64748B);
  static const PdfColor _accent = PdfColor.fromInt(0xFF0F4C81);
  static const PdfColor _border = PdfColor.fromInt(0xFFD7DFEA);
  static const PdfColor _surface = PdfColor.fromInt(0xFFF6F8FB);

  static pw.PageTheme pageTheme() {
    return pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 32),
    );
  }

  static pw.Widget header({
    required String title,
    required StandardPdfCompanyInfo company,
    String? subtitle,
    List<StandardPdfField> metadata = const <StandardPdfField>[],
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        color: _surface,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: _border),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      title,
                      style: pw.TextStyle(
                        color: _accent,
                        fontSize: 19,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if ((subtitle ?? '').trim().isNotEmpty) ...[
                      pw.SizedBox(height: 6),
                      pw.Text(
                        subtitle!.trim(),
                        style: const pw.TextStyle(
                          color: _muted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: pw.BorderRadius.circular(999),
                  border: pw.Border.all(color: _border),
                ),
                child: pw.Text(
                  'Ponto Certo',
                  style: pw.TextStyle(
                    color: _accent,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            _safe(company.name),
            style: pw.TextStyle(
              color: _ink,
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          if (company.document.trim().isNotEmpty)
            pw.Text(
              'CPF/CNPJ: ${company.document.trim()}',
              style: const pw.TextStyle(color: _muted, fontSize: 10),
            ),
          if (company.address.trim().isNotEmpty)
            pw.Text(
              company.address.trim(),
              style: const pw.TextStyle(color: _muted, fontSize: 10),
            ),
          if (company.secondaryLine.trim().isNotEmpty)
            pw.Text(
              company.secondaryLine.trim(),
              style: const pw.TextStyle(color: _muted, fontSize: 10),
            ),
          if (metadata.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            infoGrid(metadata),
          ],
        ],
      ),
    );
  }

  static pw.Widget infoGrid(List<StandardPdfField> fields) {
    final visible = fields
        .where((field) => field.label.trim().isNotEmpty)
        .toList(growable: false);
    return pw.Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final field in visible)
          pw.Container(
            width: 240,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(10),
              border: pw.Border.all(color: _border),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  field.label,
                  style: pw.TextStyle(
                    color: _muted,
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  _safe(field.value),
                  style: const pw.TextStyle(color: _ink, fontSize: 11),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static pw.Widget section({
    required String title,
    required List<pw.Widget> children,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 14),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              color: _accent,
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(12),
              border: pw.Border.all(color: _border),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget paragraph(String text) {
    return pw.Text(
      _safe(text),
      style: const pw.TextStyle(color: _ink, fontSize: 11, lineSpacing: 3),
      textAlign: pw.TextAlign.justify,
    );
  }

  static List<pw.Widget> bulletList(List<String> items) {
    final visible = items
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (visible.isEmpty) {
      return [paragraph('Sem informacoes registradas neste bloco.')];
    }
    return [
      for (final item in visible)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 5),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '- ',
                style: pw.TextStyle(
                  color: _accent,
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Expanded(child: paragraph(item)),
            ],
          ),
        ),
    ];
  }

  static pw.Widget signatureBlock(List<StandardPdfSigner> signers) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 16),
      child: pw.Wrap(
        spacing: 18,
        runSpacing: 18,
        children: [
          for (final signer in signers)
            pw.Container(
              width: 240,
              padding: const pw.EdgeInsets.only(top: 18),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(height: 1, color: _border),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    _safe(signer.name),
                    style: pw.TextStyle(
                      color: _ink,
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    _safe(signer.label),
                    style: const pw.TextStyle(color: _muted, fontSize: 10),
                  ),
                  for (final detail in signer.details)
                    pw.Text(
                      _safe(detail),
                      style: const pw.TextStyle(color: _muted, fontSize: 9),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _safe(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? '-' : normalized;
  }
}
