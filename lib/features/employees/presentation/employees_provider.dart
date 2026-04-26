import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/company/company_visual_identity.dart';
import 'package:pontocerto/core/firebase/employee_access_service.dart';
import 'package:pontocerto/core/firebase/firebase_status.dart';
import 'package:pontocerto/features/audit/presentation/audit_provider.dart';
import 'package:pontocerto/features/employees/domain/employee.dart';

class EmployeesNotifier extends Notifier<List<Employee>> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  @override
  List<Employee> build() {
    ref.onDispose(() => _sub?.cancel());
    final firebaseDisponivel = ref.watch(firebaseAvailableProvider);
    final sessao = ref.watch(sessionProvider);
    _bindStream(firebaseDisponivel, sessao);
    return <Employee>[];
  }

  void _bindStream(bool firebaseDisponivel, Session? sessao) {
    _sub?.cancel();
    if (!firebaseDisponivel || sessao == null) {
      state = <Employee>[];
      return;
    }

    final query = FirebaseFirestore.instance
        .collection('users')
        .where('companyId', isEqualTo: sessao.companyId);

    _sub = query.snapshots().listen(
      (snapshot) {
        state = [
          for (final doc in snapshot.docs)
            if (_isEmployeeRole(doc.data()['role'])) _fromDoc(doc),
        ];
      },
      onError: (error, stackTrace) {
        // Mantem o estado atual em falha temporaria de stream.
      },
    );
  }

  bool _isEmployeeRole(dynamic roleValue) {
    final role = _normalizeRole(roleValue);
    return role == 'employee' ||
        role == 'manager' ||
        role == 'accountant' ||
        role == 'unknown';
  }

  Employee _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? <String, dynamic>{};
    final normalizedRole = _normalizeRole(map['role']);
    final role = switch (normalizedRole) {
      'manager' => EmployeeRole.manager,
      'accountant' => EmployeeRole.accountant,
      _ => EmployeeRole.employee,
    };
    final compensationRaw =
        map['compensationType']?.toString().trim().toUpperCase() ?? 'MONTHLY';
    final compensationType = switch (compensationRaw) {
      'DAILY' => EmployeeCompensationType.daily,
      'WEEKLY' => EmployeeCompensationType.weekly,
      'COMMISSION' => EmployeeCompensationType.commission,
      _ => EmployeeCompensationType.monthly,
    };

    return Employee(
      id: doc.id,
      nomeCompleto: map['nome']?.toString() ?? '',
      documento: map['documento']?.toString() ?? '',
      pix: map['pix']?.toString() ?? '',
      telefone: _limparOpcional(map['telefone']?.toString()),
      email: _limparOpcional(map['email']?.toString()),
      endereco: _limparOpcional(map['endereco']?.toString()),
      apelido: _limparOpcional(map['apelido']?.toString()),
      fotoUrl: _limparOpcional(map['fotoUrl']?.toString()),
      cargo: _limparOpcional(map['cargo']?.toString()),
      admissionDate: _toDate(map['admissionDate']),
      compensationType: compensationType,
      salaryAmountCents: (map['salaryAmountCents'] as num?)?.toInt(),
      commissionPercent: (map['commissionPercent'] as num?)?.toDouble(),
      role: role,
      ativo: map['ativo'] != false,
    );
  }

  Future<void> add({
    String? id,
    required String nomeCompleto,
    required String documento,
    required String pix,
    String? telefone,
    String? email,
    String? endereco,
    String? apelido,
    String? fotoUrl,
    String? cargo,
    DateTime? admissionDate,
    required EmployeeCompensationType compensationType,
    int? salaryAmountCents,
    double? commissionPercent,
    required EmployeeRole role,
  }) async {
    final sessao = ref.read(sessionProvider);
    if (sessao == null) throw Exception('Sessao nao encontrada.');

    final employeeId = id ?? DateTime.now().microsecondsSinceEpoch.toString();
    final snapshotAnterior = state;
    final novo = Employee(
      id: employeeId,
      nomeCompleto: nomeCompleto.trim(),
      documento: documento.trim(),
      pix: pix.trim(),
      telefone: _limparOpcional(telefone),
      email: _limparOpcional(email),
      endereco: _limparOpcional(endereco),
      apelido: _limparOpcional(apelido),
      fotoUrl: _limparOpcional(fotoUrl),
      cargo: _limparOpcional(cargo),
      admissionDate: admissionDate,
      compensationType: compensationType,
      salaryAmountCents: salaryAmountCents,
      commissionPercent: commissionPercent,
      role: role,
      ativo: true,
    );
    state = [
      novo,
      for (final item in state)
        if (item.id != employeeId) item,
    ];

    try {
      await FirebaseFirestore.instance.collection('users').doc(employeeId).set({
        'companyId': sessao.companyId,
        'role': switch (role) {
          EmployeeRole.manager => 'MANAGER',
          EmployeeRole.accountant => 'ACCOUNTANT',
          EmployeeRole.employee => 'EMPLOYEE',
        },
        'nome': nomeCompleto.trim(),
        'documento': documento.trim(),
        'pix': pix.trim(),
        'telefone': _limparOpcional(telefone),
        'email': _limparOpcional(email),
        'endereco': _limparOpcional(endereco),
        'apelido': _limparOpcional(apelido),
        'fotoUrl': _limparOpcional(fotoUrl),
        'cargo': _limparOpcional(cargo),
        'admissionDate': admissionDate == null
            ? null
            : Timestamp.fromDate(admissionDate),
        'compensationType': _compensationTypeToFirestore(compensationType),
        'salaryAmountCents': salaryAmountCents,
        'commissionPercent': commissionPercent,
        'ativo': true,
        'employeeId': employeeId,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _syncAccountantLink(
        employeeId: employeeId,
        role: role,
        nomeCompleto: nomeCompleto.trim(),
        email: _limparOpcional(email),
        ativo: true,
      );
    } catch (e) {
      state = snapshotAnterior;
      rethrow;
    }

    _registrarAuditoria('add');
  }

  Future<void> update({
    required String id,
    required String nomeCompleto,
    required String documento,
    required String pix,
    String? telefone,
    String? email,
    String? endereco,
    String? apelido,
    String? fotoUrl,
    String? cargo,
    DateTime? admissionDate,
    required EmployeeCompensationType compensationType,
    int? salaryAmountCents,
    double? commissionPercent,
    required EmployeeRole role,
  }) async {
    final sessao = ref.read(sessionProvider);
    if (sessao == null) throw Exception('Sessao nao encontrada.');

    final snapshotAnterior = state;
    state = [
      for (final item in state)
        if (item.id == id)
          item.copyWith(
            nomeCompleto: nomeCompleto.trim(),
            documento: documento.trim(),
            pix: pix.trim(),
            telefone: _limparOpcional(telefone),
            email: _limparOpcional(email),
            endereco: _limparOpcional(endereco),
            apelido: _limparOpcional(apelido),
            fotoUrl: _limparOpcional(fotoUrl),
            cargo: _limparOpcional(cargo),
            admissionDate: admissionDate,
            compensationType: compensationType,
            salaryAmountCents: salaryAmountCents,
            commissionPercent: commissionPercent,
            role: role,
          )
        else
          item,
    ];

    try {
      final before = snapshotAnterior.where((item) => item.id == id).firstOrNull;
      await FirebaseFirestore.instance.collection('users').doc(id).set({
        'companyId': sessao.companyId,
        'role': switch (role) {
          EmployeeRole.manager => 'MANAGER',
          EmployeeRole.accountant => 'ACCOUNTANT',
          EmployeeRole.employee => 'EMPLOYEE',
        },
        'nome': nomeCompleto.trim(),
        'documento': documento.trim(),
        'pix': pix.trim(),
        'telefone': _limparOpcional(telefone),
        'email': _limparOpcional(email),
        'endereco': _limparOpcional(endereco),
        'apelido': _limparOpcional(apelido),
        'fotoUrl': _limparOpcional(fotoUrl),
        'cargo': _limparOpcional(cargo),
        'admissionDate': admissionDate == null
            ? null
            : Timestamp.fromDate(admissionDate),
        'compensationType': _compensationTypeToFirestore(compensationType),
        'salaryAmountCents': salaryAmountCents,
        'commissionPercent': commissionPercent,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _syncAccountantLink(
        employeeId: id,
        role: role,
        nomeCompleto: nomeCompleto.trim(),
        email: _limparOpcional(email),
        ativo: before?.ativo ?? true,
      );
    } catch (e) {
      state = snapshotAnterior;
      rethrow;
    }

    _registrarAuditoria('update');
  }

  Future<void> toggleAtivo(String id) async {
    final sessao = ref.read(sessionProvider);
    if (sessao == null) throw Exception('Sessao nao encontrada.');

    Employee? employee;
    for (final item in state) {
      if (item.id == id) {
        employee = item;
        break;
      }
    }
    if (employee == null) return;

    final snapshotAnterior = state;
    state = [
      for (final item in state)
        if (item.id == id) item.copyWith(ativo: !item.ativo) else item,
    ];

    try {
      await FirebaseFirestore.instance.collection('users').doc(id).set({
        'companyId': sessao.companyId,
        'ativo': !employee.ativo,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!_isNumericOnly(id)) {
        try {
          await EmployeeAccessService(ref).atualizarStatusFuncionario(
            employeeUid: id,
            ativo: !employee.ativo,
          );
        } catch (_) {
          // Mantem a troca local mesmo se o ajuste do Auth falhar.
        }
      }
      await _syncAccountantLink(
        employeeId: id,
        role: employee.role,
        nomeCompleto: employee.nomeCompleto,
        email: employee.email,
        ativo: !employee.ativo,
      );
    } catch (e) {
      state = snapshotAnterior;
      rethrow;
    }

    _registrarAuditoria('toggleAtivo');
  }

  bool _isNumericOnly(String id) => RegExp(r'^\d+$').hasMatch(id);

  Future<void> remove(String id) async {
    final snapshotAnterior = state;
    state = [
      for (final item in state)
        if (item.id != id) item,
    ];
    try {
      await FirebaseFirestore.instance.collection('users').doc(id).delete();
      await FirebaseFirestore.instance.collection('accountant_links').doc(id).delete();
    } catch (e) {
      state = snapshotAnterior;
      rethrow;
    }
    _registrarAuditoria('remove');
  }

  String? _limparOpcional(String? valor) {
    final texto = valor?.trim();
    if (texto == null || texto.isEmpty) return null;
    return texto;
  }

  DateTime? _toDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  String _normalizeRole(dynamic rawRole) {
    final role = rawRole?.toString().trim().toLowerCase() ?? '';
    if (role == 'manager' || role == 'gerente') return 'manager';
    if (role == 'accountant' || role == 'contador') return 'accountant';
    if (role == 'employee' || role == 'funcionario') return 'employee';
    if (role.isEmpty) return 'unknown';
    return role;
  }

  String _compensationTypeToFirestore(EmployeeCompensationType type) {
    return switch (type) {
      EmployeeCompensationType.daily => 'DAILY',
      EmployeeCompensationType.weekly => 'WEEKLY',
      EmployeeCompensationType.monthly => 'MONTHLY',
      EmployeeCompensationType.commission => 'COMMISSION',
    };
  }

  Future<void> rebuildAccountantLinks() async {
    final session = ref.read(sessionProvider);
    if (session == null) throw Exception('Sessao nao encontrada.');
    final accountants = state.where((item) => item.role == EmployeeRole.accountant);
    final companyMeta = await _loadCompanyLinkMeta(session.companyId);
    final batch = FirebaseFirestore.instance.batch();
    for (final accountant in accountants) {
      final linkId = '${session.companyId}_${accountant.id}';
      final refDoc = FirebaseFirestore.instance
          .collection('accountant_links')
          .doc(linkId);
      batch.set(refDoc, {
        'companyId': session.companyId,
        'companyName': companyMeta.companyName,
        'companyDocument': companyMeta.companyDocument,
        'companyDisplayCode': companyMeta.companyDisplayCode,
        'accountantUserId': accountant.id,
        'accountantName': accountant.nomeCompleto,
        'accountantEmail': accountant.email,
        'linkedByUserId': session.userId,
        'linkedByName': session.nome,
        'status': accountant.ativo ? 'active' : 'inactive',
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
    _registrarAuditoria('rebuildAccountantLinks');
  }

  Future<void> _syncAccountantLink({
    required String employeeId,
    required EmployeeRole role,
    required String nomeCompleto,
    required String? email,
    required bool ativo,
  }) async {
    final session = ref.read(sessionProvider);
    if (session == null) return;
    final linkId = '${session.companyId}_$employeeId';
    final linkRef = FirebaseFirestore.instance
        .collection('accountant_links')
        .doc(linkId);
    if (role != EmployeeRole.accountant) {
      await linkRef.delete();
      return;
    }
    final companyMeta = await _loadCompanyLinkMeta(session.companyId);
    await linkRef.set({
      'companyId': session.companyId,
      'companyName': companyMeta.companyName,
      'companyDocument': companyMeta.companyDocument,
      'companyDisplayCode': companyMeta.companyDisplayCode,
      'accountantUserId': employeeId,
      'accountantName': nomeCompleto,
      'accountantEmail': email,
      'linkedByUserId': session.userId,
      'linkedByName': session.nome,
      'status': ativo ? 'active' : 'inactive',
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<
    ({
      String companyName,
      String companyDocument,
      String companyDisplayCode,
    })
  > _loadCompanyLinkMeta(String companyId) async {
    final settingsDoc = await FirebaseFirestore.instance
        .collection('company_settings')
        .doc(companyId)
        .get();
    final settingsData = settingsDoc.data() ?? <String, dynamic>{};
    final companyData =
        (settingsData['companyData'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    final companyName =
        companyData['nomeFantasia']?.toString().trim().isNotEmpty == true
        ? companyData['nomeFantasia'].toString().trim()
        : companyData['razaoSocial']?.toString().trim() ?? '';
    final companyDocument = companyData['cnpj']?.toString().trim() ?? '';
    return (
      companyName: companyName,
      companyDocument: companyDocument,
      companyDisplayCode: buildCompanyDisplayCode(
        cnpj: companyDocument,
        companyName: companyName,
      ),
    );
  }

  void _registrarAuditoria(String acao) {
    try {
      ref.read(auditProvider.notifier).log(modulo: 'employees', acao: acao);
    } catch (_) {
      // Nao bloqueia o fluxo principal se auditoria falhar.
    }
  }
}

final employeesProvider = NotifierProvider<EmployeesNotifier, List<Employee>>(
  EmployeesNotifier.new,
);
