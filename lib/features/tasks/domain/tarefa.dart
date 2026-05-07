class ItemServico {
  ItemServico({
    required this.nome,
    this.concluido = false,
    this.valorCents,
    this.quantidade = 1,
    this.valorTotalLinhaCents,
  });

  final String nome;
  final bool concluido;
  final int? valorCents;
  final int quantidade;

  /// Total da linha quando informado diretamente; se null, usa [valorCents] x quantidade.
  final int? valorTotalLinhaCents;

  ItemServico copyWith({
    bool? concluido,
    int? valorCents,
    bool limparValor = false,
    int? quantidade,
    int? valorTotalLinhaCents,
    bool limparValorTotalLinha = false,
  }) {
    return ItemServico(
      nome: nome,
      concluido: concluido ?? this.concluido,
      valorCents: limparValor ? null : valorCents ?? this.valorCents,
      quantidade: quantidade ?? this.quantidade,
      valorTotalLinhaCents: limparValorTotalLinha
          ? null
          : valorTotalLinhaCents ?? this.valorTotalLinhaCents,
    );
  }

  int get quantidadeNormalizada => quantidade < 1 ? 1 : quantidade;

  int? get totalCents {
    if (valorTotalLinhaCents != null) return valorTotalLinhaCents;
    if (valorCents == null) return null;
    return valorCents! * quantidadeNormalizada;
  }

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'concluido': concluido,
      'valorCents': valorCents,
      'quantidade': quantidadeNormalizada,
      'valorTotalLinhaCents': valorTotalLinhaCents,
    };
  }

  factory ItemServico.fromMap(Map<String, dynamic> map) {
    return ItemServico(
      nome: map['nome']?.toString() ?? '',
      concluido: map['concluido'] == true,
      valorCents: (map['valorCents'] as num?)?.toInt(),
      quantidade: ((map['quantidade'] as num?)?.toInt() ?? 1).clamp(1, 999999),
      valorTotalLinhaCents: (map['valorTotalLinhaCents'] as num?)?.toInt(),
    );
  }
}

class MaterialTarefa {
  const MaterialTarefa({
    required this.nome,
    this.quantidade = 1,
    this.unidade = 'un',
    this.observacao = '',
    this.valorCents,
    this.valorTotalLinhaCents,
  });

  final String nome;
  final int quantidade;
  final String unidade;
  final String observacao;

  /// Preco unitario opcional (mesma ideia dos itens do servico).
  final int? valorCents;

  /// Total da linha quando informado diretamente; se null, usa [valorCents] x quantidade.
  final int? valorTotalLinhaCents;

  MaterialTarefa copyWith({
    String? nome,
    int? quantidade,
    String? unidade,
    String? observacao,
    int? valorCents,
    int? valorTotalLinhaCents,
    bool limparValorCents = false,
    bool limparValorTotalLinha = false,
  }) {
    return MaterialTarefa(
      nome: nome ?? this.nome,
      quantidade: quantidade ?? this.quantidade,
      unidade: unidade ?? this.unidade,
      observacao: observacao ?? this.observacao,
      valorCents: limparValorCents ? null : valorCents ?? this.valorCents,
      valorTotalLinhaCents: limparValorTotalLinha
          ? null
          : valorTotalLinhaCents ?? this.valorTotalLinhaCents,
    );
  }

  int get quantidadeNormalizada => quantidade < 1 ? 1 : quantidade;

  String get unidadeNormalizada => unidade.trim().isEmpty ? 'un' : unidade.trim();

  /// Total em centavos para exibicao (manual ou calculado).
  int? get totalMaterialCents {
    if (valorTotalLinhaCents != null) return valorTotalLinhaCents;
    if (valorCents != null) return valorCents! * quantidadeNormalizada;
    return null;
  }

