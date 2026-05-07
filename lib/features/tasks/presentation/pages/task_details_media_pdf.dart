part of 'tasks_page.dart';

class _TaskPdfPalette {
  static final PdfColor ink = PdfColor.fromInt(0xFF1F2937);
  static final PdfColor muted = PdfColor.fromInt(0xFF64748B);
  static final PdfColor accent = PdfColor.fromInt(0xFF0F4C81);
  static final PdfColor border = PdfColor.fromInt(0xFFD7DFEA);
}

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

    final corpo = <pw.Widget>[
      StandardPdfDocument.header(
        title: titulo,
        subtitle:
            'Documento para o cliente acompanhar servicos, produtos e valores. '
            'A empresa emissora aparece abaixo.',
        company: StandardPdfCompanyInfo(
          name: empresa.nome,
          document: empresa.cnpj == '-' ? '' : empresa.cnpj,
          address: empresa.endereco == '-' ? '' : empresa.endereco,
        ),
        metadata: _pdfCamposMetadadosResumo(tarefa),
      ),
      _pdfBlocoClienteServicoObra(tarefa),
    ];

    if (tarefa.itens.any((i) => i.nome.trim().isNotEmpty)) {
      corpo.add(_pdfSecaoItensTabela(tarefa));
    }

    final materiaisPdf = _resolverMateriaisPdf(tarefa);
    if (materiaisPdf.lista.isNotEmpty) {
      corpo.add(
        _pdfSecaoMateriaisCliente(
          tarefa,
          materiaisPdf.lista,
          fallbackPrevisto: materiaisPdf.fallbackPrevisto,
        ),
      );
    }

    if (tarefa.status == StatusTarefa.finalizado) {
      final blocosConclusao = _pdfWidgetsConclusaoServico(
        anexosResolvidos,
      );
      if (blocosConclusao.isNotEmpty) {
        corpo.add(_pdfSecaoTituloExterno('Conclusao do servico', blocosConclusao));
      }
    }

    if (_pdfDeveExibirResumoValores(tarefa)) {
      corpo.add(_pdfResumoValoresFinais(tarefa));
    }

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(22, 20, 22, 26),
        ),
        build: (_) => corpo,
      ),
    );
    return pdf.save();
  }

  List<StandardPdfField> _pdfCamposMetadadosResumo(TarefaItem tarefa) {
    String limpo(String v) => v.trim();

    void incluir(List<StandardPdfField> lista, String rotulo, String valor) {
      final v = limpo(valor);
      if (v.isEmpty || v == '-') return;
      lista.add(StandardPdfField(rotulo, v));
    }

    final meta = <StandardPdfField>[
      StandardPdfField('Status', _rotuloStatus(tarefa.status)),
      StandardPdfField(
        'Valor total',
        _formatarMoeda(_valorTotalCabecalhoPdf(tarefa)),
      ),
      StandardPdfField('Emitido em', _formatarData(DateTime.now())),
    ];

    final dataExec = tarefa.dataExecucao;
    if (dataExec != null) {
      incluir(meta, 'Data da execucao', _formatarData(dataExec));
    }

    incluir(meta, 'Responsavel pela execucao', tarefa.autorNome);

    return meta;
  }

  /// Lista mostrada no PDF e totais: orcamento = previstos; finalizado = utilizados,
  /// ou previstos como fallback se finalizado sem linhas em utilizados.
  ({List<MaterialTarefa> lista, bool fallbackPrevisto}) _resolverMateriaisPdf(
    TarefaItem tarefa,
  ) {
    bool ok(MaterialTarefa m) => m.nome.trim().isNotEmpty;
    if (tarefa.status == StatusTarefa.finalizado) {
      final u = tarefa.materiaisUtilizados.where(ok).toList();
      if (u.isNotEmpty) return (lista: u, fallbackPrevisto: false);
      final n = tarefa.materiaisNecessarios.where(ok).toList();
      return (lista: n, fallbackPrevisto: n.isNotEmpty);
    }
    final n = tarefa.materiaisNecessarios.where(ok).toList();
    return (lista: n, fallbackPrevisto: false);
  }

  List<MaterialTarefa> _materiaisParaPdfCliente(TarefaItem tarefa) =>
      _resolverMateriaisPdf(tarefa).lista;

  /// Soma linhas em [materiaisUtilizados] (nome preenchido). Usada no valor do topo e no resumo geral do PDF.
  int _sumMateriaisUtilizadosSomenteCents(TarefaItem tarefa) {
    var soma = 0;
    for (final m in tarefa.materiaisUtilizados) {
      if (m.nome.trim().isEmpty) continue;
      final t = m.totalMaterialCents;
      if (t != null) soma += t;
    }
    return soma;
  }

  pw.Widget _pdfLinhaRotuloValor(String rotulo, String valor) {
    final v = valor.trim();
    if (v.isEmpty || v == '-') {
      return pw.SizedBox.shrink();
    }
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 124,
            child: pw.Text(
              rotulo,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: _TaskPdfPalette.muted,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              v,
              style: pw.TextStyle(
                fontSize: 11,
                color: _TaskPdfPalette.ink,
                lineSpacing: 2,
              ),
              textAlign: pw.TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfBlocoClienteServicoObra(TarefaItem tarefa) {
    final desc = tarefa.descricao.trim();
    final clienteNome = tarefa.clienteNome.trim();
    final docCliente = tarefa.clienteDocumentoFormatado.trim();

    final filhos = <pw.Widget>[
      pw.Text(
        'Cliente e servico',
        style: pw.TextStyle(
          color: _TaskPdfPalette.accent,
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
      pw.SizedBox(height: 10),
      _pdfLinhaRotuloValor(
        'Cliente',
        clienteNome.isEmpty ? '-' : clienteNome,
      ),
      _pdfLinhaRotuloValor(
        'CPF / CNPJ do cliente',
        docCliente.isEmpty ? '-' : docCliente,
      ),
      _pdfLinhaRotuloValor(
        'Servico ou obra',
        tarefa.nome.trim().isEmpty ? '-' : tarefa.nome.trim(),
      ),
    ];

    final dataExec = tarefa.dataExecucao;
    if (dataExec != null) {
      filhos.add(
        _pdfLinhaRotuloValor(
          'Data (execucao / referencia)',
          _formatarData(dataExec),
        ),
      );
    }

    if (desc.isNotEmpty) {
      filhos.add(pw.SizedBox(height: 8));
      filhos.add(
        pw.Text(
          'Descricao dos servicos / escopo',
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: _TaskPdfPalette.muted,
          ),
        ),
      );
      filhos.add(pw.SizedBox(height: 4));
      filhos.add(
        pw.Text(
          desc,
          style: pw.TextStyle(
            color: _TaskPdfPalette.ink,
            fontSize: 11,
            lineSpacing: 4,
          ),
          textAlign: pw.TextAlign.left,
        ),
      );
    }

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 12),
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: _TaskPdfPalette.border),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: filhos,
      ),
    );
  }

  int _sumItensServicoCents(TarefaItem tarefa) {
    var soma = 0;
    for (final i in tarefa.itens) {
      final t = i.totalCents;
      if (t != null) soma += t;
    }
    return soma;
  }

  /// Servicos + materiais utilizados; se soma zero, mantem total manual/automatico da tarefa.
  int _valorTotalCabecalhoPdf(TarefaItem tarefa) {
    final materiais = _sumMateriaisUtilizadosSomenteCents(tarefa);
    final computed = _sumItensServicoCents(tarefa) + materiais;
    if (computed > 0) return computed;
    return _valorTotalEfetivoCents(tarefa);
  }

  bool _pdfDeveExibirResumoValores(TarefaItem tarefa) {
    if (tarefa.itens.any((i) => i.nome.trim().isNotEmpty)) return true;
    if (_materiaisParaPdfCliente(tarefa).isNotEmpty) return true;
    return false;
  }

  /// Uma linha logica por trecho: sem quebras manuais e troca de pontuacao tipografica por ASCII.
  String _pdfTextoFluxoUnico(String texto) {
    var t = texto.replaceAll(RegExp(r'[\r\n]+'), ' ');
    t = t.replaceAll('\u2014', '-'); // em dash
    t = t.replaceAll('\u2013', '-'); // en dash
    t = t.replaceAll('\u00b7', ','); // middle dot
    t = t.replaceAll('\u2022', ','); // bullet
    t = t.replaceAll('\u00a0', ' '); // nbsp
    t = t.replaceAll('\u2026', '...'); // ellipsis
    t = t.replaceAll('\u201c', '"'); // left double quote
    t = t.replaceAll('\u201d', '"'); // right double quote
    t = t.replaceAll('\u2018', "'"); // left single
    t = t.replaceAll('\u2019', "'"); // right single
    t = t.replaceAll('|', ',');
    return t.replaceAll(RegExp(r' +'), ' ').trim();
  }

  pw.Widget _pdfCartaoListaLinhas(List<String> linhas) {
    final effective = linhas.isEmpty ? <String>['-'] : linhas;
    final styleBase = pw.TextStyle(
      fontSize: 10,
      color: _TaskPdfPalette.ink,
      lineSpacing: 1.2,
    );
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: _TaskPdfPalette.border),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < effective.length; i++) ...[
            if (i > 0) pw.SizedBox(height: 6),
            pw.Text(effective[i], style: styleBase),
          ],
        ],
      ),
    );
  }

  pw.Widget _pdfLinhaValorTotalForaCard(String rotulo, String valorFormatado) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 10),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Text(
              rotulo,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: _TaskPdfPalette.ink,
              ),
            ),
          ),
          pw.Text(
            valorFormatado,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: _TaskPdfPalette.accent,
            ),
          ),
        ],
      ),
    );
  }

  List<String> _pdfLinhasItensServicoNumerados(TarefaItem tarefa) {
    final itens = tarefa.itens.where((i) => i.nome.trim().isNotEmpty).toList();
    final out = <String>[];
    for (var i = 0; i < itens.length; i++) {
      final item = itens[i];
      final buf = StringBuffer('${i + 1}. ${_pdfTextoFluxoUnico(item.nome)}');
      buf.write(', ${item.quantidadeNormalizada} un');
      if (item.valorCents != null && item.valorCents != 0) {
        buf.write(', Unit. ${_formatarMoeda(item.valorCents!)}');
      }
      final tc = item.totalCents;
      if (tc != null && tc != 0) {
        buf.write(', Total ${_formatarMoeda(tc)}');
      }
      buf.write(', ');
      buf.write(item.concluido ? 'Sim' : 'Nao');
      out.add(buf.toString());
    }
    return out;
  }

  List<String> _pdfLinhasMateriaisNumerados(List<MaterialTarefa> mats) {
    final out = <String>[];
    for (var i = 0; i < mats.length; i++) {
      final m = mats[i];
      final buf = StringBuffer('${i + 1}. ${_pdfTextoFluxoUnico(m.nome)}');
      if (m.valorCents != null && m.valorCents != 0) {
        buf.write(', Unit. ${_formatarMoeda(m.valorCents!)}');
      }
      final tm = m.totalMaterialCents;
      if (tm != null && tm != 0) {
        buf.write(', Total ${_formatarMoeda(tm)}');
      }
      buf.write(', ${m.quantidadeNormalizada} ${m.unidadeNormalizada}');
      final obs = m.observacao.trim();
      if (obs.isNotEmpty) {
        buf.write(', ${_pdfTextoFluxoUnico(obs)}');
      }
      out.add(buf.toString());
    }
    return out;
  }

  pw.Widget _pdfSecaoItensTabela(TarefaItem tarefa) {
    final totalItens = _sumItensServicoCents(tarefa);
    final linhas = _pdfLinhasItensServicoNumerados(tarefa);

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 14),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Servicos prestados',
            style: pw.TextStyle(
              color: _TaskPdfPalette.accent,
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Um item por linha, numerado; texto sem caracteres especiais.',
            style: pw.TextStyle(color: _TaskPdfPalette.muted, fontSize: 9),
          ),
          pw.SizedBox(height: 8),
          _pdfCartaoListaLinhas(linhas),
          _pdfLinhaValorTotalForaCard(
            'Total dos servicos prestados',
            _formatarMoeda(totalItens),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfSecaoMateriaisCliente(
    TarefaItem tarefa,
    List<MaterialTarefa> mats, {
    bool fallbackPrevisto = false,
  }) {
    final titulo = fallbackPrevisto
        ? 'Produtos e materiais (previsto - referencia)'
        : (tarefa.status == StatusTarefa.finalizado
            ? 'Produtos e materiais utilizados'
            : 'Produtos e materiais previstos');
    final subtitulo = fallbackPrevisto
        ? 'Nao ha itens em Materiais utilizados nesta tarefa; valores abaixo referem-se ao previsto.'
        : 'Um material por linha, numerado; texto sem caracteres especiais.';

    final totalMat = mats.fold<int>(0, (s, m) {
      final t = m.totalMaterialCents;
      return t != null ? s + t : s;
    });
    final linhas = _pdfLinhasMateriaisNumerados(mats);

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 14),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            titulo,
            style: pw.TextStyle(
              color: _TaskPdfPalette.accent,
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            subtitulo,
            style: pw.TextStyle(color: _TaskPdfPalette.muted, fontSize: 9),
          ),
          pw.SizedBox(height: 8),
          _pdfCartaoListaLinhas(linhas),
          _pdfLinhaValorTotalForaCard(
            'Total de produtos e materiais',
            _formatarMoeda(totalMat),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfResumoValoresFinais(TarefaItem tarefa) {
    final si = _sumItensServicoCents(tarefa);
    final sm = _sumMateriaisUtilizadosSomenteCents(tarefa);
    final grand = _valorTotalCabecalhoPdf(tarefa);
    final temMateriais = _materiaisParaPdfCliente(tarefa).isNotEmpty;

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 18),
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFEFF6FF),
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: _TaskPdfPalette.accent, width: 1.2),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Resumo para pagamento',
            style: pw.TextStyle(
              color: _TaskPdfPalette.accent,
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Total dos servicos prestados',
                style: pw.TextStyle(fontSize: 10, color: _TaskPdfPalette.ink),
              ),
              pw.Text(
                _formatarMoeda(si),
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: _TaskPdfPalette.ink,
                ),
              ),
            ],
          ),
          if (temMateriais || sm != 0) ...[
            pw.SizedBox(height: 6),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Total materiais utilizados',
                  style: pw.TextStyle(fontSize: 10, color: _TaskPdfPalette.ink),
                ),
                pw.Text(
                  _formatarMoeda(sm),
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: _TaskPdfPalette.ink,
                  ),
                ),
              ],
            ),
          ],
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 10),
            child: pw.Divider(thickness: 0.8, color: _TaskPdfPalette.border),
          ),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'TOTAL GERAL (servicos + materiais utilizados)',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: _TaskPdfPalette.accent,
                ),
              ),
              pw.Text(
                _formatarMoeda(grand),
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: _TaskPdfPalette.accent,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'O "Valor total" no topo soma os servicos e apenas materiais utilizados. '
            'Materiais previstos (ou previsto como referencia no PDF) aparecem na secao com '
            'subtotal proprio abaixo do cartao, mas so entram no topo quando copiados em utilizados.',
            style: pw.TextStyle(
              fontSize: 8,
              color: _TaskPdfPalette.muted,
              lineSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfCartao({
    required List<pw.Widget> filhos,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.all(11),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: _TaskPdfPalette.border),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: filhos,
      ),
    );
  }

  pw.Widget _pdfCartaoAnexoPdf(({AnexoTarefa anexo, String url}) item) {
    final linhas = <pw.Widget>[
      pw.Text(
        _formatoAnexo(item.anexo),
        style: pw.TextStyle(
          color: _TaskPdfPalette.ink,
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    ];
    final desc = item.anexo.descricao.trim();
    if (desc.isNotEmpty) {
      linhas.add(pw.SizedBox(height: 4));
      linhas.add(
        pw.Text(desc, style: pw.TextStyle(color: _TaskPdfPalette.ink, fontSize: 10)),
      );
    }
    linhas.add(pw.SizedBox(height: 4));
    linhas.add(
      pw.Text(
        item.url.trim(),
        style: pw.TextStyle(color: _TaskPdfPalette.muted, fontSize: 9),
      ),
    );
    return _pdfCartao(filhos: linhas);
  }

  List<pw.Widget> _pdfWidgetsConclusaoServico(
    List<({AnexoTarefa anexo, String url})> anexosResolvidos,
  ) {
    final out = <pw.Widget>[];

    if (anexosResolvidos.isNotEmpty) {
      out.add(
        pw.Text(
          'Anexos',
          style: pw.TextStyle(
            color: _TaskPdfPalette.ink,
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      );
      out.add(pw.SizedBox(height: 6));
      for (final a in anexosResolvidos) {
        out.add(_pdfCartaoAnexoPdf(a));
      }
    }

    return out;
  }

  pw.Widget _pdfSecaoTituloExterno(String titulo, List<pw.Widget> children) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 14),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            titulo,
            style: pw.TextStyle(
              color: _TaskPdfPalette.accent,
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          ...children,
        ],
      ),
    );
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
