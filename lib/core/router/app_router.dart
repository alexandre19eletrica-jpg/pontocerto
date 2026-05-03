import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/navigation/app_root_navigator_key.dart';
import 'package:pontocerto/core/navigation/app_route_shell.dart';
import 'package:pontocerto/core/platform/platform_access.dart';
import 'package:pontocerto/features/audit/presentation/pages/audit_page.dart';
import 'package:pontocerto/features/accountant_links/presentation/pages/accountant_companies_page.dart';
import 'package:pontocerto/features/accountant_links/presentation/pages/accountant_fiscal_profile_page.dart';
import 'package:pontocerto/features/accountant_links/presentation/pages/accountant_partner_page.dart';
import 'package:pontocerto/features/accountant_declarations/presentation/pages/accountant_declarations_page.dart';
import 'package:pontocerto/features/assistant/presentation/pages/assistant_page.dart';
import 'package:pontocerto/features/auth/presentation/pages/cadastro_empresa_page.dart';
import 'package:pontocerto/features/auth/presentation/pages/empresa_activation_page.dart';
import 'package:pontocerto/features/auth/presentation/pages/inicio_page.dart';
import 'package:pontocerto/features/auth/presentation/pages/login_contador_page.dart';
import 'package:pontocerto/features/auth/presentation/pages/login_empresa_page.dart';
import 'package:pontocerto/features/auth/presentation/pages/login_funcionario_page.dart';
import 'package:pontocerto/features/company/presentation/pages/company_page.dart';
import 'package:pontocerto/features/clients/presentation/pages/clients_page.dart';
import 'package:pontocerto/features/debts/presentation/pages/debts_page.dart';
import 'package:pontocerto/features/document_drafts/presentation/pages/document_drafts_page.dart';
import 'package:pontocerto/features/employees/presentation/pages/employees_page.dart';
import 'package:pontocerto/features/fiscal/presentation/pages/fiscal_readiness_page.dart';
import 'package:pontocerto/features/finance/presentation/pages/finance_entry_page.dart';
import 'package:pontocerto/features/home/presentation/pages/home_page.dart';
import 'package:pontocerto/features/justifications/presentation/pages/justifications_page.dart';
import 'package:pontocerto/features/material_catalog/presentation/pages/material_catalog_page.dart';
import 'package:pontocerto/features/marketing/presentation/pages/sales_page.dart';
import 'package:pontocerto/features/marketing/presentation/pages/accountant_partner_invite_page.dart';
import 'package:pontocerto/features/marketing/presentation/pages/accounting_office_signup_page.dart';
import 'package:pontocerto/features/marketing/presentation/pages/vendas_contador_page.dart';
import 'package:pontocerto/features/marketing/presentation/pages/vendas_convite_page.dart';
import 'package:pontocerto/features/marketing/presentation/pages/vendas_empresa_page.dart';
import 'package:pontocerto/features/marketing/presentation/pages/employee_tester_showcase_page.dart';
import 'package:pontocerto/features/marketing/presentation/pages/employee_tester_signup_page.dart';
import 'package:pontocerto/features/marketing/presentation/pages/public_demo_access_page.dart';
import 'package:pontocerto/features/marketing/presentation/pages/sales_onboarding_page.dart';
import 'package:pontocerto/features/payments/presentation/pages/payments_page.dart';
import 'package:pontocerto/features/platform_admin/presentation/pages/platform_admin_page.dart';
import 'package:pontocerto/features/platform_admin/presentation/platform_admin_section.dart';
import 'package:pontocerto/features/punch/presentation/pages/punch_page.dart';
import 'package:pontocerto/features/product_feedback/presentation/pages/product_feedback_page.dart';
import 'package:pontocerto/features/proposals/presentation/pages/service_proposals_page.dart';
import 'package:pontocerto/features/proposals/presentation/pages/contract_clauses_page.dart';
import 'package:pontocerto/features/recurring_billing/presentation/pages/recurring_billing_page.dart';
import 'package:pontocerto/features/reports/presentation/pages/reports_page.dart';
import 'package:pontocerto/features/runtime_incidents/presentation/pages/runtime_incidents_page.dart';
import 'package:pontocerto/features/service_catalog/presentation/pages/service_catalog_page.dart';
import 'package:pontocerto/features/service_orders/presentation/pages/service_orders_page.dart';
import 'package:pontocerto/features/settings/presentation/pages/settings_page.dart';
import 'package:pontocerto/features/tasks/presentation/pages/tasks_page.dart';
import 'package:pontocerto/features/workforce/presentation/pages/workforce_management_page.dart';

