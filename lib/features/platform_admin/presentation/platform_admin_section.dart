/// Seções do painel interno [PlatformAdminPage], roteadas em `/platform-admin/...`.
enum PlatformAdminSection {
  escritorios,
  governanca,
  convidar,
  financeiro,
  integracoes,
}

const String kPlatformAdminEscritoriosPath = '/platform-admin/escritorios';
const String kPlatformAdminGovernancaPath = '/platform-admin/governanca';
const String kPlatformAdminConvidarPath = '/platform-admin/convidar';
const String kPlatformAdminFinanceiroPath = '/platform-admin/financeiro';
const String kPlatformAdminIntegracoesPath = '/platform-admin/integracoes';

/// Origem canónica do site público (links de campanha / pré-cadastro).
const String kPublicWebAppOrigin = 'https://pontocerto-e1dab.web.app';
