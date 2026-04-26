part of 'tasks_page.dart';

bool _documentoEhCnpjTexto(String valor) => _somenteDigitosTexto(valor).length == 14;

bool _documentoEhCpfTexto(String valor) => _somenteDigitosTexto(valor).length == 11;

String _somenteDigitosTexto(String valor) => valor.replaceAll(RegExp(r'[^0-9]'), '');

String _sharedCustomerId(String document) {
  final digits = _somenteDigitosTexto(document);
  if (digits.isNotEmpty) return digits;
  return DateTime.now().microsecondsSinceEpoch.toString();
}

void _applySharedCustomer({
  required InvoiceCustomer customer,
  required TextEditingController clienteCtrl,
  required TextEditingController clienteDocumentoCtrl,
}) {
  clienteCtrl.text = customer.legalName.isNotEmpty
      ? customer.legalName
      : customer.tradeName;
  clienteDocumentoCtrl.text = customer.document;
}

Future<String> _saveSharedCustomer({
  required Session sessao,
  required String clientId,
  required String clientName,
  required String clientDocument,
  String email = '',
  String phone = '',
  String municipalRegistration = '',
  String stateRegistration = '',
  String zipCode = '',
  String street = '',
  String number = '',
  String complement = '',
  String neighborhood = '',
  String city = '',
  String state = '',
}) async {
  await FirebaseFirestore.instance.collection('invoice_customers').doc(clientId).set({
    'companyId': sessao.companyId,
    'legalName': clientName,
    'tradeName': '',
    'document': clientDocument,
    'email': email,
    'phone': phone,
    'municipalRegistration': municipalRegistration,
    'stateRegistration': stateRegistration,
    'zipCode': zipCode,
    'street': street,
    'number': number,
    'complement': complement,
    'neighborhood': neighborhood,
    'city': city,
    'state': state,
    'country': 'BRASIL',
    'notes': '',
    'createdAtIso': DateTime.now().toIso8601String(),
    'updatedAtIso': DateTime.now().toIso8601String(),
  }, SetOptions(merge: true));
  return clientId;
}

Employee? _findResponsibleById(List<Employee> employees, String? employeeId) {
  if (employeeId == null || employeeId.trim().isEmpty) return null;
  return employees.where((e) => e.id == employeeId).firstOrNull;
}

String _taskStatusLabel(StatusTarefa status) {
  switch (status) {
    case StatusTarefa.orcamento:
      return 'Orcamento';
    case StatusTarefa.aprovado:
      return 'Aprovado';
    case StatusTarefa.iniciado:
      return 'Iniciado';
    case StatusTarefa.emAndamento:
      return 'Em andamento';
    case StatusTarefa.finalizado:
      return 'Finalizado';
  }
}

String _taskFormatDate(DateTime? data) {
  if (data == null) return '-';
  final dia = data.day.toString().padLeft(2, '0');
  final mes = data.month.toString().padLeft(2, '0');
  return '$dia/$mes/${data.year}';
}

String _taskFormatDateTime(DateTime data) {
  final dia = data.day.toString().padLeft(2, '0');
  final mes = data.month.toString().padLeft(2, '0');
  final hora = data.hour.toString().padLeft(2, '0');
  final minuto = data.minute.toString().padLeft(2, '0');
  return '$dia/$mes/${data.year} $hora:$minuto';
}

String _taskAttachmentTitle(AnexoTarefa anexo) {
  final formato = _taskAttachmentFormat(anexo);
  return '$formato - ${_taskFormatDateTime(anexo.criadoEm)}';
}

String _taskAttachmentSubtitle(AnexoTarefa anexo) {
  if (anexo.descricao.trim().isNotEmpty) return anexo.descricao.trim();
  return anexo.tipo == TipoAnexoTarefa.foto ? 'Foto anexada' : 'Video anexado';
}

String _taskAttachmentFormat(AnexoTarefa anexo) {
  final nome = anexo.nomeArquivo.trim().toLowerCase();
  if (nome.endsWith('.jpg') || nome.endsWith('.jpeg')) return 'JPG';
  if (nome.endsWith('.png')) return 'PNG';
  if (nome.endsWith('.mp4')) return 'MP4';
  if (nome.endsWith('.mov')) return 'MOV';
  if (nome.endsWith('.avi')) return 'AVI';
  return anexo.tipo == TipoAnexoTarefa.foto ? 'FOTO' : 'VIDEO';
}

int? _taskParseReaisParaCents(String valor) {
  var texto = valor.trim().replaceAll('R\$', '').replaceAll(' ', '');
  if (texto.isEmpty) return null;
  texto = texto.replaceAll('.', '').replaceAll(',', '.');
  final numero = double.tryParse(texto);
  if (numero == null) return null;
  return (numero * 100).round();
}

String _taskCentsToInput(int? cents) {
  if (cents == null) return '';
  final reais = cents ~/ 100;
  final centavos = (cents % 100).abs().toString().padLeft(2, '0');
  return '$reais,$centavos';
}

String _taskFormatMoney(int cents) {
  final negativo = cents < 0;
  final absoluto = cents.abs();
  final reais = absoluto ~/ 100;
  final centavos = (absoluto % 100).toString().padLeft(2, '0');
  final reaisTexto = reais.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => '.',
  );
  return '${negativo ? '-' : ''}R\$ $reaisTexto,$centavos';
}

class _OpcaoAnexo {
  _OpcaoAnexo(this.tipo, this.origem);

  final TipoAnexoTarefa tipo;
  final ImageSource origem;
}
