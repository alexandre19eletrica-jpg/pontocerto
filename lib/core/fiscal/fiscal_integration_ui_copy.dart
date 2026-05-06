import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/platform/platform_access.dart';

/// Textos da integração NFS-e/NF-e: nome do fornecedor **Focus** aparece apenas
/// quando o utilizador é dono na [empresa suprema].
bool showFiscalVendorName(Session? session) =>
    hasSupremePlatformAccess(session);

class FiscalIntegrationUiCopy {
  FiscalIntegrationUiCopy._();

  static String vendor(Session? session) =>
      showFiscalVendorName(session) ? 'Focus' : 'provedor integrador';

  /// Título tipo "NFSe Nacional Focus" vs genérico.
  static String nationalRoute(Session? session) =>
      showFiscalVendorName(session)
          ? 'Focus NFSe Nacional'
          : 'NFSe nacional (provedor integrador)';

  static String municipalRoute(Session? session) =>
      showFiscalVendorName(session)
          ? 'Focus municipal'
          : 'NFSe municipal (provedor integrador)';

  static String approvedInvoicesMetric(Session? session) =>
      showFiscalVendorName(session)
          ? 'Aprovadas (Sefin / Focus)'
          : 'Aprovadas (Sefin / provedor integrador)';

  static String inboundDocumentsTitle(Session? session) =>
      showFiscalVendorName(session)
          ? 'Documentos fiscais recebidos (Focus)'
          : 'Documentos fiscais recebidos (provedor integrador)';

  static String inboundDocumentsSubtitle(Session? session) =>
      showFiscalVendorName(session)
          ? 'NF-e e NFS-e nacional recebidas via integração configurada pela plataforma.'
          : 'NF-e e NFS-e nacional recebidas pelo canal integrador configurado pela plataforma.';

  static String providerDropdownLabel(Session? session) =>
      showFiscalVendorName(session) ? 'Focus NFe' : 'Provedor integrador NFS-e';

  static String xmlAwaitingVendorMessage(Session? session) =>
      showFiscalVendorName(session)
          ? 'Quando a Focus devolver o XML completo e ele for salvo no Storage, o download aparece aqui.'
          : 'Quando o provedor integrador devolver o XML completo e ele for salvo no Storage, o download aparece aqui.';

  static String integrationRealToggleLabel(Session? session) =>
      showFiscalVendorName(session)
          ? 'Integracao real (Focus)'
          : 'Integracao real (provedor)';

  static String integrationRealLockedFootnote(Session? session) =>
      showFiscalVendorName(session)
          ? 'A «Integracao real (Focus)» so a empresa suprema liga. Ative a preparacao de NFS-e acima, '
              'conclua o provisionamento, sincronize e emita.'
          : 'A integracao real fiscal global so a empresa suprema liga nesta base. Ative a preparacao de NFS-e acima, '
              'conclua o provisionamento, sincronize e emita.';

  static String modoFiscalSubtitle(
    Session? session,
    bool canEditGlobalIntegration,
  ) =>
      canEditGlobalIntegration
          ? 'Nivel de operacao fiscal e integracao com a plataforma.'
          : 'A integracao global (${vendor(session)}) fica na empresa suprema. Aqui a empresa liga a preparacao de NFS-e e segue o provisionamento, sincronizacao e emissao.';

  static String accountantNationalFlowSummary(Session? session) =>
      showFiscalVendorName(session)
          ? 'Esta empresa esta no fluxo NFSe Nacional da Focus. O sistema ja distingue isso do fluxo municipal para evitar processo duplicado de prefeitura.'
          : 'Esta empresa esta no fluxo NFSe nacional do provedor integrador. O sistema distingue municipal e nacional para evitar processo duplicado.';

  static String accountantMunicipalFlowSummary(Session? session) =>
      showFiscalVendorName(session)
          ? 'Esta empresa esta no fluxo municipal da Focus. O contador continua vendo apenas o que falta na rota municipal, sem duplicar processo nacional.'
          : 'Esta empresa esta no fluxo municipal do provedor integrador. O contador ve o que falta na rota municipal, sem duplicar processo nacional.';

