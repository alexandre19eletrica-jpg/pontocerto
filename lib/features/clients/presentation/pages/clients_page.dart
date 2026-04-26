import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/navigation/app_shell.dart';
import 'package:pontocerto/core/navigation/shell_page_chrome.dart';
import 'package:pontocerto/core/theme/app_branding.dart';
import 'package:pontocerto/core/theme/app_layout.dart';
import 'package:pontocerto/core/utils/formatadores_input.dart';
import 'package:pontocerto/features/clients/presentation/clients_provider.dart';
import 'package:pontocerto/features/fiscal/domain/invoice_customer.dart';
import 'package:pontocerto/features/fiscal/presentation/services/fiscal_registry_lookup_service.dart';
import 'package:pontocerto/core/ui/app_user_message.dart';

class ClientsPage extends ConsumerStatefulWidget {
  const ClientsPage({super.key});

  @override
  ConsumerState<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends ConsumerState<ClientsPage> {
  final _lookup = FiscalRegistryLookupService();

  Widget _surface({
    required Widget child,
    EdgeInsetsGeometry margin = const EdgeInsets.only(bottom: 10),
  }) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppBrandColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    if (session == null) {
      return const Scaffold(body: Center(child: Text('Sem sessao ativa')));
    }
    final clients = ref.watch(clientsProvider);
    final clientesComDocumento = clients
        .where((client) => client.document.trim().isNotEmpty)
        .length;
    final clientesComCidade = clients
        .where((client) => client.city.trim().isNotEmpty)
        .length;

    ref.read(shellPageChromeProvider.notifier).state = ShellPageChrome(
      header: AppWorkspaceHeader(
        title: 'Clientes',
        subtitle:
            'Base unica de tomadores e clientes para tarefas, propostas e emissao fiscal.',
        chips: [
          AppHeaderChip('Cadastro compartilhado'),
          AppHeaderChip('Busca por CNPJ'),
          AppHeaderChip('Base ${clients.length}'),
        ],
      ),
    );

    return AppGradientBackground(
      child: AppPageLayout(
        child: ListView(
          children: [
            AppWorkspaceCard(
              title: 'Panorama',
              subtitle:
                  'Concentrador de tomadores e clientes para reduzir retrabalho entre operacao, comercial e emissao fiscal.',
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  AppMetricCard(
                    label: 'Clientes',
                    value: clients.length.toString(),
                    caption: 'Cadastros na base compartilhada',
                  ),
                  AppMetricCard(
                    label: 'Com documento',
                    value: clientesComDocumento.toString(),
                    caption: 'CPF ou CNPJ informado',
                  ),
                  AppMetricCard(
                    label: 'Com cidade',
                    value: clientesComCidade.toString(),
                    caption: 'Endereco parcialmente preenchido',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppWorkspaceCard(
              title: 'Base de clientes',
              subtitle:
                  'Tudo salvo aqui pode ser reaproveitado nas tarefas e na NFS-e sem digitar de novo.',
              trailing: TextButton.icon(
                onPressed: () => _openClientDialog(session: session),
                icon: const Icon(Icons.add),
                label: const Text('Novo'),
              ),
              child: Column(
                children: [
                  if (clients.isEmpty)
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Nenhum cliente cadastrado.'),
                      subtitle: Text(
                        'Use o CNPJ para preencher automaticamente os dados do tomador.',
                      ),
                    )
                  else
                    ...clients.map(
                      (client) => _surface(
                        child: ListTile(
                          leading: const Icon(Icons.apartment_outlined),
                          title: Text(
                            client.legalName.isEmpty
                                ? client.tradeName
                                : client.legalName,
                          ),
                          subtitle: Text(
                            '${client.document.isEmpty ? '-' : client.document}\n'
                            '${client.city.isEmpty ? '-' : client.city} - ${client.state.isEmpty ? '-' : client.state}',
                          ),
                          isThreeLine: true,
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                tooltip: 'Editar cliente',
                                onPressed: () => _openClientDialog(
                                  session: session,
                                  editing: client,
                                ),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openClientDialog({
    required Session session,
    InvoiceCustomer? editing,
  }) async {
    final legalNameController = TextEditingController(
      text: editing?.legalName ?? '',
    );
    final tradeNameController = TextEditingController(
      text: editing?.tradeName ?? '',
    );
    final documentController = TextEditingController(
      text: editing?.document ?? '',
    );
    final emailController = TextEditingController(text: editing?.email ?? '');
    final phoneController = TextEditingController(text: editing?.phone ?? '');
    final municipalRegistrationController = TextEditingController(
      text: editing?.municipalRegistration ?? '',
    );
    final stateRegistrationController = TextEditingController(
      text: editing?.stateRegistration ?? '',
    );
    final zipCodeController = TextEditingController(
      text: editing?.zipCode ?? '',
    );
    final streetController = TextEditingController(text: editing?.street ?? '');
    final numberController = TextEditingController(text: editing?.number ?? '');
    final complementController = TextEditingController(
      text: editing?.complement ?? '',
    );
    final neighborhoodController = TextEditingController(
      text: editing?.neighborhood ?? '',
    );
    final cityController = TextEditingController(text: editing?.city ?? '');
    final stateController = TextEditingController(text: editing?.state ?? '');
    bool lookupBusy = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(editing == null ? 'Novo cliente' : 'Editar cliente'),
          content: SizedBox(
            width: 700,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: documentController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [CpfCnpjInputFormatter()],
                          maxLength: 18,
                          decoration: const InputDecoration(
                            labelText: 'CNPJ / CPF',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: lookupBusy
                            ? null
                            : () async {
                                final document = _onlyDigits(documentController.text);
                                if (document.length != 14) {
                                  _msg('Informe um CNPJ valido com 14 digitos.');
                                  return;
                                }
                                setDialogState(() => lookupBusy = true);
                                try {
                                  final result = await _lookup.lookupCnpj(document);
                                  legalNameController.text =
                                      result['legalName']?.toString() ?? '';
                                  tradeNameController.text =
                                      result['tradeName']?.toString() ?? '';
                                  emailController.text =
                                      result['email']?.toString() ?? '';
                                  phoneController.text =
                                      result['phone']?.toString() ?? '';
                                  municipalRegistrationController.text =
                                      sanitizeMunicipalRegistrationFromCnpjLookup(
                                    result,
                                    municipalRegistrationController.text,
                                  );
                                  stateRegistrationController.text =
                                      result['stateRegistration']?.toString() ?? '';
                                  zipCodeController.text =
                                      result['zipCode']?.toString() ?? '';
                                  streetController.text =
                                      result['street']?.toString() ?? '';
                                  numberController.text =
                                      result['number']?.toString() ?? '';
                                  complementController.text =
                                      result['complement']?.toString() ?? '';
                                  neighborhoodController.text =
                                      result['neighborhood']?.toString() ?? '';
                                  cityController.text =
                                      result['city']?.toString() ?? '';
                                  stateController.text =
                                      result['state']?.toString() ?? '';
                                } catch (_) {
                                  _msg('Nao foi possivel buscar o CNPJ agora.');
                                } finally {
                                  if (context.mounted) {
                                    setDialogState(() => lookupBusy = false);
                                  }
                                }
                              },
                        icon: const Icon(Icons.search),
                        label: const Text('Buscar CNPJ'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: legalNameController,
                    decoration: const InputDecoration(labelText: 'Razao social'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: tradeNameController,
                    decoration: const InputDecoration(labelText: 'Nome fantasia'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: emailController,
                          decoration: const InputDecoration(labelText: 'Email'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: phoneController,
                          decoration: const InputDecoration(labelText: 'Telefone'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: municipalRegistrationController,
                          decoration: const InputDecoration(
                            labelText: 'Inscricao municipal',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: stateRegistrationController,
                          decoration: const InputDecoration(
                            labelText: 'Inscricao estadual',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: zipCodeController,
                          decoration: const InputDecoration(labelText: 'CEP'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: cityController,
                          decoration: const InputDecoration(labelText: 'Cidade'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 90,
                        child: TextField(
                          controller: stateController,
                          decoration: const InputDecoration(labelText: 'UF'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: streetController,
                    decoration: const InputDecoration(labelText: 'Rua'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: numberController,
                          decoration: const InputDecoration(labelText: 'Numero'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: neighborhoodController,
                          decoration: const InputDecoration(labelText: 'Bairro'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: complementController,
                    decoration: const InputDecoration(labelText: 'Complemento'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (legalNameController.text.trim().isEmpty &&
                    tradeNameController.text.trim().isEmpty) {
                  _msg('Informe ao menos a razao social ou nome fantasia.');
                  return;
                }
                await FirebaseFirestore.instance
                    .collection('invoice_customers')
                    .doc(
                      editing?.id.isNotEmpty == true
                          ? editing!.id
                          : (_onlyDigits(documentController.text).isEmpty
                                ? DateTime.now().microsecondsSinceEpoch.toString()
                                : _onlyDigits(documentController.text)),
                    )
                    .set({
                      'companyId': session.companyId,
                      'legalName': legalNameController.text.trim(),
                      'tradeName': tradeNameController.text.trim(),
                      'document': documentController.text.trim(),
                      'email': emailController.text.trim(),
                      'phone': phoneController.text.trim(),
                      'municipalRegistration':
                          municipalRegistrationController.text.trim(),
                      'stateRegistration':
                          stateRegistrationController.text.trim(),
                      'zipCode': zipCodeController.text.trim(),
                      'street': streetController.text.trim(),
                      'number': numberController.text.trim(),
                      'complement': complementController.text.trim(),
                      'neighborhood': neighborhoodController.text.trim(),
                      'city': cityController.text.trim(),
                      'state': stateController.text.trim(),
                      'country': 'BRASIL',
                      'notes': '',
                      if (editing == null)
                        'createdAtIso': DateTime.now().toIso8601String(),
                      'updatedAtIso': DateTime.now().toIso8601String(),
                    }, SetOptions(merge: true));
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    legalNameController.dispose();
    tradeNameController.dispose();
    documentController.dispose();
    emailController.dispose();
    phoneController.dispose();
    municipalRegistrationController.dispose();
    stateRegistrationController.dispose();
    zipCodeController.dispose();
    streetController.dispose();
    numberController.dispose();
    complementController.dispose();
    neighborhoodController.dispose();
    cityController.dispose();
    stateController.dispose();
  }

  String _onlyDigits(String input) => input.replaceAll(RegExp(r'\D'), '');

  void _msg(String text) {
    if (!mounted) return;
    context.showUserMessage(text);
  }
}
