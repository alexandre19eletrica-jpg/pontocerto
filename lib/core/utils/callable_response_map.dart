/// Converte o payload devolvido por [HttpsCallable.call] para um mapa utilizável em Dart,
/// inclusive quando os tipos de interop/web não fazem cast directo para Map com chaves String.
Map<String, dynamic> mapFromCallableData(Object? data) {
  if (data == null) return <String, dynamic>{};
  if (data is Map<String, dynamic>) {
    return Map<String, dynamic>.from(data);
  }
  if (data is Map) {
    final out = <String, dynamic>{};
    data.forEach((key, value) {
      out[key.toString()] = value;
    });
    return out;
  }
  return <String, dynamic>{};
}