  static String accountantRouteGenericSummary(Session? session) =>
      showFiscalVendorName(session)
          ? 'A leitura abaixo respeita a rota fiscal detectada para a empresa e evita duplicar processo entre Focus municipal, Focus nacional e revisao manual.'
          : 'A leitura abaixo respeita a rota fiscal detectada e evita duplicar processo municipal, nacional e revisao manual.';

  static String provisioningAutoTitle(Session? session) =>
      showFiscalVendorName(session)
          ? 'Provisionamento automatico Focus'
          : 'Provisionamento automatico (integrador fiscal)';

  static String provisioningExternalIdLabel(Session? session) =>
      showFiscalVendorName(session)
          ? 'Empresa Focus ID:'
          : 'ID integracao fiscal:';

  static String accountantWhatIntegratorResolvesTitle(Session? session) =>
      showFiscalVendorName(session)
          ? 'O que a Focus ja valida ou resolve'
          : 'O que o integrador fiscal ja valida ou resolve';

  static String provisioningSyncedBody(Session? session) =>
      showFiscalVendorName(session)
          ? 'Empresa provisionada automaticamente na Focus.'
          : 'Empresa provisionada automaticamente no integrador fiscal.';

  static String provisioningErrorBody(Session? session) =>
      showFiscalVendorName(session)
          ? 'A automacao tentou sincronizar a empresa, mas a Focus retornou erro.'
          : 'A automacao tentou sincronizar a empresa, mas o integrador retornou erro.';

  /// Valor guardado no Firestore (inalterado).
  static const String providerFocusNfeValue = 'Focus NFe';

  static String integratorApiModalLabel(Session? session) =>
      showFiscalVendorName(session)
          ? 'API Focus para emissao'
          : 'API do integrador para emissao';

  static String nfseMunicipalDropdownChild(Session? session) =>
      showFiscalVendorName(session)
          ? 'NFSe municipal Focus'
          : 'NFSe municipal (integrador)';

  static String platformTokenExplanation(Session? session) =>
      showFiscalVendorName(session)
          ? 'Token API Focus: a plataforma ja provisiona a credencial de forma segura. '
              'Ninguem ve o valor nesta tela; ela fica apenas na infraestrutura (Functions / ambiente).'
          : 'Token da integracao fiscal: a plataforma ja provisiona a credencial de forma segura. '
              'Ninguem ve o valor nesta tela; ela fica apenas na infraestrutura (Functions / ambiente).';

  static String nonGlobalTokenHelper(Session? session) =>
      showFiscalVendorName(session)
          ? 'Apenas para integradores fora do fluxo Focus global.'
          : 'Apenas para integradores fora do fluxo global da plataforma.';

  static String syncCompanyButton(Session? session) =>
      showFiscalVendorName(session)
          ? 'Sincronizar Focus'
          : 'Sincronizar integracao fiscal';

  static String provisioningDocumentsHint(Session? session) =>
      showFiscalVendorName(session)
          ? 'Certificado e documentos para o provisionamento na Focus.'
          : 'Certificado e documentos para o provisionamento no integrador fiscal.';

  static String reprocessProvisioningHint(Session? session) =>
      showFiscalVendorName(session)
          ? 'Reprocessar automacao de provisionamento Focus apenas para esta empresa.'
          : 'Reprocessar automacao de provisionamento no integrador apenas para esta empresa.';

  static String syncAfterSignupHint(Session? session) =>
      showFiscalVendorName(session)
          ? 'Sincronize esta empresa com a Focus apos o cadastro e a documentacao.'
          : 'Sincronize esta empresa com o integrador fiscal apos o cadastro e a documentacao.';

