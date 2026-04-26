part of 'tasks_page.dart';

extension _TaskDetailsMediaPdf on TaskDetailsPage {
  Future<void> _compartilharTarefaPdf(
    BuildContext context,
    TarefaItem tarefa,
  ) async {
    try {
      final bytes = await _montarPdfTarefa(tarefa);
      final nomeArquivo = 'tarefa-${tarefa.id}.pdf';
      if (kIsWeb) {
        await sharePdfBytes(bytes: bytes, filename: nomeArquivo);
        if (context.mounted) {
          _msg(context, 'PDF da tarefa baixado com sucesso.');
        }
        return;
      }
      await sharePdfBytes(bytes: bytes, filename: nomeArquivo);
    } catch (_) {
      if (context.mounted) {
        _msg(context, 'Nao foi possivel compartilhar o PDF da tarefa.');
      }
    }
  }

  Future<void> _adicionarAnexo(
    BuildContext context,
    WidgetRef ref,
    TarefaItem tarefa,
  ) async {
    final sessao = ref.read(sessionProvider);
    if (sessao == null) return _msg(context, 'Sessao nao encontrada.');

    final opcao = await showModalBottomSheet<_OpcaoAnexo>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Foto da camera'),
              onTap: () => Navigator.of(
                ctx,
              ).pop(_OpcaoAnexo(TipoAnexoTarefa.foto, ImageSource.camera)),
            ),
            ListTile(
              title: const Text('Foto da galeria'),
              onTap: () => Navigator.of(
                ctx,
              ).pop(_OpcaoAnexo(TipoAnexoTarefa.foto, ImageSource.gallery)),
            ),
            ListTile(
              title: const Text('Video da camera'),
              onTap: () => Navigator.of(
                ctx,
              ).pop(_OpcaoAnexo(TipoAnexoTarefa.video, ImageSource.camera)),
            ),
            ListTile(
              title: const Text('Video da galeria'),
              onTap: () => Navigator.of(
                ctx,
              ).pop(_OpcaoAnexo(TipoAnexoTarefa.video, ImageSource.gallery)),
            ),
          ],
        ),
      ),
    );
    if (opcao == null) return;

    final picker = ImagePicker();
    final arquivo = opcao.tipo == TipoAnexoTarefa.foto
        ? await picker.pickImage(source: opcao.origem, imageQuality: 85)
        : await picker.pickVideo(source: opcao.origem);
    if (arquivo == null) return;

    if (!context.mounted) return;
    final descricaoCtrl = TextEditingController();
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Descricao do anexo'),
        content: TextField(
          controller: descricaoCtrl,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Descricao'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    final descricao = descricaoCtrl.text.trim();
    descricaoCtrl.dispose();
    if (confirmar != true) return;

    try {
      final id = DateTime.now().microsecondsSinceEpoch.toString();
      final nome = opcao.tipo == TipoAnexoTarefa.foto ? '$id.jpg' : '$id.mp4';
      final companyId = await _resolverCompanyId(sessao);
      final caminhoStorage = 'companies/$companyId/tasks/${tarefa.id}/$nome';
      final url = await FirebaseMediaUpload.uploadXFileWithBucketFallback(
        caminhoStorage: caminhoStorage,
        source: arquivo,
        contentType: opcao.tipo == TipoAnexoTarefa.foto
            ? 'image/jpeg'
            : 'video/mp4',
      );
      final anexos = [
        ...tarefa.anexos,
        AnexoTarefa(
          id: id,
          tipo: opcao.tipo,
          url: url,
          descricao: descricao,
          nomeArquivo: nome,
          criadoEm: DateTime.now(),
        ),
      ];
      await ref
          .read(tasksProvider.notifier)
          .updateById(tarefa.id, tarefa.copyWith(anexos: anexos));
      if (!context.mounted) return;
      _msg(context, 'Anexo salvo com sucesso.');
    } on FirebaseException catch (e) {
      if (!context.mounted) return;
      final detalhe = (e.message ?? '').trim();
      _msg(context, 'Erro ao salvar anexo: ${e.code}${detalhe.isEmpty ? '' : ' - $detalhe'}');
    } catch (_) {
      if (!context.mounted) return;
      _msg(context, 'Erro ao salvar anexo.');
    }
  }

  Future<String> _resolverCompanyId(Session sessao) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? sessao.userId;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final companyId = doc.data()?['companyId']?.toString().trim();
      if (companyId != null && companyId.isNotEmpty) return companyId;
    } catch (_) {
      // fallback na sessao.
    }
    return sessao.companyId;
  }

  Future<void> _excluirAnexo(
    BuildContext context,
    WidgetRef ref,
    TarefaItem tarefa,
    AnexoTarefa anexo,
  ) async {
    final anexos = [
      for (final a in tarefa.anexos)
        if (a.id != anexo.id) a,
    ];
    await ref
        .read(tasksProvider.notifier)
        .updateById(tarefa.id, tarefa.copyWith(anexos: anexos));
    try {
      await FirebaseStorage.instance.refFromURL(anexo.url).delete();
    } catch (_) {
      // Nao bloqueia exclusao do registro se falhar no storage.
    }
    if (context.mounted) _msg(context, 'Anexo excluido.');
  }

  void _abrirAnexo(BuildContext context, AnexoTarefa anexo) {
    if (anexo.tipo == TipoAnexoTarefa.foto) {
      showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          child: FutureBuilder<ImageProvider>(
            future: _resolverImagemProvider(anexo.url),
            builder: (_, snapshot) {
              if (snapshot.hasData) {
                return Image(image: snapshot.data!, fit: BoxFit.contain);
              }
              if (snapshot.hasError) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Nao foi possivel abrir a imagem.'),
                );
              }
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              );
            },
          ),
        ),
      );
      return;
    }
    _abrirVideo(context, anexo.url);
  }

  Future<ImageProvider> _resolverImagemProvider(String origem) async {
    if (origem.startsWith('http://') || origem.startsWith('https://')) {
      return NetworkImage(origem);
    }
    if (!origem.startsWith('gs://')) {
      return NetworkImage(origem);
    }
    final ref = FirebaseStorage.instance.refFromURL(origem);
    try {
      final url = await ref.getDownloadURL();
      return NetworkImage(url);
    } catch (_) {
      final metadata = await ref.getMetadata();
      final size = metadata.size ?? 0;
      if (size > 5 * 1024 * 1024) {
        throw Exception('Imagem acima do limite para visualizacao inline.');
      }
      final Uint8List? bytes = await ref.getData(5 * 1024 * 1024);
      if (bytes == null) throw Exception('Imagem indisponivel.');
      return MemoryImage(bytes);
    }
  }

  Future<void> _abrirVideo(BuildContext context, String origem) async {
    try {
      final url = await _resolverUrlMidia(origem);
      final uri = Uri.tryParse(url);
      if (uri == null) throw Exception('URL invalida.');
      final abriu = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!abriu && context.mounted) {
        _msg(context, 'Nao foi possivel abrir o video.');
      }
    } catch (_) {
      if (context.mounted) {
        _msg(context, 'Nao foi possivel abrir o video.');
      }
    }
  }

  Future<String> _resolverUrlMidia(String origem) async {
    if (origem.startsWith('http://') || origem.startsWith('https://')) {
      return origem;
    }
    if (!origem.startsWith('gs://')) {
      return origem;
    }
    final ref = FirebaseStorage.instance.refFromURL(origem);
    return ref.getDownloadURL();
  }

  Future<void> _excluirTarefa(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    await ref.read(tasksProvider.notifier).removeById(id);
    if (!context.mounted) return;
    Navigator.of(context).pop();
    _msg(context, 'Tarefa excluida com sucesso.');
  }

  Future<void> _gerarPdf(BuildContext context, TarefaItem tarefa) async {
    final bytes = await _montarPdfTarefa(tarefa);
    if (kIsWeb) {
      await saveBytesFile(
        filename: 'tarefa-${tarefa.id}.pdf',
        bytes: bytes,
        mimeType: 'application/pdf',
      );
      if (context.mounted) {
        _msg(context, 'PDF da tarefa baixado com sucesso.');
      }
      return;
    }
    await openPdfBytes(
      bytes: bytes,
      filename: 'tarefa-${tarefa.id}.pdf',
    );
  }

  Future<Uint8List> _montarPdfTarefa(TarefaItem tarefa) async {
    final empresa = await _dadosEmpresaParaPdf();
    final anexosResolvidos = <({AnexoTarefa anexo, String url})>[];
    if (tarefa.status == StatusTarefa.finalizado && tarefa.anexos.isNotEmpty) {
      for (final anexo in tarefa.anexos) {
        var url = anexo.url;
        try {
          url = await _resolverUrlMidia(anexo.url);
        } catch (_) {
          // Mantem URL original em caso de falha temporaria na resolucao.
        }
        anexosResolvidos.add((anexo: anexo, url: url));
      }
    }

    final titulo = tarefa.status == StatusTarefa.finalizado
        ? 'Relatorio de servico finalizado'
        : 'Orcamento de servico';
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageTheme: StandardPdfDocument.pageTheme(),
        build: (_) => [
          StandardPdfDocument.header(
            title: titulo,
            subtitle:
                'Documento padronizado para envio ao cliente e arquivo interno da empresa.',
            company: StandardPdfCompanyInfo(
              name: empresa.nome,
              document: empresa.cnpj == '-' ? '' : empresa.cnpj,
              address: empresa.endereco == '-' ? '' : empresa.endereco,
            ),
            metadata: [
              StandardPdfField('Servico', tarefa.nome),
              StandardPdfField('Status', _rotuloStatus(tarefa.status)),
              StandardPdfField('Data da execucao', _formatarData(tarefa.dataExecucao)),
              StandardPdfField('Responsavel', tarefa.autorNome),
              StandardPdfField(
                'Cliente',
                tarefa.clienteNome.isEmpty ? '-' : tarefa.clienteNome,
              ),
              StandardPdfField(
                'Documento do cliente',
                tarefa.clienteDocumentoFormatado.isEmpty
                    ? '-'
                    : tarefa.clienteDocumentoFormatado,
              ),
              StandardPdfField(
                'Valor total',
                _formatarMoeda(_valorTotalEfetivoCents(tarefa)),
              ),
              StandardPdfField(
                'Gerado em',
                _formatarData(DateTime.now()),
              ),
            ],
          ),
          StandardPdfDocument.section(
            title: 'Descricao do servico',
            children: [
              StandardPdfDocument.paragraph(
                tarefa.descricao.trim().isEmpty
                    ? 'Servico sem descricao complementar registrada.'
                    : tarefa.descricao.trim(),
              ),
            ],
          ),
          StandardPdfDocument.section(
            title: 'Itens do servico',
            children: StandardPdfDocument.bulletList([
              if (tarefa.itens.isEmpty) 'Nenhum item cadastrado.',
              for (final item in tarefa.itens)
                '${item.nome} | ${item.concluido ? 'Concluido' : 'Pendente'} | Quantidade ${item.quantidadeNormalizada}'
                    '${item.valorCents == null ? '' : ' | Unitario ${_formatarMoeda(item.valorCents!)} | Total ${_formatarMoeda(item.totalCents ?? item.valorCents!)}'}',
            ]),
          ),
          StandardPdfDocument.section(
            title: 'Materiais previstos',
            children: StandardPdfDocument.bulletList([
              if (tarefa.materiaisNecessarios.isEmpty)
                'Nenhum material necessario cadastrado.',
              for (final material in tarefa.materiaisNecessarios)
                material.descricaoCurta,
            ]),
          ),
          if (tarefa.status == StatusTarefa.finalizado)
            StandardPdfDocument.section(
              title: 'Conclusao do servico',
              children: [
                ...StandardPdfDocument.bulletList([
                  if (tarefa.materiaisUtilizados.isEmpty)
                    'Nenhum material utilizado cadastrado.'
                  else
                    'Materiais utilizados: ${tarefa.materiaisUtilizados.map((m) => m.descricaoCurta).join(', ')}',
                ]),
                pw.SizedBox(height: 8),
                ...StandardPdfDocument.bulletList([
                  if (anexosResolvidos.isEmpty)
                    'Nenhum anexo cadastrado.'
                  else
                    for (final item in anexosResolvidos)
                      '${_formatoAnexo(item.anexo)}${item.anexo.descricao.trim().isEmpty ? '' : ' - ${item.anexo.descricao.trim()}'} | ${item.url}',
                ]),
              ],
            ),
        ],
      ),
    );
    return pdf.save();
  }

  Future<({String nome, String cnpj, String endereco})> _dadosEmpresaParaPdf() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return (nome: '-', cnpj: '-', endereco: '-');
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final map = doc.data();
      final companyData = (map?['companyData'] as Map?)?.cast<String, dynamic>();
      final nome = companyData?['nomeFantasia']?.toString().trim();
      final cnpj = companyData?['cnpj']?.toString().trim();
      final enderecoPadrao = companyData?['endereco']?.toString().trim();
      final rua = companyData?['rua']?.toString().trim() ?? '';
      final quadra = companyData?['quadra']?.toString().trim() ?? '';
      final lote = companyData?['lote']?.toString().trim() ?? '';
      final cidade = companyData?['cidade']?.toString().trim() ?? '';
      final estado = companyData?['estado']?.toString().trim() ?? '';
      final enderecoCompleto = <String>[
        if (rua.isNotEmpty) 'RUA $rua',
        if (quadra.isNotEmpty) 'QUADRA $quadra',
        if (lote.isNotEmpty) 'LOTE $lote',
        if (cidade.isNotEmpty) cidade,
        if (estado.isNotEmpty) estado,
      ].join(', ');
      final endereco = enderecoCompleto.isNotEmpty ? enderecoCompleto : (enderecoPadrao ?? '');
      return (
        nome: (nome == null || nome.isEmpty) ? '-' : nome,
        cnpj: (cnpj == null || cnpj.isEmpty) ? '-' : cnpj,
        endereco: endereco.isEmpty ? '-' : endereco,
      );
    } catch (_) {
      return (nome: '-', cnpj: '-', endereco: '-');
    }
  }

  String _rotuloStatus(StatusTarefa status) {
    return _taskStatusLabel(status);
  }

  String _formatarData(DateTime? data) {
    return _taskFormatDate(data);
  }

  String _tituloAnexo(AnexoTarefa anexo) {
    return _taskAttachmentTitle(anexo);
  }

  String _subtituloAnexo(AnexoTarefa anexo) {
    return _taskAttachmentSubtitle(anexo);
  }

  String _formatoAnexo(AnexoTarefa anexo) {
    return _taskAttachmentFormat(anexo);
  }

  int? _parseReaisParaCents(String valor) {
    return _taskParseReaisParaCents(valor);
  }

  String _centsParaInput(int? cents) {
    return _taskCentsToInput(cents);
  }

  String _formatarMoeda(int cents) {
    return _taskFormatMoney(cents);
  }

  void _msg(BuildContext context, String texto) {
    if (!context.mounted) return;
    context.showUserMessage(texto);
  }
}
