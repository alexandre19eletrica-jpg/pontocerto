import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/features/runtime_incidents/domain/runtime_incident.dart';
import 'package:pontocerto/features/runtime_incidents/domain/system_issue.dart';

final runtimeIncidentsProvider =
    StreamProvider.autoDispose<List<RuntimeIncident>>((ref) {
      final session = ref.watch(sessionProvider);
      if (session == null) {
        return const Stream<List<RuntimeIncident>>.empty();
      }

      return FirebaseFirestore.instance
          .collection('runtime_incidents')
          .where('companyId', isEqualTo: session.companyId)
          .limit(120)
          .snapshots()
          .map((snapshot) {
            int timestamp(DateTime? value) =>
                value?.millisecondsSinceEpoch ?? 0;
            final items = snapshot.docs
                .map(RuntimeIncident.fromDoc)
                .toList(growable: true)
              ..sort(
                (a, b) => timestamp(b.createdAt).compareTo(timestamp(a.createdAt)),
              );
            return items;
          });
    });

final systemIssuesProvider = StreamProvider.autoDispose<List<SystemIssue>>((ref) {
  final session = ref.watch(sessionProvider);
  if (session == null) {
    return const Stream<List<SystemIssue>>.empty();
  }

  return FirebaseFirestore.instance
      .collection('system_issues')
      .where('companyId', isEqualTo: session.companyId)
      .limit(120)
      .snapshots()
      .map((snapshot) {
        int timestamp(DateTime? value) => value?.millisecondsSinceEpoch ?? 0;
        final items = snapshot.docs
            .map(SystemIssue.fromDoc)
            .toList(growable: true)
          ..sort(
            (a, b) => timestamp(b.lastSeenAt).compareTo(timestamp(a.lastSeenAt)),
          );
        return items;
      });
});

class RuntimeIncidentsActions {
  RuntimeIncidentsActions({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  Future<void> updateStatus({
    required String incidentId,
    required String status,
    String resolutionNote = '',
  }) async {
    await FirebaseFirestore.instance
        .collection('runtime_incidents')
        .doc(incidentId)
        .set({
          'status': status,
          'resolutionNote': resolutionNote.trim(),
          'resolvedAt': status == 'resolved'
              ? FieldValue.serverTimestamp()
              : FieldValue.delete(),
          'ignoredAt': status == 'ignored'
              ? FieldValue.serverTimestamp()
              : FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> analyze(String incidentId) async {
    final callable = _functions.httpsCallable('runtimeIncidentAnalyze');
    await callable.call(<String, dynamic>{'incidentId': incidentId});
  }

  Future<void> executeSafeAction(String incidentId) async {
    final callable = _functions.httpsCallable('runtimeIncidentExecuteSafeAction');
    await callable.call(<String, dynamic>{'incidentId': incidentId});
  }

  Future<void> promoteToIssue(String incidentId) async {
    final callable = _functions.httpsCallable('runtimeIssueUpsertFromIncident');
    await callable.call(<String, dynamic>{'incidentId': incidentId});
  }

  Future<void> updateIssueStatus({
    required String issueId,
    required String status,
    String fixStatus = '',
    String resolutionNote = '',
  }) async {
    final callable = _functions.httpsCallable('runtimeIssueUpdateStatus');
    await callable.call(<String, dynamic>{
      'issueId': issueId,
      'status': status,
      'fixStatus': fixStatus,
      'resolutionNote': resolutionNote,
    });
  }

  Future<ObservabilityExportResult> exportSnapshot({
    required String companyId,
  }) async {
    const endpoint =
        'https://us-central1-pontocerto-e1dab.cloudfunctions.net/observabilityExportSupremeEphemeral?key=observability-export-20260329';
    final uri = Uri.parse('$endpoint&companyId=$companyId');
    final response = await http.get(uri);
    final body = response.body.trim();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        body.isEmpty ? 'Falha ao exportar observabilidade.' : body,
      );
    }
    final payload = body.isNotEmpty ? jsonDecode(body) as Map<String, dynamic> : <String, dynamic>{};

    final incidents = (payload['incidents'] as List<dynamic>? ?? const []);
    final issues = (payload['issues'] as List<dynamic>? ?? const []);
    final lines = <String>[
      'SNAPSHOT DE OBSERVABILIDADE',
      '',
      'Exportado em: ${payload['exportedAt'] ?? ''}',
      'Empresa: ${payload['companyId'] ?? ''}',
      'Incidentes encontrados: ${incidents.length}',
      'Problemas confirmados: ${issues.length}',
      '',
      'INCIDENTES',
      '',
    ];

    for (final raw in incidents) {
      final incident = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      lines.add('Id: ${incident['id'] ?? ''}');
      lines.add('Status: ${_incidentStatusLabel(incident['status']?.toString() ?? '')}');
      lines.add('Origem: ${incident['source'] ?? ''}');
      lines.add('Categoria: ${incident['category'] ?? ''}');
      lines.add('Severidade: ${_severityLabel(incident['severity']?.toString() ?? '')}');
      if ((incident['screenLabel']?.toString() ?? '').isNotEmpty) {
        lines.add('Tela: ${incident['screenLabel']}');
      }
      final occurrenceCount = (incident['occurrenceCount'] as num?)?.toInt() ?? 1;
      if (occurrenceCount > 1) {
        lines.add('Ocorrencias: $occurrenceCount');
      }
      lines.add('Erro: ${incident['message'] ?? ''}');
      if ((incident['assistantSummary']?.toString() ?? '').isNotEmpty) {
        lines.add('Analise: ${incident['assistantSummary']}');
      }
      if ((incident['recommendedAction']?.toString() ?? '').isNotEmpty) {
        lines.add('Acao recomendada: ${incident['recommendedAction']}');
      }
      lines.add('');
    }

    lines.add('PROBLEMAS CONFIRMADOS');
    lines.add('');

    for (final raw in issues) {
      final issue = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      lines.add('Id: ${issue['id'] ?? ''}');
      lines.add('Status: ${_issueStatusLabel(issue['status']?.toString() ?? '')}');
      lines.add('Correcao: ${_fixStatusLabel(issue['fixStatus']?.toString() ?? '')}');
      lines.add('Modulo: ${issue['module'] ?? ''}');
      lines.add('Origem: ${issue['source'] ?? ''}');
      lines.add('Titulo: ${issue['title'] ?? ''}');
      lines.add('Descricao: ${issue['description'] ?? ''}');
      final occurrenceCount = (issue['occurrenceCount'] as num?)?.toInt() ?? 1;
      if (occurrenceCount > 1) {
        lines.add('Ocorrencias: $occurrenceCount');
      }
      if ((issue['recommendedAction']?.toString() ?? '').isNotEmpty) {
        lines.add('Acao recomendada: ${issue['recommendedAction']}');
      }
      lines.add('');
    }
    final textContent = lines.join('\n');
    final pdfBytes = await _buildObservabilityPdf(
      lines: lines,
      exportedAt: payload['exportedAt']?.toString() ?? '',
      companyId: payload['companyId']?.toString() ?? companyId,
    );

    return ObservabilityExportResult(
      textContent: textContent,
      pdfBytes: pdfBytes,
    );
  }

  Future<ObservabilityCleanupResult> cleanupOpenIncidents({
    required String companyId,
  }) async {
    const endpoint =
        'https://us-central1-pontocerto-e1dab.cloudfunctions.net/observabilityCleanupSupremeEphemeral?key=observability-cleanup-20260330';
    final uri = Uri.parse('$endpoint&companyId=$companyId');
    final response = await http.get(uri);
    final body = response.body.trim();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        body.isEmpty ? 'Falha ao limpar incidentes.' : body,
      );
    }
    final payload = body.isNotEmpty ? jsonDecode(body) as Map<String, dynamic> : <String, dynamic>{};
    return ObservabilityCleanupResult(
      deletedCount: (payload['deletedCount'] as num?)?.toInt() ?? 0,
      summary: payload['summary']?.toString() ?? '',
    );
  }
}

final runtimeIncidentsActionsProvider = Provider<RuntimeIncidentsActions>((ref) {
  return RuntimeIncidentsActions();
});

class ObservabilityExportResult {
  const ObservabilityExportResult({
    this.textContent = '',
    this.pdfBytes,
  });

