part of 'tasks_page.dart';

extension _TaskDetailsSections on TaskDetailsPage {
  Widget _bloco(BuildContext context, String titulo, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(valor),
        ],
      ),
    );
  }

  Widget _secaoMateriais({
    required BuildContext context,
    required String titulo,
    required List<MaterialTarefa> lista,
    required bool canManage,
    required VoidCallback onAdd,
    required VoidCallback onOpenCatalog,
    required void Function(int idx) onEdit,
    required void Function(int idx) onDelete,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                titulo,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (canManage)
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Adicionar'),
              ),
            if (canManage)
              TextButton.icon(
                onPressed: onOpenCatalog,
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Banco'),
              ),
          ],
        ),
        if (lista.isEmpty)
          _surface(
            child: _buildSimpleTaskInfoTile('Nenhum material cadastrado.'),
          ),
        ...lista.asMap().entries.map(
          (entry) => _surface(
            child: ListTile(
              title: Text(entry.value.nome),
              subtitle: Text(
                '${entry.value.quantidadeNormalizada} ${entry.value.unidadeNormalizada}'
                '${entry.value.observacao.trim().isEmpty ? '' : ' | ${entry.value.observacao.trim()}'}',
              ),
              trailing: Wrap(
                spacing: 4,
                children: [
                  if (canManage)
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => onEdit(entry.key),
                    ),
                  if (canManage)
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => onDelete(entry.key),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _chipStatus(
    BuildContext context,
    WidgetRef ref,
    TarefaItem tarefa,
    StatusTarefa novoStatus,
    String label,
    {required bool enabled}
  ) {
    return ChoiceChip(
      label: Text(label),
      selected: tarefa.status == novoStatus,
      onSelected: enabled
          ? (_) async {
        final exigeAprovacao =
            novoStatus == StatusTarefa.iniciado ||
            novoStatus == StatusTarefa.emAndamento ||
            novoStatus == StatusTarefa.finalizado;
        if (exigeAprovacao &&
            tarefa.status != StatusTarefa.aprovado &&
            tarefa.status != StatusTarefa.iniciado &&
            tarefa.status != StatusTarefa.emAndamento &&
            tarefa.status != StatusTarefa.finalizado) {
          _msg(
            context,
            'A tarefa precisa estar aprovada para iniciar o servico.',
          );
          return;
        }
        if (novoStatus == StatusTarefa.finalizado &&
            tarefa.itens.any((e) => !e.concluido)) {
          _msg(context, 'Marque todos os itens antes de finalizar.');
          return;
        }
        await ref
            .read(tasksProvider.notifier)
            .updateById(tarefa.id, tarefa.copyWith(status: novoStatus));
      }
          : null,
    );
  }

  Widget _buildSimpleTaskInfoTile(String message) {
    return ListTile(title: Text(message));
  }
}
