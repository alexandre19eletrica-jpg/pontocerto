import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class EmployeeTesterShowcasePage extends StatelessWidget {
  const EmployeeTesterShowcasePage({super.key});

  static const _salesUrl = 'https://gestao-ponto-certo.com/vendas';

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Conhecer o sistema real')),
      body: SelectionArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF7FAFF), Color(0xFFE8F1FF)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: uid == null
                ? null
                : FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .snapshots(),
            builder: (context, snapshot) {
              final data = snapshot.data?.data() ?? const <String, dynamic>{};
              final realAccessUrl =
                  data['realAccessUrl']?.toString().trim() ?? '';
              final realAccessLabel =
                  data['realAccessLabel']?.toString().trim().isNotEmpty == true
                  ? data['realAccessLabel'].toString().trim()
                  : 'Ir para o ambiente real';
              final realReleased =
                  data['realAccessReleasedAt'] != null &&
                  realAccessUrl.isNotEmpty;
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _HeroCard(
                    realReleased: realReleased,
                    realAccessLabel: realAccessLabel,
                    onOpenSales: _openSales,
                    onOpenReal: realReleased
                        ? () => _openExternal(realAccessUrl)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  const _ShowcaseBlock(
                    title: 'O que voce ja testou no app',
                    items: [
                      'acesso isolado do colaborador sem misturar dados da empresa',
                      'ponto, tarefas, ordens, justificativas e rotina de uso no celular',
                      'fluxo leve para testar a experiencia operacional real de quem executa o trabalho',
                    ],
                  ),
                  const SizedBox(height: 12),
                  const _ShowcaseBlock(
                    title: 'O que existe no sistema real completo',
                    items: [
                      'empresa organizada em uma unica base com operacao, financeiro e fiscal',
                      'painel do dono, clientes, materiais, catalogo, cobranca, contratos, documentos e relatorios',
                      'contador conectado na mesma estrutura, com leitura fiscal, documentos e acompanhamento da empresa',
                    ],
                  ),
                  const SizedBox(height: 12),
                  const _ShowcaseBlock(
                    title: 'O que muda quando voce sai do teste',
                    items: [
                      'voce deixa de ver apenas o modulo do funcionario e conhece a plataforma completa',
                      'o ambiente real pode ser liberado para continuidade apos o periodo de teste',
                      'essa tela funciona como uma pagina de apresentacao interna para criar expectativa sobre a versao oficial',
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: () => _openSales(),
                        icon: const Icon(Icons.public_outlined),
                        label: const Text('Ver pagina comercial completa'),
                      ),
                      OutlinedButton.icon(
                        onPressed: realReleased
                            ? () => _openExternal(realAccessUrl)
                            : null,
                        icon: const Icon(Icons.open_in_new_outlined),
                        label: Text(realAccessLabel),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _openSales() async {
    await _openExternal(_salesUrl);
  }

  Future<void> _openExternal(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.realReleased,
    required this.realAccessLabel,
    required this.onOpenSales,
    required this.onOpenReal,
  });

  final bool realReleased;
  final String realAccessLabel;
  final Future<void> Function() onOpenSales;
  final Future<void> Function()? onOpenReal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF102B46), Color(0xFF1F5D96)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Conhecer o sistema real',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            realReleased
                ? 'Seu acesso ao ambiente real ja foi liberado. Voce pode sair do teste e seguir para a experiencia oficial quando quiser.'
                : 'Voce entrou como testador do app de funcionario. Esta area mostra como esse teste se conecta ao sistema real completo para empresa, equipe e contador, sem separar o que acontece na rua do que precisa chegar organizado no escritorio.',
            style: const TextStyle(color: Colors.white, height: 1.4),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: onOpenSales,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70),
                ),
                icon: const Icon(Icons.arrow_forward_outlined),
                label: const Text('Abrir pagina comercial'),
              ),
              FilledButton.icon(
                onPressed: onOpenReal,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF123355),
                ),
                icon: const Icon(Icons.rocket_launch_outlined),
                label: Text(realAccessLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShowcaseBlock extends StatelessWidget {
  const _ShowcaseBlock({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD7E3F3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF16324A),
            ),
          ),
          const SizedBox(height: 12),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: Color(0xFF1E5FA8),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
