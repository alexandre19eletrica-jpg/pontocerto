part of 'tasks_page.dart';

class TaskDetailsPage extends ConsumerWidget {
  const TaskDetailsPage({super.key, required this.taskId});

  final String taskId;

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
  Widget build(BuildContext context, WidgetRef ref) {
    final sessao = ref.watch(sessionProvider);
    final tarefa = ref
        .watch(tasksProvider)
        .where((e) => e.id == taskId)
        .firstOrNull;
    if (tarefa == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalhes da tarefa')),
        body: const Center(child: Text('Tarefa nao encontrada.')),
      );
    }
    final readOnlyAccountant = sessao?.role == Role.accountant;

    return Scaffold(
      appBar: AppBar(
        title: Text(tarefa.nome),
        actions: readOnlyAccountant
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editarTarefa(context, ref, tarefa),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _excluirTarefa(context, ref, tarefa.id),
                ),
              ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (readOnlyAccountant)
            _surface(
              child: const ListTile(
                title: Text('Consulta do contador'),
                subtitle: Text(
                  'Esta tarefa esta em modo somente leitura para conferencia operacional e apoio a emissao fiscal da empresa ativa.',
                ),
              ),
            ),
          _bloco(
            context,
            'Descricao',
            tarefa.descricao.isEmpty ? '-' : tarefa.descricao,
          ),
          _bloco(
            context,
            'Cliente',
            tarefa.clienteNome.isEmpty ? '-' : tarefa.clienteNome,
          ),
          _bloco(
            context,
            'Documento do cliente',
            tarefa.clienteDocumentoFormatado.isEmpty
                ? '-'
                : tarefa.clienteDocumentoFormatado,
          ),
          _bloco(
            context,
            'Data da execucao',
            _formatarData(tarefa.dataExecucao),
          ),
          _bloco(
            context,
            'Responsavel',
            tarefa.autorNome.isEmpty ? '-' : tarefa.autorNome,
          ),
          _bloco(
            context,
            'Status',
            _rotuloStatus(tarefa.status),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Itens do servico',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (!readOnlyAccountant)
                TextButton.icon(
                  onPressed: () => _adicionarItem(context, ref, tarefa),
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar'),
                ),
            ],
          ),
          if (tarefa.itens.isEmpty)
            _surface(child: _buildSimpleTaskInfoTile('Nenhum item cadastrado.')),
          ...tarefa.itens.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            return _surface(
              child: CheckboxListTile(
                value: item.concluido,
                title: Text(item.nome),
              subtitle: Text(
                _taskItemServicoSubtitle(item),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
                secondary: Wrap(
                  spacing: 4,
                  children: [
                    if (!readOnlyAccountant)
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _editarItem(context, ref, tarefa, idx),
                      ),
                    if (!readOnlyAccountant)
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _excluirItem(context, ref, tarefa, idx),
                      ),
                  ],
                ),
                onChanged: readOnlyAccountant
                    ? null
                    : (valor) =>
                        _marcarItem(context, ref, tarefa, idx, valor ?? false),
              ),
            );
          }),
          const SizedBox(height: 6),
          _surface(
            child: ListTile(
              title: const Text('Valor total'),
              subtitle: Text(_formatarMoeda(_valorTotalEfetivoCents(tarefa))),
              trailing: Wrap(
                spacing: 4,
                children: [
                  if (!readOnlyAccountant)
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _editarValorTotal(context, ref, tarefa),
                    ),
                  IconButton(
                    icon: const Icon(Icons.share_outlined),
                    tooltip: 'Compartilhar tarefa em PDF',
                    onPressed: () => _compartilharTarefaPdf(context, tarefa),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          _secaoMateriais(
            context: context,
            titulo: 'Materiais previstos',
            lista: tarefa.materiaisNecessarios,
            canManage: !readOnlyAccountant,
            onAdd: () => _adicionarMaterial(
              context,
              ref,
              tarefa,
              utilizado: false,
            ),
            onOpenCatalog: () => _abrirBancoMateriais(context, ref, tarefa),
            onEdit: (idx) => _editarMaterial(
              context,
              ref,
              tarefa,
              idx,
              utilizado: false,
            ),
            onDelete: (idx) => _excluirMaterial(
              ref,
              tarefa,
              idx,
              utilizado: false,
            ),
          ),
          const SizedBox(height: 10),
          _secaoMateriais(
            context: context,
            titulo: 'Materiais utilizados',
            lista: tarefa.materiaisUtilizados,
            canManage: !readOnlyAccountant,
            onAdd: () => _adicionarMaterial(
              context,
              ref,
              tarefa,
              utilizado: true,
            ),
            onOpenCatalog: () => _abrirBancoMateriais(context, ref, tarefa),
            onCopiarDosPrevistos: tarefa.materiaisNecessarios.isEmpty
                ? null
                : () => _copiarPrevistosParaUtilizados(context, ref, tarefa),
            onEdit: (idx) => _editarMaterial(
              context,
              ref,
              tarefa,
              idx,
              utilizado: true,
            ),
            onDelete: (idx) => _excluirMaterial(
              ref,
              tarefa,
              idx,
              utilizado: true,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Anexos',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (!readOnlyAccountant)
                TextButton.icon(
                  onPressed: () => _adicionarAnexo(context, ref, tarefa),
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Adicionar'),
                ),
            ],
          ),
          if (tarefa.anexos.isEmpty)
            _surface(
              child: _buildSimpleTaskInfoTile('Nenhum anexo cadastrado.'),
            ),
          ...tarefa.anexos.map(
            (a) => _surface(
              child: ListTile(
                leading: Icon(
                  a.tipo == TipoAnexoTarefa.foto ? Icons.photo : Icons.videocam,
                ),
                title: Text(_tituloAnexo(a)),
                subtitle: Text(_subtituloAnexo(a)),
                onTap: () => _abrirAnexo(context, a),
                trailing: readOnlyAccountant
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _excluirAnexo(context, ref, tarefa, a),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              _chipStatus(
                context,
                ref,
                tarefa,
                StatusTarefa.orcamento,
                'Orcamento',
                enabled: !readOnlyAccountant,
              ),
              _chipStatus(
                context,
                ref,
                tarefa,
                StatusTarefa.aprovado,
                'Aprovado',
                enabled: !readOnlyAccountant,
              ),
              _chipStatus(
                context,
                ref,
                tarefa,
                StatusTarefa.iniciado,
                'Iniciado',
                enabled: !readOnlyAccountant,
              ),
              _chipStatus(
                context,
                ref,
                tarefa,
                StatusTarefa.emAndamento,
                'Em andamento',
                enabled: !readOnlyAccountant,
              ),
              _chipStatus(
                context,
                ref,
                tarefa,
                StatusTarefa.finalizado,
                'Finalizado',
                enabled: !readOnlyAccountant,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (tarefa.status == StatusTarefa.finalizado)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _gerarPdf(context, tarefa),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Gerar PDF'),
              ),
            ),
        ],
      ),
    );
  }
}
