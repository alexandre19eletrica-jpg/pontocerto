import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/errors/app_error_mapper.dart';
import 'package:pontocerto/core/media/mobile_upload_optimizer.dart';
import 'package:pontocerto/core/navigation/app_shell.dart';
import 'package:pontocerto/core/navigation/shell_page_chrome.dart';
import 'package:pontocerto/core/theme/app_branding.dart';
import 'package:pontocerto/core/theme/app_layout.dart';
import 'package:pontocerto/core/ui/app_user_message.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:url_launcher/url_launcher.dart';

class ContractClausesPage extends ConsumerStatefulWidget {
  const ContractClausesPage({super.key});

  @override
  ConsumerState<ContractClausesPage> createState() => _ContractClausesPageState();
}

class _ContractClausesPageState extends ConsumerState<ContractClausesPage> {
  bool _salvando = false;

  @override
  Widget build(BuildContext context) {
    final sessao = ref.watch(sessionProvider);
    if (sessao == null || sessao.role == Role.employee) {
      ref.read(shellPageChromeProvider.notifier).state = const ShellPageChrome();
      return const Scaffold(
        body: Center(child: Text('Modulo disponivel apenas para empresa.')),
      );
    }

    ref.read(shellPageChromeProvider.notifier).state = const ShellPageChrome(
      header: AppWorkspaceHeader(
        title: 'Clausulas contratuais',
        subtitle:
            'Cada empresa pode manter suas proprias clausulas em PDF. Contratos com clientes usam a base comercial. Contratos de funcionarios usam a base trabalhista.',
        chips: [
          AppHeaderChip('Multiempresa'),
          AppHeaderChip('PDF com extracao de texto'),
        ],
      ),
    );
    return AppGradientBackground(
      child: AppPageLayout(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('company_settings')
              .doc(sessao.companyId)
              .snapshots(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data() ?? <String, dynamic>{};
            return ListView(
              children: [
                AppWorkspaceCard(
                  title: 'Regra de uso',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Propostas usam o resumo comercial. Contratos de prestacao de servico usam as clausulas comerciais completas. Contratos de funcionario usam as clausulas trabalhistas completas.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildClauseSection(
                  title: 'Clientes e prestacao de servico',
                  subtitle:
                      'Base comercial da empresa para propostas e contratos com clientes.',
                  summaryPdfUrlKey: 'clausesSummaryPdfUrl',
                  summaryTextKey: 'clausesSummaryText',
                  fullPdfUrlKey: 'clausesFullPdfUrl',
                  fullTextKey: 'clausesFullText',
                  companyId: sessao.companyId,
                  data: data,
                ),
                const SizedBox(height: 16),
                _buildClauseSection(
                  title: 'Funcionarios e RH',
                  subtitle:
                      'Base trabalhista da empresa para contratos de funcionarios.',
                  fullPdfUrlKey: 'employeeClausesFullPdfUrl',
                  fullTextKey: 'employeeClausesFullText',
                  companyId: sessao.companyId,
                  data: data,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildClauseSection({
    required String title,
    required String subtitle,
    required String fullPdfUrlKey,
    required String fullTextKey,
    required String companyId,
    required Map<String, dynamic> data,
    String? summaryPdfUrlKey,
    String? summaryTextKey,
  }) {
    final summaryPdfUrl = summaryPdfUrlKey == null
        ? ''
        : data[summaryPdfUrlKey]?.toString() ?? '';
    final fullPdfUrl = data[fullPdfUrlKey]?.toString() ?? '';
    final summaryText = summaryTextKey == null
        ? ''
        : data[summaryTextKey]?.toString() ?? '';
    final fullText = data[fullTextKey]?.toString() ?? '';

    return AppWorkspaceCard(
      title: title,
      subtitle: subtitle,
      child: Column(
        children: [
          if (summaryPdfUrlKey != null && summaryTextKey != null)
            _buildUploadTile(
              title: 'Resumo em PDF',
              subtitle: summaryPdfUrl.isEmpty
                  ? 'Nenhum PDF de resumo salvo.'
                  : '${_linhas(summaryText).length} linha(s) extraidas.',
              onUpload: () => _subirPdf(
                companyId: companyId,
                pdfUrlKey: summaryPdfUrlKey,
                textKey: summaryTextKey,
                filePrefix: 'clausulas-resumo',
              ),
              onOpen: summaryPdfUrl.isEmpty ? null : () => _abrirLink(summaryPdfUrl),
            ),
          _buildUploadTile(
            title: 'Clausulas completas em PDF',
            subtitle: fullPdfUrl.isEmpty
                ? 'Nenhum PDF completo salvo.'
                : '${_linhas(fullText).length} linha(s) extraidas.',
            onUpload: () => _subirPdf(
              companyId: companyId,
              pdfUrlKey: fullPdfUrlKey,
              textKey: fullTextKey,
              filePrefix: fullPdfUrlKey.contains('employee')
                  ? 'clausulas-funcionarios'
                  : 'clausulas-completas',
            ),
            onOpen: fullPdfUrl.isEmpty ? null : () => _abrirLink(fullPdfUrl),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _salvando
                      ? null
                      : () => _limparSecao(
                            companyId: companyId,
                            keys: _sectionKeys(
                              summaryPdfUrlKey: summaryPdfUrlKey,
                              summaryTextKey: summaryTextKey,
                              fullPdfUrlKey: fullPdfUrlKey,
                              fullTextKey: fullTextKey,
                            ),
                      ),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Limpar secao'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadTile({
    required String title,
    required String subtitle,
    required VoidCallback onUpload,
    VoidCallback? onOpen,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppBrandColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed: _salvando ? null : onUpload,
              child: const Text('Subir PDF'),
            ),
            if (onOpen != null)
              OutlinedButton(
                onPressed: onOpen,
                child: const Text('Abrir PDF'),
              ),
          ],
        ),
      ),
    );
  }

  List<String> _sectionKeys({
    String? summaryPdfUrlKey,
    String? summaryTextKey,
    required String fullPdfUrlKey,
    required String fullTextKey,
  }) {
    return [
      summaryPdfUrlKey,
      summaryTextKey,
      fullPdfUrlKey,
      fullTextKey,
    ].whereType<String>().toList();
  }

  Future<void> _subirPdf({
    required String companyId,
    required String pdfUrlKey,
    required String textKey,
    required String filePrefix,
  }) async {
    setState(() => _salvando = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        withData: true,
        allowedExtensions: const ['pdf'],
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      PreparedUploadData prepared;
      try {
        prepared = await MobileUploadOptimizer.preparePlatformFile(
          file: file,
          fallbackContentType: 'application/pdf',
        );
      } on MobileUploadOptimizerException catch (error) {
        _msg(error.message);
        return;
      }
      final bytes = prepared.bytes;
      if (bytes.isEmpty) {
        _msg('Arquivo PDF invalido.');
        return;
      }

      final doc = PdfDocument(inputBytes: bytes);
      final textoBruto = PdfTextExtractor(doc).extractText();
      doc.dispose();

      final nomeArquivo = '$filePrefix-${DateTime.now().millisecondsSinceEpoch}.pdf';
      final refStorage = FirebaseStorage.instance
          .ref()
          .child('companies/$companyId/clauses/$nomeArquivo');
      await refStorage.putData(
        bytes,
        SettableMetadata(contentType: 'application/pdf'),
      );
      final url = await refStorage.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('company_settings')
          .doc(companyId)
          .set({
            pdfUrlKey: url,
            textKey: _normalizarTexto(textoBruto),
            'clausesUpdatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      _msg('PDF salvo com sucesso.');
    } catch (e) {
      _msg(
        AppErrorMapper.messageFrom(
          e,
          fallback: 'Nao foi possivel salvar o PDF das clausulas.',
        ),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _limparSecao({
    required String companyId,
    required List<String> keys,
  }) async {
    setState(() => _salvando = true);
    try {
      await FirebaseFirestore.instance
          .collection('company_settings')
          .doc(companyId)
          .set({
            for (final key in keys) key: FieldValue.delete(),
            'clausesUpdatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      _msg('Clausulas removidas.');
    } catch (e) {
      _msg(
        AppErrorMapper.messageFrom(
          e,
          fallback: 'Nao foi possivel limpar as clausulas.',
        ),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _abrirLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  List<String> _linhas(String texto) {
    return texto
        .split('\n')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  String _normalizarTexto(String texto) {
    return texto
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{2,}'), '\n')
        .trim();
  }

  void _msg(String texto) {
    if (!mounted) return;
    context.showUserMessage(texto);
  }
}
