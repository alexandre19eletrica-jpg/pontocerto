import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/navigation/app_shell.dart';
import 'package:pontocerto/core/navigation/shell_page_chrome.dart';
import 'package:pontocerto/core/theme/app_branding.dart';
import 'package:pontocerto/core/theme/app_layout.dart';
import 'package:pontocerto/features/accountant_links/presentation/accountant_fiscal_profile_provider.dart';
import 'package:pontocerto/core/ui/app_user_message.dart';

class AccountantFiscalProfilePage extends ConsumerStatefulWidget {
  const AccountantFiscalProfilePage({super.key});

  @override
  ConsumerState<AccountantFiscalProfilePage> createState() =>
      _AccountantFiscalProfilePageState();
}

class _AccountantFiscalProfilePageState
    extends ConsumerState<AccountantFiscalProfilePage> {
  final _officeName = TextEditingController();
  final _officeDocument = TextEditingController();
  final _officeEmail = TextEditingController();
  final _officePhone = TextEditingController();
  final _contractReference = TextEditingController();
  final _apiCredentialLabel = TextEditingController();
  final _certificateLabel = TextEditingController();
  final _serviceScopesSummary = TextEditingController();
  final _notes = TextEditingController();

  bool _integraContadorActive = false;
  bool _apiCredentialsConfigured = false;
  bool _ecnpjCertificateReady = false;
  bool _serviceScopesReady = false;
  bool _seeded = false;
  bool _saving = false;

  @override
  void dispose() {
    _officeName.dispose();
    _officeDocument.dispose();
    _officeEmail.dispose();
    _officePhone.dispose();
    _contractReference.dispose();
    _apiCredentialLabel.dispose();
    _certificateLabel.dispose();
    _serviceScopesSummary.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _seed(AccountantFiscalProfile profile) {
    if (_seeded) return;
    _officeName.text = profile.officeName;
    _officeDocument.text = profile.officeDocument;
    _officeEmail.text = profile.officeEmail;
    _officePhone.text = profile.officePhone;
    _contractReference.text = profile.contractReference;
    _apiCredentialLabel.text = profile.apiCredentialLabel;
    _certificateLabel.text = profile.certificateLabel;
    _serviceScopesSummary.text = profile.serviceScopesSummary;
    _notes.text = profile.notes;
    _integraContadorActive = profile.integraContadorActive;
    _apiCredentialsConfigured = profile.apiCredentialsConfigured;
    _ecnpjCertificateReady = profile.ecnpjCertificateReady;
    _serviceScopesReady = profile.serviceScopesReady;
    _seeded = true;
  }

  Future<void> _save(Session session) async {
    final officeName = _officeName.text.trim();
    final officeEmail = _officeEmail.text.trim();
    if (officeName.isEmpty || officeEmail.isEmpty) {
      _msg('Informe o nome do escritorio e o email principal.');
      return;
    }

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(session.userId)
          .set({
            'accountantFiscalProfile': {
              'officeName': officeName,
              'officeDocument': _officeDocument.text.trim(),
              'officeEmail': officeEmail,
              'officePhone': _officePhone.text.trim(),
              'integraContadorActive': _integraContadorActive,
              'apiCredentialsConfigured': _apiCredentialsConfigured,
              'ecnpjCertificateReady': _ecnpjCertificateReady,
              'serviceScopesReady': _serviceScopesReady,
              'contractReference': _contractReference.text.trim(),
              'apiCredentialLabel': _apiCredentialLabel.text.trim(),
              'certificateLabel': _certificateLabel.text.trim(),
              'serviceScopesSummary': _serviceScopesSummary.text.trim(),
              'notes': _notes.text.trim(),
              'appliesToLinkedCompanies': true,
              'updatedAt': FieldValue.serverTimestamp(),
            },
          }, SetOptions(merge: true));
      _msg('Perfil fiscal do contador salvo.');
    } catch (error) {
      _msg('Nao foi possivel salvar o perfil fiscal.');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _msg(String text) {
    if (!mounted) return;
    context.showUserMessage(text);
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    if (session == null || session.role != Role.accountant) {
      return const Scaffold(body: Center(child: Text('Acesso negado.')));
    }
    final profileAsync = ref.watch(accountantFiscalProfileProvider);

    ref.read(shellPageChromeProvider.notifier).state = ShellPageChrome(
      header: const AppWorkspaceHeader(
        title: 'Perfil fiscal do contador',
        subtitle:
            'Configure uma vez os dados oficiais do escritorio para Receita Federal e Integra Contador. Esse perfil passa a valer para todas as empresas vinculadas ao contador.',
        chips: [
          AppHeaderChip('Base unica do escritorio'),
          AppHeaderChip('Vale para toda a carteira'),
        ],
      ),
    );

    return AppGradientBackground(
        child: AppPageLayout(
          child: profileAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => AppWorkspaceCard(
              title: 'Perfil indisponivel',
              subtitle: error.toString(),
              child: const Text('Nao foi possivel carregar o perfil fiscal.'),
            ),
            data: (profile) {
              _seed(profile);
              return ListView(
                children: [
                  AppWorkspaceCard(
                    title: 'Resumo do perfil',
                    subtitle:
                        'O perfil do escritorio evita repetir a configuracao de credenciais oficiais em cada empresa. Procuracoes e autorizacoes por cliente continuam sendo tratadas por empresa quando exigidas.',
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        AppHeaderChip(
                          _integraContadorActive
                              ? 'Integra Contador ativo'
                              : 'Integra Contador pendente',
                        ),
                        AppHeaderChip(
                          _apiCredentialsConfigured
                              ? 'Credenciais oficiais prontas'
                              : 'Credenciais oficiais pendentes',
                        ),
                        AppHeaderChip(
                          _ecnpjCertificateReady
                              ? 'e-CNPJ pronto'
                              : 'e-CNPJ pendente',
                        ),
                        AppHeaderChip(
                          _serviceScopesReady
                              ? 'Escopos liberados'
                              : 'Escopos pendentes',
                        ),
                        const AppHeaderChip('Aplicado a empresas vinculadas'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const AppWorkspaceCard(
                    title: 'Regra de seguranca',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cadastre aqui apenas os dados e referencias oficiais do escritorio para integracoes com Receita Federal e Serpro.',
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Senha pessoal de gov.br e senha de e-CAC nao devem ser armazenadas no sistema. O perfil centraliza a base do escritorio, enquanto autorizacoes e procuracoes continuam por empresa quando a Receita exigir.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppWorkspaceCard(
                    title: 'Base oficial do escritorio',
                    child: Column(
                      children: [
                        _field(_officeName, 'Nome do escritorio *'),
                        const SizedBox(height: 10),
                        _field(_officeDocument, 'CNPJ do escritorio'),
                        const SizedBox(height: 10),
                        _field(_officeEmail, 'Email principal *'),
                        const SizedBox(height: 10),
                        _field(_officePhone, 'Telefone'),
                        const SizedBox(height: 10),
                        _field(
                          _contractReference,
                          'Referencia do contrato / conta Integra Contador',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppWorkspaceCard(
                    title: 'Credenciais oficiais e prontidao',
                    subtitle:
                        'Use nomes de referencia e status do escritorio. Nao coloque senha pessoal de gov.br ou e-CAC.',
                    child: Column(
                      children: [
                        SwitchListTile.adaptive(
                          value: _integraContadorActive,
                          onChanged: (value) =>
                              setState(() => _integraContadorActive = value),
                          title: const Text('Integra Contador contratado e ativo'),
                          subtitle: const Text(
                            'Marca que o escritorio ja tem a frente oficial preparada para servicos autorizados da Receita.',
                          ),
                        ),
                        SwitchListTile.adaptive(
                          value: _apiCredentialsConfigured,
                          onChanged: (value) =>
                              setState(() => _apiCredentialsConfigured = value),
                          title: const Text('Credenciais oficiais da API configuradas'),
                          subtitle: const Text(
                            'Status do acesso tecnico do escritorio, reutilizado em toda a carteira.',
                          ),
                        ),
                        SwitchListTile.adaptive(
                          value: _ecnpjCertificateReady,
                          onChanged: (value) =>
                              setState(() => _ecnpjCertificateReady = value),
                          title: const Text('e-CNPJ do escritorio pronto'),
                          subtitle: const Text(
                            'Perfil do escritorio pronto para os fluxos oficiais que dependem do certificado contabil.',
                          ),
                        ),
                        SwitchListTile.adaptive(
                          value: _serviceScopesReady,
                          onChanged: (value) =>
                              setState(() => _serviceScopesReady = value),
                          title: const Text('Escopos oficiais liberados'),
                          subtitle: const Text(
                            'Indica que os servicos contratados do escritorio ja estao liberados para uso.',
                          ),
                        ),
                        const SizedBox(height: 8),
                        _field(
                          _apiCredentialLabel,
                          'Identificador da credencial oficial',
                        ),
                        const SizedBox(height: 10),
                        _field(
                          _certificateLabel,
                          'Identificador do certificado do escritorio',
                        ),
                        const SizedBox(height: 10),
                        _field(
                          _serviceScopesSummary,
                          'Escopos / servicos habilitados',
                          maxLines: 2,
                        ),
                        const SizedBox(height: 10),
                        _field(
                          _notes,
                          'Observacoes operacionais do escritorio',
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppWorkspaceCard(
                    title: 'Como isso vale para a carteira',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          '- o contador prepara esse perfil uma vez no proprio acesso',
                        ),
                        SizedBox(height: 8),
                        Text(
                          '- as empresas vinculadas passam a herdar a prontidao do escritorio para os servicos oficiais',
                        ),
                        SizedBox(height: 8),
                        Text(
                          '- o que continua por empresa: procuracao, certificado da empresa quando aplicavel e dados fiscais do proprio cliente',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : () => _save(session),
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(_saving ? 'Salvando...' : 'Salvar perfil'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
    );
  }
}
