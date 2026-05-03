part of 'fiscal_readiness_page.dart';

extension _FiscalReadinessPdfActions on _FiscalReadinessPageState {
  Future<void> _previewInvoicePdf({
    required Map<String, dynamic> companyData,
    required Map<String, dynamic> data,
  }) async {
    try {
      final service =
          (data['service'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{};
      final tax =
          (data['tax'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          build: (_) => [
            pw.Text(
              'Documento auxiliar de NFS-e / Nota de servico',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              'Empresa: ${companyData['nomeFantasia'] ?? companyData['razaoSocial'] ?? '-'}',
            ),
            pw.Text('CNPJ: ${companyData['cnpj'] ?? '-'}'),
            pw.Text('Cliente: ${data['clientName'] ?? '-'}'),
            pw.Text('CPF/CNPJ cliente: ${data['clientDocument'] ?? '-'}'),
            if ((((data['sourceTask'] as Map?)?['id']?.toString().trim() ?? '')
                .isNotEmpty))
              pw.Text('Origem operacional: ${_invoiceSourceTaskLabel(data)}'),
            pw.Text(
              'Descricao do servico: ${data['serviceDescription'] ?? '-'}',
            ),
            if ((service['serviceCode']?.toString().trim() ?? '').isNotEmpty)
              pw.Text('Codigo do servico: ${service['serviceCode']}'),
            if ((service['municipalServiceCode']?.toString().trim() ?? '')
                .isNotEmpty)
              pw.Text('Codigo municipal: ${service['municipalServiceCode']}'),
            if ((service['cnae']?.toString().trim() ?? '').isNotEmpty)
              pw.Text('CNAE: ${service['cnae']}'),
            if ((service['cityOfIncidence']?.toString().trim() ?? '')
                .isNotEmpty)
              pw.Text('Municipio da incidencia: ${service['cityOfIncidence']}'),
            pw.Text(
              'Valor: ${_formatCurrency((data['amountCents'] as num?)?.toInt() ?? 0)}',
            ),
            pw.Text(
              'Base de calculo: ${_formatCurrency((tax['taxableBaseCents'] as num?)?.toInt() ?? 0)}',
            ),
            pw.Text(
              'ISS estimado: ${_formatCurrency((tax['issAmountCents'] as num?)?.toInt() ?? 0)}',
            ),
            if (((tax['inssRetained'] as bool?) ?? false) ||
                ((tax['inssAmountCents'] as num?)?.toInt() ?? 0) > 0)
              pw.Text(
                'INSS retido: ${_formatCurrency((tax['inssAmountCents'] as num?)?.toInt() ?? 0)}',
              ),
            if (((tax['otherRetentionsCents'] as num?)?.toInt() ?? 0) > 0)
              pw.Text(
                'Outras retencoes: ${_formatCurrency((tax['otherRetentionsCents'] as num?)?.toInt() ?? 0)}',
              ),
            if ((tax['taxRegime']?.toString().trim() ?? '').isNotEmpty)
              pw.Text('Regime tributario: ${tax['taxRegime']}'),
            if ((tax['operationNature']?.toString().trim() ?? '').isNotEmpty ||
                (tax['operationNatureLabel']?.toString().trim() ?? '')
                    .isNotEmpty)
              pw.Text(
                'Natureza da operacao: ${_operationNatureDisplayLabel(tax['operationNatureLabel']?.toString(), rawValue: tax['operationNature']?.toString())}',
              ),
            pw.Text(
              'Data do servico: ${_formatDate(_toDate(data['serviceDate']))}',
            ),
            pw.Text(
              'Data de emissao: ${_formatDate(_invoiceReferenceDate(data))}',
            ),
            pw.Text(
              'Status: ${_invoiceStatusLabel(data['status']?.toString())}',
            ),
            pw.Text(
              'Numero oficial: ${_invoiceOfficialNumber(data).isEmpty ? '-' : _invoiceOfficialNumber(data)}',
            ),
            pw.Text('Portal oficial: ${data['officialPortalUrl'] ?? '-'}'),
            if ((data['financeMovementId']?.toString().trim() ?? '').isNotEmpty)
              pw.Text('Financeiro vinculado: ${data['financeMovementId']}'),
            pw.SizedBox(height: 12),
            pw.Text(
              'Observacao: este documento serve como espelho operacional interno. A emissao fiscal oficial depende do ambiente oficial da prefeitura/NFS-e.',
            ),
          ],
        ),
      );
      await openPdfBytes(
        bytes: await pdf.save(),
        filename: 'nfse-${data['id'] ?? 'rascunho'}.pdf',
      );
    } catch (_) {
      _msg('Nao foi possivel gerar o PDF da nota.');
    }
  }

  Future<void> _openUrl(String? url) async {
    final parsed = Uri.tryParse(url ?? '');
    if (parsed == null) {
      _msg('Link do portal invalido.');
      return;
    }
    await launchUrl(parsed, mode: LaunchMode.externalApplication);
  }

  Future<void> _exportFiscalSummaryPdf({
    required Session sessao,
    required Map<String, dynamic> companyData,
    required _FiscalRealIntegrationSetup realIntegration,
    required String competence,
  }) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('service_invoices')
          .where('companyId', isEqualTo: sessao.companyId)
          .get();
      final competenceInvoices =
          snapshot.docs.where((doc) {
            final issueDate = _invoiceReferenceDate(doc.data());
            return '${issueDate.year}-${issueDate.month.toString().padLeft(2, '0')}' ==
                competence;
          }).toList()..sort(
            (a, b) => _invoiceReferenceDate(
              b.data(),
            ).compareTo(_invoiceReferenceDate(a.data())),
          );
      final activeIssuedInvoices = competenceInvoices
          .where((doc) => _invoiceIsOfficiallyIssued(doc.data()))
          .where((doc) => !_invoiceIsCanceled(doc.data()))
          .toList();
      final invoiceCount = competenceInvoices.length;
      final officialMissing = competenceInvoices
          .where(
            (doc) => _invoiceOfficialNumber(doc.data()).isEmpty,
          )
          .length;
      final portalMissing = competenceInvoices
          .where(
            (doc) => (doc.data()['officialPortalUrl']?.toString().trim() ?? '')
                .isEmpty,
          )
          .length;
      final grossAmount = activeIssuedInvoices.fold<int>(
        0,
        (total, doc) => total + _invoiceGrossAmount(doc.data()),
      );
      final netAmount = activeIssuedInvoices.fold<int>(
        0,
        (total, doc) =>
            total +
            ((((doc.data()['tax'] as Map?)?['netAmountCents'] as num?)
                    ?.toInt()) ??
                ((doc.data()['amountCents'] as num?)?.toInt() ?? 0)),
      );
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (context) => [
            pw.Text(
              'Resumo fiscal / contador - competencia $competence',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18),
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              'Empresa: ${companyData['razaoSocial'] ?? companyData['nomeFantasia'] ?? '-'}',
            ),
            pw.Text('CNPJ: ${companyData['cnpj'] ?? '-'}'),
            pw.Text('CNAE principal: ${companyData['mainCnae'] ?? '-'}'),
            pw.Text(
              'Descricao CNAE: ${companyData['mainCnaeDescription'] ?? '-'}',
            ),
            pw.Text(
              'Regime tributario: ${companyData['regimeTributario'] ?? _inferTaxRegime(companyData)}',
            ),
            pw.Text('Provedor configurado: ${realIntegration.providerLabel}'),
            pw.Text('Ambiente: ${realIntegration.environmentLabel}'),
            pw.SizedBox(height: 12),
            pw.Bullet(text: 'Notas monitoradas: $invoiceCount'),
            pw.Bullet(
              text: 'Notas emitidas ativas: ${activeIssuedInvoices.length}',
            ),
            pw.Bullet(text: 'Notas sem numero oficial: $officialMissing'),
            pw.Bullet(text: 'Notas sem portal oficial: $portalMissing'),
            pw.Bullet(
              text: 'Valor bruto total: ${_formatCurrency(grossAmount)}',
            ),
            pw.Bullet(
              text: 'Valor liquido total: ${_formatCurrency(netAmount)}',
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              'Documento preparatorio para conferencia interna e envio ao contador por PDF, email ou WhatsApp.',
            ),
            pw.SizedBox(height: 14),
            pw.Text(
              'Notas da competencia',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
            ),
            pw.SizedBox(height: 8),
            if (competenceInvoices.isEmpty)
              pw.Text('Nenhuma nota cadastrada nesta competencia.')
            else
              ...competenceInvoices.map((doc) {
                final data = doc.data();
                final service =
                    (data['service'] as Map?)?.cast<String, dynamic>() ??
                    <String, dynamic>{};
                final tax =
                    (data['tax'] as Map?)?.cast<String, dynamic>() ??
                    <String, dynamic>{};
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 10),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        '${data['clientName'] ?? '-'} - ${_formatCurrency((data['amountCents'] as num?)?.toInt() ?? 0)}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text('Documento: ${data['clientDocument'] ?? '-'}'),
                      pw.Text('Servico: ${data['serviceDescription'] ?? '-'}'),
                      pw.Text(
                        'Codigo servico: ${service['serviceCode'] ?? '-'} | CNAE: ${service['cnae'] ?? '-'}',
                      ),
                      pw.Text(
                        'ISS: ${_formatCurrency((tax['issAmountCents'] as num?)?.toInt() ?? 0)} | INSS: ${_formatCurrency((tax['inssAmountCents'] as num?)?.toInt() ?? 0)} | Liquido: ${_formatCurrency((tax['netAmountCents'] as num?)?.toInt() ?? ((data['amountCents'] as num?)?.toInt() ?? 0))}',
                      ),
                      pw.Text(
                        'Status: ${_invoiceStatusLabel(_invoiceDerivedStatus(data))} | Numero oficial: ${_invoiceOfficialNumber(data).isNotEmpty ? _invoiceOfficialNumber(data) : 'pendente'}',
                      ),
                      if ((((data['sourceTask'] as Map?)?['id']
                                  ?.toString()
                                  .trim() ??
                              '')
                          .isNotEmpty))
                        pw.Text('Origem: ${_invoiceSourceTaskLabel(data)}'),
                      if ((data['financeMovementId']?.toString().trim() ?? '')
                          .isNotEmpty)
                        pw.Text('Financeiro: ${data['financeMovementId']}'),
                    ],
                  ),
                );
              }),
          ],
        ),
      );
      await openPdfBytes(
        bytes: await pdf.save(),
        filename: 'resumo-fiscal-${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      _msg('Resumo fiscal gerado em PDF.');
    } catch (_) {
      _msg('Nao foi possivel gerar o resumo fiscal.');
    }
  }
}
