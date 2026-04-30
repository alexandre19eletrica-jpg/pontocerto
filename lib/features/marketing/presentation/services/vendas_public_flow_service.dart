import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Chamadas do fluxo publico de vendas (Cloud Functions isoladas).
class VendasPublicFlowService {
  VendasPublicFlowService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  Future<Map<String, dynamic>> getConvite({required String token}) async {
    final callable = _functions.httpsCallable('vendasPublicGetConvite');
    final result = await callable.call(<String, dynamic>{'token': token});
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<Map<String, dynamic>> submitContadorConvite({
    required String token,
    required String nomeContador,
    required String email,
    required String senha,
    required String confirmaSenha,
  }) async {
    final callable = _functions.httpsCallable('vendasPublicSubmitContadorConvite');
    final result = await callable.call(<String, dynamic>{
      'token': token,
      'nome_contador': nomeContador,
      'email': email,
      'senha': senha,
      'confirma_senha': confirmaSenha,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }
}

/// Origem para POST /api/lead-contabilidade (mesmo host no web).
Uri vendasLeadContabilidadeUri() {
  if (kIsWeb) {
    final base = Uri.base;
    return base.replace(path: '/api/lead-contabilidade', query: '');
  }
  return Uri.parse('https://gestao-ponto-certo.com/api/lead-contabilidade');
}
