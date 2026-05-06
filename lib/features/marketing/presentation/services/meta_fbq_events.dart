import 'package:go_router/go_router.dart';
import 'meta_fbq_events_stub.dart'
    if (dart.library.html) 'meta_fbq_events_web.dart' as impl;

/// Rota publica de vendas: ViewContent complementar (PageView vem do [metaFbqBindGoRouter] na web).
void metaFbqTrackVendasFunnel() => impl.metaFbqTrackVendasFunnel();

/// Pagina de cadastro do escritorio (ex.: a partir de /contratar).
void metaFbqTrackCadastroEscritorioView() => impl.metaFbqTrackCadastroEscritorioView();

/// Landing /vendas-empresa (convite ao contador): ViewContent para remarketing.
void metaFbqTrackVendasEmpresaLandingView() => impl.metaFbqTrackVendasEmpresaLandingView();

/// Fluxo "solicitar teste" (pre-cadastro com contador), quando essa tela for usada.
void metaFbqTrackSolicitacaoTesteView() => impl.metaFbqTrackSolicitacaoTesteView();

void metaFbqTrackPageView() => impl.metaFbqTrackPageView();

/// Web: registra [PageView] a cada troca de rota (SPA). Chamar uma vez no startup.
void metaFbqBindGoRouter(GoRouter router) => impl.metaFbqBindGoRouter(router);

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

/// Convite ao contador enviado a partir da landing /vendas-empresa (conversao Lead).
void metaFbqTrackLeadConviteContadorLandingEmpresa({required String leadId}) {
  return impl.metaFbqTrackLeadConviteContadorLandingEmpresa(leadId: leadId);
}

/// Abrir WhatsApp comercial — evento padrão [Contact].
void metaFbqTrackContactWhatsapp() => impl.metaFbqTrackContactWhatsapp();

/// Início do teste grátis do escritório (CTA para cadastro / contratar).
void metaFbqTrackStartTrialEscritorio() => impl.metaFbqTrackStartTrialEscritorio();

/// Pré-cadastro / trial da empresa (`/pre-cadastro-empresa` e páginas de entrada).
void metaFbqTrackStartTrialEmpresa() => impl.metaFbqTrackStartTrialEmpresa();

/// Conclusão do pré-cadastro empresa leve (criação de tenant).
void metaFbqTrackLeadPrecadastroEmpresaLeve({required String companyId}) {
  return impl.metaFbqTrackLeadPrecadastroEmpresaLeve(companyId: companyId);
}

/// Visualização do formulário de pré-cadastro empresa leve.
void metaFbqTrackPrecadastroEmpresaLeveView() =>
    impl.metaFbqTrackPrecadastroEmpresaLeveView();

/// Pre-cadastro de lead (tela de solicitacao de teste) enviado.
void metaFbqTrackLeadPreCadastro({
  required String leadId,
  required String planCode,
}) {
  return impl.metaFbqTrackLeadPreCadastro(leadId: leadId, planCode: planCode);
}
