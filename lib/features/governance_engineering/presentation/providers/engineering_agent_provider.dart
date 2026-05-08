import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontocerto/features/governance_engineering/data/engineering_agent_service.dart';

final engineeringAgentServiceProvider = Provider<EngineeringAgentService>((ref) {
  return EngineeringAgentService();
});
