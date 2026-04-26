import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontocerto/core/auth/session.dart';

class EmployeeAccessService {
  EmployeeAccessService(this.ref);

  final Object ref;

  Session? _readSession() {
    if (ref is WidgetRef) {
      return (ref as WidgetRef).read(sessionProvider);
    }
    if (ref is Ref) {
      return (ref as Ref).read(sessionProvider);
    }
    throw Exception('Referencia do Riverpod invalida para acesso de funcionario.');
  }

  Future<EmployeeAccessResult> criarAcessoFuncionario({
    required String nomeCompleto,
    required String email,
    required String role,
  }) async {
    final sessao = _readSession();
    if (sessao == null) {
      throw Exception('Sessao nao encontrada.');
    }

    final callable = FirebaseFunctions.instance.httpsCallable(
      'createEmployeeAccess',
    );

    final resultado = await callable.call(<String, dynamic>{
      'companyId': sessao.companyId,
      'nome': nomeCompleto,
      'email': email,
      'role': role,
    });

    final dados = resultado.data;
    if (dados is! Map) {
      throw Exception('Resposta invalida ao criar acesso do funcionario.');
    }
    final uid = dados['uid']?.toString();
    if (uid == null || uid.isEmpty) {
      throw Exception('UID do funcionario nao retornado.');
    }

    final emailSent = dados['emailSent'] == true;
    return EmployeeAccessResult(uid: uid, emailSent: emailSent);
  }

  Future<InviteConfigStatus> obterStatusConfiguracaoConvite() async {
    final sessao = _readSession();
    if (sessao == null) {
      throw Exception('Sessao nao encontrada.');
    }

    final callable = FirebaseFunctions.instance.httpsCallable(
      'getInviteConfigurationStatus',
    );
    final resultado = await callable.call(<String, dynamic>{});
    final dados = resultado.data;
    if (dados is! Map) {
      throw Exception(
        'Resposta invalida ao consultar configuracao de convite.',
      );
    }

    final configured = dados['configured'] == true;
    final missingRaw = dados['missing'];
    final missing = <String>[
      if (missingRaw is List) ...missingRaw.map((item) => item.toString()),
    ];

    return InviteConfigStatus(configured: configured, missing: missing);
  }

  Future<void> sincronizarPerfilEmpresa({
    required String companyName,
    required Map<String, dynamic> companyData,
  }) async {
    final sessao = _readSession();
    if (sessao == null) {
      throw Exception('Sessao nao encontrada.');
    }

    final callable = FirebaseFunctions.instance.httpsCallable(
      'syncCompanyProfile',
    );

    await callable.call(<String, dynamic>{
      'companyId': sessao.companyId,
      'companyName': companyName,
      'companyData': companyData,
    });
  }

  Future<void> atualizarPerfilFuncionario({
    required String employeeUid,
    required String nome,
    required String role,
    String? documento,
    String? pix,
    String? telefone,
    String? email,
    String? endereco,
    String? apelido,
    String? cargo,
    DateTime? admissionDate,
    String? compensationType,
    int? salaryAmountCents,
    double? commissionPercent,
  }) async {
    final sessao = _readSession();
    if (sessao == null) {
      throw Exception('Sessao nao encontrada.');
    }

    final callable = FirebaseFunctions.instance.httpsCallable(
      'updateEmployeeProfile',
    );

    await callable.call(<String, dynamic>{
      'companyId': sessao.companyId,
      'employeeUid': employeeUid,
      'nome': nome,
      'role': role,
      'documento': documento,
      'pix': pix,
      'telefone': telefone,
      'email': email,
      'endereco': endereco,
      'apelido': apelido,
      'cargo': cargo,
      'admissionDate': admissionDate?.toIso8601String(),
      'compensationType': compensationType,
      'salaryAmountCents': salaryAmountCents,
      'commissionPercent': commissionPercent,
    });
  }

  Future<void> atualizarStatusFuncionario({
    required String employeeUid,
    required bool ativo,
  }) async {
    final sessao = _readSession();
    if (sessao == null) {
      throw Exception('Sessao nao encontrada.');
    }

    final callable = FirebaseFunctions.instance.httpsCallable(
      'setEmployeeActiveStatus',
    );

    await callable.call(<String, dynamic>{
      'companyId': sessao.companyId,
      'employeeUid': employeeUid,
      'ativo': ativo,
    });
  }
}

class EmployeeAccessResult {
  const EmployeeAccessResult({required this.uid, required this.emailSent});

  final String uid;
  final bool emailSent;
}

class InviteConfigStatus {
  const InviteConfigStatus({required this.configured, required this.missing});

  final bool configured;
  final List<String> missing;
}
