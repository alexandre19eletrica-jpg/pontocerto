import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppErrorMapper {
  const AppErrorMapper._();

  static String messageFrom(
    Object error, {
    String fallback = 'Nao foi possivel concluir a operacao.',
  }) {
    if (error is FirebaseAuthException) {
      return _authMessage(error) ?? error.message ?? fallback;
    }

    if (error is FirebaseFunctionsException) {
      return _functionsMessage(error) ?? error.message ?? fallback;
    }

    if (error is FirebaseException) {
      return _firebaseMessage(error) ?? error.message ?? fallback;
    }

    if (error is TimeoutException) {
      return 'Tempo de resposta excedido. Tente novamente.';
    }

    final raw = error.toString().toLowerCase();
    if (raw.contains('socketexception') ||
        raw.contains('network') ||
        raw.contains('connection')) {
      return 'Sem conexao com a internet. Verifique a rede e tente novamente.';
    }

    return fallback;
  }

  static String? _authMessage(FirebaseAuthException e) {
    return switch (e.code) {
      'invalid-email' => 'Email invalido.',
      'user-not-found' => 'Usuario nao encontrado.',
      'wrong-password' => 'Senha incorreta.',
      'invalid-credential' => 'Credenciais invalidas.',
      'email-already-in-use' => 'Este email ja esta em uso.',
      'weak-password' => 'Senha fraca. Use pelo menos 6 caracteres.',
      'too-many-requests' => 'Muitas tentativas. Tente novamente em instantes.',
      'network-request-failed' => 'Sem conexao com a internet.',
      'operation-not-allowed' => 'Metodo de login nao habilitado no Firebase Auth.',
      'user-disabled' => 'Conta desativada.',
      _ => null,
    };
  }

  static String? _functionsMessage(FirebaseFunctionsException e) {
    return switch (e.code) {
      'unauthenticated' => 'Sessao expirada. Entre novamente.',
      'permission-denied' => 'Seu perfil nao tem permissao para esta acao.',
      'invalid-argument' => 'Dados invalidos para esta operacao.',
      'failed-precondition' => e.message,
      'resource-exhausted' => e.message,
      'not-found' => 'Servico indisponivel no momento.',
      'deadline-exceeded' => 'Tempo de resposta excedido.',
      'unavailable' => 'Servico temporariamente indisponivel.',
      'internal' =>
          (e.message != null && e.message!.trim().isNotEmpty) ? e.message : null,
      _ => null,
    };
  }

  static String? _firebaseMessage(FirebaseException e) {
    if (e.plugin == 'cloud_firestore') {
      return switch (e.code) {
        'permission-denied' => 'Operacao bloqueada pelas regras de seguranca.',
        'unavailable' => 'Firestore indisponivel no momento.',
        'not-found' => 'Registro nao encontrado.',
        'failed-precondition' => 'Precondicao nao atendida no Firestore.',
        _ => null,
      };
    }
    return null;
  }
}
