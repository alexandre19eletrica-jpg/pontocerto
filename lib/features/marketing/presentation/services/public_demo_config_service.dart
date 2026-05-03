import 'package:cloud_functions/cloud_functions.dart';

class PublicDemoConfigService {
  PublicDemoConfigService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  Future<PublicDemoConfig> fetch() async {
    final callable = _functions.httpsCallable('platformGetDemoAccessConfig');
    final result = await callable.call();
    final data = Map<String, dynamic>.from(result.data as Map);
    return PublicDemoConfig.fromMap(
      Map<String, dynamic>.from(
        data['config'] as Map? ?? const <String, dynamic>{},
      ),
    );
  }

  Future<PublicDemoConfig> update(PublicDemoConfig config) async {
    final callable = _functions.httpsCallable('platformUpdateDemoAccessConfig');
    final result = await callable.call(<String, dynamic>{
      'config': config.toMap(),
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return PublicDemoConfig.fromMap(
      Map<String, dynamic>.from(
        data['config'] as Map? ?? const <String, dynamic>{},
      ),
    );
  }
}

class PublicDemoConfig {
  const PublicDemoConfig({
    required this.enabled,
    required this.ownerUid,
    required this.ownerCompanyId,
    required this.ownerDisplayName,
    required this.accountantUid,
    required this.accountantCompanyId,
    required this.accountantDisplayName,
  });

  final bool enabled;
  final String ownerUid;
  final String ownerCompanyId;
  final String ownerDisplayName;
  final String accountantUid;
  final String accountantCompanyId;
  final String accountantDisplayName;

  factory PublicDemoConfig.defaults() {
    return const PublicDemoConfig(
      enabled: true,
      ownerUid: 'public_demo_owner',
      ownerCompanyId: '',
      ownerDisplayName: 'Ponto Certo',
      accountantUid: 'public_demo_accountant',
      accountantCompanyId: '',
      accountantDisplayName: 'Escritorio Ponto Certo',
    );
  }

  factory PublicDemoConfig.fromMap(Map<String, dynamic> map) {
    return PublicDemoConfig(
      enabled: map['enabled'] != false,
      ownerUid: map['ownerUid']?.toString() ?? 'public_demo_owner',
      ownerCompanyId: map['ownerCompanyId']?.toString() ?? '',
      ownerDisplayName: map['ownerDisplayName']?.toString() ?? 'Ponto Certo',
      accountantUid:
          map['accountantUid']?.toString() ?? 'public_demo_accountant',
      accountantCompanyId: map['accountantCompanyId']?.toString() ?? '',
      accountantDisplayName:
          map['accountantDisplayName']?.toString() ??
          'Escritorio Ponto Certo',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'ownerUid': ownerUid,
      'ownerCompanyId': ownerCompanyId,
      'ownerDisplayName': ownerDisplayName,
      'accountantUid': accountantUid,
      'accountantCompanyId': accountantCompanyId,
      'accountantDisplayName': accountantDisplayName,
    };
  }
}
