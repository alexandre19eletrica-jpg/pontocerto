import 'package:cloud_functions/cloud_functions.dart';
import 'package:pontocerto/features/governance_engineering/domain/engineering_agent_message.dart';

Map<String, dynamic> _mapFromCallableData(dynamic data) {
  if (data == null) return {};
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return Map<String, dynamic>.from(data);
  return {};
}

EngineeringAgentProjectSummary _projectFromMap(Map<String, dynamic> m, String fallbackId) {
  return EngineeringAgentProjectSummary(
    id: '${m['id'] ?? fallbackId}',
    name: '${m['name'] ?? ''}',
    type: '${m['type'] ?? ''}',
    rootPath: '${m['rootPath'] ?? ''}',
    stackDetected: '${m['stackDetected'] ?? ''}',
    knownCommands: '${m['knownCommands'] ?? ''}',
    mainDocs: '${m['mainDocs'] ?? ''}',
    authorizationStatus: '${m['authorizationStatus'] ?? ''}',
    lastUsedAtIso: '${m['lastUsedAtIso'] ?? ''}',
  );
}

class EngineeringAgentProjectsLoadResult {
  const EngineeringAgentProjectsLoadResult({
    required this.builtin,
    required this.projects,
    required this.selectedProjectId,
  });

  final EngineeringAgentProjectSummary builtin;
  final List<EngineeringAgentProjectSummary> projects;
  final String selectedProjectId;
}

class EngineeringAgentService {
  EngineeringAgentService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  Future<EngineeringAgentProjectsLoadResult> listProjects() async {
    final callable = _functions.httpsCallable('engineeringAgentListProjects');
    final result = await callable.call();
    final data = _mapFromCallableData(result.data);
    if (data['ok'] != true) {
      throw Exception('Falha ao listar projetos.');
    }
    final builtinRaw = Map<String, dynamic>.from(data['builtinProject'] as Map? ?? {});
    final builtin = _projectFromMap(builtinRaw, kEngineeringAgentPontocertoProjectId);
    final rawList = data['projects'];
    final projects = <EngineeringAgentProjectSummary>[];
    if (rawList is List) {
      for (final e in rawList) {
        projects.add(_projectFromMap(Map<String, dynamic>.from(e as Map), ''));
      }
    }
    final sel = '${data['selectedProjectId'] ?? kEngineeringAgentPontocertoProjectId}';
    return EngineeringAgentProjectsLoadResult(
      builtin: builtin,
      projects: projects,
      selectedProjectId: sel.isEmpty ? kEngineeringAgentPontocertoProjectId : sel,
    );
  }

  Future<String> createProject({
    required String name,
    required String type,
    required String rootPath,
    String manifestSnippet = '',
  }) async {
    final callable = _functions.httpsCallable('engineeringAgentCreateProject');
    final result = await callable.call({
      'name': name,
      'type': type,
      'rootPath': rootPath,
      'manifestSnippet': manifestSnippet,
    });
    final data = _mapFromCallableData(result.data);
    if (data['ok'] != true) {
      throw Exception('Falha ao criar projeto.');
    }
    return '${data['projectId'] ?? ''}';
  }

  Future<void> selectProject(String projectId) async {
    final callable = _functions.httpsCallable('engineeringAgentSelectProject');
    final result = await callable.call({'projectId': projectId});
    final data = _mapFromCallableData(result.data);
    if (data['ok'] != true) {
      throw Exception('Falha ao selecionar projeto.');
    }
  }

