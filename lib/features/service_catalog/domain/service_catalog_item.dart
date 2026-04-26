class ServiceCatalogItem {
  ServiceCatalogItem({
    required this.id,
    required this.companyId,
    required this.nome,
    required this.valorCents,
    this.pendingDelete = false,
    this.pendingDeleteByName = '',
    this.pendingEditNome,
    this.pendingEditValorCents,
    this.pendingEditByName = '',
  });

  final String id;
  final String companyId;
  final String nome;
  final int valorCents;

  final bool pendingDelete;
  final String pendingDeleteByName;

  final String? pendingEditNome;
  final int? pendingEditValorCents;
  final String pendingEditByName;

  bool get hasPendingEdit =>
      (pendingEditNome != null && pendingEditNome!.trim().isNotEmpty) ||
      pendingEditValorCents != null;

  factory ServiceCatalogItem.fromMap(String id, Map<String, dynamic> map) {
    return ServiceCatalogItem(
      id: id,
      companyId: map['companyId']?.toString() ?? '',
      nome: map['nome']?.toString() ?? '',
      valorCents: (map['valorCents'] as num?)?.toInt() ?? 0,
      pendingDelete: map['pendingDelete'] == true,
      pendingDeleteByName: map['pendingDeleteByName']?.toString() ?? '',
      pendingEditNome: map['pendingEditNome']?.toString(),
      pendingEditValorCents: (map['pendingEditValorCents'] as num?)?.toInt(),
      pendingEditByName: map['pendingEditByName']?.toString() ?? '',
    );
  }
}
