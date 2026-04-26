import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/navigation/app_shell.dart';
import 'package:pontocerto/core/navigation/shell_page_chrome.dart';
import 'package:pontocerto/core/theme/app_branding.dart';
import 'package:pontocerto/core/theme/app_layout.dart';
import 'package:pontocerto/features/device_consent/presentation/device_consent_provider.dart';
import 'package:pontocerto/features/employees/presentation/employees_provider.dart';
import 'package:pontocerto/features/punch/domain/punch.dart';
import 'package:pontocerto/features/punch/presentation/punch_provider.dart';
import 'package:pontocerto/core/ui/app_user_message.dart';

class PunchPage extends ConsumerStatefulWidget {
  const PunchPage({super.key});

  @override
  ConsumerState<PunchPage> createState() => _PunchPageState();
}

class _PunchPageState extends ConsumerState<PunchPage> {
  String? _employeeSelecionadoId;
  final _obraOuClienteController = TextEditingController();

  Widget _surface({
    required Widget child,
    EdgeInsetsGeometry margin = const EdgeInsets.only(bottom: 10),
    Color? color,
  }) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? Colors.white,
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
  void dispose() {
    _obraOuClienteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessao = ref.watch(sessionProvider);
    if (sessao == null) {
      return const Scaffold(body: Center(child: Text('Sem sessao ativa')));
    }

    final isEmployee = sessao.role == Role.employee;
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? sessao.userId;
    final punches = ref.watch(punchProvider);
    final workedDaysAll = ref.watch(workedDaysProvider);

    if (isEmployee) {
      final employeeId = currentUid;
      final consent = ref
          .watch(deviceConsentsProvider)
          .where((c) => c.employeeId == employeeId && c.companyId == sessao.companyId)
          .firstOrNull;
      final consentAtivo = consent?.accepted == true;
      Punch? ultimo;
      for (final item in punches.reversed) {
        if (item.employeeId == employeeId) {
          ultimo = item;
          break;
        }
      }

      final workedDays = workedDaysAll.where((e) => e.employeeId == employeeId).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      final listaPontos = punches.where((e) => e.employeeId == employeeId).toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

      ref.read(shellPageChromeProvider.notifier).state = const ShellPageChrome(
        header: AppWorkspaceHeader(
          title: 'Ponto e jornada',
          subtitle:
              'Registro de entrada e saida com autorizacao do dispositivo, leitura por ciclos e historico individual.',
          chips: [
            AppHeaderChip('Uso do celular'),
            AppHeaderChip('Ciclos semanais e mensais'),
          ],
        ),
      );

      return AppPageLayout(
        child: ListView(
          children: [
            _surface(
              child: ListTile(
                leading: const Icon(Icons.summarize_outlined),
                title: const Text('Resumo'),
                subtitle: Text(
                  'Pontos: ${listaPontos.length} | Dias trabalhados: ${workedDays.length}',
                ),
              ),
            ),
            const SizedBox(height: 12),
            _surface(
              color: consentAtivo ? const Color(0xFFE6F7EC) : const Color(0xFFFFF4E5),
              child: ListTile(
                leading: Icon(
                  consentAtivo ? Icons.verified_user : Icons.warning_amber_rounded,
                  color: consentAtivo ? Colors.green : Colors.orange,
                ),
                title: Text(
                  consentAtivo
                      ? 'Autorizacao de uso do celular ativa'
                      : 'Autorizacao de uso do celular pendente',
                ),
                subtitle: Text(
                  consentAtivo
                      ? 'Aceita em ${_formatarDataHora(consent?.acceptedAt ?? DateTime.now())}'
                      : 'Para bater ponto no proprio celular, autorize o termo de uso.',
                ),
                trailing: TextButton(
                  onPressed: () async {
                    try {
                      if (consentAtivo) {
                        await ref.read(deviceConsentsProvider.notifier).revokeOwnDeviceUse();
                        _ok('Autorizacao revogada.');
                      } else {
                        final aceitou = await _confirmarAutorizacao(context);
                        if (aceitou != true) return;
                        await ref.read(deviceConsentsProvider.notifier).acceptOwnDeviceUse();
                        _ok('Autorizacao registrada com sucesso.');
                      }
                    } catch (e) {
                      _ok(_erroTexto(e, fallback: 'Erro ao atualizar autorizacao.'));
                    }
                  },
                  child: Text(consentAtivo ? 'Revogar' : 'Autorizar'),
                ),
                isThreeLine: true,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final obraOuCliente = _obraOuClienteController.text.trim();
                  if (obraOuCliente.isEmpty) {
                    _ok('Informe a obra ou cliente antes de bater o ponto.');
                    return;
                  }
                  try {
                    await ref.read(punchProvider.notifier).register(
                          employeeId: employeeId,
                          obraOuCliente: obraOuCliente,
                        );
                    _ok('Ponto registrado com sucesso.');
                  } catch (e) {
                    _ok(_erroTexto(e, fallback: 'Erro ao registrar ponto.'));
                  }
                },
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
                child: const Text('Registrar Ponto'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _obraOuClienteController,
              decoration: const InputDecoration(
                labelText: 'Obra ou cliente *',
                hintText: 'Ex.: Obra Centro / Cliente XPTO',
              ),
            ),
            const SizedBox(height: 12),
            _surface(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_textoUltimoRegistro(ultimo)),
              ),
            ),
            const SizedBox(height: 12),
            _sectionTitle('Dias trabalhados'),
            if (workedDays.isEmpty)
              _surface(
                child: const ListTile(title: Text('Nenhum dia trabalhado registrado.')),
              ),
            ...workedDays.map(
              (d) => _surface(
                child: ListTile(
                  title: Text('${_weekdayName(d.date)} - ${_formatarData(d.date)}'),
                  subtitle: Text(
                    '${d.period == WorkedDayPeriod.fullDay ? 'Dia todo' : 'Meio dia'} | '
                    '${d.hasEntry ? 'Entrada OK' : 'Sem entrada'} | '
                    '${d.hasExit ? 'Saida OK' : 'Saida automatica'}\n'
                    'Ciclo semanal: ${_formatarCicloSemanal(d.date)} | '
                    'Ciclo mensal: ${_formatarCicloMensal(d.date)}',
                  ),
                  isThreeLine: true,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _sectionTitle('Registros de ponto (ciclos)'),
            if (listaPontos.isEmpty)
              _surface(
                child: const ListTile(title: Text('Sem registro de ponto.')),
              ),
            ...listaPontos.map(
              (date) => _surface(
                child: ListTile(
                  title: Text(
                    '${date.tipo == PunchType.entrada ? 'Entrada' : 'Saida'} - ${_formatarDataHora(date.timestamp)}',
                  ),
                  subtitle: Text(
                    'Obra/Cliente: ${date.obraOuCliente.isEmpty ? '-' : date.obraOuCliente}\n'
                    'Ciclo semanal: ${_formatarCicloSemanal(date.timestamp)} | '
                    'Ciclo mensal: ${_formatarCicloMensal(date.timestamp)}',
                  ),
                  isThreeLine: true,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final employees = ref.watch(employeesProvider).where((e) => e.ativo).toList();
    if (employees.isEmpty) {
      ref.read(shellPageChromeProvider.notifier).state = const ShellPageChrome(
        header: AppWorkspaceHeader(
          title: 'Ponto da equipe',
          subtitle:
              'Controle de jornada por colaborador com marcacao administrativa, exclusoes e ajuste de dias trabalhados.',
        ),
      );
      return const Center(child: Text('Nenhum funcionario ativo para selecionar.'));
    }

    _employeeSelecionadoId ??= employees.first.id;
    if (!employees.any((e) => e.id == _employeeSelecionadoId)) {
      _employeeSelecionadoId = employees.first.id;
    }

    final employeeId = _employeeSelecionadoId!;
    final lista = punches.where((item) => item.employeeId == employeeId).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final workedDays = workedDaysAll.where((e) => e.employeeId == employeeId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    ref.read(shellPageChromeProvider.notifier).state = const ShellPageChrome(
      header: AppWorkspaceHeader(
        title: 'Ponto da equipe',
        subtitle:
            'Controle de jornada por colaborador com marcacao administrativa, exclusoes e ajuste de dias trabalhados.',
        chips: [
          AppHeaderChip('Supervisao da equipe'),
          AppHeaderChip('Edicao operacional'),
        ],
      ),
    );

    return AppPageLayout(
      child: ListView(
        children: [
          DropdownButtonFormField<String>(
            initialValue: _employeeSelecionadoId,
            decoration: const InputDecoration(labelText: 'Funcionario'),
            items: [
              for (final employee in employees)
                DropdownMenuItem(value: employee.id, child: Text(employee.nome)),
            ],
            onChanged: (valor) {
              if (valor != null) setState(() => _employeeSelecionadoId = valor);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _obraOuClienteController,
            decoration: const InputDecoration(
              labelText: 'Obra ou cliente para o proximo ponto *',
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final obraOuCliente = _obraOuClienteController.text.trim();
                if (obraOuCliente.isEmpty) {
                  _ok('Informe a obra ou cliente antes de marcar o ponto.');
                  return;
                }
                try {
                  await ref.read(punchProvider.notifier).register(
                        employeeId: employeeId,
                        obraOuCliente: obraOuCliente,
                      );
                  _ok('Ponto marcado com sucesso para o funcionario.');
                } catch (e) {
                  _ok(_erroTexto(e, fallback: 'Erro ao marcar ponto.'));
                }
              },
              icon: const Icon(Icons.fingerprint),
              label: const Text('Marcar ponto do funcionario'),
            ),
          ),
          const SizedBox(height: 12),
          _surface(
            child: ListTile(
              leading: const Icon(Icons.summarize_outlined),
              title: const Text('Resumo do funcionario'),
              subtitle: Text(
                'Pontos: ${lista.length} | Dias trabalhados: ${workedDays.length}',
              ),
            ),
          ),
          const SizedBox(height: 12),
          _sectionTitle('Registros de ponto'),
          if (lista.isEmpty)
            _surface(
              child: const ListTile(title: Text('Sem registros para este funcionario.')),
            ),
          ...lista.map(
            (item) => _surface(
              child: ListTile(
                title: Text(_textoTipo(item.tipo)),
                subtitle: Text(
                  '${_formatarDataHora(item.timestamp)}\nObra/Cliente: ${item.obraOuCliente.isEmpty ? '-' : item.obraOuCliente}',
                ),
                isThreeLine: true,
                onLongPress: () async {
                  try {
                    await ref.read(punchProvider.notifier).remove(item.id);
                    _ok('Registro removido com sucesso.');
                  } catch (_) {
                    _ok('Erro ao remover registro.');
                  }
                },
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Excluir ponto',
                  onPressed: () async {
                    try {
                      await ref.read(punchProvider.notifier).remove(item.id);
                      _ok('Registro removido com sucesso.');
                    } catch (_) {
                      _ok('Erro ao remover registro.');
                    }
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _sectionTitle('Dias trabalhados (edicao da empresa)'),
          if (workedDays.isEmpty)
            _surface(
              child: const ListTile(title: Text('Nenhum dia trabalhado registrado.')),
            ),
          ...workedDays.map(
            (d) => _surface(
              child: ListTile(
                title: Text('${_weekdayName(d.date)} - ${_formatarData(d.date)}'),
                subtitle: Text(d.autoClosed ? 'Saida fechada automaticamente' : 'Registro normal'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButton<WorkedDayPeriod>(
                      value: d.period,
                      items: const [
                        DropdownMenuItem(
                          value: WorkedDayPeriod.fullDay,
                          child: Text('Dia todo'),
                        ),
                        DropdownMenuItem(
                          value: WorkedDayPeriod.halfDay,
                          child: Text('Meio dia'),
                        ),
                      ],
                      onChanged: (valor) async {
                        if (valor == null) return;
                        try {
                          await ref.read(workedDaysProvider.notifier).setPeriod(d.id, valor);
                          _ok('Periodo atualizado com sucesso.');
                        } catch (_) {
                          _ok('Erro ao atualizar periodo.');
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Excluir dia',
                      onPressed: () async {
                        try {
                          await ref.read(workedDaysProvider.notifier).remove(d.id);
                          _ok('Dia trabalhado removido com sucesso.');
                        } catch (_) {
                          _ok('Erro ao remover dia trabalhado.');
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _textoUltimoRegistro(Punch? item) {
    if (item == null) return 'Ultimo registro: nenhum';
    return 'Ultimo registro: ${_textoTipo(item.tipo)} - ${_formatarDataHora(item.timestamp)}'
        '\nObra/Cliente: ${item.obraOuCliente.isEmpty ? '-' : item.obraOuCliente}';
  }

  String _textoTipo(PunchType tipo) => tipo == PunchType.entrada ? 'Entrada' : 'Saida';

  String _weekdayName(DateTime data) {
    const dias = <String>[
      'Segunda',
      'Terca',
      'Quarta',
      'Quinta',
      'Sexta',
      'Sabado',
      'Domingo',
    ];
    return dias[data.weekday - 1];
  }

  String _formatarData(DateTime data) {
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    return '$dia/$mes/${data.year}';
  }

  String _formatarDataHora(DateTime data) {
    final hora = data.hour.toString().padLeft(2, '0');
    final minuto = data.minute.toString().padLeft(2, '0');
    return '${_weekdayName(data)}, ${_formatarData(data)} $hora:$minuto';
  }

  String _formatarCicloSemanal(DateTime data) {
    final base = DateTime(data.year, data.month, data.day);
    final inicio = base.subtract(Duration(days: data.weekday - DateTime.monday));
    final fim = inicio.add(const Duration(days: 5)); // segunda a sabado
    return '${_formatarData(inicio)} a ${_formatarData(fim)}';
  }

  String _formatarCicloMensal(DateTime data) {
    final mes = data.month.toString().padLeft(2, '0');
    return '$mes/${data.year}';
  }

  Widget _sectionTitle(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(texto, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  void _ok(String msg) {
    if (!mounted) return;
    if (!context.mounted) return;
    context.showUserMessage(msg);
  }

  String _erroTexto(Object erro, {required String fallback}) {
    final texto = erro.toString().trim();
    if (texto.isEmpty) return fallback;
    if (texto.startsWith('Exception: ')) {
      final limpo = texto.substring('Exception: '.length).trim();
      return limpo.isEmpty ? fallback : limpo;
    }
    return texto;
  }

  Future<bool?> _confirmarAutorizacao(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Autorizar uso do celular'),
        content: const Text(
          'Declaro, de forma livre e informada, que autorizo o uso do meu celular pessoal '
          'como ferramenta de trabalho no app da empresa para registro de ponto e rotinas operacionais.\n\n'
          'Versao do termo: v2.0-2026-03-07',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Concordo'),
          ),
        ],
      ),
    );
  }
}