  Future<List<EngineeringAgentSessionSummary>> listSessions({required String projectId}) async {
    final callable = _functions.httpsCallable('engineeringAgentListSessions');
    final result = await callable.call({'projectId': projectId});
    final data = _mapFromCallableData(result.data);
    if (data['ok'] != true) {
      return [];
    }
    final raw = data['sessions'];
    if (raw is! List) return [];
    return raw.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return EngineeringAgentSessionSummary(
        id: '${m['id'] ?? ''}',
        title: '${m['title'] ?? ''}',
        updatedAtIso: '${m['updatedAtIso'] ?? ''}',
        preview: '${m['preview'] ?? ''}',
        patchApproved: m['patchApproved'] == true,
        projectId: '${m['projectId'] ?? projectId}',
      );
    }).toList();
  }

  Future<({EngineeringAgentSessionDetail session, List<EngineeringAgentChatMessage> messages})>
      getSession(String sessionId) async {
    final callable = _functions.httpsCallable('engineeringAgentGetSession');
    final result = await callable.call({'sessionId': sessionId});
    final data = _mapFromCallableData(result.data);
    if (data['ok'] != true) {
      throw Exception('Sessao indisponivel.');
    }
    final s = Map<String, dynamic>.from(data['session'] as Map? ?? {});
    final session = EngineeringAgentSessionDetail(
      id: '${s['id'] ?? sessionId}',
      title: '${s['title'] ?? ''}',
      patchApproved: s['patchApproved'] == true,
      projectId: '${s['projectId'] ?? kEngineeringAgentPontocertoProjectId}',
      projectType: '${s['projectType'] ?? 'pontocerto'}',
      lastPlan: '${s['lastPlan'] ?? ''}',
      lastFiles: '${s['lastFiles'] ?? ''}',
      lastDocs: '${s['lastDocs'] ?? ''}',
      lastRisks: '${s['lastRisks'] ?? ''}',
      lastImpact: '${s['lastImpact'] ?? ''}',
      lastPatchPreview: '${s['lastPatchPreview'] ?? ''}',
      lastCommand: '${s['lastCommand'] ?? ''}',
      updatedAtIso: '${s['updatedAtIso'] ?? ''}',
    );
    final rawMsgs = data['messages'];
    final messages = <EngineeringAgentChatMessage>[];
    if (rawMsgs is List) {
      for (final item in rawMsgs) {
        final m = Map<String, dynamic>.from(item as Map);
        messages.add(
          EngineeringAgentChatMessage(
            id: '${m['id'] ?? ''}',
            role: '${m['role'] ?? 'user'}',
            text: '${m['text'] ?? ''}',
            createdAtIso: '${m['createdAtIso'] ?? ''}',
          ),
        );
      }
    }
    return (session: session, messages: messages);
  }

  Future<({String sessionId, EngineeringAgentStructuredSlots structured, String reply})> sendMessage({
    required String text,
    required String projectId,
    String? sessionId,
  }) async {
    final callable = _functions.httpsCallable('engineeringAgentSendMessage');
    final payload = <String, dynamic>{'message': text, 'projectId': projectId};
    if (sessionId != null && sessionId.isNotEmpty) {
      payload['sessionId'] = sessionId;
    }
    final result = await callable.call(payload);
    final data = _mapFromCallableData(result.data);
    if (data['ok'] != true) {
      throw Exception('Falha ao enviar mensagem.');
    }
    final sid = '${data['sessionId'] ?? ''}';
    final structuredRaw = Map<String, dynamic>.from(data['structured'] as Map? ?? {});
    final structured = EngineeringAgentStructuredSlots(
      plan: '${structuredRaw['plan'] ?? ''}',
      files: '${structuredRaw['files'] ?? ''}',
      docs: '${structuredRaw['docs'] ?? ''}',
      risks: '${structuredRaw['risks'] ?? ''}',
      impact: '${structuredRaw['impact'] ?? ''}',
      patchPreview: '${structuredRaw['patchPreview'] ?? ''}',
      command: '${structuredRaw['command'] ?? ''}',
      reply: '${data['reply'] ?? ''}',
    );
    return (sessionId: sid, structured: structured, reply: structured.reply);
  }

  Future<void> approvePatch({required String sessionId, required bool approved, String note = ''}) async {
    final callable = _functions.httpsCallable('engineeringAgentApprovePatch');
    final result = await callable.call({
      'sessionId': sessionId,
      'approved': approved,
      'note': note,
    });
    final data = _mapFromCallableData(result.data);
    if (data['ok'] != true) {
      throw Exception('Falha ao registar aprovacao.');
    }
  }

  Future<String> generateCommand({required String sessionId, bool mergeToSession = true}) async {
    final callable = _functions.httpsCallable('engineeringAgentGenerateCommand');
    final result = await callable.call({
      'sessionId': sessionId,
      'mergeToSession': mergeToSession,
    });
    final data = _mapFromCallableData(result.data);
    if (data['ok'] != true) {
      throw Exception('Falha ao gerar comando.');
    }
    return '${data['command'] ?? ''}'.trim();
  }

  Future<void> registerContinuity({required String sessionId, required String note}) async {
    final callable = _functions.httpsCallable('engineeringAgentRegisterContinuity');
    final result = await callable.call({'sessionId': sessionId, 'note': note});
    final data = _mapFromCallableData(result.data);
    if (data['ok'] != true) {
      throw Exception('Falha ao registar continuidade.');
    }
  }
}
