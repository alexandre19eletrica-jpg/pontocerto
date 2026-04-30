import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pontocerto/core/errors/app_error_mapper.dart';
import 'package:pontocerto/core/ui/app_user_message.dart';
import 'package:pontocerto/features/marketing/presentation/services/vendas_public_flow_service.dart';

const _ink = Color(0xFF16202B);
const _primary = Color(0xFF1E4FD7);
const _surface = Color(0xFFF4F7FB);

/// Convite do fluxo vendas: valida token e cria acesso de contador (isolado).
class VendasConvitePage extends StatefulWidget {
  const VendasConvitePage({super.key, required this.token});

  final String token;

  @override
  State<VendasConvitePage> createState() => _VendasConvitePageState();
}

class _VendasConvitePageState extends State<VendasConvitePage> {
  final _service = VendasPublicFlowService();
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  final _confirma = TextEditingController();

  bool _carregando = true;
  bool _valido = false;
  bool _expirado = false;
  bool _usado = false;
  String? _nomeEmpresaCliente;
  String _emailBloqueado = '';
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    _senha.dispose();
    _confirma.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    final t = widget.token.trim();
    if (t.isEmpty) {
      setState(() {
        _carregando = false;
        _valido = false;
      });
      return;
    }
    setState(() => _carregando = true);
    try {
      final r = await _service.getConvite(token: t);
      final valid = r['valid'] == true;
      final expired = r['expired'] == true;
      final used = r['used'] == true;
      final email = r['emailContador']?.toString() ?? '';
      final nomeEmpresa = r['nomeEmpresa']?.toString() ?? '';
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _valido = valid;
        _expirado = expired;
        _usado = used;
        _nomeEmpresaCliente = nomeEmpresa.isEmpty ? null : nomeEmpresa;
        _emailBloqueado = email;
        _email.text = email;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _valido = false;
      });
      if (mounted) context.showUserError(AppErrorMapper.messageFrom(e));
    }
  }

  Future<void> _criarAcesso() async {
    final t = widget.token.trim();
    if (_senha.text != _confirma.text) {
      context.showUserError('A confirmacao de senha nao confere.');
      return;
    }
    setState(() => _enviando = true);
    try {
      final map = await _service.submitContadorConvite(
        token: t,
        nomeContador: _nome.text.trim(),
        email: _email.text.trim().toLowerCase(),
        senha: _senha.text,
        confirmaSenha: _confirma.text,
      );
      if (!mounted) return;
      final nomeEmpresa = _nomeEmpresaCliente?.trim() ?? 'a empresa indicada';
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Acesso criado'),
          content: Text(
            'Proximo passo: entre no Ponto Certo como contador e cadastre no painel a empresa '
            '"$nomeEmpresa" (fluxo de nova empresa da carteira). '
            'O cliente nao finaliza cadastro sozinho neste fluxo. Enviamos os detalhes tambem no seu email.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      context.go('/login-contador');
    } catch (e) {
      if (mounted) context.showUserError(AppErrorMapper.messageFrom(e));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 720;

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        foregroundColor: _ink,
        title: const Text('Convite Ponto Certo'),
      ),
      body: SafeArea(
        child: _carregando
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 32, vertical: 12),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: !_valido
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                _expirado
                                    ? 'Este convite expirou.'
                                    : _usado
                                    ? 'Este convite ja foi utilizado.'
                                    : 'Convite invalido ou nao encontrado.',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: _ink,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () => context.go('/inicio'),
                                child: const Text('Ir ao inicio'),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_nomeEmpresaCliente != null)
                                Text(
                                  'Cliente: ${_nomeEmpresaCliente!}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: _primary,
                                    fontSize: 15,
                                  ),
                                ),
                              const SizedBox(height: 16),
                              const Text(
                                'Crie seu acesso de contador',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: _ink,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Use o mesmo email que recebeu o convite. Em seguida voce cadastra a empresa do cliente pelo painel (nao e o cliente que abre conta aqui).',
                                style: TextStyle(color: _ink, height: 1.4),
                              ),
                              const SizedBox(height: 20),
                              TextField(
                                controller: _nome,
                                decoration: const InputDecoration(
                                  labelText: 'Seu nome',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _email,
                                readOnly: _emailBloqueado.isNotEmpty,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _senha,
                                obscureText: true,
                                decoration: const InputDecoration(
                                  labelText: 'Senha',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _confirma,
                                obscureText: true,
                                decoration: const InputDecoration(
                                  labelText: 'Confirmar senha',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 24),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: _primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                                onPressed: _enviando ? null : _criarAcesso,
                                child: _enviando
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('CRIAR ACESSO', style: TextStyle(fontWeight: FontWeight.w800)),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
      ),
    );
  }
}
