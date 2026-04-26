import 'dart:convert';

import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/errors/app_error_mapper.dart';
import 'package:pontocerto/core/navigation/app_shell.dart';
import 'package:pontocerto/core/navigation/shell_page_chrome.dart';
import 'package:pontocerto/core/theme/app_branding.dart';
import 'package:pontocerto/core/theme/app_layout.dart';
import 'package:pontocerto/core/utils/formatadores_input.dart';
import 'package:pontocerto/features/service_catalog/domain/service_catalog_item.dart';
import 'package:pontocerto/features/service_catalog/presentation/service_catalog_provider.dart';
import 'package:pontocerto/core/ui/app_user_message.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

enum _CatalogAction {
  importSpreadsheet,
  importPdf,
  uploadFile,
  clearAll,
  selectAll,
  deleteAll,
  seedInitial,
}

class ServiceCatalogPage extends ConsumerWidget {
  const ServiceCatalogPage({super.key});

  Widget _surface({
    required Widget child,
    EdgeInsetsGeometry margin = const EdgeInsets.only(bottom: 10),
  }) {
    return Container(
      margin: margin,
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
      child: child,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessao = ref.watch(sessionProvider);
    if (sessao == null) {
      return const Scaffold(body: Center(child: Text('Sem sessao ativa')));
    }

    final width = MediaQuery.sizeOf(context).width;
    final compactActions = width < 760;
    final isEmpresa = sessao.role != Role.employee;
    final itens = ref.watch(serviceCatalogProvider);
    final ativos = itens.where((i) => !i.pendingDelete).toList();
    final pendentesExclusao = isEmpresa
        ? itens.where((i) => i.pendingDelete).toList()
        : const <ServiceCatalogItem>[];
    final pendentesEdicao = isEmpresa
        ? itens.where((i) => i.hasPendingEdit).toList()
        : const <ServiceCatalogItem>[];

    ref.read(shellPageChromeProvider.notifier).state = ShellPageChrome(
      header: AppWorkspaceHeader(
        title: 'Catalogo de servicos',
        subtitle:
            'Base de servicos para composicao de tarefas, propostas e contratos com importacao e aprovacao de ajustes.',
        chips: const [
          AppHeaderChip('Banco operacional'),
          AppHeaderChip('Importacao assistida'),
        ],
      ),
      beforeLogout: compactActions
          ? [
              IconButton(
                onPressed: () => _abrirNovo(context, ref),
                icon: const Icon(Icons.add),
                tooltip: 'Adicionar servico',
              ),
              PopupMenuButton<_CatalogAction>(
                tooltip: 'Mais acoes',
                onSelected: (action) => _handleAction(
                  context,
                  ref,
                  action,
                  itens: itens,
                  ativos: ativos,
                  isEmpresa: isEmpresa,
                ),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: _CatalogAction.importSpreadsheet,
                    child: Text('Importar planilha'),
                  ),
                  const PopupMenuItem(
                    value: _CatalogAction.importPdf,
                    child: Text('Importar PDF'),
                  ),
                  const PopupMenuItem(
                    value: _CatalogAction.uploadFile,
                    child: Text('Subir arquivo do celular'),
                  ),
                  const PopupMenuItem(
                    value: _CatalogAction.clearAll,
                    child: Text('Limpar tudo'),
                  ),
                  if (isEmpresa)
                    const PopupMenuItem(
                      value: _CatalogAction.selectAll,
                      child: Text('Marcar todos'),
                    ),
                  if (isEmpresa)
                    const PopupMenuItem(
                      value: _CatalogAction.deleteAll,
                      child: Text('Apagar todos'),
                    ),
                  if (isEmpresa)
                    const PopupMenuItem(
                      value: _CatalogAction.seedInitial,
                      child: Text('Carregar lista inicial'),
                    ),
                ],
              ),
            ]
          : [
              if (isEmpresa)
                IconButton(
                  onPressed: () => _marcarTodos(context, ref, ativos),
                  icon: const Icon(Icons.select_all_rounded),
                  tooltip: 'Marcar todos',
                ),
              if (isEmpresa)
                IconButton(
                  onPressed: () => _apagarTodos(context, ref, itens),
                  icon: const Icon(Icons.delete_sweep_outlined),
                  tooltip: 'Apagar todos',
                ),
              IconButton(
                onPressed: () => _limparTudo(context, ref, itens),
                icon: const Icon(Icons.cleaning_services_outlined),
                tooltip: 'Limpar tudo',
              ),
              IconButton(
                onPressed: () => _abrirNovo(context, ref),
                icon: const Icon(Icons.add),
                tooltip: 'Adicionar servico',
              ),
              IconButton(
                onPressed: () => _abrirImportacaoPlanilha(context, ref),
                icon: const Icon(Icons.table_chart_outlined),
                tooltip: 'Importar planilha',
              ),
              IconButton(
                onPressed: () => _abrirImportacaoPdf(context, ref),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                tooltip: 'Importar PDF',
              ),
              IconButton(
                onPressed: () => _importarArquivoDoCelular(context, ref),
                icon: const Icon(Icons.upload_file_outlined),
                tooltip: 'Subir arquivo do celular',
              ),
              if (isEmpresa)
                IconButton(
                  onPressed: () => _seedInicial(ref),
                  icon: const Icon(Icons.download_for_offline_outlined),
                  tooltip: 'Carregar lista inicial',
                ),
            ],
    );

