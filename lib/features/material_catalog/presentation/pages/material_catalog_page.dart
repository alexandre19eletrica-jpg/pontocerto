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
import 'package:pontocerto/features/material_catalog/domain/material_catalog_item.dart';
import 'package:pontocerto/features/material_catalog/presentation/material_catalog_provider.dart';
import 'package:pontocerto/core/ui/app_user_message.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

enum _MaterialCatalogAction { add, importSpreadsheet, importPdf, uploadFile }

class MaterialCatalogPage extends ConsumerWidget {
  const MaterialCatalogPage({super.key});

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
      return const Scaffold(
        body: Center(child: Text('Sem sessao ativa')),
      );
    }

    final width = MediaQuery.sizeOf(context).width;
    final compactActions = width < 760;
    final isEmpresa = sessao.role != Role.employee;
    final materiais = ref.watch(materialCatalogProvider);
    final ativos = materiais.where((item) => !item.pendingCreate).toList();
    final pendentesAdicao = isEmpresa
        ? materiais.where((item) => item.pendingCreate).toList()
        : const <MaterialCatalogItem>[];
    final pendentesEdicao = isEmpresa
        ? materiais
            .where((item) => !item.pendingCreate && item.hasPendingEdit)
            .toList()
        : const <MaterialCatalogItem>[];

    ref.read(shellPageChromeProvider.notifier).state = ShellPageChrome(
      header: AppWorkspaceHeader(
        title: 'Banco de materiais',
        subtitle:
            'Cada empresa mantem sua base de materiais por planilha, PDF ou cadastro direto. Funcionarios podem sugerir inclusoes e edicoes para aprovacao da empresa.',
        chips: [
          const AppHeaderChip('Multiempresa'),
          const AppHeaderChip('Importacao por arquivo'),
          AppHeaderChip('Base ${ativos.length}'),
        ],
      ),
      beforeLogout: compactActions
          ? [
              IconButton(
                onPressed: () => _abrirEditor(context, ref),
                icon: const Icon(Icons.add),
                tooltip: 'Adicionar material',
              ),
              if (isEmpresa)
                PopupMenuButton<_MaterialCatalogAction>(
                  tooltip: 'Mais acoes',
                  onSelected: (action) => _handleAction(context, ref, action),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: _MaterialCatalogAction.importSpreadsheet,
                      child: Text('Importar planilha'),
                    ),
                    PopupMenuItem(
                      value: _MaterialCatalogAction.importPdf,
                      child: Text('Importar PDF'),
                    ),
                    PopupMenuItem(
                      value: _MaterialCatalogAction.uploadFile,
                      child: Text('Subir arquivo do celular'),
                    ),
                  ],
                ),
            ]
          : [
              IconButton(
                onPressed: () => _abrirEditor(context, ref),
                icon: const Icon(Icons.add),
                tooltip: 'Adicionar material',
              ),
              if (isEmpresa)
                IconButton(
                  onPressed: () => _abrirImportacaoPlanilha(context, ref),
                  icon: const Icon(Icons.table_chart_outlined),
                  tooltip: 'Importar planilha',
                ),
              if (isEmpresa)
                IconButton(
                  onPressed: () => _abrirImportacaoPdf(context, ref),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  tooltip: 'Importar PDF',
                ),
              if (isEmpresa)
                IconButton(
                  onPressed: () => _importarArquivo(context, ref),
                  icon: const Icon(Icons.upload_file_outlined),
                  tooltip: 'Subir arquivo do celular',
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
                    'Base de materiais reaproveitavel na operacao, no orcamento e no fechamento dos servicos.',
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    AppMetricCard(
                      label: 'Materiais',
                      value: ativos.length.toString(),
                      caption: 'Itens na base compartilhada',
                    ),
                    const AppMetricCard(
                      label: 'Cadastro',
                      value: 'Direto',
                      caption: 'Inclusao manual disponivel',
                    ),
                    AppMetricCard(
                      label: 'Pendencias',
                      value: '${pendentesAdicao.length + pendentesEdicao.length}',
                      caption: isEmpresa
                          ? 'Aguardando aprovacao'
                          : 'Sugestoes em analise',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppWorkspaceCard(
                title: 'Base compartilhada da empresa',
                subtitle:
                    'Materiais prontos para compor tarefas e orcamentos no fluxo da empresa.',
                child: Column(
                  children: [
                    if (ativos.isEmpty)
                      const ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Nenhum material cadastrado.'),
                        subtitle: Text(
                          'Use o botao + ou importe planilha/PDF para montar o banco da empresa.',
                        ),
                      ),
                    ...ativos.map(
                      (item) => _surface(
                        child: ListTile(
                          leading: const Icon(Icons.construction_outlined),
                          title: Text(item.nome),
                          subtitle: Text(
                            '${item.quantidadeNormalizada} ${item.unidadeNormalizada}'
                            '${item.observacaoNormalizada.isEmpty ? '' : ' | ${item.observacaoNormalizada}'}',
                          ),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                onPressed: () =>
                                    _abrirEditor(context, ref, material: item),
                                icon: const Icon(Icons.edit_outlined),
                                tooltip: 'Editar',
                              ),
                              if (isEmpresa)
                                IconButton(
                                  onPressed: () => ref
                                      .read(materialCatalogProvider.notifier)
                                      .delete(item.id),
                                  icon: const Icon(Icons.delete_outline),
                                  tooltip: 'Excluir',
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
                  title: 'Adicoes pendentes',
                  subtitle:
                      'Sugestoes de novos materiais feitas pela equipe aguardando aprovacao da empresa.',
                  child: Column(
                    children: [
                      if (pendentesAdicao.isEmpty)
                        const ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Nenhuma adicao pendente.'),
                        ),
                      ...pendentesAdicao.map(
                        (item) => _surface(
                          child: ListTile(
                            leading: const Icon(Icons.playlist_add_check_outlined),
                            title: Text(item.nome),
                            subtitle: Text(
                              '${item.quantidadeNormalizada} ${item.unidadeNormalizada}'
                              '${item.observacaoNormalizada.isEmpty ? '' : ' | ${item.observacaoNormalizada}'}'
                              '${item.pendingCreateByName.isEmpty ? '' : '\nSolicitado por ${item.pendingCreateByName}'}',
                            ),
                            isThreeLine: item.pendingCreateByName.isNotEmpty,
                            trailing: Wrap(
                              spacing: 4,
                              children: [
                                IconButton(
                                  onPressed: () => ref
                                      .read(materialCatalogProvider.notifier)
                                      .approveCreate(item),
                                  icon: const Icon(Icons.check_circle_outline),
                                  tooltip: 'Aprovar adicao',
                                ),
                                IconButton(
                                  onPressed: () => ref
                                      .read(materialCatalogProvider.notifier)
                                      .rejectCreate(item),
                                  icon: const Icon(Icons.undo),
                                  tooltip: 'Rejeitar adicao',
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
                      'Alteracoes sugeridas pela equipe antes de entrarem na base compartilhada.',
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
                            leading: const Icon(Icons.edit_note_outlined),
                            title: Text(item.nome),
                            subtitle: Text(
                              'Atual: ${item.quantidadeNormalizada} ${item.unidadeNormalizada}'
                              '${item.observacaoNormalizada.isEmpty ? '' : ' | ${item.observacaoNormalizada}'}\n'
                              'Pendente: ${item.pendingEditNome ?? item.nome} | ${item.pendingEditQuantidade ?? item.quantidadeNormalizada} ${item.pendingEditUnidade ?? item.unidadeNormalizada}'
                              '${(item.pendingEditObservacao ?? '').trim().isEmpty ? '' : ' | ${item.pendingEditObservacao!.trim()}'}'
                              '${item.pendingEditByName.isEmpty ? '' : '\nSolicitado por ${item.pendingEditByName}'}',
                            ),
                            isThreeLine: true,
                            trailing: Wrap(
                              spacing: 4,
                              children: [
                                IconButton(
                                  onPressed: () => ref
                                      .read(materialCatalogProvider.notifier)
                                      .approveEdit(item),
                                  icon: const Icon(Icons.check_circle_outline),
                                  tooltip: 'Aprovar edicao',
                                ),
                                IconButton(
                                  onPressed: () => ref
                                      .read(materialCatalogProvider.notifier)
                                      .rejectEdit(item),
                                  icon: const Icon(Icons.undo),
                                  tooltip: 'Rejeitar edicao',
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
    _MaterialCatalogAction action,
  ) async {
    switch (action) {
      case _MaterialCatalogAction.add:
        return _abrirEditor(context, ref);
      case _MaterialCatalogAction.importSpreadsheet:
        return _abrirImportacaoPlanilha(context, ref);
      case _MaterialCatalogAction.importPdf:
        return _abrirImportacaoPdf(context, ref);
      case _MaterialCatalogAction.uploadFile:
        return _importarArquivo(context, ref);
    }
  }

  Future<void> _abrirEditor(
    BuildContext context,
    WidgetRef ref, {
    MaterialCatalogItem? material,
  }) async {
    final sessao = ref.read(sessionProvider);
    final nomeController = TextEditingController(text: material?.nome ?? '');
    final quantidadeController = TextEditingController(
      text: (material?.quantidadeNormalizada ?? 1).toString(),
    );
    final unidadeController = TextEditingController(
      text: material?.unidadeNormalizada ?? 'un',
    );
    final observacaoController = TextEditingController(
      text: material?.observacaoNormalizada ?? '',
    );

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(material == null ? 'Novo material' : 'Editar material'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome do material',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: quantidadeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantidade padrao',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: unidadeController,
                decoration: const InputDecoration(labelText: 'Unidade'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: observacaoController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Observacao'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final nome = _normalizarNome(nomeController.text);
              final quantidade =
                  int.tryParse(quantidadeController.text.trim()) ?? 1;
              if (nome.isEmpty) return;
              try {
                await ref
                    .read(materialCatalogProvider.notifier)
                    .save(
                      id: material?.id,
                      nome: nome,
                      quantidade: quantidade,
                      unidade: unidadeController.text.trim(),
                      observacao: observacaoController.text.trim(),
                    );
                if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                if (context.mounted && sessao?.role == Role.employee) {
                  context.showUserMessage(
                    'Sugestao enviada para aprovacao da empresa.',
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  context.showUserError(
                    AppErrorMapper.messageFrom(
                      e,
                      fallback: 'Nao foi possivel salvar o material.',
                    ),
                  );
                }
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    nomeController.dispose();
    quantidadeController.dispose();
    unidadeController.dispose();
    observacaoController.dispose();
  }

  Future<void> _abrirImportacaoPlanilha(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final textoCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Importar planilha de materiais'),
        content: SizedBox(
          width: 620,
          child: TextField(
            controller: textoCtrl,
            maxLines: 12,
            decoration: const InputDecoration(
              hintText:
                  'Cole linhas como:\n'
                  'CHUVEIRO; 3; un; 5500W\n'
                  'CABO FLEXIVEL 2,5MM; 50; m; rolo\n'
                  'DISJUNTOR MONOFASICO - 2 un',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
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
        title: const Text('Importar PDF de materiais'),
        content: SizedBox(
          width: 620,
          child: TextField(
            controller: textoCtrl,
            maxLines: 12,
            decoration: const InputDecoration(
              hintText:
                  'Cole o texto extraido do PDF. O sistema tenta separar nome, quantidade, unidade e observacao.',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
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

  Future<void> _importarArquivo(BuildContext context, WidgetRef ref) async {
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
    List<_MaterialDraft> drafts = <_MaterialDraft>[];

    if (ext == 'pdf') {
      drafts = _parsePdfBytes(bytes);
    } else if (ext == 'xlsx' || ext == 'xls') {
      drafts = _parseExcelBytes(bytes);
    } else {
      drafts = _parsePlanilha(_bytesToText(bytes));
    }

    if (drafts.isEmpty) {
      if (context.mounted) {
        context.showUserMessage('Nao ha materiais identificados no arquivo.');
      }
      return;
    }

    if (!context.mounted) return;
    await _revisarImportacao(context, ref, drafts);
  }

  Future<void> _revisarImportacao(
    BuildContext context,
    WidgetRef ref,
    List<_MaterialDraft> drafts,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revisar importacao'),
        content: SizedBox(
          width: 760,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: drafts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final draft = drafts[i];
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      initialValue: draft.nome,
                      onChanged: (value) => draft.nome = value,
                      decoration: const InputDecoration(labelText: 'Material'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 90,
                    child: TextFormField(
                      initialValue: draft.quantidade.toString(),
                      onChanged: (value) => draft.quantidade =
                          int.tryParse(value) ?? draft.quantidade,
                      decoration: const InputDecoration(labelText: 'Qtd'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 110,
                    child: TextFormField(
                      initialValue: draft.unidade,
                      onChanged: (value) => draft.unidade = value,
                      decoration: const InputDecoration(labelText: 'Unidade'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      initialValue: draft.observacao,
                      onChanged: (value) => draft.observacao = value,
                      decoration: const InputDecoration(
                        labelText: 'Observacao',
                      ),
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
              final materiais =
                  <
                    ({
                      String nome,
                      int quantidade,
                      String unidade,
                      String observacao,
                    })
                  >[
                    for (final draft in drafts)
                      if (_normalizarNome(draft.nome).isNotEmpty)
                        (
                          nome: _normalizarNome(draft.nome),
                          quantidade: draft.quantidade < 1
                              ? 1
                              : draft.quantidade,
                          unidade: draft.unidade.trim().isEmpty
                              ? 'un'
                              : draft.unidade.trim(),
                          observacao: draft.observacao.trim(),
                        ),
                  ];
              try {
                await ref
                    .read(materialCatalogProvider.notifier)
                    .upsertMany(materiais);
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (context.mounted) {
                  context.showUserSuccess(
                    'Importacao concluida: ${materiais.length} material(is) processado(s).',
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  context.showUserError(
                    AppErrorMapper.messageFrom(
                      e,
                      fallback:
                          'Nao foi possivel importar agora. Tente novamente.',
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

  String _bytesToText(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return latin1.decode(bytes, allowInvalid: true);
    }
  }

  List<_MaterialDraft> _parseExcelBytes(List<int> bytes) {
    final excel = Excel.decodeBytes(bytes);
    final linhas = <String>[];
    for (final tableName in excel.tables.keys) {
      final table = excel.tables[tableName];
      if (table == null) continue;
      for (final row in table.rows) {
        final texto = row
            .map((cell) => cell?.value?.toString().trim() ?? '')
            .where((value) => value.isNotEmpty)
            .join(' ; ');
        if (texto.isNotEmpty) linhas.add(texto);
      }
    }
    return _parsePlanilha(linhas.join('\n'));
  }

  List<_MaterialDraft> _parsePdfBytes(List<int> bytes) {
    final doc = PdfDocument(inputBytes: bytes);
    final texto = PdfTextExtractor(doc).extractText();
    doc.dispose();
    return _parsePdfTexto(texto);
  }

  List<_MaterialDraft> _parsePdfTexto(String texto) => _parsePlanilha(texto);

  List<_MaterialDraft> _parsePlanilha(String texto) {
    final linhas = texto
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final drafts = <_MaterialDraft>[];
    for (final linha in linhas) {
      final normalized = linha.replaceAll('\t', ';');
      final partes = normalized
          .split(';')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
      if (partes.isEmpty) continue;

      if (partes.length >= 2) {
        final nome = _normalizarNome(partes.first);
        if (nome.isNotEmpty) {
          drafts.add(
            _MaterialDraft(
              nome,
              _extractQuantidade(partes[1]),
              partes.length >= 3
                  ? _normalizarUnidade(partes[2])
                  : _inferUnidade(linha),
              partes.length >= 4
                  ? partes.sublist(3).join(' | ').trim()
                  : _extractObservacao(linha, partes),
            ),
          );
          continue;
        }
      }

      final regex = RegExp(
        r'^(.+?)\s*[-:]\s*(\d+)\s*([A-Za-z]+)?(?:\s*[-:]\s*(.+))?$',
      );
      final match = regex.firstMatch(linha);
      if (match != null) {
        drafts.add(
          _MaterialDraft(
            _normalizarNome(match.group(1) ?? ''),
            int.tryParse(match.group(2) ?? '') ?? 1,
            _normalizarUnidade(match.group(3) ?? ''),
            (match.group(4) ?? '').trim(),
          ),
        );
        continue;
      }

      final nome = _normalizarNome(linha);
      if (nome.isNotEmpty) {
        drafts.add(_MaterialDraft(nome, 1, _inferUnidade(linha), ''));
      }
    }
    return drafts;
  }

  int _extractQuantidade(String texto) {
    final match = RegExp(r'\d+').firstMatch(texto);
    return int.tryParse(match?.group(0) ?? '') ?? 1;
  }

  String _extractObservacao(String linha, List<String> partes) {
    if (partes.length <= 3) return '';
    return partes.sublist(3).join(' | ').trim();
  }

  String _inferUnidade(String texto) {
    final lower = texto.toLowerCase();
    if (lower.contains(' metro') || RegExp(r'\b(m|mt|mts)\b').hasMatch(lower)) {
      return 'm';
    }
    if (RegExp(r'\b(kg|quilo|quilos)\b').hasMatch(lower)) {
      return 'kg';
    }
    if (RegExp(r'\b(cx|caixa|caixas)\b').hasMatch(lower)) {
      return 'cx';
    }
    return 'un';
  }

  String _normalizarUnidade(String texto) {
    final unidade = texto.trim().toLowerCase();
    if (unidade.isEmpty) return 'un';
    return unidade;
  }

  String _normalizarNome(String texto) {
    var value = texto
        .replaceAll(RegExp(r'[\u0000-\u001F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    while (value.isNotEmpty && !_isNomeValido(value.codeUnitAt(0))) {
      value = value.substring(1);
    }
    while (value.isNotEmpty &&
        !_isNomeValido(value.codeUnitAt(value.length - 1))) {
      value = value.substring(0, value.length - 1);
    }
    return value.toUpperCase();
  }

  bool _isNomeValido(int codeUnit) {
    final isDigit = codeUnit >= 48 && codeUnit <= 57;
    final isUpper = codeUnit >= 65 && codeUnit <= 90;
    final isLower = codeUnit >= 97 && codeUnit <= 122;
    final isLatinAccent = codeUnit >= 192 && codeUnit <= 255;
    return isDigit || isUpper || isLower || isLatinAccent;
  }
}

class _MaterialDraft {
  _MaterialDraft(this.nome, this.quantidade, this.unidade, this.observacao);

  String nome;
  int quantidade;
  String unidade;
  String observacao;
}
