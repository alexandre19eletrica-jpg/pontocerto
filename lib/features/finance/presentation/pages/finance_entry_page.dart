import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/features/finance/presentation/pages/finance_company_page.dart';
import 'package:pontocerto/features/finance/presentation/pages/finance_employee_page.dart';

class FinanceEntryPage extends ConsumerWidget {
  const FinanceEntryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessao = ref.watch(sessionProvider);
    if (sessao == null) {
      return const Scaffold(body: Center(child: Text('Sem sessao ativa')));
    }

    if (sessao.role == Role.employee) {
      return const FinanceEmployeePage();
    }

    return const FinanceCompanyPage();
  }
}
