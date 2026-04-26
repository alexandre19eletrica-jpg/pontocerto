import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/errors/app_error_mapper.dart';
import 'package:pontocerto/core/navigation/app_shell.dart';
import 'package:pontocerto/core/navigation/shell_page_chrome.dart';
import 'package:pontocerto/core/theme/app_branding.dart';
import 'package:pontocerto/core/theme/app_layout.dart';
import 'package:pontocerto/features/accountant_links/domain/accountant_link.dart';
import 'package:pontocerto/features/accountant_links/presentation/accountant_links_provider.dart';
import 'package:pontocerto/features/company/presentation/services/company_billing_service.dart';
import 'package:pontocerto/features/employees/domain/employee.dart';
import 'package:pontocerto/features/employees/presentation/pages/employee_review_page.dart';
import 'package:pontocerto/features/employees/presentation/employees_provider.dart';
import 'package:pontocerto/core/ui/app_user_message.dart';

class EmployeesPage extends ConsumerWidget {
  const EmployeesPage({super.key});

  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );
  static final CompanyBillingService _companyBillingService = CompanyBillingService();

  Widget _surface({
    required Widget child,
    EdgeInsetsGeometry margin = EdgeInsets.zero,
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
    if (sessao == null) {
      return const Scaffold(body: Center(child: Text('Sem sessao ativa.')));
    }
    final lista = ref.watch(employeesProvider);
    final accountantLinks =
        ref.watch(accountantLinksProvider).valueOrNull ?? const [];
    final operational = lista.where((e) => e.isOperationalTeam).toList();
    final accountants = lista.where((e) => e.isAccountant).toList();
    final ativos = operational.where((e) => e.ativo).length;
    final activeAccountants = accountants.where((e) => e.ativo).length;

    ref.read(shellPageChromeProvider.notifier).state = ShellPageChrome(
      header: AppWorkspaceHeader(
        title: 'Funcionarios e acessos',
        subtitle:
            'Tela de consulta da equipe. O cadastro operacional de funcionario fica no modulo Trabalhista.',
        chips: [
          AppHeaderChip('Total ${lista.length}'),
          AppHeaderChip('Ativos $ativos'),
          AppHeaderChip('Contadores $activeAccountants'),
          AppHeaderChip(
            operational.length == ativos
                ? 'Sem inativos'
                : 'Inativos ${operational.length - ativos}',
          ),
        ],
      ),
    );
    return AppGradientBackground(
      child: AppPageLayout(
        child: ListView(
          children: [
            AppWorkspaceCard(
              title: 'Resumo da equipe',
              child: AppHorizontalCardGrid(
                minItemWidth: 220,
                maxColumns: 4,
                children: [
                  _summaryTile(
                    icon: Icons.groups_rounded,
                    label: 'Equipe',
                    value: operational.length.toString(),
                  ),
                  _summaryTile(
                    icon: Icons.verified_user_outlined,
                    label: 'Equipe ativa',
                    value: ativos.toString(),
                  ),
                  _summaryTile(
                    icon: Icons.calculate_outlined,
                    label: 'Contadores',
                    value: accountants.length.toString(),
                  ),
                  _summaryTile(
                    icon: Icons.pause_circle_outline,
                    label: 'Equipe inativa',
                    value: (operational.length - ativos).toString(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (sessao.role == Role.owner || sessao.role == Role.manager)
              _EmployeeBaseSnapshotCard(
                streamTotal: lista.length,
                streamOperational: operational.length,
                streamAccountants: accountants.length,
              ),
            const SizedBox(height: 12),
            if (sessao.role == Role.owner)
              AppWorkspaceCard(
                title: 'Plano e acessos do app',
                subtitle:
                    'A assinatura renova automaticamente todo mes ate cancelamento. Use esta area para ampliar os acessos do app Play Store da equipe.',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _openAdditionalAccessDialog(
                        context,
                        ref,
                        currentAccesses: operational.length,
                      ),
                      icon: const Icon(Icons.shop_two_outlined),
                      label: const Text(
                        'Contratar acesso app Play Store para funcionario',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _cancelPlan(context),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Cancelar plano'),
                    ),
                  ],
                ),
              ),
            if (sessao.role == Role.owner) const SizedBox(height: 12),
            AppWorkspaceCard(
              title: 'Funcionarios da operacao',
              subtitle:
                  'Pessoas que trabalham no dia a dia da empresa. Cadastros e alteracoes operacionais seguem pelo Trabalhista.',
              child: operational.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text('Nenhum colaborador operacional cadastrado.'),
                      ),
                    )
                  : AppHorizontalCardGrid(
                      minItemWidth: 280,
                      maxColumns: 3,
                      children: [
                        for (final item in operational)
                          _employeeListTile(context, item),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            AppWorkspaceCard(
              title: 'Contadores vinculados',
              subtitle: 'Contadores que podem cuidar da parte fiscal desta empresa.',
              trailing: TextButton.icon(
                onPressed: () async {
                  try {
                    await ref.read(employeesProvider.notifier).rebuildAccountantLinks();
                    if (!context.mounted) return;
                    _ok(context, 'Vinculos contabeis regularizados.');
                  } catch (_) {
                    if (!context.mounted) return;
                    _ok(context, 'Nao foi possivel regularizar os vinculos.');
                  }
                },
                icon: const Icon(Icons.sync_outlined),
                label: const Text('Regularizar vinculos'),
              ),
              child: accountants.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text('Nenhum contador vinculado.'),
                      ),
                    )
                  : Column(
                      children: [
                        if (accountantLinks.isNotEmpty) ...[
                          _accountantLinksPanel(accountantLinks),
                          const SizedBox(height: 12),
                        ],
                        AppHorizontalCardGrid(
                          minItemWidth: 280,
                          maxColumns: 3,
                          children: [
                            for (final item in accountants)
                              _employeeListTile(context, item),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAdditionalAccessDialog(
    BuildContext context,
    WidgetRef ref, {
    required int currentAccesses,
  }) async {
    final controller = TextEditingController(
      text: currentAccesses <= 0 ? '1' : currentAccesses.toString(),
    );
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Contratar acesso app Play Store'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Total de acessos contratados',
              helperText: 'Informe o total desejado para a equipe.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Fechar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Atualizar'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      final contractedAppUsers = int.tryParse(controller.text.trim());
      if (contractedAppUsers == null || contractedAppUsers <= 0) {
        throw Exception('Informe um total valido de acessos.');
      }
      final result = await _companyBillingService.updateAdditionalAppAccess(
        contractedAppUsers: contractedAppUsers,
      );
      if (!context.mounted) return;
      ref.invalidate(employeesProvider);
      _ok(
        context,
        'Acessos atualizados para ${result.contractedAppUsers}. Novo total ${_formatMoney(result.monthlyPriceCents)}.',
      );
    } catch (error) {
      if (!context.mounted) return;
      _ok(context, AppErrorMapper.messageFrom(error));
    } finally {
      controller.dispose();
    }
  }

  Future<void> _cancelPlan(BuildContext context) async {
    final reasonController = TextEditingController(
      text: 'Cancelamento solicitado pela empresa.',
    );
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cancelar plano'),
          content: TextField(
            controller: reasonController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Motivo interno',
              helperText:
                  'A renovacao automatica sera encerrada e o acesso fica ativo ate o fim do ciclo vigente.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Voltar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Cancelar plano'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      final result = await _companyBillingService.cancelSubscription(
        reason: reasonController.text.trim(),
      );
      if (!context.mounted) return;
      _ok(
        context,
        'Plano cancelado. Acesso mantido ate ${result.accessUntil.split('T').first}.',
      );
    } catch (error) {
      if (!context.mounted) return;
      _ok(context, AppErrorMapper.messageFrom(error));
    } finally {
      reasonController.dispose();
    }
  }

  Widget _accountantLinksPanel(List<AccountantLink> accountantLinks) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppBrandColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vinculos formais da empresa',
            style: TextStyle(
              color: AppBrandColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          for (final link in accountantLinks) ...[
            Text(
              '${link.accountantName} | ${link.accountantEmail.isEmpty ? 'email nao informado' : link.accountantEmail} | ${link.isActive ? 'ativo' : 'inativo'}',
              style: const TextStyle(color: AppBrandColors.softText),
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }

  Widget _summaryTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD8E6FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF4FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppBrandColors.primaryDeep),
          ),
          const SizedBox(height: 14),
          Text(
            label,
            style: const TextStyle(color: AppBrandColors.softText),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _employeeListTile(
    BuildContext context,
    Employee item,
  ) {
    final apelido = item.apelido == null ? '' : ' (${item.apelido})';
    return _surface(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => EmployeeReviewPage(employee: item),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _employeeAvatar(item),
              const SizedBox(height: 14),
              Text(
                '${item.nomeCompleto}$apelido',
                style: const TextStyle(
                  color: AppBrandColors.ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _rotuloRole(item.role),
                style: const TextStyle(
                  color: AppBrandColors.softText,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.ativo ? 'Acesso ativo' : 'Acesso inativo',
                style: TextStyle(
                  color: item.ativo
                      ? const Color(0xFF0F766E)
                      : AppBrandColors.softText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppBrandColors.border),
                    ),
                    child: const Text(
                      'Consulta',
                      style: TextStyle(
                        color: AppBrandColors.softText,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _rotuloRole(EmployeeRole role) {
    return switch (role) {
      EmployeeRole.manager => 'Gerente',
      EmployeeRole.accountant => 'Contador',
      EmployeeRole.employee => 'Funcionario',
    };
  }

  CircleAvatar _employeeAvatar(Employee item) {
    final hasPhoto = item.fotoUrl != null && item.fotoUrl!.isNotEmpty;
    return CircleAvatar(
      backgroundColor: item.ativo
          ? const Color(0xFFDDEBFF)
          : const Color(0xFFE9EDF3),
      backgroundImage: hasPhoto ? NetworkImage(item.fotoUrl!) : null,
      child: hasPhoto
          ? null
          : Icon(
              item.role == EmployeeRole.manager
                  ? Icons.workspace_premium_rounded
                  : item.role == EmployeeRole.accountant
                  ? Icons.calculate_outlined
                  : Icons.badge_rounded,
              color: const Color(0xFF113A6B),
            ),
    );
  }

  void _ok(BuildContext context, String msg) {
    if (!context.mounted) return;
    context.showUserMessage(msg);
  }

  String _formatMoney(int cents) {
    final reais = cents ~/ 100;
    final centavos = (cents % 100).toString().padLeft(2, '0');
    return 'R\$ $reais,$centavos';
  }

}

class _EmployeeBaseSnapshotCard extends StatefulWidget {
  const _EmployeeBaseSnapshotCard({
    required this.streamTotal,
    required this.streamOperational,
    required this.streamAccountants,
  });

  final int streamTotal;
  final int streamOperational;
  final int streamAccountants;

  @override
  State<_EmployeeBaseSnapshotCard> createState() =>
      _EmployeeBaseSnapshotCardState();
}

class _EmployeeBaseSnapshotCardState extends State<_EmployeeBaseSnapshotCard> {
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _snapshot;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await EmployeesPage._functions
          .httpsCallable('employeesGetBaseSnapshot')
          .call();
      final data = (result.data as Map?)?.cast<String, dynamic>();
      if (!mounted) return;
      setState(() {
        _snapshot = data;
        _loading = false;
      });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AppErrorMapper.messageFrom(
          e,
          fallback: 'Nao foi possivel conferir a base real da empresa.',
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Nao foi possivel conferir a base real da empresa.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _snapshot;
    final totalBase = (data?['totalUsers'] as num?)?.toInt();
    final operationalBase = (data?['operationalEmployees'] as num?)?.toInt();
    final accountantsBase = (data?['accountants'] as num?)?.toInt();
    final activeBase = (data?['activeUsers'] as num?)?.toInt();
    final sample = ((data?['sample'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
    final exportedAt = data?['exportedAtIso']?.toString() ?? '';

    final hasMismatch = totalBase != null &&
        (totalBase != widget.streamTotal ||
            (operationalBase != null &&
                operationalBase != widget.streamOperational) ||
            (accountantsBase != null &&
                accountantsBase != widget.streamAccountants));

    return AppWorkspaceCard(
      title: 'Conferencia direta da base',
      subtitle:
          'Confere os usuarios direto no Firestore da empresa para validar se a equipe realmente esta na base.',
      trailing: FilledButton.icon(
        onPressed: _loading ? null : _load,
        icon: Icon(_loading ? Icons.sync : Icons.verified_outlined),
        label: Text(_loading ? 'Conferindo...' : 'Conferir base'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statusChip('Tela ${widget.streamTotal}'),
              _statusChip('Operacao ${widget.streamOperational}'),
              _statusChip('Contadores ${widget.streamAccountants}'),
              if (totalBase != null) _statusChip('Base $totalBase'),
              if (activeBase != null) _statusChip('Ativos na base $activeBase'),
            ],
          ),
          if (data != null) ...[
            const SizedBox(height: 12),
            Text(
              hasMismatch
                  ? 'Atencao: a leitura atual da tela nao bate com a contagem direta da base.'
                  : 'A leitura atual da tela bate com a contagem direta da base.',
              style: TextStyle(
                color: hasMismatch
                    ? const Color(0xFF9A3412)
                    : AppBrandColors.softText,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (exportedAt.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Ultima conferencia: ${_formatIso(exportedAt)}',
                style: const TextStyle(color: AppBrandColors.softText),
              ),
            ],
            if (sample.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Amostra da base',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              for (final item in sample.take(6)) ...[
                Text(
                  '${item['nome'] ?? 'Sem nome'} | ${_roleLabel(item['role']?.toString() ?? '')} | ${item['ativo'] == false ? 'inativo' : 'ativo'}',
                  style: const TextStyle(color: AppBrandColors.softText),
                ),
                const SizedBox(height: 4),
              ],
            ],
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(
                color: Color(0xFFB91C1C),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppBrandColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppBrandColors.ink,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  static String _formatIso(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return value;
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  static String _roleLabel(String role) {
    switch (role.toUpperCase()) {
      case 'OWNER':
        return 'Owner';
      case 'MANAGER':
        return 'Gerente';
      case 'ACCOUNTANT':
        return 'Contador';
      default:
        return 'Funcionario';
    }
  }
}
