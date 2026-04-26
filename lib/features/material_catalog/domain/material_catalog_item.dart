class MaterialCatalogItem {
  const MaterialCatalogItem({
    required this.id,
    required this.companyId,
    required this.nome,
    this.quantidade = 1,
    this.unidade = 'un',
    this.observacao = '',
    this.pendingCreate = false,
    this.pendingCreateByName = '',
    this.pendingEditNome,
    this.pendingEditQuantidade,
    this.pendingEditUnidade,
    this.pendingEditObservacao,
    this.pendingEditByName = '',
  });

  final String id;
  final String companyId;
  final String nome;
  final int quantidade;
  final String unidade;
  final String observacao;
  final bool pendingCreate;
  final String pendingCreateByName;
  final String? pendingEditNome;
  final int? pendingEditQuantidade;
  final String? pendingEditUnidade;
  final String? pendingEditObservacao;
  final String pendingEditByName;

  int get quantidadeNormalizada => quantidade < 1 ? 1 : quantidade;

  String get unidadeNormalizada =>
      unidade.trim().isEmpty ? 'un' : unidade.trim();

  String get observacaoNormalizada => observacao.trim();

  bool get hasPendingEdit =>
      (pendingEditNome != null && pendingEditNome!.trim().isNotEmpty) ||
      pendingEditQuantidade != null ||
      (pendingEditUnidade != null && pendingEditUnidade!.trim().isNotEmpty) ||
      (pendingEditObservacao != null &&
          pendingEditObservacao!.trim().isNotEmpty);

  factory MaterialCatalogItem.fromMap(String id, Map<String, dynamic> map) {
    return MaterialCatalogItem(
      id: id,
      companyId: map['companyId']?.toString() ?? '',
      nome: map['nome']?.toString() ?? '',
      quantidade: ((map['quantidade'] as num?)?.toInt() ?? 1).clamp(1, 999999),
      unidade: map['unidade']?.toString() ?? 'un',
      observacao: map['observacao']?.toString() ?? '',
      pendingCreate: map['pendingCreate'] == true,
      pendingCreateByName: map['pendingCreateByName']?.toString() ?? '',
      pendingEditNome: map['pendingEditNome']?.toString(),
      pendingEditQuantidade: (map['pendingEditQuantidade'] as num?)?.toInt(),
      pendingEditUnidade: map['pendingEditUnidade']?.toString(),
      pendingEditObservacao: map['pendingEditObservacao']?.toString(),
      pendingEditByName: map['pendingEditByName']?.toString() ?? '',
    );
  }
}
