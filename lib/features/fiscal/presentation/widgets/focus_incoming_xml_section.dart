import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/theme/app_branding.dart';
import 'package:pontocerto/core/theme/app_layout.dart';
import 'package:pontocerto/core/ui/app_user_message.dart';
import 'package:pontocerto/core/utils/bytes_download.dart';
import 'package:pontocerto/features/accountant_declarations/domain/focus_incoming_document.dart';
import 'package:pontocerto/features/fiscal/presentation/services/focus_incoming_xml_service.dart';

/// Documentos recebidos (NF-e / NFS-e nacional) importados via API Focus.
///
/// Usado na rota da **empresa** (`/fiscal`) e na página **Declarações** do contador.
/// A Cloud Function grava em `empresas/{id}/documentos_fiscais`; regras permitem
/// owner, manager e accountant vinculados. Em **sessão demo** a sync fica bloqueada na UI.
class FocusIncomingXmlSection extends StatefulWidget {
  const FocusIncomingXmlSection({super.key, required this.session});

  final Session session;

  @override
  State<FocusIncomingXmlSection> createState() =>
      _FocusIncomingXmlSectionState();
}

class _FocusIncomingXmlSectionState extends State<FocusIncomingXmlSection> {
  final _service = FocusIncomingXmlService();
  bool _syncingNfe = false;
  bool _syncingNfse = false;

