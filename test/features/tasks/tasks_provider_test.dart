import 'package:flutter_test/flutter_test.dart';
import 'package:pontocerto/features/tasks/domain/tarefa.dart';

void main() {
  test('serializa e desserializa tarefa com itens', () {
    final original = TarefaItem(
      id: 't1',
      autorId: 'u1',
      autorNome: 'Usuario Teste',
      nome: 'Servico teste',
      descricao: 'Descricao',
      clienteNome: 'Cliente XPTO',
      dataExecucao: DateTime(2026, 3, 5),
      itens: [
        ItemServico(nome: 'Item 1', concluido: true),
        ItemServico(nome: 'Item 2', concluido: false),
      ],
      anexos: [
        AnexoTarefa(
          id: 'a1',
          tipo: TipoAnexoTarefa.foto,
          url: 'https://example.com/foto.jpg',
          descricao: 'Foto frente',
          nomeArquivo: 'foto.jpg',
          criadoEm: DateTime(2026, 3, 5),
        ),
      ],
      status: StatusTarefa.emAndamento,
    );

    final map = original.toMap();
    final copia = TarefaItem.fromMap(map);

    expect(copia.id, 't1');
    expect(copia.autorId, 'u1');
    expect(copia.nome, 'Servico teste');
    expect(copia.descricao, 'Descricao');
    expect(copia.clienteNome, 'Cliente XPTO');
    expect(copia.dataExecucao, DateTime(2026, 3, 5));
    expect(copia.status, StatusTarefa.emAndamento);
    expect(copia.itens.length, 2);
    expect(copia.itens.first.concluido, true);
    expect(copia.anexos.length, 1);
    expect(copia.anexos.first.descricao, 'Foto frente');
  });
}
