import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pontocerto/core/errors/app_error_mapper.dart';
import 'package:pontocerto/core/theme/app_branding.dart';
import 'package:pontocerto/core/theme/app_layout.dart';
import 'package:pontocerto/features/marketing/presentation/services/accountant_partner_invite_service.dart';
import 'package:pontocerto/core/ui/app_user_message.dart';

class AccountantPartnerInvitePage extends StatefulWidget {
  const AccountantPartnerInvitePage({
    super.key,
    required this.token,
  });

  final String token;

  @override
  State<AccountantPartnerInvitePage> createState() =>
      _AccountantPartnerInvitePageState();
}

class _AccountantPartnerInvitePageState
    extends State<AccountantPartnerInvitePage> {
  final _service = AccountantPartnerInviteService();
  bool _loading = true;
  bool _accepting = false;
  AccountantPartnerInviteSnapshot? _snapshot;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final snapshot = await _service.getInvite(widget.token);
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      if (context.mounted) { context.showUserError(AppErrorMapper.messageFrom(error)); }
      setState(() => _loading = false);
    }
  }

  Future<void> _accept() async {
    if (_accepting) return;
    setState(() => _accepting = true);
    try {
      final snapshot = await _service.accept(widget.token);
      if (!mounted) return;
      setState(() => _snapshot = snapshot);
      if (context.mounted) {
        context.showUserSuccess(
          'Convite aceito. O onboarding sera enviado apos o pagamento.',
        );
      }
    } catch (error) {
      if (!mounted) return;
      if (context.mounted) { context.showUserError(AppErrorMapper.messageFrom(error)); }
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final snapshot = _snapshot;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seja nosso parceiro'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/vendas'),
        ),
      ),
      body: AppGradientBackground(
        child: AppPageLayout(
          child: ListView(
            children: [
              AppWorkspaceCard(
                title: snapshot?.accepted == true
                    ? 'Parceria confirmada'
                    : 'Seja nosso parceiro',
                subtitle:
                    'Use o PontoCerto para reduzir retrabalho fiscal, organizar melhor as empresas da carteira e abrir uma nova frente comercial.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Empresa: ${snapshot?.customerName ?? '-'}'),
                    const SizedBox(height: 6),
                    Text('Contato da empresa: ${snapshot?.customerEmail ?? '-'}'),
                    const SizedBox(height: 6),
                    Text('Plano: ${snapshot?.planTitle ?? '-'}'),
                    const SizedBox(height: 12),
                    const Text(
                      'Ao aceitar, voce entra como contador parceiro deste lead. Quando o pagamento do plano for confirmado, o onboarding web da empresa sera enviado para voce concluir o cadastro inicial e a vinculacao contabil.',
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Vantagens para o contador:',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• menos retrabalho para fechar fiscal e documentos\n• empresa mais organizada para o escritorio operar\n• oportunidade de comissao sobre clientes indicados\n• mais contexto e menos cobranca manual do cliente',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (snapshot?.accepted != true)
                FilledButton.icon(
                  onPressed: _accepting ? null : _accept,
                  icon: _accepting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.handshake_outlined),
                  label: Text(_accepting ? 'Confirmando...' : 'Aceitar parceria'),
                )
              else
                FilledButton.icon(
                  onPressed: () => context.go('/login-contador'),
                  icon: const Icon(Icons.login),
                  label: const Text('Abrir acesso do contador'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
