import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _chaveNomeEmpresa = 'nome_empresa_cache';

final nomeEmpresaCacheProvider = StateProvider<String?>((ref) => null);

Future<String?> lerNomeEmpresaCache() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_chaveNomeEmpresa);
}

Future<void> salvarNomeEmpresaCache(String nomeEmpresa) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_chaveNomeEmpresa, nomeEmpresa);
}
