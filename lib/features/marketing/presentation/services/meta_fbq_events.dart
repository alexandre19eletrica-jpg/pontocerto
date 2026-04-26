import 'meta_fbq_events_stub.dart'
    if (dart.library.html) 'meta_fbq_events_web.dart' as impl;

/// Rota publica de vendas: PageView + ViewContent.
void metaFbqTrackVendasFunnel() => impl.metaFbqTrackVendasFunnel();

/// Pagina de cadastro do escritorio (ex.: a partir de /contratar).
void metaFbqTrackCadastroEscritorioView() => impl.metaFbqTrackCadastroEscritorioView();

/// Fluxo "solicitar teste" (pre-cadastro com contador), quando essa tela for usada.
void metaFbqTrackSolicitacaoTesteView() => impl.metaFbqTrackSolicitacaoTesteView();

void metaFbqTrackPageView() => impl.metaFbqTrackPageView();

/// Cadastro de escritorio concluido (conversao).
void metaFbqTrackCompleteRegistrationEscritorio({
  required String officeId,
  required String contentName,
}) {
  return impl.metaFbqTrackCompleteRegistrationEscritorio(
    officeId: officeId,
    contentName: contentName,
  );
}

/// Pre-cadastro de lead (tela de solicitacao de teste) enviado.
void metaFbqTrackLeadPreCadastro({
  required String leadId,
  required String planCode,
}) {
  return impl.metaFbqTrackLeadPreCadastro(leadId: leadId, planCode: planCode);
}
