import 'package:cloud_functions/cloud_functions.dart';

class AssistantAdminService {
  AssistantAdminService({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  Future<AssistantCompanyConfigStatus> getCompanyConfigStatus() async {
    final callable = _functions.httpsCallable('assistantGetCompanyConfigStatus');
    final result = await callable.call();
    final data = Map<String, dynamic>.from(result.data as Map);
    return AssistantCompanyConfigStatus.fromMap(data);
  }

  Future<void> saveCompanyApiKey(
    String apiKey, {
    String? model,
  }) async {
    final callable = _functions.httpsCallable('assistantSaveCompanyApiKey');
    await callable.call(<String, dynamic>{
      'apiKey': apiKey,
      if (model != null && model.trim().isNotEmpty) 'model': model.trim(),
    });
  }

  /// Atualiza apenas o modelo quando ja existe chave no Firestore da suprema.
  Future<void> patchCompanyModel(String model) async {
    final callable = _functions.httpsCallable('assistantSaveCompanyApiKey');
    await callable.call(<String, dynamic>{
      'model': model.trim(),
    });
  }

  Future<void> removeCompanyApiKey() async {
    final callable = _functions.httpsCallable('assistantSaveCompanyApiKey');
    await callable.call(<String, dynamic>{'remove': true});
  }
}

class AssistantCompanyConfigStatus {
  const AssistantCompanyConfigStatus({
    required this.credentialDetailRestricted,
    required this.assistantOperational,
    this.source = '',
    this.model = '',
    this.hasCompanyApiKey = false,
    this.hasPlatformApiKey = false,
    this.usesEnvApiKey = false,
    this.hasSupremeStoredKey = false,
    this.keyPreview = '',
    this.supremeStoredModelHint = '',
    this.updatedByName = '',
    this.updatedAtIso = '',
  });

  factory AssistantCompanyConfigStatus.fromMap(Map<String, dynamic> data) {
    final restricted = data['credentialDetailRestricted'] == true;
    if (restricted) {
      return AssistantCompanyConfigStatus(
        credentialDetailRestricted: true,
        assistantOperational: data['assistantOperational'] == true,
      );
    }
    return AssistantCompanyConfigStatus(
      credentialDetailRestricted: false,
      assistantOperational: data['assistantOperational'] == true,
      source: data['source']?.toString() ?? '',
      model: data['model']?.toString() ?? '',
      hasCompanyApiKey: data['hasCompanyApiKey'] == true,
      hasPlatformApiKey: data['hasPlatformApiKey'] == true,
      usesEnvApiKey: data['usesEnvApiKey'] == true,
      hasSupremeStoredKey: data['hasSupremeStoredKey'] == true,
      keyPreview: data['keyPreview']?.toString() ?? '',
      supremeStoredModelHint:
          data['supremeStoredModelHint']?.toString() ?? '',
      updatedByName: data['updatedByName']?.toString() ?? '',
      updatedAtIso: data['updatedAtIso']?.toString() ?? '',
    );
  }

  final bool credentialDetailRestricted;
  final bool assistantOperational;
  final String source;
  final String model;
  final bool hasCompanyApiKey;
  final bool hasPlatformApiKey;
  final bool usesEnvApiKey;
  final bool hasSupremeStoredKey;
  final String keyPreview;
  final String supremeStoredModelHint;
  final String updatedByName;
  final String updatedAtIso;
}
