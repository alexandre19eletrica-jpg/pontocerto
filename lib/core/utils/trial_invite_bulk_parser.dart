import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class BulkInviteRow {
  const BulkInviteRow({
    required this.companyEmail,
    required this.accountantEmail,
    this.companyName,
    this.accountantName,
    this.companyCnpj,
    this.companyOpenedAt,
  });

  final String companyEmail;
  final String accountantEmail;
  final String? companyName;
  final String? accountantName;
  final String? companyCnpj;
  final String? companyOpenedAt;
}

class BulkInviteParseResult {
  const BulkInviteParseResult({
    required this.rows,
    required this.skipped,
    this.hint,
  });

  final List<BulkInviteRow> rows;
  final List<String> skipped;
  final String? hint;
}

final _emailRe = RegExp(
  r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}',
  caseSensitive: false,
);

const int kTitanBulkWaveMaxInvites = 10;
const int kTitanBulkMinSecondsBetweenInvites = 75;
const int kTitanBulkMaxInvitesPerRollingHour = 32;
const int kTitanBulkCooldownMinutesAfterWave = 55;

bool _isValidEmail(String value) {
  final email = value.trim().toLowerCase();
  if (email.isEmpty || !email.contains('@') || email.length > 254) return false;
  final at = email.indexOf('@');
  if (at < 1 || at == email.length - 1) return false;
  final domain = email.substring(at + 1);
  if (!domain.contains('.') || domain.startsWith('.') || domain.endsWith('.')) {
    return false;
  }
  return _emailRe.hasMatch(email);
}

