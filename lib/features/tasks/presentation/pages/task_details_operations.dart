part of 'tasks_page.dart';

extension _TaskDetailsOperations on TaskDetailsPage {
  Future<void> _editarTarefa(
    BuildContext context,
    WidgetRef ref,
    TarefaItem tarefa,
  ) async {
    final sessao = ref.read(sessionProvider);
    if (sessao == null) {
      _msg(context, 'Sessao nao encontrada.');
      return;
    }
    final nomeCtrl = TextEditingController(text: tarefa.nome);
    final descCtrl = TextEditingController(text: tarefa.descricao);
    final clienteCtrl = TextEditingController(text: tarefa.clienteNome);
    final clienteDocumentoCtrl = TextEditingController(text: tarefa.clienteDocumento);
    String? selectedClientId = tarefa.clienteId.isEmpty ? null : tarefa.clienteId;
    final isEmpresa = sessao.role != Role.employee;
    final employees = ref
        .read(employeesProvider)
        .where((e) => e.ativo || e.id == tarefa.autorId)
        .toList()
      ..sort((a, b) => a.nomeCompleto.compareTo(b.nomeCompleto));
    String? selectedEmployeeId = isEmpresa ? tarefa.autorId : null;
    bool lookupBusy = false;
    DateTime? dataExecucao = tarefa.dataExecucao;
    final clients = ref.read(clientsProvider);
    final registryLookup = FiscalRegistryLookupService();

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (_, setDialog) => AlertDialog(
          title: const Text('Editar tarefa'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nomeCtrl,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Descricao'),
                ),
                const SizedBox(height: 8),
                if (isEmpresa) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _findResponsibleById(
                          employees,
                          selectedEmployeeId,
                        ) !=
                        null
                        ? selectedEmployeeId
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Responsavel pela tarefa',
                    ),
                    items: [
                      for (final employee in employees)
                        DropdownMenuItem(
                          value: employee.id,
                          child: Text(employee.nomeCompleto),
                        ),
                    ],
                    onChanged: (value) {
                      setDialog(() => selectedEmployeeId = value);
                    },
                  ),
                  const SizedBox(height: 8),
                ],
                if (clients.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    initialValue: clients.any((client) => client.id == selectedClientId)
                        ? selectedClientId
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Cliente salvo',
                    ),
                    items: clients
                        .map(
                          (client) => DropdownMenuItem(
                            value: client.id,
                            child: Text(
                              client.legalName.isNotEmpty
                                  ? client.legalName
                                  : client.tradeName,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      final selected = clients.where((c) => c.id == value).firstOrNull;
                      if (selected == null) return;
                      _applySharedCustomer(
                        customer: selected,
                        clienteCtrl: clienteCtrl,
                        clienteDocumentoCtrl: clienteDocumentoCtrl,
                      );
                      setDialog(() => selectedClientId = value);
                    },
                  ),
                  const SizedBox(height: 8),
                ],
                TextField(
                  controller: clienteCtrl,
                  decoration: const InputDecoration(labelText: 'Cliente'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: clienteDocumentoCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [CpfCnpjInputFormatter()],
                        maxLength: 18,
                        onChanged: (_) => setDialog(() => selectedClientId = null),
                        decoration: const InputDecoration(
                          labelText: 'CPF ou CNPJ do cliente',
                          hintText: 'Digite o documento ou selecione um cliente salvo',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: lookupBusy
                          ? null
                          : () async {
                              final digits = _somenteDigitosTexto(
                                clienteDocumentoCtrl.text,
                              );
                              if (digits.length != 14) {
                                _msg(context, 'Informe um CNPJ valido com 14 digitos.');
                                return;
                              }
                              setDialog(() => lookupBusy = true);
                              try {
                                final result = await registryLookup.lookupCnpj(digits);
                                clienteCtrl.text =
                                    result['legalName']?.toString().trim().isNotEmpty == true
                                    ? result['legalName'].toString()
                                    : result['tradeName']?.toString() ?? '';
                                final clientId = _sharedCustomerId(
                                  clienteDocumentoCtrl.text,
                                );
                                selectedClientId = await _saveSharedCustomer(
                                  sessao: sessao,
                                  clientId: clientId,
                                  clientName: clienteCtrl.text.trim(),
                                  clientDocument: clienteDocumentoCtrl.text.trim(),
                                  email: result['email']?.toString() ?? '',
                                  phone: result['phone']?.toString() ?? '',
                                  municipalRegistration:
                                      sanitizeMunicipalRegistrationFromCnpjLookup(
                                    result,
                                    '',
                                  ),
                                  stateRegistration:
                                      result['stateRegistration']?.toString() ?? '',
                                  zipCode: result['zipCode']?.toString() ?? '',
                                  street: result['street']?.toString() ?? '',
                                  number: result['number']?.toString() ?? '',
                                  complement: result['complement']?.toString() ?? '',
                                  neighborhood:
                                      result['neighborhood']?.toString() ?? '',
                                  city: result['city']?.toString() ?? '',
                                  state: result['state']?.toString() ?? '',
                                );
                                if (context.mounted) {
                                  _msg(context, 'Cliente carregado e salvo na base.');
                                }
                              } catch (_) {
                                if (context.mounted) {
                                  _msg(
                                    context,
                                    'Nao foi possivel buscar o CNPJ agora.',
                                  );
                                }
                              } finally {
                                if (context.mounted) {
                                  setDialog(() => lookupBusy = false);
                                }
                              }
                            },
                      icon: const Icon(Icons.search),
                      label: const Text('Buscar CNPJ'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_documentoEhCnpjTexto(clienteDocumentoCtrl.text))
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Ao buscar o CNPJ, o cliente entra automaticamente na base compartilhada.',
                    ),
                  ),
                if (_documentoEhCpfTexto(clienteDocumentoCtrl.text))
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'CPF continua manual por privacidade e LGPD.',
                    ),
                  ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Data da execucao'),
                  subtitle: Text(_formatarData(dataExecucao)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final escolhida = await showDatePicker(
                      context: dialogCtx,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                      initialDate: dataExecucao ?? DateTime.now(),
                    );
                    if (escolhida != null) {
                      setDialog(() => dataExecucao = escolhida);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nomeCtrl.text.trim().isEmpty ||
                    clienteCtrl.text.trim().isEmpty ||
                    dataExecucao == null) {
                  return;
                }
                final responsible = isEmpresa
                    ? _findResponsibleById(employees, selectedEmployeeId)
                    : null;
                if (isEmpresa && responsible == null) {
                  _msg(
                    context,
                    employees.isEmpty
                        ? 'Cadastre um funcionario ativo antes de direcionar tarefas.'
                        : 'Selecione o funcionario responsavel pela tarefa.',
                  );
                  return;
                }
                await ref
                    .read(tasksProvider.notifier)
                    .updateById(
                      tarefa.id,
                      tarefa.copyWith(
                        autorId: responsible?.id ?? tarefa.autorId,
                        autorNome:
                            responsible?.nomeCompleto ?? tarefa.autorNome,
                        nome: nomeCtrl.text.trim(),
                        descricao: descCtrl.text.trim(),
                        clienteId:
                            selectedClientId ??
                            (_somenteDigitosTexto(clienteDocumentoCtrl.text).isEmpty
                                ? ''
                                : _sharedCustomerId(clienteDocumentoCtrl.text)),
                        clienteNome: clienteCtrl.text.trim(),
                        clienteDocumento: clienteDocumentoCtrl.text.trim(),
                        dataExecucao: DateTime(
                          dataExecucao!.year,
                          dataExecucao!.month,
                          dataExecucao!.day,
                        ),
                      ),
                    );
                if (clienteCtrl.text.trim().isNotEmpty &&
                    clienteDocumentoCtrl.text.trim().isNotEmpty) {
                  await _saveSharedCustomer(
                    sessao: sessao,
                    clientId:
                        selectedClientId ??
                        _sharedCustomerId(clienteDocumentoCtrl.text),
                    clientName: clienteCtrl.text.trim(),
                    clientDocument: clienteDocumentoCtrl.text.trim(),
                  );
                }
                if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    nomeCtrl.dispose();
    descCtrl.dispose();
    clienteCtrl.dispose();
    clienteDocumentoCtrl.dispose();
  }

  Future<void> _adicionarItem(
    BuildContext context,
    WidgetRef ref,
    TarefaItem tarefa,
  ) async {
    final controller = TextEditingController();
    final valorUnitarioController = TextEditingController();
    final valorTotalLinhaController = TextEditingController();
    final quantidadeController = TextEditingController(text: '1');
    final servicos = ref
        .read(serviceCatalogProvider)
        .where((s) => !s.pendingDelete)
        .toList();
    final nomesExistentes = servicos
        .map((s) => s.nome.trim().toLowerCase())
        .toSet();
    String? servicoSelecionadoId;
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (_, setDialog) => AlertDialog(
          title: const Text('Adicionar item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (servicos.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Selecionar servico do banco',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 180,
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: ListView.builder(
                      itemCount: servicos.length,
                      itemBuilder: (_, i) {
                        final s = servicos[i];
                        final selected = servicoSelecionadoId == s.id;
                        return ListTile(
                          dense: true,
                          selected: selected,
                          title: Text(s.nome),
                          subtitle: Text(_formatarMoeda(s.valorCents)),
                          onTap: () {
                            setDialog(() => servicoSelecionadoId = s.id);
                            controller.text = s.nome;
                            valorUnitarioController.text =
                                _centsParaInput(s.valorCents);
                            valorTotalLinhaController.clear();
                          },
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              TextField(
                controller: controller,
                decoration: const InputDecoration(labelText: 'Item (ou novo servico)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: valorUnitarioController,
                inputFormatters: [CurrencyPtBrInputFormatter()],
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Valor unitario (R\$) — opcional',
                  hintText: 'Ex.: 120,50',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: valorTotalLinhaController,
                inputFormatters: [CurrencyPtBrInputFormatter()],
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Valor total da linha (R\$) — opcional',
                  hintText: 'Vazio: quantidade x unitario',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: quantidadeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantidade',
                  hintText: 'Ex.: 3',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final nome = controller.text.trim();
                if (nome.isEmpty) return;
                final valorUnit = valorUnitarioController.text.trim();
                final valorTotLinha = valorTotalLinhaController.text.trim();
                final valorCents =
                    valorUnit.isEmpty ? null : _parseReaisParaCents(valorUnit);
                final valorTotalLinhaCents =
                    valorTotLinha.isEmpty ? null : _parseReaisParaCents(valorTotLinha);
                if (valorUnit.isNotEmpty && valorCents == null) {
                  _msg(context, 'Valor unitario invalido.');
                  return;
                }
                if (valorTotLinha.isNotEmpty && valorTotalLinhaCents == null) {
                  _msg(context, 'Valor total da linha invalido.');
                  return;
                }
                final quantidade =
                    int.tryParse(quantidadeController.text.trim()) ?? 1;
                final itens = [
                  ...tarefa.itens,
                  ItemServico(
                    nome: nome,
                    valorCents: valorCents,
                    valorTotalLinhaCents: valorTotalLinhaCents,
                    quantidade: quantidade < 1 ? 1 : quantidade,
                  ),
                ];
                await ref
                    .read(tasksProvider.notifier)
                    .updateById(
                      tarefa.id,
                      tarefa.copyWith(
                        itens: itens,
                        status: _recalcularStatus(tarefa.status, itens),
                        valorTotalCents: _totalAutomaticoCents(itens),
                      ),
                    );
                if (!nomesExistentes.contains(nome.toLowerCase()) &&
                    valorCents != null &&
                    valorCents > 0) {
                  if (!dialogCtx.mounted) return;
                  final adicionar = await _confirmarAdicionarAoBanco(
                    dialogCtx,
                    nome,
                    valorCents,
                  );
                  if (adicionar == true) {
                    await ref.read(serviceCatalogProvider.notifier).add(
                      nome: nome,
                      valorCents: valorCents,
                    );
                  }
                }
                if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    valorUnitarioController.dispose();
    valorTotalLinhaController.dispose();
    quantidadeController.dispose();
  }

  Future<void> _editarItem(
    BuildContext context,
    WidgetRef ref,
    TarefaItem tarefa,
    int idx,
  ) async {
    final controller = TextEditingController(text: tarefa.itens[idx].nome);
    final valorUnitarioController = TextEditingController(
      text: _centsParaInput(tarefa.itens[idx].valorCents),
    );
    final valorTotalLinhaController = TextEditingController(
      text: _centsParaInput(tarefa.itens[idx].valorTotalLinhaCents),
    );
    final quantidadeController = TextEditingController(
      text: tarefa.itens[idx].quantidadeNormalizada.toString(),
    );
    final servicos = ref
        .read(serviceCatalogProvider)
        .where((s) => !s.pendingDelete)
        .toList();
    String? servicoSelecionadoId;
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (_, setDialog) => AlertDialog(
          title: const Text('Editar item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (servicos.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Selecionar servico do banco',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 180,
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: ListView.builder(
                      itemCount: servicos.length,
                      itemBuilder: (_, i) {
                        final s = servicos[i];
                        final selected = servicoSelecionadoId == s.id;
                        return ListTile(
                          dense: true,
                          selected: selected,
                          title: Text(s.nome),
                          subtitle: Text(_formatarMoeda(s.valorCents)),
                          onTap: () {
                            setDialog(() => servicoSelecionadoId = s.id);
                            controller.text = s.nome;
                            valorUnitarioController.text =
                                _centsParaInput(s.valorCents);
                            valorTotalLinhaController.clear();
                          },
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              TextField(
                controller: controller,
                decoration: const InputDecoration(labelText: 'Item'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: valorUnitarioController,
                inputFormatters: [CurrencyPtBrInputFormatter()],
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Valor unitario (R\$) — opcional',
                  hintText: 'Ex.: 120,50',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: valorTotalLinhaController,
                inputFormatters: [CurrencyPtBrInputFormatter()],
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Valor total da linha (R\$) — opcional',
                  hintText: 'Vazio: quantidade x unitario',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: quantidadeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantidade'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final nome = controller.text.trim();
                if (nome.isEmpty) return;
                final valorUnit = valorUnitarioController.text.trim();
                final valorTotLinha = valorTotalLinhaController.text.trim();
                final valorCents =
                    valorUnit.isEmpty ? null : _parseReaisParaCents(valorUnit);
                final valorTotalLinhaCents =
                    valorTotLinha.isEmpty ? null : _parseReaisParaCents(valorTotLinha);
                if (valorUnit.isNotEmpty && valorCents == null) {
                  _msg(context, 'Valor unitario invalido.');
                  return;
                }
                if (valorTotLinha.isNotEmpty && valorTotalLinhaCents == null) {
                  _msg(context, 'Valor total da linha invalido.');
                  return;
                }
                final quantidade =
                    int.tryParse(quantidadeController.text.trim()) ?? 1;
                final itens = <ItemServico>[
                  for (var i = 0; i < tarefa.itens.length; i++)
                    if (i == idx)
                      ItemServico(
                        nome: nome,
                        concluido: tarefa.itens[i].concluido,
                        valorCents: valorCents,
                        valorTotalLinhaCents: valorTotalLinhaCents,
                        quantidade: quantidade < 1 ? 1 : quantidade,
                      )
                    else
                      tarefa.itens[i],
                ];
                await ref
                    .read(tasksProvider.notifier)
                    .updateById(
                      tarefa.id,
                      tarefa.copyWith(
                        itens: itens,
                        status: _recalcularStatus(tarefa.status, itens),
                        valorTotalCents: _totalAutomaticoCents(itens),
                      ),
                    );
                if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    valorUnitarioController.dispose();
    valorTotalLinhaController.dispose();
    quantidadeController.dispose();
  }

  Future<void> _excluirItem(
    BuildContext context,
    WidgetRef ref,
    TarefaItem tarefa,
    int idx,
  ) async {
    final itens = <ItemServico>[
      for (var i = 0; i < tarefa.itens.length; i++)
        if (i != idx) tarefa.itens[i],
    ];
    await ref
        .read(tasksProvider.notifier)
        .updateById(
          tarefa.id,
          tarefa.copyWith(
            itens: itens,
            status: _recalcularStatus(tarefa.status, itens),
            valorTotalCents: _totalAutomaticoCents(itens),
          ),
        );
  }

  Future<void> _marcarItem(
    BuildContext context,
    WidgetRef ref,
    TarefaItem tarefa,
    int idx,
    bool concluido,
  ) async {
    final itens = <ItemServico>[
      for (var i = 0; i < tarefa.itens.length; i++)
        if (i == idx)
          tarefa.itens[i].copyWith(concluido: concluido)
        else
          tarefa.itens[i],
    ];
    await ref
        .read(tasksProvider.notifier)
        .updateById(
          tarefa.id,
          tarefa.copyWith(
            itens: itens,
            status: _recalcularStatus(tarefa.status, itens),
            valorTotalCents: _totalAutomaticoCents(itens),
          ),
        );
  }

  StatusTarefa _recalcularStatus(
    StatusTarefa statusAtual,
    List<ItemServico> itens,
  ) {
    if (statusAtual == StatusTarefa.orcamento ||
        statusAtual == StatusTarefa.aprovado) {
      return statusAtual;
    }
    if (itens.isEmpty) return StatusTarefa.iniciado;
    final concluidos = itens.where((e) => e.concluido).length;
    if (concluidos == 0) return StatusTarefa.iniciado;
    if (concluidos == itens.length) return StatusTarefa.finalizado;
    return StatusTarefa.emAndamento;
  }

  int _totalAutomaticoCents(List<ItemServico> itens) {
    return itens.fold<int>(0, (soma, item) => soma + (item.totalCents ?? 0));
  }

  int _valorTotalEfetivoCents(TarefaItem tarefa) {
    return tarefa.valorTotalCents ?? _totalAutomaticoCents(tarefa.itens);
  }

  Future<void> _editarValorTotal(
    BuildContext context,
    WidgetRef ref,
    TarefaItem tarefa,
  ) async {
    final valorController = TextEditingController(
      text: _centsParaInput(tarefa.valorTotalCents),
    );
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Editar valor total'),
        content: TextField(
          controller: valorController,
          inputFormatters: [CurrencyPtBrInputFormatter()],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Valor total (R\$)',
            hintText: 'Deixe vazio para usar a soma dos itens',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final texto = valorController.text.trim();
              final valorCents = texto.isEmpty
                  ? null
                  : _parseReaisParaCents(texto);
              if (texto.isNotEmpty && valorCents == null) {
                _msg(context, 'Valor invalido.');
                return;
              }
              await ref
                  .read(tasksProvider.notifier)
                  .updateById(
                    tarefa.id,
                    tarefa.copyWith(
                      valorTotalCents: valorCents,
                      limparValorTotal: valorCents == null,
                    ),
                  );
              if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    valorController.dispose();
  }

  Future<bool?> _confirmarAdicionarAoBanco(
    BuildContext context,
    String nome,
    int valorCents,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adicionar ao banco de servicos?'),
        content: Text(
          'Deseja adicionar "$nome" (${_formatarMoeda(valorCents)}) ao banco de servicos?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Nao'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sim'),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirBancoMateriais(
    BuildContext context,
    WidgetRef ref,
    TarefaItem tarefa,
  ) async {
    final sessao = ref.read(sessionProvider);
    if (sessao == null) return;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Banco de materiais'),
        content: SizedBox(
          width: 640,
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('material_catalog')
                .where('companyId', isEqualTo: sessao.companyId)
                .snapshots(),
            builder: (context, snapshot) {
              final docs = (snapshot.data?.docs ?? const [])
                  .map(
                    (doc) => (
                      id: doc.id,
                      material: MaterialTarefa.fromDynamic(doc.data()),
                    ),
                  )
                  .where((entry) => entry.material.nome.trim().isNotEmpty)
                  .toList()
                ..sort(
                  (a, b) => a.material.nome.toLowerCase().compareTo(
                    b.material.nome.toLowerCase(),
                  ),
                );

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () =>
                              _abrirDialogoCatalogoMaterial(context, ref),
                          icon: const Icon(Icons.add),
                          label: const Text('Novo material'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () =>
                              _adicionarMaterial(context, ref, tarefa, utilizado: false),
                          icon: const Icon(Icons.playlist_add),
                          label: const Text('Adicionar na tarefa'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (docs.isEmpty)
                    _surface(
                      margin: EdgeInsets.zero,
                      child: const ListTile(
                        title: Text('Nenhum material padrao cadastrado.'),
                      ),
                    ),
                  if (docs.isNotEmpty)
                    SizedBox(
                      height: 360,
                      child: ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (_, index) {
                          final entry = docs[index];
                          return _surface(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(entry.material.nome),
                              subtitle: _subtitleMaterialBancoSugestao(
                                context,
                                entry.material,
                              ),
                              trailing: Wrap(
                                spacing: 4,
                                children: [
                                  IconButton(
                                    tooltip: 'Previsto',
                                    onPressed: () => _usarMaterialDoBanco(
                                      ref,
                                      tarefa,
                                      entry.material,
                                      utilizado: false,
                                    ),
                                    icon: const Icon(Icons.arrow_downward_outlined),
                                  ),
                                  IconButton(
                                    tooltip: 'Utilizado',
                                    onPressed: () => _usarMaterialDoBanco(
                                      ref,
                                      tarefa,
                                      entry.material,
                                      utilizado: true,
                                    ),
                                    icon: const Icon(Icons.checklist_outlined),
                                  ),
                                  IconButton(
                                    tooltip: 'Editar',
                                    onPressed: () => _abrirDialogoCatalogoMaterial(
                                      context,
                                      ref,
                                      id: entry.id,
                                      material: entry.material,
                                    ),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
                                    tooltip: 'Apagar',
                                    onPressed: () => _excluirCatalogoMaterial(entry.id),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirDialogoCatalogoMaterial(
    BuildContext context,
    WidgetRef ref, {
    String? id,
    MaterialTarefa? material,
  }) async {
    final sessao = ref.read(sessionProvider);
    if (sessao == null) return;
    final nomeController = TextEditingController(text: material?.nome ?? '');
    final quantidadeController = TextEditingController(
      text: (material?.quantidadeNormalizada ?? 1).toString(),
    );
    final unidadeController = TextEditingController(
      text: material?.unidadeNormalizada ?? 'un',
    );
    final observacaoController = TextEditingController(
      text: material?.observacao ?? '',
    );
    final valorPadraoController = TextEditingController(
      text: _centsParaInput(material?.valorCents),
    );

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(id == null ? 'Novo material padrao' : 'Editar material padrao'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeController,
                decoration: const InputDecoration(labelText: 'Material'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: valorPadraoController,
                inputFormatters: [CurrencyPtBrInputFormatter()],
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Valor unitario padrao (R\$) — opcional',
                  hintText: 'Ex.: 12,50',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: quantidadeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantidade padrao'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: unidadeController,
                decoration: const InputDecoration(labelText: 'Unidade'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: observacaoController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Observacao'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final nome = nomeController.text.trim();
              if (nome.isEmpty) return;
              final quantidade =
                  int.tryParse(quantidadeController.text.trim()) ?? 1;
              final valorPadraoTexto = valorPadraoController.text.trim();
              final valorPadraoCents = valorPadraoTexto.isEmpty
                  ? null
                  : _parseReaisParaCents(valorPadraoTexto);
              if (valorPadraoTexto.isNotEmpty && valorPadraoCents == null) {
                _msg(context, 'Valor padrao invalido.');
                return;
              }
              final docId =
                  id ?? DateTime.now().microsecondsSinceEpoch.toString();
              await FirebaseFirestore.instance
                  .collection('material_catalog')
                  .doc(docId)
                  .set({
                    'companyId': sessao.companyId,
                    'nome': nome,
                    'quantidade': quantidade < 1 ? 1 : quantidade,
                    'unidade': unidadeController.text.trim().isEmpty
                        ? 'un'
                        : unidadeController.text.trim(),
                    'observacao': observacaoController.text.trim(),
                    'valorCents': valorPadraoCents,
                    'updatedAt': FieldValue.serverTimestamp(),
                    if (id == null) 'createdAt': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));
              if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    nomeController.dispose();
    quantidadeController.dispose();
    unidadeController.dispose();
    observacaoController.dispose();
    valorPadraoController.dispose();
  }

  Future<void> _excluirCatalogoMaterial(String id) async {
    await FirebaseFirestore.instance.collection('material_catalog').doc(id).delete();
  }

  Future<void> _usarMaterialDoBanco(
    WidgetRef ref,
    TarefaItem tarefa,
    MaterialTarefa material, {
    required bool utilizado,
  }) async {
    final necessarios = [...tarefa.materiaisNecessarios];
    final utilizados = [...tarefa.materiaisUtilizados];
    if (utilizado) {
      utilizados.add(material);
    } else {
      necessarios.add(material);
    }
    await ref
        .read(tasksProvider.notifier)
        .updateById(
          tarefa.id,
          tarefa.copyWith(
            materiaisNecessarios: necessarios,
            materiaisUtilizados: utilizados,
          ),
        );
  }

  Future<void> _adicionarMaterial(
    BuildContext context,
    WidgetRef ref,
    TarefaItem tarefa, {
    required bool utilizado,
  }) async {
    final controller = TextEditingController();
    final quantidadeController = TextEditingController(text: '1');
    final unidadeController = TextEditingController(text: 'un');
    final observacaoController = TextEditingController();
    final valorUnitarioController = TextEditingController();
    final valorTotalController = TextEditingController();
    final sessao = ref.read(sessionProvider);
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(
          utilizado
              ? 'Adicionar material utilizado'
              : 'Adicionar material previsto',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (sessao != null)
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('material_catalog')
                      .where('companyId', isEqualTo: sessao.companyId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final materiais = (snapshot.data?.docs ?? const [])
                        .map((doc) => MaterialTarefa.fromDynamic(doc.data()))
                        .where((item) => item.nome.trim().isNotEmpty)
                        .toList()
                      ..sort(
                        (a, b) => a.nome.toLowerCase().compareTo(
                          b.nome.toLowerCase(),
                        ),
                      );
                    if (materiais.isEmpty) return const SizedBox.shrink();
                    return Column(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Sugestoes do banco',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 130,
                          child: ListView.builder(
                            itemCount: materiais.length,
                            itemBuilder: (_, index) {
                              final material = materiais[index];
                              return ListTile(
                                dense: true,
                                title: Text(material.nome),
                                subtitle: _subtitleMaterialBancoSugestao(context, material),
                                onTap: () {
                                  controller.text = material.nome;
                                  quantidadeController.text = material
                                      .quantidadeNormalizada
                                      .toString();
                                  unidadeController.text = material
                                      .unidadeNormalizada;
                                  observacaoController.text =
                                      material.observacao;
                                  valorUnitarioController.text =
                                      _centsParaInput(material.valorCents);
                                  valorTotalController.text =
                                      _centsParaInput(material.valorTotalLinhaCents);
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    );
                  },
                ),
              TextField(
                controller: controller,
                decoration: const InputDecoration(labelText: 'Material'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: valorUnitarioController,
                inputFormatters: [CurrencyPtBrInputFormatter()],
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Valor unitario (R\$) — opcional',
                  hintText: 'Ex.: 10,00',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: valorTotalController,
                inputFormatters: [CurrencyPtBrInputFormatter()],
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Valor total da linha (R\$) — opcional',
                  hintText: 'Vazio: quantidade x unitario',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: quantidadeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantidade'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: unidadeController,
                decoration: const InputDecoration(labelText: 'Unidade'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: observacaoController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Observacao'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final materialNome = controller.text.trim();
              if (materialNome.isEmpty) return;
              final quantidade =
                  int.tryParse(quantidadeController.text.trim()) ?? 1;
              final tu = valorUnitarioController.text.trim();
              final tt = valorTotalController.text.trim();
              final vc = tu.isEmpty ? null : _parseReaisParaCents(tu);
              final vt = tt.isEmpty ? null : _parseReaisParaCents(tt);
              if (tu.isNotEmpty && vc == null) {
                _msg(context, 'Valor unitario invalido.');
                return;
              }
              if (tt.isNotEmpty && vt == null) {
                _msg(context, 'Valor total da linha invalido.');
                return;
              }
              final item = MaterialTarefa(
                nome: materialNome,
                quantidade: quantidade < 1 ? 1 : quantidade,
                unidade: unidadeController.text.trim(),
                observacao: observacaoController.text.trim(),
                valorCents: vc,
                valorTotalLinhaCents: vt,
              );
              final necessarios = [...tarefa.materiaisNecessarios];
              final utilizados = [...tarefa.materiaisUtilizados];
              if (utilizado) {
                utilizados.add(item);
              } else {
                necessarios.add(item);
              }
              await ref
                  .read(tasksProvider.notifier)
                  .updateById(
                    tarefa.id,
                    tarefa.copyWith(
                      materiaisNecessarios: necessarios,
                      materiaisUtilizados: utilizados,
                    ),
                  );
              if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    controller.dispose();
    quantidadeController.dispose();
    unidadeController.dispose();
    observacaoController.dispose();
    valorUnitarioController.dispose();
    valorTotalController.dispose();
  }

  Future<void> _editarMaterial(
    BuildContext context,
    WidgetRef ref,
    TarefaItem tarefa,
    int idx, {
    required bool utilizado,
  }) async {
    final listaOrigem = utilizado
        ? tarefa.materiaisUtilizados
        : tarefa.materiaisNecessarios;
    final atual = listaOrigem[idx];
    final controller = TextEditingController(text: atual.nome);
    final quantidadeController = TextEditingController(
      text: atual.quantidadeNormalizada.toString(),
    );
    final unidadeController = TextEditingController(
      text: atual.unidadeNormalizada,
    );
    final observacaoController = TextEditingController(
      text: atual.observacao,
    );
    final valorUnitarioController = TextEditingController(
      text: _centsParaInput(atual.valorCents),
    );
    final valorTotalController = TextEditingController(
      text: _centsParaInput(atual.valorTotalLinhaCents),
    );
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(
          utilizado
              ? 'Editar material utilizado'
              : 'Editar material previsto',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(labelText: 'Material'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: valorUnitarioController,
                inputFormatters: [CurrencyPtBrInputFormatter()],
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Valor unitario (R\$) — opcional',
                  hintText: 'Ex.: 10,00',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: valorTotalController,
                inputFormatters: [CurrencyPtBrInputFormatter()],
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Valor total da linha (R\$) — opcional',
                  hintText: 'Vazio: quantidade x unitario',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: quantidadeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantidade'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: unidadeController,
                decoration: const InputDecoration(labelText: 'Unidade'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: observacaoController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Observacao'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final materialNome = controller.text.trim();
              if (materialNome.isEmpty) return;
              final quantidade =
                  int.tryParse(quantidadeController.text.trim()) ?? 1;
              final tu = valorUnitarioController.text.trim();
              final tt = valorTotalController.text.trim();
              final vc = tu.isEmpty ? null : _parseReaisParaCents(tu);
              final vt = tt.isEmpty ? null : _parseReaisParaCents(tt);
              if (tu.isNotEmpty && vc == null) {
                _msg(context, 'Valor unitario invalido.');
                return;
              }
              if (tt.isNotEmpty && vt == null) {
                _msg(context, 'Valor total da linha invalido.');
                return;
              }
              final atualizado = MaterialTarefa(
                nome: materialNome,
                quantidade: quantidade < 1 ? 1 : quantidade,
                unidade: unidadeController.text.trim(),
                observacao: observacaoController.text.trim(),
                valorCents: vc,
                valorTotalLinhaCents: vt,
              );
              final necessarios = [...tarefa.materiaisNecessarios];
              final utilizados = [...tarefa.materiaisUtilizados];
              if (utilizado) {
                utilizados[idx] = atualizado;
              } else {
                necessarios[idx] = atualizado;
              }
              await ref
                  .read(tasksProvider.notifier)
                  .updateById(
                    tarefa.id,
                    tarefa.copyWith(
                      materiaisNecessarios: necessarios,
                      materiaisUtilizados: utilizados,
                    ),
                  );
              if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    controller.dispose();
    quantidadeController.dispose();
    unidadeController.dispose();
    observacaoController.dispose();
    valorUnitarioController.dispose();
    valorTotalController.dispose();
  }

  Future<void> _copiarPrevistosParaUtilizados(
    BuildContext context,
    WidgetRef ref,
    TarefaItem tarefa,
  ) async {
    final previstos = tarefa.materiaisNecessarios;
    if (previstos.isEmpty) return;

    final selected = List<bool>.filled(previstos.length, false);

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Materiais utilizados a partir do previsto'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Marque os itens do previsto que foram utilizados no servico. '
                    'Eles serao copiados para Materiais utilizados (pode editar valores depois).',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < previstos.length; i++)
                    CheckboxListTile(
                      dense: true,
                      value: selected[i],
                      onChanged: (v) {
                        setDialog(() => selected[i] = v ?? false);
                      },
                      title: Text(previstos[i].nome),
                      subtitle: _subtitleMaterialBancoSugestao(context, previstos[i]),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: const Text('Copiar selecionados'),
            ),
          ],
        ),
      ),
    );

    if (ok != true || !context.mounted) return;

    final copias = <MaterialTarefa>[];
    for (var i = 0; i < previstos.length; i++) {
      if (!selected[i]) continue;
      final m = previstos[i];
      copias.add(
        MaterialTarefa(
          nome: m.nome,
          quantidade: m.quantidadeNormalizada,
          unidade: m.unidadeNormalizada,
          observacao: m.observacao,
          valorCents: m.valorCents,
          valorTotalLinhaCents: m.valorTotalLinhaCents,
        ),
      );
    }
    if (copias.isEmpty) {
      _msg(context, 'Nenhum material selecionado.');
      return;
    }

    await ref
        .read(tasksProvider.notifier)
        .updateById(
          tarefa.id,
          tarefa.copyWith(
            materiaisUtilizados: [...tarefa.materiaisUtilizados, ...copias],
          ),
        );
    if (context.mounted) {
      _msg(context, '${copias.length} material(is) copiado(s) para utilizados.');
    }
  }

  Future<void> _excluirMaterial(
    WidgetRef ref,
    TarefaItem tarefa,
    int idx, {
    required bool utilizado,
  }) async {
    final necessarios = [...tarefa.materiaisNecessarios];
    final utilizados = [...tarefa.materiaisUtilizados];
    if (utilizado) {
      utilizados.removeAt(idx);
    } else {
      necessarios.removeAt(idx);
    }
    await ref
        .read(tasksProvider.notifier)
        .updateById(
          tarefa.id,
          tarefa.copyWith(
            materiaisNecessarios: necessarios,
            materiaisUtilizados: utilizados,
          ),
        );
  }

  Widget _subtitleMaterialBancoSugestao(BuildContext context, MaterialTarefa m) {
    final obs = m.observacao.trim();
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _taskMaterialLinhaPrecos(m),
          style: tema.textTheme.bodySmall,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (obs.isNotEmpty)
          Text(
            obs,
            style: tema.textTheme.bodySmall?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}
