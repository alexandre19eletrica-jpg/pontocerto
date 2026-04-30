import 'package:flutter_riverpod/flutter_riverpod.dart';

enum Role { owner, manager, accountant, employee }

class Session {
  const Session({
    required this.userId,
    required this.companyId,
    required this.role,
    required this.nome,
    this.email = '',
  });

  final String userId;
  final String companyId;
  final Role role;
  final String nome;
  final String email;
}

bool canAccessRoute(Role role, String location) {
  if (location == '/accountant-companies') {
    return role == Role.accountant;
  }
  if (location == '/accountant-partner') {
    return role == Role.accountant;
  }
  if (location == '/accountant-fiscal-profile') {
    return role == Role.accountant;
  }
  if (location == '/accountant-register-company') {
    return role == Role.accountant;
  }
  if (location == '/accountant-declarations') {
    return role == Role.accountant;
  }

  if (role == Role.owner) {
    return true;
  }

  if (role == Role.manager) {
    return location != '/settings' &&
        location != '/audit' &&
        !location.startsWith('/platform-admin') &&
        location != '/runtime-incidents';
  }

  if (role == Role.accountant) {
    const rotasPermitidasContador = <String>{
      '/home',
      '/assistant',
      '/accountant-companies',
      '/accountant-partner',
      '/accountant-fiscal-profile',
      '/accountant-register-company',
      '/accountant-declarations',
      '/billing',
      '/contracts',
      '/documents',
      '/fiscal',
      '/improvements',
      '/workforce',
      '/employees',
    };
    return rotasPermitidasContador.contains(location);
  }

  if (location == '/runtime-incidents') {
    return false;
  }

  const rotasPermitidasFuncionario = <String>{
    '/home',
    '/documents',
    '/tasks',
    '/service-orders',
    '/service-catalog',
    '/materials',
    '/finance',
    '/punch',
    '/justifications',
    '/jornada-ponto-certo',
  };

  return rotasPermitidasFuncionario.contains(location);
}

class SessionController extends StateNotifier<Session?> {
  SessionController() : super(null);

  void definirSessao(Session sessao) {
    state = sessao;
  }

  void trocarEmpresa({required String companyId, String? nome}) {
    final atual = state;
    if (atual == null) return;
    state = Session(
      userId: atual.userId,
      companyId: companyId,
      role: atual.role,
      nome: nome ?? atual.nome,
      email: atual.email,
    );
  }

  void definirSessaoPorMapa({
    required String userId,
    required Map<String, dynamic> dados,
  }) {
    final role = _parseRole(dados['role']?.toString());

    state = Session(
      userId: userId,
      companyId: dados['companyId']?.toString() ?? 'empresa_sem_id',
      role: role,
      nome: dados['nome']?.toString() ?? 'Usuario',
      email: dados['email']?.toString() ?? '',
    );
  }

  void loginLocal(Role role) {
    final nome = switch (role) {
      Role.owner => 'Dono Local',
      Role.manager => 'Gerente Local',
      Role.accountant => 'Contador Local',
      Role.employee => 'Funcionario Local',
    };

    final userId = switch (role) {
      Role.owner => 'local_owner',
      Role.manager => 'local_manager',
      Role.accountant => 'local_accountant',
      Role.employee => 'local_employee',
    };

    state = Session(
      userId: userId,
      companyId: 'empresa_local',
      role: role,
      nome: nome,
      email: '',
    );
  }

  void logout() {
    state = null;
  }

  Role _parseRole(String? valor) {
    final normalizado = valor?.trim().toLowerCase();
    return switch (normalizado) {
      'owner' || 'dono' => Role.owner,
      'manager' || 'gerente' => Role.manager,
      'accountant' || 'contador' => Role.accountant,
      'employee' || 'funcionario' => Role.employee,
      _ => Role.employee,
    };
  }
}

final sessionProvider = StateNotifierProvider<SessionController, Session?>((
  ref,
) {
  return SessionController();
});
