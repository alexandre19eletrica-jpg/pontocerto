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
    return AssistantCompanyConfigStatus(
      source: data['source']?.toString() ?? 'missing',
      model: data['model']?.toString() ?? 'gpt-5-mini',
      hasCompanyApiKey: data['hasCompanyApiKey'] == true,
      hasPlatformApiKey: data['hasPlatformApiKey'] == true,
      keyPreview: data['keyPreview']?.toString() ?? '',
      updatedByName: data['updatedByName']?.toString() ?? '',
      updatedAtIso: data['updatedAtIso']?.toString() ?? '',
    );
  }

  Future<void> saveCompanyApiKey(String apiKey) async {
    final callable = _functions.httpsCallable('assistantSaveCompanyApiKey');
    await callable.call(<String, dynamic>{'apiKey': apiKey});
  }

  Future<void> removeCompanyApiKey() async {
    final callable = _functions.httpsCallable('assistantSaveCompanyApiKey');
    await callable.call(<String, dynamic>{'remove': true});
  }
}

class AssistantCompanyConfigStatus {
  const AssistantCompanyConfigStatus({
    required this.source,
    required this.model,
    required this.hasCompanyApiKey,
    required this.hasPlatformApiKey,
    required this.keyPreview,
    required this.updatedByName,
    required this.updatedAtIso,
  });

  final String source;
  final String model;
  final bool hasCompanyApiKey;
  final bool hasPlatformApiKey;
  final String keyPreview;
  final String updatedByName;
  final String updatedAtIso;
}
