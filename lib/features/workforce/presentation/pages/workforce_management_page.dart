import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/media/mobile_upload_optimizer.dart';
import 'package:pontocerto/core/monitoring/runtime_incident_reporter.dart';
import 'package:pontocerto/core/navigation/app_shell.dart';
import 'package:pontocerto/core/navigation/shell_page_chrome.dart';
import 'package:pontocerto/core/pdf/pdf_output.dart';
import 'package:pontocerto/core/pdf/standard_document.dart';
import 'package:pontocerto/core/theme/app_branding.dart';
import 'package:pontocerto/core/theme/app_layout.dart';
import 'package:pontocerto/core/ui/app_user_message.dart';
import 'package:pontocerto/features/employees/domain/employee.dart';
import 'package:pontocerto/features/employees/presentation/employees_provider.dart';
import 'package:pontocerto/features/finance/presentation/services/finance_actions_service.dart';
import 'package:pontocerto/features/finance/presentation/services/finance_cleanup_service.dart';
import 'package:pontocerto/features/payments/domain/payment.dart';
import 'package:pontocerto/features/payments/presentation/payments_provider.dart';
import 'package:pontocerto/features/tasks/domain/tarefa.dart';
import 'package:pontocerto/features/tasks/presentation/tasks_provider.dart';
import 'package:pontocerto/features/work_entries/domain/work_entry.dart';
import 'package:pontocerto/features/work_entries/presentation/work_entries_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pontocerto/core/firebase/employee_access_service.dart';
part 'workforce_management_support.dart';
part 'workforce_management_payroll_sections.dart';
part 'workforce_management_workspace_sections.dart';
part 'workforce_management_operational_actions.dart';
part 'workforce_management_governance_actions.dart';


class WorkforceManagementPage extends ConsumerStatefulWidget {
  const WorkforceManagementPage({super.key});

  @override
  ConsumerState<WorkforceManagementPage> createState() =>
      _WorkforceManagementPageState();
}

