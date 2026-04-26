import 'package:cloud_functions/cloud_functions.dart';

class FiscalRegistryLookupService {
  FiscalRegistryLookupService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  Future<Map<String, dynamic>> lookupCnpj(String cnpj) async {
    final callable = _functions.httpsCallable('lookupBrazilCnpj');
    final response = await callable.call(<String, dynamic>{'cnpj': cnpj});
    final data = response.data;
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> lookupCep(String cep) async {
    final callable = _functions.httpsCallable('lookupBrazilCep');
    final response = await callable.call(<String, dynamic>{'cep': cep});
    final data = response.data;
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    return <String, dynamic>{};
  }
}