  static String preCheckOfficialTitle(Session? session) =>
      showFiscalVendorName(session)
          ? 'Emissao oficial (pre-check alinhado a Focus)'
          : 'Emissao oficial (pre-check alinhado ao integrador)';

  static String informServiceValueForReadiness(Session? session) =>
      showFiscalVendorName(session)
          ? 'Informe o valor do serviço para listar o que ainda falta para a Focus/Sefin.'
          : 'Informe o valor do serviço para listar o que ainda falta para o integrador/Sefin.';

  static String totalsIssRuleFootnote(Session? session) =>
      showFiscalVendorName(session)
          ? 'Totais (mesma regra do salvamento e da Focus: valor_iss, valor_cp, valor_liquido).'
          : 'Totais (mesma regra do salvamento e do integrador: valor_iss, valor_cp, valor_liquido).';

  static String invoiceBodyFocusFootnote(Session? session) =>
      showFiscalVendorName(session)
          ? '(corpo da nota na Focus). Podem ser editados tambem ao abrir Nova NFS-e.'
          : '(corpo da nota no integrador). Podem ser editados tambem ao abrir Nova NFS-e.';

  static String globalIntegrationReadonlyFootnote(Session? session) =>
      showFiscalVendorName(session)
          ? 'So a suprema altera ambiente, provedor, API Focus, URL e tokens (uma base para todas as empresas). '
              'Nesta empresa continuam livres: inscricao municipal, CNAE, matriz fiscal, preparacao pelo CNPJ e checklist. '
          : 'So a suprema altera ambiente, provedor, API do integrador, URL e tokens (uma base para todas as empresas). '
              'Nesta empresa continuam livres: inscricao municipal, CNAE, matriz fiscal, preparacao pelo CNPJ e checklist. ';

  static String globalEnvProviderReadonlyLine(Session? session) =>
      showFiscalVendorName(session)
          ? 'Ambiente, provedor, API Focus e URL base vêm da empresa suprema (somente leitura). '
          : 'Ambiente, provedor, API do integrador e URL base vêm da empresa suprema (somente leitura). ';

  static String accountantChipProvisioning(Session? session, String rawStatus) {
    final status = rawStatus.trim().isEmpty ? 'PENDING' : rawStatus.trim();
    return showFiscalVendorName(session)
        ? 'Focus $status'
        : 'Integrador $status';
  }

  static String accountantProviderConfigured(Session? session) =>
      showFiscalVendorName(session)
          ? 'Provedor Focus configurado'
          : 'Provedor integrador fiscal configurado';

  static String accountantNationalEmissionDefined(Session? session) =>
      showFiscalVendorName(session)
          ? 'Sistema definiu emissao pela NFSe Nacional da Focus'
          : 'Sistema definiu emissao pela NFSe nacional pelo integrador';

  static String accountantMunicipalEmissionDefined(Session? session) =>
      showFiscalVendorName(session)
          ? 'Sistema definiu emissao pela integracao municipal da Focus'
          : 'Sistema definiu emissao pela integracao municipal pelo integrador';

  static String accountantCompanySynced(Session? session) =>
      showFiscalVendorName(session)
          ? 'Empresa sincronizada na Focus'
          : 'Empresa sincronizada no integrador fiscal';

  static String accountantPendingFromVendor(Session? session, String item) =>
      showFiscalVendorName(session)
          ? 'Focus ainda aponta pendencia: $item'
          : 'Integrador fiscal ainda aponta pendencia: $item';

  static String accountantEmitterRegistration(Session? session) =>
      showFiscalVendorName(session)
          ? 'Cadastro/sincronizacao da empresa emitente na Focus'
          : 'Cadastro/sincronizacao da empresa emitente no integrador fiscal';

  static String invoiceRetentionInss(Session? session) =>
      showFiscalVendorName(session)
          ? 'Marque quando a retencao de INSS/CP for devida. O valor e calculado com a aliquota acima; na emissao real a Focus recebe o valor (valor_cp) quando for maior que zero.'
          : 'Marque quando a retencao de INSS/CP for devida. O valor e calculado com a aliquota acima; na emissao real o integrador recebe o valor (valor_cp) quando for maior que zero.';