  Future<void> _sync(String documentType) async {
    if (widget.session.isDemo) {
      if (mounted) {
        context.showUserMessage(
          'Sessao demo: sincronizacao com a Focus nao e executada neste ambiente.',
        );
      }
      return;
    }
    setState(() {
      if (documentType == 'nfe') {
        _syncingNfe = true;
      } else {
        _syncingNfse = true;
      }
    });
    try {
      final result = await _service.sync(documentType: documentType);
      if (!mounted) return;
      context.showUserSuccess(
        '${result.label}: ${result.documentsFetched} documento(s) sincronizado(s), '
        '${result.xmlCaptured} XML capturado(s), ultimo NSU '
        '${result.ultimoNsu.isEmpty ? '-' : result.ultimoNsu}.',
      );
    } catch (error) {
      if (!mounted) return;
      context.showUserError(
        'Nao foi possivel sincronizar ${documentType == 'nfe' ? 'NF-e' : 'NFS-e nacional'} '
        'pela Focus: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          if (documentType == 'nfe') {
            _syncingNfe = false;
          } else {
            _syncingNfse = false;
          }
        });
      }
    }
  }

  Future<void> _downloadXml(FocusIncomingDocument doc) async {
    if (!doc.canDownloadXml) {
      context.showUserError(
        'Este documento ainda nao possui XML salvo para download.',
      );
      return;
    }
    try {
      final result = await _service.downloadXml(documentId: doc.id);
      await saveBytesFile(
        filename: result.filename,
        bytes: result.bytes,
        mimeType: 'application/xml',
      );
      if (!mounted) return;
      context.showUserSuccess('XML preparado para download.');
    } catch (_) {
      if (!mounted) return;
      context.showUserError('O navegador bloqueou o download do XML.');
    }
  }

  static String _focusEnvSummary(Map<String, dynamic> data) {
    final sync = data['xml_sync_state'];
    if (sync is! Map) return '';
    final parts = <String>[];
    for (final kind in ['nfe', 'nfse_nacional']) {
      final sub = sync[kind];
      if (sub is Map) {
        final e = sub['environment']?.toString().trim() ?? '';
        if (e.isNotEmpty) {
          parts.add(kind == 'nfse_nacional' ? 'NFS-e: $e' : 'NF-e: $e');
        }
      }
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    if (widget.session.isDemo) {
      return AppWorkspaceCard(
        title: 'Documentos fiscais recebidos (Focus)',
        subtitle:
            'Na demonstracao, a leitura pode aparecer, mas a sincronizacao com a Focus nao corre — use o botao do banner amarelo para abrir o acesso real.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Empresa ativa no demo: ${widget.session.companyId}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppBrandColors.softText,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Com login real, este bloco executa a mesma integracao de producao '
              '(token e ambiente vêm de company_settings / configuracao da plataforma).',
              style: TextStyle(
                color: AppBrandColors.softText,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
        ),
      );
    }

    final companyStream = FirebaseFirestore.instance
        .collection('empresas')
        .doc(widget.session.companyId)
        .snapshots();
    final docsStream = FirebaseFirestore.instance
        .collection('empresas')
        .doc(widget.session.companyId)
        .collection('documentos_fiscais')
        .limit(60)
        .snapshots();

    return AppWorkspaceCard(
      title: 'Documentos fiscais via Focus',
      subtitle:
          'NF-e e NFS-e nacional recebidas: busca na Focus, gravacao em Firestore '
          'e XML no Storage quando a API envia corpo. Mesma integracao para empresa e contador.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              AppHeaderChip('Empresa ativa: ${widget.session.companyId}'),
              const AppHeaderChip('Isolamento por companyId'),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'A emissao de notas pela empresa nao e alterada aqui. Esta area apenas importa documentos que entraram para o seu CNPJ.',
            style: TextStyle(
              color: AppBrandColors.softText,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: companyStream,
            builder: (context, snapshot) {
              final data = snapshot.data?.data() ?? const <String, dynamic>{};
              final status = data['xml_sync_status']?.toString() ?? 'sem_sync';
              final nsu = data['ultimo_nsu']?.toString() ?? '-';
              final lastSync = _formatXmlDateTime(data['xml_ultima_sincronizacao']);
              final lastError = data['xml_ultimo_erro']?.toString() ?? '';
              final envLine = _focusEnvSummary(data);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      AppHeaderChip('Status sync: $status'),
                      AppHeaderChip('Ultimo NSU: $nsu'),
                      AppHeaderChip('Ultima sync: $lastSync'),
                    ],
                  ),
                  if (envLine.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Ambiente registo (ultima sync por tipo): $envLine',
                      style: const TextStyle(
                        color: AppBrandColors.softText,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                  if (lastError.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Ultimo erro: $lastError',
                      style: const TextStyle(
                        color: AppBrandColors.softText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: _syncingNfe ? null : () => _sync('nfe'),
                icon: _syncingNfe
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_for_offline_outlined),
                label: Text(
                  _syncingNfe ? 'Sincronizando NF-e...' : 'Sincronizar NF-e',
                ),
              ),
              FilledButton.icon(
                onPressed: _syncingNfse ? null : () => _sync('nfse_nacional'),
                icon: _syncingNfse
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.receipt_long_outlined),
                label: Text(
                  _syncingNfse
                      ? 'Sincronizando NFS-e nacional...'
                      : 'Sincronizar NFS-e nacional',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Lista de XMLs importados',
            style: TextStyle(
              color: AppBrandColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: docsStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text(
                  'Nao foi possivel carregar os XMLs capturados.',
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs =
                  snapshot.data!.docs
                      .map(FocusIncomingDocument.fromSnapshot)
                      .toList()
                    ..sort((a, b) {
                      final aTime =
                          a.dataEmissao ??
                          a.receivedAt ??
                          DateTime.fromMillisecondsSinceEpoch(0);
                      final bTime =
                          b.dataEmissao ??
                          b.receivedAt ??
                          DateTime.fromMillisecondsSinceEpoch(0);
                      return bTime.compareTo(aTime);
                    });
              if (docs.isEmpty) {
                return const Text(
                  'Nenhum documento recebido foi capturado ainda para a empresa ativa.',
                );
              }
              return Column(
                children: [
                  for (final doc in docs) ...[
                    _IncomingXmlTile(
                      doc: doc,
                      onDownloadXml: doc.canDownloadXml
                          ? () => _downloadXml(doc)
                          : null,
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _IncomingXmlTile extends StatelessWidget {
  const _IncomingXmlTile({required this.doc, required this.onDownloadXml});

  final FocusIncomingDocument doc;
  final VoidCallback? onDownloadXml;

  @override
  Widget build(BuildContext context) {
    final issuedLabel = _formatXmlDateTime(doc.dataEmissao, dateOnly: true);
    final totalLabel = doc.valorTotal == null
        ? '-'
        : 'R\$ ${doc.valorTotal!.toStringAsFixed(2).replaceAll('.', ',')}';

    return Material(
      color: const Color(0xFFF5F7FB),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppHeaderChip(doc.typeLabel),
                AppHeaderChip(
                  'Status: ${doc.status.isEmpty ? 'novo' : doc.status}',
                ),
                if (doc.manifestStatus.isNotEmpty)
                  AppHeaderChip('Manifesto: ${doc.manifestStatus}'),
                AppHeaderChip(doc.canDownloadXml ? 'XML salvo' : 'XML pendente'),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              doc.emitente.isEmpty ? 'Emitente nao informado' : doc.emitente,
              style: const TextStyle(
                color: AppBrandColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Chave: ${doc.chave.isEmpty ? '-' : doc.chave}\n'
              'NSU: ${doc.nsu.isEmpty ? '-' : doc.nsu}\n'
              'Numero/Serie: ${doc.number.isEmpty ? '-' : doc.number} / ${doc.series.isEmpty ? '-' : doc.series}\n'
              'Documento emitente: ${doc.cnpjEmitente.isEmpty ? '-' : doc.cnpjEmitente}\n'
              'Destinatario: ${doc.destinatario.isEmpty ? '-' : doc.destinatario}\n'
              'Emissao: $issuedLabel\n'
              'Valor: $totalLabel',
              style: const TextStyle(color: AppBrandColors.ink),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: onDownloadXml,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Baixar XML'),
                ),
                if (!doc.canDownloadXml)
                  const Text(
                    'Quando a Focus devolver o XML completo e ele for salvo no Storage, o download aparece aqui.',
                    style: TextStyle(
                      color: AppBrandColors.softText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _formatXmlDateTime(Object? value, {bool dateOnly = false}) {
  DateTime? date;
  if (value is Timestamp) {
    date = value.toDate();
  } else if (value is DateTime) {
    date = value;
  } else if (value is String) {
    date = DateTime.tryParse(value);
  }
  if (date == null) return '-';
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year.toString().padLeft(4, '0');
  if (dateOnly) return '$day/$month/$year';
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day/$month/$year $hour:$minute';
}