class _WorkforceManagementPageState
    extends ConsumerState<WorkforceManagementPage> {
  final _actions = FinanceActionsService();
  final _cleanup = FinanceCleanupService();
  final _competenciaController = TextEditingController(
    text:
        '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}',
  );
  String? _employeeId;
  int _selectedAreaIndex = 0;
  bool _showOnlyPendingPayroll = false;
  String _approvalHistoryFilter = 'Todos';

  @override
  void dispose() {
    _competenciaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessao = ref.watch(sessionProvider);
    if (sessao == null) {
      return const Scaffold(body: Center(child: Text('Sem sessao ativa.')));
    }
    if (sessao.role == Role.employee) {
      ref.read(shellPageChromeProvider.notifier).state = const ShellPageChrome();
      return const Scaffold(
        body: Center(
          child: Text('Modulo disponivel apenas para empresa, gerencia ou contador.'),
        ),
      );
    }

    final employees = ref
        .watch(employeesProvider)
        .where((e) => e.ativo && e.isOperationalTeam)
        .toList()
          ..sort((a, b) => a.nomeCompleto.compareTo(b.nomeCompleto));
    final payments = ref.watch(paymentsProvider);
    final workEntries = ref.watch(workEntriesProvider);
    final tasks = ref.watch(tasksProvider);

    if (employees.isNotEmpty) {
      _employeeId ??= employees.first.id;
      if (!employees.any((e) => e.id == _employeeId)) {
        _employeeId = employees.first.id;
      }
    }

    final selectedEmployee = _findEmployee(employees, _employeeId);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(sessao.userId)
                .snapshots(),
            builder: (context, companyUserSnapshot) {
              final companyData =
                  (companyUserSnapshot.data?.data()?['companyData'] as Map?)
                      ?.cast<String, dynamic>() ??
                  <String, dynamic>{};

              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('company_settings')
                    .doc(sessao.companyId)
                    .snapshots(),
                builder: (context, settingsSnapshot) {
                  final companySettings =
                      settingsSnapshot.data?.data() ?? <String, dynamic>{};
                  ref.read(shellPageChromeProvider.notifier).state = ShellPageChrome(
                    header: AppWorkspaceHeader(
                      title: 'Trabalhista',
                      subtitle:
                          'Cuide da folha, contratos e documentos da equipe de forma simples e organizada.',
                    ),
                  );

                  return AppGradientBackground(
                    child: AppPageLayout(
                      child: _selectedAreaIndex == 0
                          ? _buildPayrollTab(
                              sessao: sessao,
                              companyData: companyData,
                              companySettings: companySettings,
                              employees: employees,
                              selectedEmployee: selectedEmployee,
                              payments: payments,
                              workEntries: workEntries,
                              tasks: tasks,
                            )
                          : _buildContractsTab(
                              sessao: sessao,
                              companyData: companyData,
                              companySettings: companySettings,
                              employees: employees,
                              selectedEmployee: selectedEmployee,
                              payments: payments,
                              workEntries: workEntries,
                              tasks: tasks,
                            ),
                    ),
                  );
                },
              );
            },
          );
  }

  int _calculateGrossFromEmployee(
    Employee employee,
    String quantityRaw, {
    required _PayrollMetrics? metrics,
    EmployeeCompensationType? compensationType,
  }) {
    final quantityText = quantityRaw.trim();
    final quantity = double.tryParse(quantityText.replaceAll(',', '.')) ?? 0;
    final effectiveType = compensationType ?? employee.compensationType;
    return switch (effectiveType) {
      EmployeeCompensationType.monthly =>
        ((employee.salaryAmountCents ?? 0) * (quantity <= 0 ? 1 : quantity))
            .round(),
      EmployeeCompensationType.weekly =>
        ((employee.salaryAmountCents ?? 0) * (quantity <= 0 ? 1 : quantity))
            .round(),
      EmployeeCompensationType.daily =>
        ((employee.salaryAmountCents ?? 0) *
                (quantity <= 0 ? (metrics?.approvedDays ?? 0) : quantity))
            .round(),
      EmployeeCompensationType.commission =>
        (((quantityText.contains(',') ||
                        quantityText.contains('.') ||
                        quantityText.contains('R\$'))
                    ? (_parseCurrencyToCents(quantityText) ??
                          metrics?.finishedServicesValueCents ??
                          0)
                    : (metrics?.finishedServicesValueCents ?? 0)) *
                ((employee.commissionPercent ?? 0) / 100))
            .round(),
    };
  }

  int _suggestedGrossForType(
    Employee employee,
    EmployeeCompensationType compensationType, {
    required _PayrollMetrics? metrics,
  }) {
    return switch (compensationType) {
      EmployeeCompensationType.monthly => employee.salaryAmountCents ?? 0,
      EmployeeCompensationType.weekly =>
        (employee.salaryAmountCents ?? 0) * (metrics?.approvedWeeks ?? 0),
      EmployeeCompensationType.daily =>
        (employee.salaryAmountCents ?? 0) * (metrics?.approvedDays ?? 0),
      EmployeeCompensationType.commission =>
        (((metrics?.finishedServicesValueCents ?? 0) *
                    ((employee.commissionPercent ?? 0) / 100)))
                .round(),
    };
  }

  String _compensationTypeLabel(EmployeeCompensationType type) {
    return switch (type) {
      EmployeeCompensationType.monthly => 'Mensal',
      EmployeeCompensationType.weekly => 'Semanal',
      EmployeeCompensationType.daily => 'Diaria',
      EmployeeCompensationType.commission => 'Comissao',
    };
  }

  String _employeeCompensationApiValue(EmployeeCompensationType type) {
    return switch (type) {
      EmployeeCompensationType.monthly => 'MONTHLY',
      EmployeeCompensationType.weekly => 'WEEKLY',
      EmployeeCompensationType.daily => 'DAILY',
      EmployeeCompensationType.commission => 'COMMISSION',
    };
  }

  double? _parsePercent(String raw) {
    final normalized = raw.trim().replaceAll('%', '').replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  String _contentTypeFromFileName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    return 'application/octet-stream';
  }

  String _compensationLabel(Employee employee) {
    return switch (employee.compensationType) {
      EmployeeCompensationType.monthly =>
        'Mensal: ${_formatCurrency(employee.salaryAmountCents ?? 0)}',
      EmployeeCompensationType.weekly =>
        'Semanal: ${_formatCurrency(employee.salaryAmountCents ?? 0)}',
      EmployeeCompensationType.daily =>
        'Diaria: ${_formatCurrency(employee.salaryAmountCents ?? 0)}',
      EmployeeCompensationType.commission =>
        'Comissao: ${(employee.commissionPercent ?? 0).toStringAsFixed(2).replaceAll('.', ',')}%',
    };
  }

  String _documentTitle(
    _PayrollDocumentType type,
    String employeeName,
    String competence,
  ) {
    return '${_documentTypeLabel(type)} - $employeeName - $competence';
  }

  String _documentTypeLabel(_PayrollDocumentType type) {
    return switch (type) {
      _PayrollDocumentType.payslip => 'Holerite simples',
      _PayrollDocumentType.receipt => 'Recibo de pagamento',
      _PayrollDocumentType.incomeProof => 'Comprovante de renda',
      _PayrollDocumentType.contract => 'Contrato simples',
      _PayrollDocumentType.thirteenthReceipt => 'Recibo 13 salario',
      _PayrollDocumentType.vacationReceipt => 'Recibo de ferias',
      _PayrollDocumentType.terminationStatement => 'Termo de rescisao',
    };
  }

  String _payrollDocumentSequenceLabelForType(
    _PayrollDocumentType type,
    int sequence,
  ) {
    return '${_payrollDocumentPrefix(type)}-${sequence.toString().padLeft(6, '0')}';
  }

  String _payrollDocumentPrefix(_PayrollDocumentType type) {
    return switch (type) {
      _PayrollDocumentType.payslip => 'HOL',
      _PayrollDocumentType.receipt => 'REC',
      _PayrollDocumentType.incomeProof => 'REN',
      _PayrollDocumentType.contract => 'CTR',
      _PayrollDocumentType.thirteenthReceipt => 'DEC',
      _PayrollDocumentType.vacationReceipt => 'FER',
      _PayrollDocumentType.terminationStatement => 'RES',
    };
  }

  String _paymentStatusLabel(PaymentStatus? status) {
    return switch (status) {
      PaymentStatus.pendente => 'Pendente',
      PaymentStatus.pago => 'Pago',
      PaymentStatus.confirmado => 'Confirmado',
      PaymentStatus.contestado => 'Contestado',
      PaymentStatus.cancelado => 'Cancelado',
      null => 'Sem lancamento',
    };
  }

  String _invoiceStatusLabel(String? status) {
    return switch ((status ?? 'DRAFT').toUpperCase()) {
      'EMITTED' => 'Emitida',
      'CANCELED' => 'Cancelada',
      'CANCELLED' => 'Cancelada',
      _ => 'Rascunho',
    };
  }

  String _periodCloseTitle(Map<String, dynamic> data) {
    final module = data['module']?.toString() ?? '';
    if (module == 'finance_cleanup') {
      return 'Limpeza financeira geral';
    }
    if (module == 'finance_settings_change') {
      return 'Ajuste sensivel do financeiro';
    }
    if (module == 'workforce_settings_change') {
      return 'Ajuste sensivel do trabalhista';
    }
    final competence = data['competence']?.toString() ?? '-';
    final closeAction = data['closeAction'] as bool? ?? true;
    return closeAction
        ? 'Fechamento da competencia $competence'
        : 'Reabertura da competencia $competence';
  }

  String _settingsChangeSummary(Map<String, dynamic> data) {
    final module = data['module']?.toString() ?? '';
    if (module == 'finance_settings_change') {
      final features =
          (data['proposedFinanceFeatures'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{};
      final active = <String>[
        if (features['enablePayments'] == true) 'pagamentos',
        if (features['enableDebts'] == true) 'dividas',
        if (features['enableCompanyMovements'] == true) 'movimentos',
        if (features['enableCleanup'] == true) 'limpeza',
      ];
      final mode = data['proposedFinanceMode']?.toString() ?? 'simple';
      return 'Modo ${mode == 'advanced' ? 'completo' : 'simples'} | Recursos: ${active.isEmpty ? 'nenhum ativo' : active.join(', ')}';
    }
    if (module == 'workforce_settings_change') {
      final features =
          (data['proposedWorkforceFeatures'] as Map?)
              ?.cast<String, dynamic>() ??
          <String, dynamic>{};
      final active = <String>[
        if (features['enablePayrollClosures'] == true) 'fechamento',
        if (features['enableMonthlyDashboard'] == true) 'painel RH',
        if (features['enableAdvancedDocuments'] == true) 'documentos',
        if (features['enableContracts'] == true) 'contratos',
      ];
      final mode = data['proposedWorkforceMode']?.toString() ?? 'simple';
      return 'Modo ${mode == 'advanced' ? 'completo' : 'simples'} | Recursos: ${active.isEmpty ? 'nenhum ativo' : active.join(', ')}';
    }
    return '';
  }

  int? _parseCurrencyToCents(String value) {
    var text = value.trim().replaceAll('R\$', '').replaceAll(' ', '');
    if (text.isEmpty) return null;
    if (text.contains(',')) {
      text = text.replaceAll('.', '').replaceAll(',', '.');
    }
    final parsed = double.tryParse(text);
    if (parsed == null) return null;
    return (parsed * 100).round();
  }

  String _currencyInput(int cents) {
    final reais = cents ~/ 100;
    final centavos = (cents % 100).toString().padLeft(2, '0');
    return '$reais,$centavos';
  }

  String _formatCurrency(int cents) {
    final reais = cents ~/ 100;
    final centavos = (cents % 100).toString().padLeft(2, '0');
    return 'R\$ $reais,$centavos';
  }

  (int, int)? _parseCompetence(String value) {
    final regex = RegExp(r'^\d{4}-\d{2}$');
    if (!regex.hasMatch(value)) return null;
    final year = int.tryParse(value.substring(0, 4));
    final month = int.tryParse(value.substring(5, 7));
    if (year == null || month == null || month < 1 || month > 12) return null;
    return (year, month);
  }

  DateTime _toDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
    return DateTime.now();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }

  String _formatDateTime(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final h = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return '$d/$m/${date.year} $h:$min';
  }

  void _msg(String texto) {
    if (!mounted) return;
    context.showUserMessage(texto);
  }
}