    return AppGradientBackground(
        child: AppPageLayout(
          child: ListView(
            children: [
              AppWorkspaceCard(
                title: 'Panorama',
                subtitle:
                    'Base operacional de servicos para tarefas, propostas e contratos, com controle de pendencias e aprovacoes.',
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    AppMetricCard(
                      label: 'Ativos',
                      value: ativos.length.toString(),
                      caption: 'Itens disponiveis para uso',
                    ),
                    AppMetricCard(
                      label: 'Exclusoes',
                      value: pendentesExclusao.length.toString(),
                      caption: 'Pendentes de confirmacao',
                    ),
                    AppMetricCard(
                      label: 'Edicoes',
                      value: pendentesEdicao.length.toString(),
                      caption: 'Aguardando aprovacao',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppWorkspaceCard(
                title: 'Servicos ativos',
                subtitle:
                    'Itens prontos para compor tarefas, propostas e contratos.',
                child: Column(
                  children: [
                    if (ativos.isEmpty)
                      const ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Nenhum servico ativo.'),
                      ),
                    ...ativos.map(
                      (item) => _surface(
                        child: ListTile(
                          leading: const Icon(Icons.dataset_outlined),
                          title: Text(item.nome),
                          subtitle: Text(_formatarMoeda(item.valorCents)),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                onPressed: () => _abrirEditar(context, ref, item),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                onPressed: () => ref.read(serviceCatalogProvider.notifier).delete(item),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isEmpresa) ...[
                const SizedBox(height: 16),
                AppWorkspaceCard(
                  title: 'Itens excluidos pendentes',
                  subtitle:
                      'Solicitacoes de exclusao aguardando confirmacao da empresa.',
                  child: Column(
                    children: [
                      if (pendentesExclusao.isEmpty)
                        const ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Nenhum item pendente de exclusao.'),
                        ),
                      ...pendentesExclusao.map(
                        (item) => _surface(
                          child: ListTile(
                            title: Text(item.nome),
                            subtitle: Text(
                              '${_formatarMoeda(item.valorCents)}'
                              '${item.pendingDeleteByName.isEmpty ? '' : ' | solicitado por ${item.pendingDeleteByName}'}',
                            ),
                            trailing: Wrap(
                              spacing: 4,
                              children: [
                                IconButton(
                                  onPressed: () => ref.read(serviceCatalogProvider.notifier).approveDelete(item),
                                  icon: const Icon(Icons.check_circle_outline),
                                  tooltip: 'Confirmar exclusao',
                                ),
                                IconButton(
                                  onPressed: () => ref.read(serviceCatalogProvider.notifier).rejectDelete(item),
                                  icon: const Icon(Icons.undo),
                                  tooltip: 'Retornar ao banco',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppWorkspaceCard(
                  title: 'Edicoes pendentes',
                  subtitle:
                      'Alteracoes aguardando confirmacao antes de entrarem na base operacional.',
                  child: Column(
                    children: [
                      if (pendentesEdicao.isEmpty)
                        const ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Nenhuma edicao pendente.'),
                        ),
                      ...pendentesEdicao.map(
                        (item) => _surface(
                          child: ListTile(
                            title: Text(item.nome),
                            subtitle: Text(
                              'Atual: ${_formatarMoeda(item.valorCents)}\n'
                              'Pendente: ${(item.pendingEditNome ?? item.nome)} - ${_formatarMoeda(item.pendingEditValorCents ?? item.valorCents)}'
                              '${item.pendingEditByName.isEmpty ? '' : '\nSolicitado por ${item.pendingEditByName}'}',
                            ),
                            isThreeLine: true,
                            trailing: Wrap(
                              spacing: 4,
                              children: [
                                IconButton(
                                  onPressed: () => ref.read(serviceCatalogProvider.notifier).approveEdit(item),
                                  icon: const Icon(Icons.check_circle_outline),
                                  tooltip: 'Confirmar edicao',
                                ),
                                IconButton(
                                  onPressed: () => ref.read(serviceCatalogProvider.notifier).rejectEdit(item),
                                  icon: const Icon(Icons.undo),
                                  tooltip: 'Retornar ao banco',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    _CatalogAction action, {
    required List<ServiceCatalogItem> itens,
    required List<ServiceCatalogItem> ativos,
    required bool isEmpresa,
  }) async {
    switch (action) {
      case _CatalogAction.importSpreadsheet:
        return _abrirImportacaoPlanilha(context, ref);
      case _CatalogAction.importPdf:
        return _abrirImportacaoPdf(context, ref);
      case _CatalogAction.uploadFile:
        return _importarArquivoDoCelular(context, ref);
      case _CatalogAction.clearAll:
        return _limparTudo(context, ref, itens);
      case _CatalogAction.selectAll:
        if (isEmpresa) return _marcarTodos(context, ref, ativos);
        return;
      case _CatalogAction.deleteAll:
        if (isEmpresa) return _apagarTodos(context, ref, itens);
        return;
      case _CatalogAction.seedInitial:
        if (isEmpresa) return _seedInicial(ref);
        return;
    }
  }

  Future<void> _abrirNovo(BuildContext context, WidgetRef ref) async {
    final nomeCtrl = TextEditingController();
    final valorCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Novo servico'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nomeCtrl,
              decoration: const InputDecoration(labelText: 'Nome do servico'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: valorCtrl,
              inputFormatters: [CurrencyPtBrInputFormatter()],
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Valor (R\$)'),
            ),
          ],
        ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                nomeCtrl.clear();
                valorCtrl.clear();
              },
              child: const Text('Limpar tudo'),
            ),
            ElevatedButton(
              onPressed: () async {
                final nome = _normalizarNomeServico(nomeCtrl.text);
                final valor = _parseReaisParaCents(valorCtrl.text);
                if (nome.isEmpty || valor == null || valor <= 0) return;
                await ref.read(serviceCatalogProvider.notifier).add(
                  nome: nome,
                valorCents: valor,
              );
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    nomeCtrl.dispose();
    valorCtrl.dispose();
  }

  Future<void> _abrirEditar(
    BuildContext context,
    WidgetRef ref,
    ServiceCatalogItem item,
  ) async {
    final nomeCtrl = TextEditingController(text: item.nome);
    final valorCtrl = TextEditingController(text: _centsParaInput(item.valorCents));
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar servico'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nomeCtrl,
              decoration: const InputDecoration(labelText: 'Nome do servico'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: valorCtrl,
              inputFormatters: [CurrencyPtBrInputFormatter()],
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Valor (R\$)'),
            ),
          ],
        ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                nomeCtrl.clear();
                valorCtrl.clear();
              },
              child: const Text('Limpar tudo'),
            ),
            ElevatedButton(
              onPressed: () async {
                final nome = _normalizarNomeServico(nomeCtrl.text);
                final valor = _parseReaisParaCents(valorCtrl.text);
                if (nome.isEmpty || valor == null || valor <= 0) return;
                await ref.read(serviceCatalogProvider.notifier).edit(
                  item: item,
                nome: nome,
                valorCents: valor,
              );
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    nomeCtrl.dispose();
    valorCtrl.dispose();
  }

  Future<void> _seedInicial(WidgetRef ref) async {
    final notifier = ref.read(serviceCatalogProvider.notifier);
    final existentes = ref
        .read(serviceCatalogProvider)
        .map((e) => e.nome.trim().toLowerCase())
        .toSet();
    for (final s in _seedServices) {
      if (existentes.contains(s.$1.trim().toLowerCase())) continue;
      await notifier.add(nome: s.$1, valorCents: s.$2);
    }
  }

  Future<void> _abrirImportacaoPlanilha(BuildContext context, WidgetRef ref) async {
    final textoCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Importar planilha'),
        content: SizedBox(
          width: 560,
          child: TextField(
            controller: textoCtrl,
            maxLines: 12,
            decoration: const InputDecoration(
              hintText:
                  'Cole linhas no formato:\n'
                  'NOME DO SERVICO; 50,00\n'
                  'ou\n'
                  'NOME DO SERVICO - R\$ 50,00',
            ),
          ),
        ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => textoCtrl.clear(),
              child: const Text('Limpar tudo'),
            ),
            ElevatedButton(
              onPressed: () async {
                final drafts = _parsePlanilha(textoCtrl.text);
                if (drafts.isEmpty) return;
              if (ctx.mounted) Navigator.of(ctx).pop();
              await _revisarImportacao(context, ref, drafts);
            },
            child: const Text('Ler dados'),
          ),
        ],
      ),
    );
    textoCtrl.dispose();
  }

  Future<void> _abrirImportacaoPdf(BuildContext context, WidgetRef ref) async {
    final textoCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Importar PDF'),
        content: SizedBox(
          width: 560,
          child: TextField(
            controller: textoCtrl,
            maxLines: 12,
            decoration: const InputDecoration(
              hintText:
                  'Cole o texto extraido do PDF.\n'
                  'O sistema tentara montar os servicos e valores automaticamente.',
            ),
          ),
        ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => textoCtrl.clear(),
              child: const Text('Limpar tudo'),
            ),
            ElevatedButton(
              onPressed: () async {
                final drafts = _parsePdfTexto(textoCtrl.text);
                if (drafts.isEmpty) return;
              if (ctx.mounted) Navigator.of(ctx).pop();
              await _revisarImportacao(context, ref, drafts);
            },
            child: const Text('Ler dados'),
          ),
        ],
      ),
    );
    textoCtrl.dispose();
  }

  Future<void> _revisarImportacao(
    BuildContext context,
    WidgetRef ref,
    List<_ServicoDraft> drafts,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revisar importacao'),
        content: SizedBox(
          width: 680,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: drafts.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final d = drafts[i];
              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          initialValue: d.nome,
                          onChanged: (v) => d.nome = v,
                          decoration: const InputDecoration(labelText: 'Servico'),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Linha ${d.linhaNumero}: ${d.linhaOrigem}',
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 140,
                    child: TextFormField(
                      initialValue: _centsParaInput(d.valorCents),
                      onChanged: (v) => d.valorCents = _parseReaisParaCents(v) ?? d.valorCents,
                      decoration: const InputDecoration(labelText: 'Valor'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final prontos = <({String nome, int valorCents})>[
                for (final d in drafts)
                  if (d.nome.trim().isNotEmpty && d.valorCents > 0)
                    (nome: _normalizarNomeServico(d.nome), valorCents: d.valorCents),
              ];
              try {
                await ref.read(serviceCatalogProvider.notifier).addMany(prontos);
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (context.mounted) {
                  context.showUserSuccess(
                    'Importacao concluida: ${prontos.length} servicos processados.',
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  context.showUserError(
                    AppErrorMapper.messageFrom(
                      e,
                      fallback: 'Nao foi possivel importar agora. Tente novamente.',
                    ),
                  );
                }
              }
            },
            child: const Text('Importar tudo'),
          ),
        ],
      ),
    );
  }

  Future<void> _marcarTodos(
    BuildContext context,
    WidgetRef ref,
    List<ServiceCatalogItem> ativos,
  ) async {
    for (final item in ativos) {
      await ref.read(serviceCatalogProvider.notifier).delete(item);
    }
    if (context.mounted) {
      if (context.mounted) { context.showUserMessage('Todos os servicos foram marcados.'); }
    }
  }

  Future<void> _apagarTodos(
    BuildContext context,
    WidgetRef ref,
    List<ServiceCatalogItem> itens,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apagar todos'),
        content: const Text('Deseja apagar todos os servicos do banco?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    final notifier = ref.read(serviceCatalogProvider.notifier);
    for (final item in itens) {
      if (item.pendingDelete) {
        await notifier.approveDelete(item);
      } else {
        await notifier.delete(item);
      }
    }
    if (context.mounted) {
      if (context.mounted) { context.showUserMessage('Todos os servicos foram apagados.'); }
    }
  }

  Future<void> _limparTudo(
    BuildContext context,
    WidgetRef ref,
    List<ServiceCatalogItem> itens,
  ) async {
    final notifier = ref.read(serviceCatalogProvider.notifier);
    for (final item in itens) {
      if (item.pendingDelete) {
        await notifier.rejectDelete(item);
      }
      if (item.hasPendingEdit) {
        await notifier.rejectEdit(item);
      }
    }
    if (context.mounted) {
      if (context.mounted) { context.showUserMessage('Pendencias limpas com sucesso.'); }
    }
  }

  Future<void> _importarArquivoDoCelular(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      withData: true,
      allowedExtensions: const ['pdf', 'csv', 'txt', 'xlsx', 'xls'],
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) return;

    final ext = (file.extension ?? '').toLowerCase();
    List<_ServicoDraft> drafts = <_ServicoDraft>[];

    if (ext == 'pdf') {
      drafts = _parsePdfBytes(bytes);
    } else if (ext == 'xlsx' || ext == 'xls') {
      drafts = _parseExcelBytes(bytes);
    } else {
      drafts = _parsePlanilha(_bytesToText(bytes));
    }

    if (drafts.isEmpty) {
      if (context.mounted) {
        context.showUserMessage('Nao ha registros identificados no arquivo.');
      }
      return;
    }

    if (!context.mounted) return;
    await _revisarImportacao(context, ref, drafts);
  }

  String _bytesToText(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return latin1.decode(bytes, allowInvalid: true);
    }
  }

  List<_ServicoDraft> _parseExcelBytes(List<int> bytes) {
    final excel = Excel.decodeBytes(bytes);
    final linhas = <String>[];
    for (final tableName in excel.tables.keys) {
      final table = excel.tables[tableName];
      if (table == null) continue;
      for (final row in table.rows) {
        final texto = row
            .map((c) => c?.value?.toString().trim() ?? '')
            .where((e) => e.isNotEmpty)
            .join(' ; ');
        if (texto.isNotEmpty) linhas.add(texto);
      }
    }
    return _parsePlanilha(linhas.join('\n'));
  }

  List<_ServicoDraft> _parsePdfBytes(List<int> bytes) {
    final doc = PdfDocument(inputBytes: bytes);
    final texto = PdfTextExtractor(doc).extractText();
    doc.dispose();
    return _parsePdfTexto(texto);
  }

  List<_ServicoDraft> _parsePlanilha(String texto) {
    final linhas = texto
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final out = <_ServicoDraft>[];
    for (var i = 0; i < linhas.length; i++) {
      final l = linhas[i];
      final parts = l.split(RegExp(r'[;\t]'));
      if (parts.length >= 2) {
        final nome = _extractNomeFromParts(parts);
        final valor = _extractValorAfterRS(parts.join(' ')) ??
            _parseReaisParaCents(parts.join(' '));
        if (nome.isNotEmpty && valor != null && valor > 0) {
          out.add(_ServicoDraft(_normalizarNomeServico(nome), valor, i + 1, l));
          continue;
        }
      }
      final valor = _extractValorAfterRS(l);
      if (valor == null || valor <= 0) continue;
      final nome = _cleanupNome(
        l.replaceFirst(RegExp(r'R\$\s*[0-9\.\,]+'), ''),
      );
      if (nome.isNotEmpty) {
        out.add(_ServicoDraft(_normalizarNomeServico(nome), valor, i + 1, l));
      }
    }
    return out;
  }

  List<_ServicoDraft> _parsePdfTexto(String texto) {
    final linhas = texto
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final out = <_ServicoDraft>[];
    for (var i = 0; i < linhas.length; i++) {
      final linha = linhas[i];
      final match = RegExp(r'R\$\s*([0-9\.\,]+)').firstMatch(linha);
      final valor = _extractValorAfterRS(linha);
      if (valor == null || valor <= 0) continue;
      String nome = '';
      if (match != null && match.start > 0) {
        nome = _cleanupNome(linha.substring(0, match.start));
      }
      for (var p = i - 1; p >= 0; p--) {
        if (nome.isNotEmpty) break;
        final cand = linhas[p];
        if (_extractValorAfterRS(cand) == null && cand.length > 4) {
          nome = _cleanupNome(cand);
          break;
        }
      }
      if (nome.isNotEmpty) {
        out.add(_ServicoDraft(_normalizarNomeServico(nome), valor, i + 1, linha));
      }
    }
    return out;
  }

  int? _parseReaisParaCents(String valor) {
    var texto = valor.trim().replaceAll('R\$', '');
    texto = texto.replaceAll(RegExp(r'[^0-9,\.]'), '');
    if (texto.isEmpty) return null;

    final lastComma = texto.lastIndexOf(',');
    final lastDot = texto.lastIndexOf('.');
    final sepIndex = lastComma > lastDot ? lastComma : lastDot;

    if (sepIndex < 0) {
      final inteiro = int.tryParse(texto.replaceAll(RegExp(r'[^0-9]'), ''));
      if (inteiro == null) return null;
      return inteiro * 100;
    }

    final parteInteira = texto
        .substring(0, sepIndex)
        .replaceAll(RegExp(r'[^0-9]'), '');
    final parteDecimalRaw = texto
        .substring(sepIndex + 1)
        .replaceAll(RegExp(r'[^0-9]'), '');

    final inteiro = int.tryParse(parteInteira.isEmpty ? '0' : parteInteira);
    if (inteiro == null) return null;

    final dec2 = parteDecimalRaw.isEmpty
        ? '00'
        : (parteDecimalRaw.length == 1
            ? '${parteDecimalRaw}0'
            : parteDecimalRaw.substring(0, 2));
    final decimal = int.tryParse(dec2);
    if (decimal == null) return null;
    return inteiro * 100 + decimal;
  }

  int? _extractValorAfterRS(String linha) {
    final match = RegExp(r'R\$\s*([0-9\.\,]+)').firstMatch(linha);
    if (match == null) return null;
    final somenteValor = match.group(1) ?? '';
    if (somenteValor.isEmpty) return null;
    return _parseReaisParaCents(somenteValor);
  }

  String _extractNomeFromParts(List<String> parts) {
    final tokens = parts.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (tokens.isEmpty) return '';
    final candidatos = <String>[];
    for (final t in tokens) {
      final maybeValor = _extractValorAfterRS(t) ?? _parseReaisParaCents(t);
      final isIndice = RegExp(r'^\d+$').hasMatch(t);
      if (maybeValor != null || isIndice) continue;
      candidatos.add(_cleanupNome(t));
    }
    if (candidatos.isEmpty) return '';
    candidatos.sort((a, b) => b.length.compareTo(a.length));
    return candidatos.first;
  }

  String _cleanupNome(String texto) {
    return texto
        .replaceFirst(RegExp(r'^\d+\s*[\)\-:;]*\s*'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(' - ', ' ')
        .trim();
  }

  String _normalizarNomeServico(String texto) {
    var t = texto
        .replaceAll(RegExp(r'[\u0000-\u001F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    while (t.isNotEmpty && !_isNomeServicoValido(t.codeUnitAt(0))) {
      t = t.substring(1);
    }
    while (t.isNotEmpty && !_isNomeServicoValido(t.codeUnitAt(t.length - 1))) {
      t = t.substring(0, t.length - 1);
    }
    return t.toUpperCase();
  }

  bool _isNomeServicoValido(int codeUnit) {
    final isDigit = codeUnit >= 48 && codeUnit <= 57;
    final isUpper = codeUnit >= 65 && codeUnit <= 90;
    final isLower = codeUnit >= 97 && codeUnit <= 122;
    final isLatinAccent = codeUnit >= 192 && codeUnit <= 255;
    return isDigit || isUpper || isLower || isLatinAccent;
  }

  String _centsParaInput(int cents) {
    final reais = cents ~/ 100;
    final centavos = (cents % 100).toString().padLeft(2, '0');
    return '$reais,$centavos';
  }

  String _formatarMoeda(int cents) {
    final reais = cents ~/ 100;
    final centavos = (cents % 100).toString().padLeft(2, '0');
    final reaisTexto = reais.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (m) => '.',
    );
    return 'R\$ $reaisTexto,$centavos';
  }
}

class _ServicoDraft {
  _ServicoDraft(this.nome, this.valorCents, this.linhaNumero, this.linhaOrigem);

  String nome;
  int valorCents;
  int linhaNumero;
  String linhaOrigem;
}

const List<(String, int)> _seedServices = <(String, int)>[
  ('INSTALACAO/TROCA/REPARO LAMPADA FLUOR LED ARAND SPOT PAFLON', 5000),
  ('INSTALACAO/TROCA/REPARO LUSTRE LUMINARIA SIMPLES', 5000),
  ('INSTALACAO/TROCA/REPARO LUSTRE LUMINARIA GRANDE', 9000),
  ('INSTALACAO/TROCA/REPARO PONTO ILUMINACAO JARDIM POSTE PAREDE', 5000),
  ('INSTALACAO/TROCA/REPARO REFLETOR POSTE PAREDE COMUM', 5000),
  ('INSTALACAO/TROCA/REPARO INTERRUPTOR SIMPLES DUPLO TRIPLO', 5000),
  ('INSTALACAO/TROCA/REPARO TOMADA 10A SIMPLES COM MATERIAL', 6000),
  ('INSTALACAO/TROCA/REPARO TOMADA DUPLA', 5000),
  ('INSTALACAO/TROCA/REPARO TOMADA TRIPLA', 5000),
  ('CHAVE DE BOIA SUPERIOR E INFERIOR RESIDENCIA', 15000),
  ('INSTALACAO/TROCA/REPARO VENTILADOR DE TETO', 12000),
  ('INSTALACAO/TROCA/REPARO VENTILADOR DE PAREDE', 12000),
  ('INSTALACAO/TROCA/REPARO CHUVEIRO ELETRICO SIMPLES', 10000),
  ('INSTALACAO/TROCA/REPARO CHUVEIRO LUXO', 10000),
  ('TORNEIRA ELETRICA', 15000),
  ('CAMPAINHA ATE 20M', 15000),
  ('INTERFONE 1 CHAMADA', 15000),
  ('INTERFONE 2 CHAMADAS', 17000),
  ('INTERFONE 4 CHAMADAS', 30000),
  ('VIDEO PORTEIRO', 15000),
  ('CAMERAS CFTV 1 CAMERA', 8000),
  ('CAMERAS CFTV + DVR', 15000),
  ('PORTAO ELETRONICO DESLIZANTE', 20000),
  ('PORTAO ELETRONICO PIVOTANTE/BASCULANTE', 37000),
  ('BOTOEIRA FECHADURA ELETRONICA', 12000),
  ('FECHADURA ELETRONICA PORTAO SOCIAL', 12000),
  ('EXAUSTOR COZINHA OU BANHEIRO', 17000),
  ('DISJUNTOR MONOFASICO', 3000),
  ('DISJUNTOR BIFASICO', 5000),
  ('DISJUNTOR TRIFASICO', 7000),
  ('IDR INTERRUPTOR DIFERENCIAL RESIDUAL', 9000),
  ('DPS PROTECAO CONTRA SURTOS', 7000),
  ('BARRAMENTO PENTE MONOPOLAR QDC', 3500),
  ('BARRAMENTO PENTE BIPOLAR QDC', 4500),
  ('BARRAMENTO PENTE TRIPOLAR QDC', 5500),
  ('BARRAMENTO DE NEUTRO/TERRA', 5000),
  ('CIRCUITO DE ATERRAMENTO ATE 5 HASTES', 34000),
  ('INSTALACAO E MONTAGEM QDC 6 CIRCUITOS + DR + DPS', 37000),
  ('INSTALACAO E MONTAGEM QDC 12 CIRCUITOS + DR + DPS', 57000),
  ('INSTALACAO E MONTAGEM QDC 18 CIRCUITOS + DR + DPS', 71000),
  ('INSTALACAO E MONTAGEM QDC 24 CIRCUITOS + DR + DPS', 95000),
  ('ENTRADA MONOFASICA QM PARA QDC', 15000),
  ('ENTRADA BIFASICA OU TRIFASICA QM PARA QDC', 19000),
  ('ALIMENTACAO AR CONDICIONADO CHUVEIRO ETC', 10000),
  ('ALIMENTACAO PARA PONTO ESPECIFICO ATE 20M', 15000),
  ('CIRCUITO INTERNO/EXTERNO TOMADAS ATE 10M', 9000),
  ('CURTO CIRCUITO MONOFASICO M/L', 12000),
  ('CURTO CIRCUITO BIFASICO M/L', 15000),
  ('CURTO CIRCUITO TRIFASICO M/L', 15000),
  ('MODULO INTERRUPTOR INTELIGENTE COM TECLA', 9000),
  ('MODULO TOMADA INTELIGENTE', 9000),
  ('CONFIGURAR LAMPADA INTELIGENTE', 9000),
  ('FITA DE LED INTELIGENTE 5 METROS', 15000),
  ('CORTINA WIFI', 12000),
  ('SENSOR DE PRESENCA WIFI', 12000),
  ('CAMERA SEGURANCA CFTV', 15000),
  ('ROTEADOR', 12000),
  ('CONTROLADOR INFRAVERMELHO WIFI', 12000),
  ('RETIRAR ILUMINACAO DE ENFEITE FACHADA', 12000),
  ('DIARIA ELETRICISTA', 50000),
  ('DIARIA PEDREIRO', 35000),
  ('DIARIA AUXILIAR DE ELETRICA', 25000),
  ('VISITA TECNICA', 25000),
  ('DESPESA ALIMENTACAO DIARIA ATE 3 FUNCIONARIOS', 10000),
  ('DESPESA COM COMBUSTIVEL DIARIO', 10000),
  ('TAXA DE ADMINISTRACAO 20% DO VALOR DA OBRA', 20000),
  ('VALOR M2 ACABADO CONSTRUCAO CIVIL GO', 152200),
  ('VALOR M2 FORRO DE GESSO LISO', 7000),
  ('VALETA PARA ALIMENTACAO METRO LINEAR', 15000),
  ('CHAVE BOIA SUPERIOR/INFERIOR CB2010', 15000),
  ('ADEQUACAO DE FIACAO EXTERNA/INTERNA METRO LINEAR', 10000),
  ('INSTALACAO CASA PROJETO CAIXA ECONOMICA', 95000),
  ('MARCAR CAIXINHAS E LEITURA DE PROJETOS HORA', 7500),
  ('TORNEIRA BOIA ALTA VAZAO INTELIGENTE', 19000),
  ('INSTALACAO/REPARO/MANUTENCAO GERAL DIARIA ATE 2 FUNC', 85000),
  ('COLOCACAO TOMADA 10A', 4500),
  ('COLOCACAO TOMADA RJ45 COM MATERIAL', 6500),
];