  static String accountantDeclarationsHeaderSubtitle(Session? session) =>
      showFiscalVendorName(session)
          ? 'Acessos oficiais com acao, isolamento por empresa ativa e captura de XML via Focus (painel igual ao modulo Fiscal da empresa).'
          : 'Acessos oficiais com acao, isolamento por empresa ativa e captura de XML pelo integrador fiscal da plataforma (painel igual ao modulo Fiscal da empresa).';

  static String accountantDeclarationsResponsibility(Session? session) =>
      showFiscalVendorName(session)
          ? 'Links levam a sistemas oficiais e a captura Focus respeita o CNPJ da empresa ativa. Manifestacao do destinatario e automacoes fiscais adicionais ficam para outra rodada.'
          : 'Links levam a sistemas oficiais e a captura via integrador respeita o CNPJ da empresa ativa. Manifestacao do destinatario e automacoes fiscais adicionais ficam para outra rodada.';

  /// Checklist: conexao com provedor Focus vs generico (integrador).
  static String checklistFocusProviderConnection(
    Session? session,
    bool hasSynced,
  ) =>
      hasSynced
          ? (showFiscalVendorName(session)
                ? 'Empresa sincronizada com a Focus. Validar retorno e credenciais.'
                : 'Empresa sincronizada com o integrador fiscal. Validar retorno e credenciais.')
          : (showFiscalVendorName(session)
                ? 'Sincronize a empresa com a Focus e valide as credenciais.'
                : 'Sincronize a empresa no integrador fiscal e valide as credenciais.');

  static String syncCompanySuccessGeneric(Session? session) =>
      showFiscalVendorName(session)
          ? 'Empresa sincronizada com a Focus NFe.'
          : 'Empresa sincronizada no integrador fiscal (NFS-e).';

  static String syncCompanySuccessDetail(
    Session? session,
    String integrationCompanyId,
    String extraSuffix,
  ) =>
      showFiscalVendorName(session)
          ? 'Focus sincronizada. Empresa ID $integrationCompanyId$extraSuffix'
          : 'Integrador sincronizado. Empresa ID $integrationCompanyId$extraSuffix';

  static String syncCompanyCallableError(Session? session) =>
      showFiscalVendorName(session)
          ? 'Nao foi possivel sincronizar com a Focus NFe.'
          : 'Nao foi possivel sincronizar com o integrador fiscal.';

  static String provisioningRefreshFocusRejected(Session? session) =>
      showFiscalVendorName(session)
          ? 'A automacao fiscal foi reprocessada, mas a Focus rejeitou a sincronizacao.'
          : 'A automacao fiscal foi reprocessada, mas o integrador rejeitou a sincronizacao.';

  static String provisioningRefreshFocusDetail(
    Session? session,
    String error,
  ) =>
      showFiscalVendorName(session)
          ? 'A automacao fiscal foi reprocessada, mas a Focus retornou: $error'
          : 'A automacao fiscal foi reprocessada, mas o integrador retornou: $error';

  static String provisioningAutoDoneMessage(Session? session, String idRaw) =>
      idRaw.trim().isEmpty
          ? (showFiscalVendorName(session)
                ? 'Provisionamento automatico da Focus concluido.'
                : 'Provisionamento automatico do integrador fiscal concluido.')
          : (showFiscalVendorName(session)
                ? 'Provisionamento automatico concluido. Empresa Focus ID ${idRaw.trim()}.'
                : 'Provisionamento automatico concluido. ID integracao ${idRaw.trim()}.');

  static String blockerSyncBeforeOfficial(Session? session) =>
      showFiscalVendorName(session)
          ? 'Sincronizar a empresa com a Focus NFe antes da operacao oficial.'
          : 'Sincronizar a empresa no integrador fiscal antes da operacao oficial.';
}
