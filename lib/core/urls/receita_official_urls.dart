/// Portais oficiais usados em botoes (evitar paginas informativas ou 404 do gov.br).
abstract final class ReceitaOfficialUrls {
  ReceitaOfficialUrls._();

  static const String pgmeiEmissaoDas =
      'https://www8.receita.fazenda.gov.br/SimplesNacional/Aplicacoes/ATSPO/pgmei.app/emissao';

  static const String ecacLogin =
      'https://servicos.receitafederal.gov.br/login?redirectUrl=https%3A%2F%2Fcav.receita.fazenda.gov.br%2FeCAC%2Fpublico%2Flogin.aspx%3Fsistema%3D3';

  static const String simplesNacionalPgdasGrupo =
      'https://www8.receita.fazenda.gov.br/SimplesNacional/Servicos/Grupo.aspx?grp=5&id=60';

  static const String dasnSimei =
      'https://www8.receita.fazenda.gov.br/SimplesNacional/Aplicacoes/ATSPO/DASNSIMEI.app/Default.aspx';

  static const String esocialPortal = 'https://www.esocial.gov.br/PORTAL';

  static String receitaAgendaTributariaAno(int year) =>
      'https://www.gov.br/receitafederal/pt-br/assuntos/agenda-tributaria/$year';

  static const String fgtsDigitalSistema = 'https://fgtsdigital.sistema.gov.br/';

  static const String serproIntegraLogin = 'https://integra.serpro.gov.br/';

  static const String nfseEmissorNacional = 'https://www.nfse.gov.br/EmissorNacional';

  static const String spedEcfDownload =
      'https://www.gov.br/receitafederal/pt-br/centrais-de-conteudo/download/sped/ecf';
}
