import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/navigation/app_shell.dart';
import 'package:pontocerto/core/navigation/shell_page_chrome.dart';
import 'package:pontocerto/core/pdf/pdf_output.dart';
import 'package:pontocerto/core/theme/app_layout.dart';
import 'package:pontocerto/features/audit/domain/audit_log.dart';
import 'package:pontocerto/features/audit/presentation/audit_provider.dart';
import 'package:pontocerto/core/ui/app_user_message.dart';

class AuditPage extends ConsumerStatefulWidget {
  const AuditPage({super.key});

  @override
  ConsumerState<AuditPage> createState() => _AuditPageState();
}

class _AuditPageState extends ConsumerState<AuditPage> {
  final _searchController = TextEditingController();
  String _selectedModule = 'Todos';
  String _selectedAction = 'Todas';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessao = ref.watch(sessionProvider);
    if (sessao == null) {
      return const Scaffold(body: Center(child: Text('Sem sessao ativa')));
    }
    final logs = [...ref.watch(auditProvider)]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final modules = <String>{
      'Todos',
      ...logs.map((log) => log.module).where((value) => value.isNotEmpty),
    }.toList()..sort();
    final actions = <String>{
      'Todas',
      ...logs.map((log) => log.action).where((value) => value.isNotEmpty),
    }.toList()..sort();
    final filteredLogs = _filterLogs(logs);

    ref.read(shellPageChromeProvider.notifier).state = ShellPageChrome(
      header: const AppWorkspaceHeader(
        title: 'Auditoria operacional',
        subtitle:
            'Registros vêm da colecao audit_logs (gravacao pelo servidor em acoes sensiveis). A exportacao em PDF usa a lista filtrada abaixo.',
        chips: [
          AppHeaderChip('Rastreabilidade'),
          AppHeaderChip('Exportacao PDF'),
        ],
      ),
      beforeLogout: [
        IconButton(
          onPressed: filteredLogs.isEmpty ? null : () => _exportAuditPdf(filteredLogs),
          icon: const Icon(Icons.picture_as_pdf_outlined),
          tooltip: 'Exportar PDF',
        ),
      ],
    );

    return AppPageLayout(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: 'Buscar por acao, modulo, entidade ou perfil',
                        suffixIcon: IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.clear),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedModule,
                            decoration: const InputDecoration(
                              labelText: 'Modulo',
                            ),
                            items: [
                              for (final module in modules)
                                DropdownMenuItem(
                                  value: module,
                                  child: Text(module),
                                ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _selectedModule = value);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedAction,
                            decoration: const InputDecoration(
                              labelText: 'Acao',
                            ),
                            items: [
                              for (final action in actions)
                                DropdownMenuItem(
                                  value: action,
                                  child: Text(action),
                                ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _selectedAction = value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Resultados: ${filteredLogs.length}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: filteredLogs.isEmpty
                ? Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              logs.isEmpty
                                  ? 'Ainda nao ha eventos de auditoria para esta empresa. '
                                      'Eles aparecem quando o backend grava em audit_logs '
                                      '(ex.: alteracoes criticas, logins, exclusoes, conforme regras do servidor). '
                                      'A consulta nao cria registro; use o filtro acima apos comecar a trilha.'
                                  : 'Nenhum registro com os filtros atuais. Ajuste modulo, acao ou busca.',
                              style: const TextStyle(height: 1.4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 0,
                    ),
                    itemCount: filteredLogs.length,
                    itemBuilder: (context, index) {
                      final log = filteredLogs[index];
                      return Card(
                        child: ListTile(
                          title: Text(
                            '${_formatarDataHora(log.createdAt)} - ${log.module}',
                          ),
                          subtitle: Text(
                            'Acao: ${log.action} | Perfil: ${log.actorRole}\n'
                            'Entidade: ${log.entityPath}/${log.entityId}',
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  List<AuditLog> _filterLogs(List<AuditLog> logs) {
    final query = _searchController.text.trim().toLowerCase();
    return logs.where((log) {
      final moduleMatches =
          _selectedModule == 'Todos' || log.module == _selectedModule;
      final actionMatches =
          _selectedAction == 'Todas' || log.action == _selectedAction;
      final queryMatches =
          query.isEmpty ||
          log.module.toLowerCase().contains(query) ||
          log.action.toLowerCase().contains(query) ||
          log.entityPath.toLowerCase().contains(query) ||
          log.entityId.toLowerCase().contains(query) ||
          log.actorRole.toLowerCase().contains(query);
      return moduleMatches && actionMatches && queryMatches;
    }).toList();
  }

  String _formatarDataHora(DateTime data) {
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final hora = data.hour.toString().padLeft(2, '0');
    final minuto = data.minute.toString().padLeft(2, '0');
    return '$dia/$mes/${data.year} $hora:$minuto';
  }

  Future<void> _exportAuditPdf(List<AuditLog> logs) async {
    try {
      final pdf = pw.Document();
      final generatedAt = DateTime.now();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (context) => [
            pw.Text(
              'Relatorio de auditoria',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Text('Gerado em ${_formatarDataHora(generatedAt)}'),
            pw.Text('Modulo: $_selectedModule | Acao: $_selectedAction'),
            pw.Text(
              'Busca: ${_searchController.text.trim().isEmpty ? 'sem filtro textual' : _searchController.text.trim()}',
            ),
            pw.SizedBox(height: 12),
            for (final log in logs.take(200))
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 8),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.blueGrey200),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '${_formatarDataHora(log.createdAt)} | ${log.module}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text('Acao: ${log.action}'),
                    pw.Text('Perfil: ${log.actorRole}'),
                    pw.Text('Entidade: ${log.entityPath}/${log.entityId}'),
                  ],
                ),
              ),
          ],
        ),
      );
      await openPdfBytes(
        bytes: await pdf.save(),
        filename: 'auditoria-${generatedAt.millisecondsSinceEpoch}.pdf',
      );
      if (!mounted) return;
      if (context.mounted) { context.showUserMessage('Relatorio em PDF gerado.'); }
    } catch (_) {
      if (!mounted) return;
      if (context.mounted) { context.showUserMessage('Nao foi possivel gerar o PDF.'); }
    }
  }
}