  final String textContent;
  final Uint8List? pdfBytes;
}

class ObservabilityCleanupResult {
  const ObservabilityCleanupResult({
    this.deletedCount = 0,
    this.summary = '',
  });

  final int deletedCount;
  final String summary;
}

String _incidentStatusLabel(String value) {
  switch (value) {
    case 'resolved':
      return 'Resolvido';
    case 'ignored':
      return 'Ignorado';
    default:
      return 'Em aberto';
  }
}

String _issueStatusLabel(String value) {
  switch (value) {
    case 'resolved':
      return 'Resolvido';
    case 'monitoring':
      return 'Monitorando';
    default:
      return 'Em aberto';
  }
}

String _fixStatusLabel(String value) {
  switch (value) {
    case 'done':
      return 'Correcao concluida';
    case 'investigating':
      return 'Investigando';
    default:
      return 'Pendente';
  }
}

String _severityLabel(String value) {
  switch (value) {
    case 'critical':
      return 'Critica';
    case 'warning':
      return 'Alerta';
    default:
      return 'Erro';
  }
}

Future<Uint8List> _buildObservabilityPdf({
  required List<String> lines,
  required String exportedAt,
  required String companyId,
}) async {
  final pdf = pw.Document();
  final blocks = _splitExportBlocks(lines);
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (_) => [
        pw.Text(
          'Snapshot de observabilidade',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Text('Exportado em: $exportedAt'),
        pw.Text('Empresa: $companyId'),
        pw.SizedBox(height: 12),
        ...blocks.map(
          (block) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Text(block),
          ),
        ),
      ],
    ),
  );
  return pdf.save();
}

List<String> _splitExportBlocks(List<String> lines, {int maxChars = 420}) {
  final text = lines.join('\n').trim();
  if (text.isEmpty) return const <String>[];
  final baseBlocks = text
      .split(RegExp(r'\n\s*\n'))
      .map((block) => block.trim())
      .where((block) => block.isNotEmpty);
  final result = <String>[];
  for (final block in baseBlocks) {
    if (block.length <= maxChars) {
      result.add(block);
      continue;
    }
    final words = block.split(RegExp(r'\s+'));
    final buffer = StringBuffer();
    for (final word in words) {
      final candidate = buffer.isEmpty ? word : '${buffer.toString()} $word';
      if (candidate.length > maxChars && buffer.isNotEmpty) {
        result.add(buffer.toString().trim());
        buffer
          ..clear()
          ..write(word);
      } else {
        buffer
          ..clear()
          ..write(candidate);
      }
    }
    final tail = buffer.toString().trim();
    if (tail.isNotEmpty) {
      result.add(tail);
    }
  }
  return result;
}
