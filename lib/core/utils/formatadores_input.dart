import 'package:flutter/services.dart';

String _somenteDigitos(String valor) => valor.replaceAll(RegExp(r'[^0-9]'), '');

String sanitizeMunicipalRegistrationFromCnpjLookup(
  Object? source, [
  String fallback = '',
]) {
  final trimmed = switch (source) {
    Map<dynamic, dynamic> map =>
      (map['municipalRegistration'] ??
              map['inscricaoMunicipal'] ??
              map['municipal_registration'] ??
              fallback)
          .toString()
          .trim(),
    _ => (source ?? fallback).toString().trim(),
  };
  if (trimmed.isEmpty) return '';
  final normalized = trimmed.toLowerCase();
  if (normalized == 'isento' ||
      normalized == 'nao possui' ||
      normalized == 'não possui' ||
      normalized == 'dispensado' ||
      normalized == 'na' ||
      normalized == 'n/a') {
    return '';
  }
  return trimmed.replaceAll(RegExp(r'[^0-9A-Za-z./-]'), '');
}

class CpfCnpjInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitos = _somenteDigitos(newValue.text);
    final max = digitos.length > 11 ? 14 : 11;
    final texto = digitos.substring(
      0,
      digitos.length > max ? max : digitos.length,
    );
    final formatado = texto.length <= 11
        ? _formatarCpf(texto)
        : _formatarCnpj(texto);
    return TextEditingValue(
      text: formatado,
      selection: TextSelection.collapsed(offset: formatado.length),
    );
  }

  String _formatarCpf(String v) {
    if (v.length <= 3) return v;
    if (v.length <= 6) return '${v.substring(0, 3)}.${v.substring(3)}';
    if (v.length <= 9) {
      return '${v.substring(0, 3)}.${v.substring(3, 6)}.${v.substring(6)}';
    }
    return '${v.substring(0, 3)}.${v.substring(3, 6)}.${v.substring(6, 9)}-${v.substring(9)}';
  }

  String _formatarCnpj(String v) {
    if (v.length <= 2) return v;
    if (v.length <= 5) return '${v.substring(0, 2)}.${v.substring(2)}';
    if (v.length <= 8) {
      return '${v.substring(0, 2)}.${v.substring(2, 5)}.${v.substring(5)}';
    }
    if (v.length <= 12) {
      return '${v.substring(0, 2)}.${v.substring(2, 5)}.${v.substring(5, 8)}/${v.substring(8)}';
    }
    return '${v.substring(0, 2)}.${v.substring(2, 5)}.${v.substring(5, 8)}/${v.substring(8, 12)}-${v.substring(12)}';
  }
}

class CnpjInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitos = _somenteDigitos(newValue.text);
    final texto = digitos.substring(
      0,
      digitos.length > 14 ? 14 : digitos.length,
    );
    final formatado = _formatarCnpj(texto);
    return TextEditingValue(
      text: formatado,
      selection: TextSelection.collapsed(offset: formatado.length),
    );
  }

  String _formatarCnpj(String v) {
    if (v.length <= 2) return v;
    if (v.length <= 5) return '${v.substring(0, 2)}.${v.substring(2)}';
    if (v.length <= 8) {
      return '${v.substring(0, 2)}.${v.substring(2, 5)}.${v.substring(5)}';
    }
    if (v.length <= 12) {
      return '${v.substring(0, 2)}.${v.substring(2, 5)}.${v.substring(5, 8)}/${v.substring(8)}';
    }
    return '${v.substring(0, 2)}.${v.substring(2, 5)}.${v.substring(5, 8)}/${v.substring(8, 12)}-${v.substring(12)}';
  }
}

class TelefoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitos = _somenteDigitos(newValue.text);
    final texto = digitos.substring(
      0,
      digitos.length > 11 ? 11 : digitos.length,
    );
    final formatado = _formatarTelefone(texto);
    return TextEditingValue(
      text: formatado,
      selection: TextSelection.collapsed(offset: formatado.length),
    );
  }

  String _formatarTelefone(String v) {
    if (v.isEmpty) return v;
    if (v.length <= 2) return '($v';
    if (v.length <= 6) return '(${v.substring(0, 2)}) ${v.substring(2)}';
    if (v.length <= 10) {
      return '(${v.substring(0, 2)}) ${v.substring(2, 6)}-${v.substring(6)}';
    }
    return '(${v.substring(0, 2)}) ${v.substring(2, 7)}-${v.substring(7)}';
  }
}

class CurrencyPtBrInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitos = _somenteDigitos(newValue.text);
    if (digitos.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }
    final centavos = int.tryParse(digitos) ?? 0;
    final reais = centavos ~/ 100;
    final cents = (centavos % 100).toString().padLeft(2, '0');
    final reaisTexto = reais.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => '.',
    );
    final formatado = '$reaisTexto,$cents';
    return TextEditingValue(
      text: formatado,
      selection: TextSelection.collapsed(offset: formatado.length),
    );
  }
}