  String get descricaoCurta {
    final base = '$nome - $quantidadeNormalizada $unidadeNormalizada';
    final obs = observacao.trim();
    if (obs.isEmpty) return base;
    return '$base | $obs';
  }

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'quantidade': quantidadeNormalizada,
      'unidade': unidadeNormalizada,
      'observacao': observacao.trim(),
      'valorCents': valorCents,
      'valorTotalLinhaCents': valorTotalLinhaCents,
    };
  }

  factory MaterialTarefa.fromDynamic(dynamic raw) {
    if (raw is String) {
      return MaterialTarefa(nome: raw.trim());
    }
    if (raw is Map) {
      return _materialFromMap(Map<String, dynamic>.from(raw));
    }
    return const MaterialTarefa(nome: '');
  }

  static MaterialTarefa _materialFromMap(Map<String, dynamic> raw) {
    return MaterialTarefa(
      nome: raw['nome']?.toString() ?? '',
      quantidade: ((raw['quantidade'] as num?)?.toInt() ?? 1).clamp(
        1,
        999999,
      ),
      unidade: raw['unidade']?.toString() ?? 'un',
      observacao: raw['observacao']?.toString() ?? '',
      valorCents: (raw['valorCents'] as num?)?.toInt(),
      valorTotalLinhaCents: (raw['valorTotalLinhaCents'] as num?)?.toInt(),
    );
  }
}

enum StatusTarefa { orcamento, aprovado, iniciado, emAndamento, finalizado }

enum TipoAnexoTarefa { foto, video }

class AnexoTarefa {
  AnexoTarefa({
    required this.id,
    required this.tipo,
    required this.url,
    this.descricao = '',
    this.nomeArquivo = '',
    required this.criadoEm,
  });

  final String id;
  final TipoAnexoTarefa tipo;
  final String url;
  final String descricao;
  final String nomeArquivo;
  final DateTime criadoEm;

  AnexoTarefa copyWith({
    String? id,
    TipoAnexoTarefa? tipo,
    String? url,
    String? descricao,
    String? nomeArquivo,
    DateTime? criadoEm,
  }) {
    return AnexoTarefa(
      id: id ?? this.id,
      tipo: tipo ?? this.tipo,
      url: url ?? this.url,
      descricao: descricao ?? this.descricao,
      nomeArquivo: nomeArquivo ?? this.nomeArquivo,
      criadoEm: criadoEm ?? this.criadoEm,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tipo': tipo.name,
      'url': url,
      'descricao': descricao,
      'nomeArquivo': nomeArquivo,
      'criadoEm': criadoEm.toIso8601String(),
    };
  }

  factory AnexoTarefa.fromMap(Map<String, dynamic> map) {
    final tipoNome = map['tipo']?.toString();
    final tipo =
        TipoAnexoTarefa.values.where((e) => e.name == tipoNome).isNotEmpty
        ? TipoAnexoTarefa.values.firstWhere((e) => e.name == tipoNome)
        : TipoAnexoTarefa.foto;
    final criadoEmRaw = map['criadoEm']?.toString();
    final criadoEm = DateTime.tryParse(criadoEmRaw ?? '') ?? DateTime.now();

    return AnexoTarefa(
      id:
          map['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      tipo: tipo,
      url: map['url']?.toString() ?? '',
      descricao: map['descricao']?.toString() ?? '',
      nomeArquivo: map['nomeArquivo']?.toString() ?? '',
      criadoEm: criadoEm,
    );
  }
}

class TarefaItem {
  TarefaItem({
    required this.id,
    required this.autorId,
    required this.autorNome,
    required this.nome,
    this.descricao = '',
    this.clienteId = '',
    this.clienteNome = '',
    this.clienteDocumento = '',
    this.dataExecucao,
    required this.itens,
    this.materiaisNecessarios = const <MaterialTarefa>[],
    this.materiaisUtilizados = const <MaterialTarefa>[],
    this.anexos = const <AnexoTarefa>[],
    this.status = StatusTarefa.orcamento,
    this.valorTotalCents,
  });

  final String id;
  final String autorId;
  final String autorNome;
  final String nome;
  final String descricao;
  final String clienteId;
  final String clienteNome;
  final String clienteDocumento;
  final DateTime? dataExecucao;
  final List<ItemServico> itens;
  final List<MaterialTarefa> materiaisNecessarios;
  final List<MaterialTarefa> materiaisUtilizados;
  final List<AnexoTarefa> anexos;
  final StatusTarefa status;
  final int? valorTotalCents;