String? _normCell(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int? _colIndexForHeader(List<String?> headers, List<String> keys) {
  for (var i = 0; i < headers.length; i++) {
    final header =
        (headers[i] ?? '').toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    for (final key in keys) {
      if (header == key || header.contains(key)) return i;
    }
  }
  return null;
}

List<String?> _rowToStrings(List<Data?> row, int maxCol) {
  final values = <String?>[];
  for (var c = 0; c < maxCol; c++) {
    values.add(c < row.length ? _normCell(row[c]?.value) : null);
  }
  return values;
}

BulkInviteParseResult parseTrialInviteBulkFile({
  required Uint8List bytes,
  required String fileName,
}) {
  final lower = fileName.toLowerCase();
  final skipped = <String>[];

  if (lower.endsWith('.pdf')) return _parsePdf(bytes, skipped, fileName);
  if (lower.endsWith('.xlsx') || lower.endsWith('.xls')) {
    return _parseExcel(bytes, skipped);
  }
  if (lower.endsWith('.csv') ||
      lower.endsWith('.txt') ||
      lower.endsWith('.tsv') ||
      lower.endsWith('.lst')) {
    return _parsePlainText(_decodePlain(bytes, skipped), skipped, fileName);
  }

  try {
    final plain = _parsePlainText(_decodePlain(bytes, skipped), skipped, fileName);
    if (plain.rows.isNotEmpty) {
      return BulkInviteParseResult(
        rows: plain.rows,
        skipped: [...skipped, ...plain.skipped],
        hint: 'Arquivo interpretado como texto.',
      );
    }
  } catch (_) {}
  try {
    final excel = _parseExcel(bytes, skipped);
    if (excel.rows.isNotEmpty) return excel;
  } catch (_) {}
  try {
    final pdf = _parsePdf(bytes, skipped, fileName);
    if (pdf.rows.isNotEmpty) return pdf;
  } catch (_) {}

  return BulkInviteParseResult(
    rows: const [],
    skipped: [
      ...skipped,
      'Nao foi possivel identificar linhas validas com email de contador.',
    ],
    hint:
        'Use .csv, .txt, .xlsx ou .pdf. Ex.: contador@dominio.com;Nome Contador ou empresa@dominio.com;Nome Empresa;contador@dominio.com;Nome Contador',
  );
}

String _decodePlain(Uint8List bytes, List<String> skipped) {
  try {
    var text = utf8.decode(bytes, allowMalformed: true).trim();
    if (text.startsWith('\ufeff')) text = text.substring(1);
    return text;
  } catch (error) {
    skipped.add('Falha ao decodificar texto: $error');
    return '';
  }
}

BulkInviteParseResult _parsePlainText(
  String text,
  List<String> skipped,
  String sourceLabel,
) {
  final rows = <BulkInviteRow>[];
  final seen = <String>{};
  final rawLines = text.split(RegExp(r'\r?\n'));

  for (var i = 0; i < rawLines.length; i++) {
    final line = rawLines[i].trim();
    if (line.isEmpty || line.startsWith('#')) continue;

    var separator = ',';
    if (!line.contains(',') && line.contains(';')) separator = ';';
    if (!line.contains(',') && !line.contains(';') && line.contains('\t')) {
      separator = '\t';
    }

    final parts = line
        .split(separator == '\t' ? RegExp(r'\t') : separator)
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    if (parts.isEmpty) continue;

    final emails = <String>[];
    final names = <String>[];
    for (final part in parts) {
      final match = _emailRe.firstMatch(part);
      if (match != null) {
        final email = match.group(0)!.toLowerCase();
        if (_isValidEmail(email) && !emails.contains(email)) {
          emails.add(email);
          continue;
        }
      }
      names.add(part);
    }

    if (emails.isEmpty) {
      skipped.add('Linha ${i + 1}: informe ao menos o email do contador.');
      continue;
    }

    final companyEmail = emails.length >= 2 ? emails[0] : '';
    final accountantEmail = emails.length >= 2 ? emails[1] : emails[0];
    final dedupeKey = '$companyEmail|$accountantEmail';
    if (!seen.add(dedupeKey)) {
      skipped.add('Linha ${i + 1}: convite duplicado ignorado ($dedupeKey).');
      continue;
    }

    rows.add(
      BulkInviteRow(
        companyEmail: companyEmail,
        accountantEmail: accountantEmail,
        companyName: names.isNotEmpty ? names[0] : null,
        accountantName: names.length > 1 ? names[1] : null,
      ),
    );
  }

  return BulkInviteParseResult(
    rows: rows,
    skipped: skipped,
    hint: rows.isEmpty
        ? 'Nenhuma linha valida em $sourceLabel. Ex.: contador@dominio.com;Nome Contador'
        : null,
  );
}

BulkInviteParseResult _parseExcel(Uint8List bytes, List<String> skipped) {
  final excel = Excel.decodeBytes(bytes);
  if (excel.tables.isEmpty) {
    return BulkInviteParseResult(rows: const [], skipped: skipped);
  }

  final rows = <BulkInviteRow>[];
  final seen = <String>{};

  for (final table in excel.tables.values) {
    final data = table.rows;
    if (data.isEmpty) continue;

    final maxCol = data.fold<int>(
      0,
      (current, row) => row.length > current ? row.length : current,
    );
    if (maxCol == 0) continue;

    final headers = _rowToStrings(data.first, maxCol);
    final companyEmailIndex = _colIndexForHeader(headers, [
      'email empresa',
      'empresa email',
      'company email',
      'email_company',
      'companyemail',
      'email',
    ]);
    final accountantEmailIndex = _colIndexForHeader(headers, [
      'email contador',
      'contador email',
      'email escritorio',
      'escritorio email',
      'accountant email',
      'office email',
    ]);
    final companyNameIndex = _colIndexForHeader(headers, [
      'nome empresa',
      'empresa nome',
      'company name',
    ]);
    final accountantNameIndex = _colIndexForHeader(headers, [
      'nome contador',
      'contador nome',
      'nome escritorio',
      'accountant name',
      'office name',
    ]);
    final companyCnpjIndex = _colIndexForHeader(headers, [
      'cnpj',
      'cnpj empresa',
      'company cnpj',
    ]);
    final companyOpenedAtIndex = _colIndexForHeader(headers, [
      'abertura',
      'data abertura',
      'data de abertura',
      'inicio atividade',
      'opened at',
    ]);

    final startRow =
        companyEmailIndex != null || accountantEmailIndex != null ? 1 : 0;

    for (var r = startRow; r < data.length; r++) {
      final values = _rowToStrings(data[r], maxCol);
      String? companyEmail;
      String? accountantEmail;
      String? companyName;
      String? accountantName;
      String? companyCnpj;
      String? companyOpenedAt;

      if (companyEmailIndex != null && companyEmailIndex < values.length) {
        companyEmail = values[companyEmailIndex];
      }
      if (accountantEmailIndex != null && accountantEmailIndex < values.length) {
        accountantEmail = values[accountantEmailIndex];
      }
      if (companyNameIndex != null && companyNameIndex < values.length) {
        companyName = values[companyNameIndex];
      }
      if (accountantNameIndex != null && accountantNameIndex < values.length) {
        accountantName = values[accountantNameIndex];
      }
      if (companyCnpjIndex != null && companyCnpjIndex < values.length) {
        companyCnpj = values[companyCnpjIndex];
      }
      if (companyOpenedAtIndex != null && companyOpenedAtIndex < values.length) {
        companyOpenedAt = values[companyOpenedAtIndex];
      }

      if (!_isValidEmail(accountantEmail ?? '')) {
        final emails = values
            .whereType<String>()
            .map((item) => _emailRe.firstMatch(item)?.group(0)?.toLowerCase())
            .whereType<String>()
            .where(_isValidEmail)
            .toList();
        if (emails.length >= 2) {
          companyEmail = emails[0];
          accountantEmail = emails[1];
        } else if (emails.length == 1) {
          companyEmail = '';
          accountantEmail = emails[0];
        }
      }

      if (!_isValidEmail(accountantEmail ?? '')) {
        skipped.add('Planilha linha ${r + 1}: faltou email valido do contador.');
        continue;
      }

      final safeCompanyEmail = (companyEmail ?? '').toLowerCase();
      final safeAccountantEmail = accountantEmail!.toLowerCase();
      final dedupeKey = '$safeCompanyEmail|$safeAccountantEmail';
      if (!seen.add(dedupeKey)) {
        skipped.add('Planilha linha ${r + 1}: convite duplicado ignorado ($dedupeKey).');
        continue;
      }

      rows.add(
        BulkInviteRow(
          companyEmail: safeCompanyEmail,
          accountantEmail: safeAccountantEmail,
          companyName: companyName,
          accountantName: accountantName,
          companyCnpj: companyCnpj,
          companyOpenedAt: companyOpenedAt,
        ),
      );
    }
  }

  return BulkInviteParseResult(
    rows: rows,
    skipped: skipped,
    hint: rows.isEmpty
        ? 'Planilha sem linhas validas. Use ao menos email contador e, se quiser, email/nome da empresa.'
        : null,
  );
}

BulkInviteParseResult _parsePdf(
  Uint8List bytes,
  List<String> skipped,
  String fileName,
) {
  try {
    final document = PdfDocument(inputBytes: bytes);
    final text = PdfTextExtractor(document).extractText();
    document.dispose();
    return _parsePlainText(text, skipped, fileName);
  } catch (error) {
    skipped.add('Falha ao ler PDF: $error');
    return BulkInviteParseResult(rows: const [], skipped: skipped);
  }
}