class RotasApp {
  static final GoRouter roteador = GoRouter(
    navigatorKey: appRootNavigatorKey,
    initialLocation: '/inicio',
    redirect: (context, state) async {
      try {
        final container = ProviderScope.containerOf(context);
        final sessao = container.read(sessionProvider);
        final location = state.matchedLocation;
        final estaNoLogin =
            location == '/login-empresa' ||
            location == '/login-funcionario' ||
            location == '/login-contador';
        final estaNoCadastro = location == '/cadastro-empresa';
        final estaNoCadastroEmpresaContador =
            location == '/cadastro-empresa-contador';
        final estaNoCadastroEscritorio =
            location == '/cadastro-escritorio-contabil';
        final estaNaAtivacao = location == '/ativacao-empresa';
        final estaNoInicio = location == '/inicio' || location == '/';
        final estaNaPaginaDeVendas = location == '/vendas';
        final estaVContador = location == '/vendas-contador';
        final estaVEmpresa = location == '/vendas-empresa';
        final estaConviteVendas = location == '/convite';
        final estaNoPreCadastroPublico = location == '/contratar';
        final estaNoOnboardingPublico = location == '/boas-vindas-empresa';
        final estaNoConviteContador = location == '/convite-contador';
        final estaNoCadastroTesteFuncionario = location == '/teste-funcionario';
        final estaNoCadastroTesteCurto = location == '/cadastro-teste';
        final estaNoDemoEmpresa = location == '/demo-empresa';
        final estaNoDemoContador = location == '/demo-contador';
        final acessoFuncionarioWebNegado =
            state.uri.queryParameters['employee-web-denied'] == '1';

        if (sessao == null) {
          if (estaNaPaginaDeVendas ||
              estaVContador ||
              estaVEmpresa ||
              estaConviteVendas ||
              estaNoPreCadastroPublico ||
              estaNoOnboardingPublico ||
              estaNoConviteContador ||
              estaNoCadastroEscritorio ||
              estaNoCadastroTesteFuncionario ||
              estaNoCadastroTesteCurto ||
              estaNoDemoEmpresa ||
              estaNoDemoContador ||
              estaNoCadastroEmpresaContador) {
            return null;
          }
          if (estaNaAtivacao) return null;
          if (isWebPlatform && location == '/login-funcionario') {
            return '/login-empresa?employee-web-denied=1';
          }
          return (estaNoLogin ||
                  estaNoCadastro ||
                  estaNoCadastroEmpresaContador ||
                  estaNoCadastroEscritorio ||
                  estaNoInicio)
              ? null
              : '/inicio';
        }

        if (isWebPlatform && sessao.role == Role.employee) {
          try {
            await FirebaseAuth.instance.signOut();
          } catch (_) {
            // Melhor esforco para impedir sessao de funcionario na web.
          }
          container.read(sessionProvider.notifier).logout();
          if (!acessoFuncionarioWebNegado) {
            return '/login-empresa?employee-web-denied=1';
          }
          return null;
        }

        if (estaNaPaginaDeVendas ||
            estaVContador ||
            estaVEmpresa ||
            estaConviteVendas) {
          return null;
        }
        if (estaNoPreCadastroPublico) {
          return null;
        }
        if (estaNoOnboardingPublico) {
          return null;
        }
        if (estaNoConviteContador) {
          return null;
        }
        if (estaNoCadastro || estaNoCadastroEmpresaContador) {
          return null;
        }
        if (estaNoCadastroEscritorio) {
          return null;
        }
        if (estaNoCadastroTesteFuncionario) {
          return null;
        }
        if (estaNoCadastroTesteCurto) {
          return null;
        }
        if (estaNoDemoEmpresa || estaNoDemoContador) {
          return null;
        }

        final precisaAtivacao = await _companyRequiresActivation(sessao);
        if (precisaAtivacao && !estaNaAtivacao) {
          return '/ativacao-empresa';
        }
        if (!precisaAtivacao && estaNaAtivacao) {
          return '/home';
        }

        if (estaNoLogin ||
            estaNoInicio ||
            location == '/login' ||
            location == '/login-funcionario') {
          return sessao.role == Role.accountant
              ? '/accountant-companies'
              : '/home';
        }

        if (!canAccessRoute(sessao.role, location)) {
          return '/home?denied=1';
        }

        // Contador: acesso liberado. Perfil fiscal e readiness fiscal passam a ser exigidos
        // apenas quando a operacao especifica precisar (na tela/acao correspondente),
        // sem bloquear o uso geral da plataforma.

        if (location.startsWith('/platform-admin') &&
            !canAccessPlatformAdminRoute(sessao)) {
          return '/home?denied=1';
        }

        if (location == '/runtime-incidents' &&
            !hasSupremePlatformAccess(sessao)) {
          return '/home?denied=1';
        }

        // Para funcionario, exige consentimento de uso do celular para todo o app
        // (exceto rotas de entrada e a propria home, onde o aceite pode ser feito).
        if (sessao.role == Role.employee &&
            location != '/home' &&
            location != '/inicio' &&
            location != '/login' &&
            location != '/login-empresa' &&
            location != '/login-funcionario') {
          final autorizado = await _employeeHasDeviceConsent(sessao);
          if (!autorizado) return '/home';
        }

        return null;
      } catch (_) {
        if (FirebaseAuth.instance.currentUser != null) {
          return null;
        }
        return '/inicio';
      }
    },
    routes: <RouteBase>[
      GoRoute(path: '/', redirect: (context, state) => '/inicio'),
      GoRoute(
        path: '/inicio',
        builder: (context, state) => const PaginaInicio(),
      ),
      GoRoute(path: '/login', redirect: (context, state) => '/login-empresa'),
      GoRoute(
        path: '/login-empresa',
        builder: (context, state) => const PaginaLoginEmpresa(),
      ),
      GoRoute(
        path: '/login-funcionario',
        builder: (context, state) => const PaginaLoginFuncionario(),
      ),
      GoRoute(
        path: '/login-contador',
        builder: (context, state) => const PaginaLoginContador(),
      ),
      GoRoute(
        path: '/cadastro-empresa',
        builder: (context, state) =>
            const PaginaCadastroEmpresa(lightweightMode: true),
      ),
      GoRoute(
        path: '/cadastro-empresa-contador',
        builder: (context, state) =>
            const PaginaCadastroEmpresa(lightweightMode: true),
      ),
      GoRoute(
        path: '/cadastro-escritorio-contabil',
        builder: (context, state) {
          final q = state.uri.queryParameters;
          return AccountingOfficeSignupPage(
            token:
                (q['token']?.trim().isNotEmpty == true
                    ? q['token']
                    : q['trialToken']) ??
                '',
          );
        },
      ),
      GoRoute(
        path: '/ativacao-empresa',
        builder: (context, state) => const EmpresaActivationPage(),
      ),
      GoRoute(path: '/vendas', builder: (context, state) => const SalesPage()),
      GoRoute(
        path: '/vendas-contador',
        builder: (context, state) => const VendasContadorPage(),
      ),
      GoRoute(
        path: '/vendas-empresa',
        builder: (context, state) => const VendasEmpresaPage(),
      ),
      GoRoute(
        path: '/convite',
        builder: (context, state) =>
            VendasConvitePage(token: state.uri.queryParameters['token'] ?? ''),
      ),
      GoRoute(
        path: '/contratar',
        redirect: (context, state) =>
            '/cadastro-escritorio-contabil${state.uri.hasQuery ? '?${state.uri.query}' : ''}',
      ),
      GoRoute(
        path: '/boas-vindas-empresa',
        builder: (context, state) => SalesOnboardingPage(
          token: state.uri.queryParameters['token'] ?? '',
        ),
      ),
      GoRoute(
        path: '/convite-contador',
        builder: (context, state) => AccountantPartnerInvitePage(
          token: state.uri.queryParameters['token'] ?? '',
        ),
      ),
      GoRoute(
        path: '/teste-funcionario',
        builder: (context, state) => const EmployeeTesterSignupPage(),
      ),
      GoRoute(
        path: '/cadastro-teste',
        builder: (context, state) => const EmployeeTesterSignupPage(),
      ),
      GoRoute(
        path: '/demo-empresa',
        builder: (context, state) => const PublicDemoAccessPage(
          profile: 'company',
          sourcePath: '/demo-empresa',
        ),
      ),
      GoRoute(
        path: '/demo-contador',
        builder: (context, state) => const PublicDemoAccessPage(
          profile: 'accountant',
          sourcePath: '/demo-contador',
        ),
      ),
      ShellRoute(
        builder: (BuildContext context, GoRouterState state, Widget child) {
          return AppRouteShell(child: child);
        },
        routes: <RouteBase>[
          GoRoute(
            path: '/home',
            builder: (context, state) => PaginaHome(
              acessoNegado: state.uri.queryParameters['denied'] == '1',
            ),
          ),
          GoRoute(
            path: '/assistant',
            builder: (context, state) => const AssistantPage(),
          ),
          GoRoute(
            path: '/improvements',
            builder: (context, state) => const ProductFeedbackPage(),
          ),
          GoRoute(
            path: '/jornada-ponto-certo',
            builder: (context, state) => const EmployeeTesterShowcasePage(),
          ),
          GoRoute(
            path: '/accountant-companies',
            builder: (context, state) => const AccountantCompaniesPage(),
          ),
          GoRoute(
            path: '/accountant-fiscal-profile',
            builder: (context, state) => const AccountantFiscalProfilePage(),
          ),
          GoRoute(
            path: '/accountant-register-company',
            builder: (context, state) => PaginaCadastroEmpresa(
              accountantMode: true,
              trialInviteToken: state.uri.queryParameters['trialToken'],
            ),
          ),
          GoRoute(
            path: '/completar-empresa',
            builder: (context, state) =>
                const PaginaCadastroEmpresa(completionMode: true),
          ),
          GoRoute(
            path: '/accountant-partner',
            builder: (context, state) => const AccountantPartnerPage(),
          ),
          GoRoute(
            path: '/accountant-declarations',
            builder: (context, state) => const AccountantDeclarationsPage(),
          ),
          GoRoute(
            path: '/employees',
            builder: (context, state) => const EmployeesPage(),
          ),
          GoRoute(
            path: '/tasks',
            builder: (context, state) => const TasksPage(),
          ),
          GoRoute(
            path: '/service-orders',
            builder: (context, state) => const ServiceOrdersPage(),
          ),
          GoRoute(
            path: '/documents',
            builder: (context, state) => const DocumentDraftsPage(),
          ),
          GoRoute(
            path: '/billing',
            builder: (context, state) => const RecurringBillingPage(),
          ),
          GoRoute(
            path: '/clients',
            builder: (context, state) => const ClientsPage(),
          ),
          GoRoute(
            path: '/service-catalog',
            builder: (context, state) => const ServiceCatalogPage(),
          ),
          GoRoute(
            path: '/materials',
            builder: (context, state) => const MaterialCatalogPage(),
          ),
          GoRoute(
            path: '/proposals',
            builder: (context, state) =>
                const ServiceProposalsPage(startInContracts: false),
          ),
          GoRoute(
            path: '/contracts',
            builder: (context, state) =>
                const ServiceProposalsPage(startInContracts: true),
          ),
          GoRoute(
            path: '/contract-clauses',
            builder: (context, state) => const ContractClausesPage(),
          ),
          GoRoute(
            path: '/debts',
            builder: (context, state) => const DebtsPage(),
          ),
          GoRoute(
            path: '/payments',
            builder: (context, state) => const PaymentsPage(),
          ),
          GoRoute(
            path: '/finance',
            builder: (context, state) => const FinanceEntryPage(),
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsPage(),
          ),
          GoRoute(
            path: '/punch',
            builder: (context, state) => const PunchPage(),
          ),
          GoRoute(
            path: '/justifications',
            builder: (context, state) => const JustificationsPage(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsPage(),
          ),
          GoRoute(
            path: '/platform-admin',
            redirect: (context, state) => state.uri.path == '/platform-admin'
                ? '/platform-admin/escritorios'
                : null,
          ),
          GoRoute(
            path: '/platform-admin/escritorios',
            builder: (context, state) => const PlatformAdminPage(
              section: PlatformAdminSection.escritorios,
            ),
          ),
          GoRoute(
            path: '/platform-admin/convidar',
            builder: (context, state) =>
                const PlatformAdminPage(section: PlatformAdminSection.convidar),
          ),
          GoRoute(
            path: '/platform-admin/financeiro',
            builder: (context, state) => const PlatformAdminPage(
              section: PlatformAdminSection.financeiro,
            ),
          ),
          GoRoute(
            path: '/platform-admin/integracoes',
            builder: (context, state) => const PlatformAdminPage(
              section: PlatformAdminSection.integracoes,
            ),
          ),
          GoRoute(
            path: '/runtime-incidents',
            builder: (context, state) => const RuntimeIncidentsPage(),
          ),
          GoRoute(
            path: '/audit',
            builder: (context, state) => const AuditPage(),
          ),
          GoRoute(
            path: '/company',
            builder: (context, state) => const CompanyPage(),
          ),
          GoRoute(
            path: '/workforce',
            builder: (context, state) => const WorkforceManagementPage(),
          ),
          GoRoute(
            path: '/fiscal',
            builder: (context, state) => const FiscalReadinessPage(),
          ),
        ],
      ),
    ],
  );

  static Future<bool> _employeeHasDeviceConsent(Session sessao) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? sessao.userId;
    final doc = await FirebaseFirestore.instance
        .collection('device_consents')
        .doc(uid)
        .get();
    final map = doc.data();
    return map != null &&
        map['accepted'] == true &&
        map['employeeId']?.toString() == uid &&
        map['companyId']?.toString() == sessao.companyId;
  }

  static Future<bool> _companyRequiresActivation(Session sessao) async {
    final companyId = sessao.companyId.trim();
    if (companyId.isEmpty ||
        companyId == 'empresa_local' ||
        isSupremePlatformCompanyId(companyId)) {
      return false;
    }
    final doc = await FirebaseFirestore.instance
        .collection('company_settings')
        .doc(companyId)
        .get();
    final raw = doc.data()?['commercialSettings'];
    if (raw is! Map) return false;
    final commercial = raw.cast<String, dynamic>();
    final accessControlMode =
        commercial['accessControlMode']?.toString() ?? 'standard';
    final activationRequired = commercial['activationRequired'] == true;
    final activationStatus =
        commercial['activationStatus']?.toString() ?? 'pending_code';
    return accessControlMode == 'activation_code' &&
        activationRequired &&
        activationStatus != 'released';
  }
}