  TarefaItem copyWith({
    String? id,
    String? autorId,
    String? autorNome,
    String? nome,
    String? descricao,
    String? clienteId,
    String? clienteNome,
    String? clienteDocumento,
    DateTime? dataExecucao,
    bool limparDataExecucao = false,
    StatusTarefa? status,
    List<ItemServico>? itens,
    List<MaterialTarefa>? materiaisNecessarios,
    List<MaterialTarefa>? materiaisUtilizados,
    List<AnexoTarefa>? anexos,
    int? valorTotalCents,
    bool limparValorTotal = false,
  }) {
    return TarefaItem(
      id: id ?? this.id,
      autorId: autorId ?? this.autorId,
      autorNome: autorNome ?? this.autorNome,
      nome: nome ?? this.nome,
      descricao: descricao ?? this.descricao,
      clienteId: clienteId ?? this.clienteId,
      clienteNome: clienteNome ?? this.clienteNome,
      clienteDocumento: clienteDocumento ?? this.clienteDocumento,
      dataExecucao: limparDataExecucao
          ? null
          : dataExecucao ?? this.dataExecucao,
      itens: itens ?? this.itens,
      materiaisNecessarios: materiaisNecessarios ?? this.materiaisNecessarios,
      materiaisUtilizados: materiaisUtilizados ?? this.materiaisUtilizados,
      anexos: anexos ?? this.anexos,
      status: status ?? this.status,
      valorTotalCents: limparValorTotal
          ? null
          : valorTotalCents ?? this.valorTotalCents,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'autorId': autorId,
      'autorNome': autorNome,
      'nome': nome,
      'descricao': descricao,
      'clienteId': clienteId,
      'clienteNome': clienteNome,
      'clienteDocumento': clienteDocumento,
      'dataExecucao': dataExecucao?.toIso8601String(),
      'itens': itens.map((e) => e.toMap()).toList(),
      'materiaisNecessarios': materiaisNecessarios.map((e) => e.toMap()).toList(),
      'materiaisUtilizados': materiaisUtilizados.map((e) => e.toMap()).toList(),
      'anexos': anexos.map((e) => e.toMap()).toList(),
      'status': status.name,
      'valorTotalCents': valorTotalCents,
    };
  }

  factory TarefaItem.fromMap(Map<String, dynamic> map) {
    final lista = map['itens'];
    final itens = <ItemServico>[
      if (lista is List)
        for (final item in lista)
          if (item is Map<String, dynamic>) ItemServico.fromMap(item),
    ];
    final listaAnexos = map['anexos'];
    final anexos = <AnexoTarefa>[
      if (listaAnexos is List)
        for (final anexo in listaAnexos)
          if (anexo is Map<String, dynamic>) AnexoTarefa.fromMap(anexo),
    ];

    final statusNome = map['status']?.toString();
    final status =
        StatusTarefa.values.where((e) => e.name == statusNome).isNotEmpty
        ? StatusTarefa.values.firstWhere((e) => e.name == statusNome)
        : StatusTarefa.orcamento;
    final dataExecucao = DateTime.tryParse(
      map['dataExecucao']?.toString() ?? '',
    );
    final materiaisNecessariosRaw = map['materiaisNecessarios'];
    final materiaisUtilizadosRaw = map['materiaisUtilizados'];

    return TarefaItem(
      id:
          map['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      autorId: map['autorId']?.toString() ?? '',
      autorNome: map['autorNome']?.toString() ?? '',
      nome: map['nome']?.toString() ?? '',
      descricao: map['descricao']?.toString() ?? '',
      clienteId: map['clienteId']?.toString() ?? '',
      clienteNome: map['clienteNome']?.toString() ?? '',
      clienteDocumento: map['clienteDocumento']?.toString() ?? '',
      dataExecucao: dataExecucao,
      itens: itens,
      materiaisNecessarios: materiaisNecessariosRaw is List
          ? materiaisNecessariosRaw
                .map(MaterialTarefa.fromDynamic)
                .where((e) => e.nome.trim().isNotEmpty)
                .toList()
          : const <MaterialTarefa>[],
      materiaisUtilizados: materiaisUtilizadosRaw is List
          ? materiaisUtilizadosRaw
                .map(MaterialTarefa.fromDynamic)
                .where((e) => e.nome.trim().isNotEmpty)
                .toList()
          : const <MaterialTarefa>[],
      anexos: anexos,
      status: status,
      valorTotalCents: (map['valorTotalCents'] as num?)?.toInt(),
    );
  }

  String get clienteDocumentoFormatado {
    final digits = clienteDocumento.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 11) {
      return '${digits.substring(0, 3)}.${digits.substring(3, 6)}.${digits.substring(6, 9)}-${digits.substring(9)}';
    }
    if (digits.length == 14) {
      return '${digits.substring(0, 2)}.${digits.substring(2, 5)}.${digits.substring(5, 8)}/${digits.substring(8, 12)}-${digits.substring(12)}';
    }
    return clienteDocumento.trim();
  }
}
