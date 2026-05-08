/// ID sintético do projeto embutido Ponto Certo (espelha Functions).
const String kEngineeringAgentPontocertoProjectId = '__pontocerto_builtin__';

class EngineeringAgentProjectSummary {
  const EngineeringAgentProjectSummary({
    required this.id,
    required this.name,
    required this.type,
    required this.rootPath,
    required this.stackDetected,
    required this.knownCommands,
    required this.mainDocs,
    required this.authorizationStatus,
    required this.lastUsedAtIso,
  });

  final String id;
  final String name;
  /// pontocerto | externo | novo
  final String type;
  final String rootPath;
  final String stackDetected;
  final String knownCommands;
  final String mainDocs;
  final String authorizationStatus;
  final String lastUsedAtIso;
}

class EngineeringAgentSessionSummary {
  const EngineeringAgentSessionSummary({
    required this.id,
    required this.title,
    required this.updatedAtIso,
    required this.preview,
    required this.patchApproved,
    required this.projectId,
  });

  final String id;
  final String title;
  final String updatedAtIso;
  final String preview;
  final bool patchApproved;
  final String projectId;
}

class EngineeringAgentChatMessage {
  const EngineeringAgentChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAtIso,
  });

  final String id;
  final String role;
  final String text;
  final String createdAtIso;
}

class EngineeringAgentStructuredSlots {
  const EngineeringAgentStructuredSlots({
    required this.plan,
    required this.files,
    required this.docs,
    required this.risks,
    required this.impact,
    required this.patchPreview,
    required this.command,
    required this.reply,
  });

  final String plan;
  final String files;
  final String docs;
  final String risks;
  final String impact;
  final String patchPreview;
  final String command;
  final String reply;

  static const empty = EngineeringAgentStructuredSlots(
    plan: '',
    files: '',
    docs: '',
    risks: '',
    impact: '',
    patchPreview: '',
    command: '',
    reply: '',
  );
}

class EngineeringAgentSessionDetail {
  const EngineeringAgentSessionDetail({
    required this.id,
    required this.title,
    required this.patchApproved,
    required this.projectId,
    required this.projectType,
    required this.lastPlan,
    required this.lastFiles,
    required this.lastDocs,
    required this.lastRisks,
    required this.lastImpact,
    required this.lastPatchPreview,
    required this.lastCommand,
    required this.updatedAtIso,
  });

  final String id;
  final String title;
  final bool patchApproved;
  final String projectId;
  final String projectType;
  final String lastPlan;
  final String lastFiles;
  final String lastDocs;
  final String lastRisks;
  final String lastImpact;
  final String lastPatchPreview;
  final String lastCommand;
  final String updatedAtIso;
}
