import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/errors/app_error_mapper.dart';
import 'package:pontocerto/core/company/company_runtime_summary_provider.dart';
import 'package:pontocerto/core/navigation/app_shell.dart';
import 'package:pontocerto/core/navigation/shell_page_chrome.dart';
import 'package:pontocerto/core/pdf/pdf_output.dart';
import 'package:pontocerto/core/platform/platform_access.dart';
import 'package:pontocerto/core/theme/app_branding.dart';
import 'package:pontocerto/core/theme/app_layout.dart';
import 'package:pontocerto/core/utils/formatadores_input.dart';
import 'package:pontocerto/features/fiscal/domain/invoice_customer.dart';
import 'package:pontocerto/features/fiscal/domain/focus_national_obra_tax_codes.dart';
import 'package:pontocerto/features/fiscal/domain/focus_official_issue_readiness.dart';
import 'package:pontocerto/features/fiscal/domain/fiscal_service_item.dart';
import 'package:pontocerto/features/fiscal/presentation/providers/fiscal_service_catalog_provider.dart';
import 'package:pontocerto/features/fiscal/presentation/services/fiscal_registry_lookup_service.dart';
import 'package:pontocerto/features/fiscal/presentation/widgets/focus_incoming_xml_section.dart';
import 'package:pontocerto/features/fiscal/presentation/widgets/invoice_dialog_sections.dart';
import 'package:pontocerto/features/fiscal/presentation/widgets/invoice_workspace_cards.dart';
import 'package:pontocerto/features/employees/domain/employee.dart';
import 'package:pontocerto/features/payments/domain/payment.dart';
import 'package:pontocerto/core/ui/app_user_message.dart';
import 'package:url_launcher/url_launcher.dart';

part 'fiscal_readiness_governance_actions.dart';
part 'fiscal_readiness_integration_actions.dart';
part 'fiscal_readiness_pdf_actions.dart';
part 'fiscal_readiness_sections.dart';

int? _parseTaxOpcaoSimplesNacional(Object? v) {
  if (v == null) return null;
  final n = int.tryParse(v.toString().trim());
  if (n == 1 || n == 2 || n == 3) return n;
  return null;
}

String _joinFiscalInvoiceDescriptionBody(String base, String complement) {
  final a = base.trim();
  final b = complement.trim();
  if (a.isEmpty) {
    return b;
  }
  if (b.isEmpty) {
    return a;
  }
  return '$a\n\n$b';
}

/// Registro oficial autorizado. `EMITTED` fica somente como compatibilidade legada.
bool _fiscalStatusIsApprovedOrLegacyEmitted(String? raw) {
  final s = (raw ?? '').toUpperCase();
  return s == 'EMITTED' || s == 'APPROVED';
}

class FiscalReadinessPage extends ConsumerStatefulWidget {
  const FiscalReadinessPage({super.key});

  @override
  ConsumerState<FiscalReadinessPage> createState() =>
      _FiscalReadinessPageState();
}

class _FiscalReadinessPageState extends ConsumerState<FiscalReadinessPage> {
  final _competenceController = TextEditingController(
    text:
        '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}',
  );
  final _registryLookup = FiscalRegistryLookupService();
  final _fiscalFunctions = FirebaseFunctions.instanceFor(region: 'us-central1');
  final Set<String> _autoReconciledProcessingKeys = <String>{};
  bool _reconcilingProcessingInvoices = false;
  bool _showInactiveFiscalServices = false;
  TextEditingController? _fiscalPaymentReceiptController;
  String? _fiscalPaymentReceiptCompanyId;
  String? _lastAutoCompetence;

  @override
  void dispose() {
    _fiscalPaymentReceiptController?.dispose();
    _competenceController.dispose();
    super.dispose();
  }

  void _ensureFiscalPaymentReceiptController({
    required String companyId,
    required Map<String, dynamic> companyData,
  }) {
    if (_fiscalPaymentReceiptCompanyId != companyId) {
      _fiscalPaymentReceiptController?.dispose();
      _fiscalPaymentReceiptController = TextEditingController(
        text: companyData['fiscalPaymentBankInfo']?.toString() ?? '',
      );
      _fiscalPaymentReceiptCompanyId = companyId;
    }
  }

  Future<void> _persistFiscalPaymentReceiptNote({
    required Session sessao,
    required Map<String, dynamic> companyData,
  }) async {
    if (sessao.isDemo) {
      _msg('Demo em leitura: alteracoes nao sao gravadas.');
      return;
    }
    final controller = _fiscalPaymentReceiptController;
    if (controller == null) {
      return;
    }
    final mergedCompanyData = Map<String, dynamic>.from(companyData);
    mergedCompanyData['fiscalPaymentBankInfo'] = controller.text.trim();
    try {
      await FirebaseFirestore.instance
          .collection('company_settings')
          .doc(sessao.companyId)
          .set(
            {
              'companyId': sessao.companyId,
              'companyData': mergedCompanyData,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
      if (!mounted) return;
      _msg('Dados de recebimento gravados. Passam para o texto da nota ao emitir.');
    } catch (_) {
      if (!mounted) return;
      _msg('Nao foi possivel gravar os dados de recebimento.');
    }
  }

  String _companyProfileLabel(String profile) {
    return switch (profile) {
      'mei' => 'MEI',
      'growing_business' => 'Crescimento',
      'enterprise' => 'Empresa estruturada',
      _ => 'Pequena',
    };
  }

  String _sharedFiscalCustomerId(String document) {
    final digits = _onlyDigits(document);
    if (digits.isNotEmpty) return digits;
    return DateTime.now().microsecondsSinceEpoch.toString();
  }

  Future<void> _openInvoiceDialog({
    required Session sessao,
    required Map<String, dynamic> companyData,
    required Map<String, dynamic> companySettings,
    required _FiscalRealIntegrationSetup realIntegration,
    QueryDocumentSnapshot<Map<String, dynamic>>? editing,
    Map<String, dynamic>? initialTaskData,
  }) async {
    final data = editing?.data() ?? <String, dynamic>{};
    final savedServices = ref.read(fiscalServiceCatalogProvider);
    final autoDefaults = _FiscalAutoDefaults.fromData(
      companyData: companyData,
      companySettings: companySettings,
      realIntegration: realIntegration,
      savedServices: savedServices,
    );
    final complianceMatrix = _FiscalComplianceMatrix.fromSettings(
      companySettings,
      realIntegration,
    );
    final useNationalEmission = _effectiveFiscalRouteType(
          companySettings: companySettings,
          setup: realIntegration,
        ) ==
        'focus_national';
    final primaryActive = savedServices.where((e) => e.active).toList();
    final emissionFiscalServiceOptions = primaryActive;
    final companyServiceOptions = _companyServiceOptions(companyData);
    final customer =
        (data['customer'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    final service =
        (data['service'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    final workSite =
        (service['workSite'] as Map?)?.cast<String, dynamic>() ??
        (data['workSite'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    final tax =
        (data['tax'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final clientController = TextEditingController(
      text:
          customer['legalName']?.toString() ??
          data['clientName']?.toString() ??
          '',
    );
    final tradeNameController = TextEditingController(
      text: customer['tradeName']?.toString() ?? '',
    );
    final documentController = TextEditingController(
      text:
          customer['document']?.toString() ??
          data['clientDocument']?.toString() ??
          '',
    );
    final municipalRegistrationController = TextEditingController(
      text: customer['municipalRegistration']?.toString() ?? '',
    );
    final stateRegistrationController = TextEditingController(
      text: customer['stateRegistration']?.toString() ?? '',
    );
    final emailController = TextEditingController(
      text: customer['email']?.toString() ?? '',
    );
    final phoneController = TextEditingController(
      text: customer['phone']?.toString() ?? '',
    );
    final zipCodeController = TextEditingController(
      text: customer['zipCode']?.toString() ?? '',
    );
    final streetController = TextEditingController(
      text: customer['street']?.toString() ?? '',
    );
    final numberController = TextEditingController(
      text: customer['number']?.toString() ?? '',
    );
    final complementController = TextEditingController(
      text: customer['complement']?.toString() ?? '',
    );
    final neighborhoodController = TextEditingController(
      text: customer['neighborhood']?.toString() ?? '',
    );
    final cityController = TextEditingController(
      text: customer['city']?.toString() ?? '',
    );
    final stateController = TextEditingController(
      text: customer['state']?.toString() ?? '',
    );
    final serviceDescriptionLegacy =
        service['description']?.toString() ??
        data['serviceDescription']?.toString() ??
        autoDefaults.defaultServiceDescription;
    final baseFromDoc = data['fiscalServiceBaseDescription']?.toString();
    final serviceController = TextEditingController(
      text: (baseFromDoc != null && baseFromDoc.trim().isNotEmpty)
          ? baseFromDoc
          : serviceDescriptionLegacy,
    );
    final serviceComplementController = TextEditingController(
      text: data['serviceDescriptionComplement']?.toString() ?? '',
    );
    final fiscalPaymentBankInfoController = TextEditingController(
      text: companyData['fiscalPaymentBankInfo']?.toString() ?? '',
    );
    final serviceCodeController = TextEditingController(
      text:
          service['serviceCode']?.toString() ?? autoDefaults.defaultServiceCode,
    );
    final municipalServiceCodeController = TextEditingController(
      text:
          service['municipalServiceCode']?.toString() ??
          autoDefaults.defaultMunicipalServiceCode,
    );
    final cnaeController = TextEditingController(
      text: service['cnae']?.toString() ?? autoDefaults.defaultCnae,
    );
    final serviceCityController = TextEditingController(
      text:
          service['cityOfIncidence']?.toString() ??
          companyData['cidade']?.toString() ??
          autoDefaults.defaultCityOfIncidence,
    );
    final amountController = TextEditingController(
      text: (service['grossAmountCents'] ?? data['amountCents']) == null
          ? ''
          : _currencyInput(
              ((service['grossAmountCents'] ?? data['amountCents']) as num)
                  .toInt(),
            ),
    );
    final deductionsController = TextEditingController(
      text: tax['deductionsCents'] == null
          ? '0,00'
          : _currencyInput((tax['deductionsCents'] as num).toInt()),
    );
    final taxRateController = TextEditingController(
      text: tax['issRate']?.toString() ?? autoDefaults.defaultIssRate,
    );
    final otherRetentionsController = TextEditingController(
      text: tax['otherRetentionsCents'] == null
          ? '0,00'
          : _currencyInput((tax['otherRetentionsCents'] as num).toInt()),
    );
    final taxRegimeController = TextEditingController(
      text:
          tax['taxRegime']?.toString() ??
          companyData['regimeTributario']?.toString() ??
          autoDefaults.defaultTaxRegime,
    );
    var issRetained = tax['issRetained'] as bool? ?? false;
    var inssRetained = tax['inssRetained'] as bool? ?? false;
    final inssRateController = TextEditingController(
      text: tax['inssRate']?.toString() ?? '11,00',
    );
    final operationNatureController = TextEditingController(
      text: _operationNatureDisplayLabel(
        tax['operationNatureLabel']?.toString(),
        rawValue:
            tax['operationNature']?.toString() ??
            autoDefaults.defaultOperationNature,
        issRetained: issRetained,
      ),
    );
    final officialNumberController = TextEditingController(
      text: _invoiceOfficialNumber(data),
    );
    final portalController = TextEditingController(
      text: data['officialPortalUrl']?.toString() ?? '',
    );
    final workSiteNameController = TextEditingController(
      text: workSite['name']?.toString() ?? '',
    );
    final workSiteCnoController = TextEditingController(
      text: workSite['cno']?.toString() ??
          workSite['cnoObra']?.toString() ??
          workSite['cno_obra']?.toString() ??
          '',
    );
    final workSiteZipCodeController = TextEditingController(
      text: workSite['zipCode']?.toString() ?? '',
    );
    final workSiteStreetController = TextEditingController(
      text: workSite['street']?.toString() ?? '',
    );
    final workSiteNumberController = TextEditingController(
      text: workSite['number']?.toString() ?? '',
    );
    final workSiteComplementController = TextEditingController(
      text: workSite['complement']?.toString() ?? '',
    );
    final workSiteNeighborhoodController = TextEditingController(
      text: workSite['neighborhood']?.toString() ?? '',
    );
    final workSiteCityController = TextEditingController(
      text: workSite['city']?.toString() ?? '',
    );
    final workSiteStateController = TextEditingController(
      text: workSite['state']?.toString() ?? '',
    );
    var status = data['status']?.toString() ?? 'DRAFT';
    var fiscalCostBearer =
        (data['billing'] as Map?)?['fiscalCostBearer']?.toString() ??
        tax['fiscalCostBearer']?.toString() ??
        'provider';
    final issRetentionListenable = ValueNotifier<bool>(issRetained);
    final inssRetentionListenable = ValueNotifier<bool>(inssRetained);
    final fiscalCostBearerListenable = ValueNotifier<String>(fiscalCostBearer);
    var lookupBusy = false;
    var workSiteCepLookupBusy = false;
    var dpsSimplesNacionalOverride = _parseTaxOpcaoSimplesNacional(
      tax['opcaoSimplesNacional'],
    );
    var fiscalAutomation = _inferFiscalAutomation(
      companyData: companyData,
      complianceMatrix: complianceMatrix,
      cnaeCode: service['cnae']?.toString() ?? '',
      activityDescription: _joinFiscalInvoiceDescriptionBody(
        (baseFromDoc != null && baseFromDoc.trim().isNotEmpty)
            ? baseFromDoc
            : (service['description']?.toString() ??
                data['serviceDescription']?.toString() ??
                autoDefaults.defaultServiceDescription),
        data['serviceDescriptionComplement']?.toString() ?? '',
      ),
      serviceCode:
          service['serviceCode']?.toString() ?? autoDefaults.defaultServiceCode,
      cityOfIncidence:
          service['cityOfIncidence']?.toString() ??
          companyData['cidade']?.toString() ??
          autoDefaults.defaultCityOfIncidence,
      fiscalCostBearer: fiscalCostBearer,
      currentTaxRateText:
          tax['issRate']?.toString() ?? autoDefaults.defaultIssRate,
    );
    if (editing == null) {
      if (taxRateController.text.trim().isEmpty) {
        taxRateController.text = fiscalAutomation.issRateText;
      }
      if (operationNatureController.text.trim().isEmpty) {
        operationNatureController.text = fiscalAutomation.operationNatureLabel;
      }
      if (serviceController.text.trim().isEmpty ||
          serviceController.text.trim() ==
              autoDefaults.defaultServiceDescription) {
        serviceController.text = fiscalAutomation.serviceDescription;
      }
      if (tax['inssRetained'] == null) {
        inssRetained = false;
      }
      if (inssRateController.text.trim().isEmpty) {
        inssRateController.text = '11,00';
      }
    }
    String? selectedCustomerId = data['customerId']?.toString();
    String? selectedFiscalServiceId = data['fiscalServiceId']?.toString();
    String? selectedTaskId =
        (data['sourceTask'] as Map?)?['id']?.toString() ??
        data['sourceTaskId']?.toString();
    Map<String, dynamic>? selectedTaskData = (data['sourceTask'] as Map?)
        ?.cast<String, dynamic>();
    String? selectedCompanyActivityCode;
    if (selectedFiscalServiceId != null &&
        !emissionFiscalServiceOptions
            .any((e) => e.id == selectedFiscalServiceId)) {
      selectedFiscalServiceId = null;
    }
    if (editing == null && selectedFiscalServiceId == null) {
      if (emissionFiscalServiceOptions.length == 1) {
        selectedFiscalServiceId = emissionFiscalServiceOptions.first.id;
      }
    }
    DateTime issueDate = _toDate(data['issueDate']);
    DateTime serviceDate = _toDate(data['serviceDate']);
    final sourceTaskName = selectedTaskData == null
        ? ''
        : (selectedTaskData['nome']?.toString().trim() ?? '');

    void refreshFiscalAutomationHintsOnly() {
      if (serviceCodeController.text.trim().isNotEmpty) {
        municipalServiceCodeController.text = serviceCodeController.text.trim();
      }
      fiscalAutomation = _inferFiscalAutomation(
        companyData: companyData,
        complianceMatrix: complianceMatrix,
        cnaeCode: cnaeController.text,
        activityDescription: _joinFiscalInvoiceDescriptionBody(
          serviceController.text,
          serviceComplementController.text,
        ),
        serviceCode: serviceCodeController.text,
        cityOfIncidence: serviceCityController.text,
        fiscalCostBearer: fiscalCostBearer,
        currentTaxRateText: taxRateController.text,
      );
    }

    void applyTaskToInvoice(Map<String, dynamic> taskData) {
      final taskClientName = taskData['clienteNome']?.toString().trim() ?? '';
      final taskClientDocument =
          taskData['clienteDocumento']?.toString().trim() ?? '';
      final taskDescription =
          taskData['descricao']?.toString().trim().isNotEmpty == true
          ? taskData['descricao'].toString().trim()
          : taskData['nome']?.toString().trim() ?? '';
      final taskAmount = (taskData['valorTotalCents'] as num?)?.toInt();
      if (clientController.text.trim().isEmpty && taskClientName.isNotEmpty) {
        clientController.text = taskClientName;
      }
      if (documentController.text.trim().isEmpty &&
          taskClientDocument.isNotEmpty) {
        documentController.text = taskClientDocument;
      }
      if (serviceController.text.trim().isEmpty && taskDescription.isNotEmpty) {
        serviceController.text = taskDescription;
      }
      if (amountController.text.trim().isEmpty &&
          taskAmount != null &&
          taskAmount > 0) {
        amountController.text = _currencyInput(taskAmount);
      }
    }

    if (editing == null && initialTaskData != null) {
      selectedTaskId = initialTaskData['id']?.toString().trim();
      selectedTaskData = initialTaskData;
      selectedCustomerId =
          initialTaskData['clienteId']?.toString().trim().isEmpty == true
          ? null
          : initialTaskData['clienteId']?.toString().trim();
      applyTaskToInvoice(initialTaskData);
    }

    bool hasAutomaticIssBase() {
      return serviceCodeController.text.trim().isNotEmpty &&
          serviceCityController.text.trim().isNotEmpty;
    }

    String issDecisionSourceLabel() {
      final matrixRule = complianceMatrix.resolve(
        cnaeCode: cnaeController.text,
        serviceCode: serviceCodeController.text,
        activityDescription: _joinFiscalInvoiceDescriptionBody(
          serviceController.text,
          serviceComplementController.text,
        ),
        cityOfIncidence: serviceCityController.text,
      );
      return matrixRule == null ? 'regra_nacional' : 'matriz_municipal';
    }

    /// Documento alinhado ao que vai para o Firestore e ao pre-check
    /// `validateInvoiceReadinessForOfficialIssue` (Cloud Function).
    Map<String, dynamic>? buildCurrentInvoiceDocument() {
      final amount = _parseCurrencyToCents(amountController.text);
      final serviceBodyNoBank = _joinFiscalInvoiceDescriptionBody(
        serviceController.text,
        serviceComplementController.text,
      );
      if (amount == null || amount <= 0) {
        return null;
      }
      final resolvedService = serviceBodyNoBank.trim().isEmpty
          ? 'Servico'
          : serviceBodyNoBank;
      final resolvedClient = clientController.text.trim().isEmpty
          ? 'Tomador do servico'
          : clientController.text.trim();
      final emitter = {
        ..._buildEmitterPayload(companyData),
        'fiscalPaymentBankInfo': fiscalPaymentBankInfoController.text.trim(),
      };

      final deductions = _parseCurrencyToCents(deductionsController.text) ?? 0;
      final otherRetentions =
          _parseCurrencyToCents(otherRetentionsController.text) ?? 0;
      final taxRate = _parsePercent(taxRateController.text);
      final inssRate = _parsePercent(inssRateController.text);
      final taxAmounts = _computeServiceInvoiceTaxAmounts(
        grossAmountCents: amount,
        deductionsCents: deductions,
        otherRetentionsCents: otherRetentions,
        issRatePercent: taxRate,
        inssRatePercent: inssRate,
        issRetained: issRetained,
        inssRetained: inssRetained,
        fiscalCostBearer: fiscalCostBearer,
      );
      final taxableBase = taxAmounts.taxableBaseCents;
      final issAmount = taxAmounts.issAmountCents;
      final inssAmount = taxAmounts.inssAmountCents;
      final netAmount = taxAmounts.netAmountCents;
      final fiscalCostAmount = taxAmounts.fiscalCostAmountCents;
      final finalAmount = taxAmounts.finalAmountCents;
      final sharedCustomerId = _sharedFiscalCustomerId(documentController.text);

      return <String, dynamic>{
        'companyId': sessao.companyId,
        'customerId': sharedCustomerId,
        'sourceTaskId': selectedTaskId,
        'fiscalServiceId': selectedFiscalServiceId,
        'clientName': resolvedClient,
        'clientDocument': documentController.text.trim(),
        'fiscalServiceBaseDescription': serviceController.text.trim().isNotEmpty
            ? serviceController.text.trim()
            : resolvedService,
        'serviceDescriptionComplement': serviceComplementController.text
            .trim(),
        'serviceDescription': resolvedService,
        'amountCents': amount,
        'emitter': emitter,
        'accountingExport': {
          'legalNature': companyData['legalNature']?.toString().trim() ?? '',
          'mainCnae': cnaeController.text.trim().isNotEmpty
              ? cnaeController.text.trim()
              : companyData['mainCnae']?.toString().trim() ?? '',
          'mainCnaeDescription':
              companyData['mainCnaeDescription']?.toString().trim() ?? '',
          'taxRegime': taxRegimeController.text.trim().isNotEmpty
              ? taxRegimeController.text.trim()
              : autoDefaults.defaultTaxRegime,
          'provider': realIntegration.provider.trim(),
          'environment': realIntegration.environment.trim(),
        },
        'customer': {
          'legalName': resolvedClient,
          'tradeName': tradeNameController.text.trim(),
          'document': documentController.text.trim(),
          'email': emailController.text.trim(),
          'phone': phoneController.text.trim(),
          'municipalRegistration': municipalRegistrationController.text.trim(),
          'stateRegistration': stateRegistrationController.text.trim(),
          'zipCode': zipCodeController.text.trim(),
          'street': streetController.text.trim(),
          'number': numberController.text.trim(),
          'complement': complementController.text.trim(),
          'neighborhood': neighborhoodController.text.trim(),
          'city': cityController.text.trim(),
          'state': stateController.text.trim(),
        },
        'service': {
          'serviceCode': serviceCodeController.text.trim(),
          'municipalServiceCode': municipalServiceCodeController.text.trim(),
          'cnae': cnaeController.text.trim(),
          'cityOfIncidence': serviceCityController.text.trim(),
          'description': resolvedService,
          'grossAmountCents': amount,
          if (workSiteZipCodeController.text.trim().isNotEmpty ||
              workSiteStreetController.text.trim().isNotEmpty ||
              workSiteCityController.text.trim().isNotEmpty ||
              workSiteCnoController.text.trim().isNotEmpty)
            'workSite': {
              'name': workSiteNameController.text.trim(),
              'cno': workSiteCnoController.text.trim(),
              'cnoObra': workSiteCnoController.text.trim(),
              'zipCode': workSiteZipCodeController.text.trim(),
              'street': workSiteStreetController.text.trim(),
              'number': workSiteNumberController.text.trim(),
              'complement': workSiteComplementController.text.trim(),
              'neighborhood': workSiteNeighborhoodController.text.trim(),
              'city': workSiteCityController.text.trim(),
              'state': workSiteStateController.text.trim(),
            },
        },
        'tax': {
          'deductionsCents': deductions,
          'otherRetentionsCents': otherRetentions,
          'taxableBaseCents': taxableBase < 0 ? 0 : taxableBase,
          'issRate': taxRate,
          'issRetained': issRetained,
          'inssRetained': inssRetained,
          'inssRate': inssRate,
          'inssAmountCents': inssAmount,
          'taxRegime': taxRegimeController.text.trim(),
          'opcaoSimplesNacional': ?dpsSimplesNacionalOverride,
          'operationNature': _normalizeOperationNatureCode(
            operationNatureController.text,
            issRetained: issRetained,
          ),
          'operationNatureLabel': _operationNatureDisplayLabel(
            operationNatureController.text,
            issRetained: issRetained,
          ),
          'issAmountCents': issAmount,
          'netAmountCents': netAmount < 0 ? 0 : netAmount,
          'fiscalCostBearer': fiscalCostBearer,
          'decisionSource': issDecisionSourceLabel(),
          'automationLocked': true,
        },
        'billing': {
          'grossServiceAmountCents': amount,
          'fiscalCostAmountCents': fiscalCostAmount < 0 ? 0 : fiscalCostAmount,
          'finalAmountCents': finalAmount < 0 ? 0 : finalAmount,
          'fiscalCostBearer': fiscalCostBearer,
        },
        if (selectedTaskId != null && selectedTaskId!.trim().isNotEmpty)
          'sourceTask': {
            'id': selectedTaskId,
            'name': sourceTaskName.isNotEmpty ? sourceTaskName : null,
            'status': selectedTaskData?['status']?.toString(),
            'executionDate': selectedTaskData?['dataExecucao']?.toString(),
            'customerId': selectedCustomerId ?? sharedCustomerId,
            'customerName': resolvedClient,
            'description': resolvedService,
          },
        'status': status,
        'officialNumber': officialNumberController.text.trim(),
        'officialPortalUrl': portalController.text.trim(),
        'issueDate': Timestamp.fromDate(issueDate),
        'serviceDate': Timestamp.fromDate(serviceDate),
        'updatedAt': FieldValue.serverTimestamp(),
        if (editing == null) 'createdAt': FieldValue.serverTimestamp(),
      };
    }

    Future<String?> saveInvoiceRecord({bool forOfficialEmission = false}) async {
      final baseDoc = buildCurrentInvoiceDocument();
      if (baseDoc == null) {
        _msg('Informe o valor do servico.');
        return null;
      }
      if (forOfficialEmission) {
        final readiness = evaluateFocusOfficialIssueReadiness(
          invoiceData: baseDoc,
          companySettings: companySettings,
          focusNfseNationalMode: useNationalEmission,
        );
        if (!readiness.isReady) {
          _msg('Emissao oficial bloqueada. Ajuste: ${readiness.message}.');
          return null;
        }
      }
      final payload = baseDoc;
      final sharedCustomerId = _sharedFiscalCustomerId(documentController.text);
      final resolvedClient = clientController.text.trim().isEmpty
          ? 'Tomador do servico'
          : clientController.text.trim();

      try {
        String invoiceId;
        if (editing == null) {
          final ref = await FirebaseFirestore.instance
              .collection('service_invoices')
              .add(payload);
          invoiceId = ref.id;
        } else {
          await FirebaseFirestore.instance
              .collection('service_invoices')
              .doc(editing.id)
              .set(payload, SetOptions(merge: true));
          invoiceId = editing.id;
        }
        // Dados cadastrais vivem em `company_settings` (a coleção `companies` não
        // possui regra no Firestore e o deny-all final impede gravação).
        final mergedCompanyData = Map<String, dynamic>.from(companyData);
        mergedCompanyData['fiscalPaymentBankInfo'] =
            fiscalPaymentBankInfoController.text.trim();
        await FirebaseFirestore.instance
            .collection('company_settings')
            .doc(sessao.companyId)
            .set(
              {
                'companyId': sessao.companyId,
                'companyData': mergedCompanyData,
                'updatedAt': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true),
            );
        await _saveInvoiceCustomer(
          sessao: sessao,
          customer: InvoiceCustomer(
            id: sharedCustomerId,
            companyId: sessao.companyId,
            legalName: resolvedClient,
            tradeName: tradeNameController.text.trim(),
            document: documentController.text.trim(),
            email: emailController.text.trim(),
            phone: phoneController.text.trim(),
            municipalRegistration: municipalRegistrationController.text.trim(),
            stateRegistration: stateRegistrationController.text.trim(),
            zipCode: zipCodeController.text.trim(),
            street: streetController.text.trim(),
            number: numberController.text.trim(),
            complement: complementController.text.trim(),
            neighborhood: neighborhoodController.text.trim(),
            city: cityController.text.trim(),
            state: stateController.text.trim(),
            country: 'BRASIL',
            notes: '',
            createdAtIso: '',
            updatedAtIso: DateTime.now().toIso8601String(),
          ),
        );
        return invoiceId;
      } catch (_) {
        _msg('Nao foi possivel salvar a nota.');
        return null;
      }
    }

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          Future<void> searchWorkSiteCep() async {
            final digits = _onlyDigits(workSiteZipCodeController.text);
            if (digits.length != 8) {
              _msg('Digite 8 numeros do CEP da obra.');
              return;
            }
            setStateDialog(() => workSiteCepLookupBusy = true);
            try {
              final r = await _registryLookup.lookupCep(digits);
              if (!context.mounted) {
                return;
              }
              workSiteZipCodeController.text =
                  (r['zipCode']?.toString().trim().isNotEmpty == true
                      ? r['zipCode'].toString()
                      : workSiteZipCodeController.text);
              if ((r['street']?.toString().trim() ?? '').isNotEmpty) {
                workSiteStreetController.text = r['street'].toString();
              }
              if ((r['neighborhood']?.toString().trim() ?? '').isNotEmpty) {
                workSiteNeighborhoodController.text =
                    r['neighborhood'].toString();
              }
              if ((r['city']?.toString().trim() ?? '').isNotEmpty) {
                workSiteCityController.text = r['city'].toString();
              }
              if ((r['state']?.toString().trim() ?? '').isNotEmpty) {
                workSiteStateController.text = r['state'].toString();
              }
              setStateDialog(() {});
              _msg('Endereco da obra preenchido a partir do CEP.');
            } on FirebaseFunctionsException catch (error) {
              _msg(
                error.message?.trim().isNotEmpty == true
                    ? error.message!
                    : 'CEP nao encontrado.',
              );
            } catch (_) {
              _msg('Nao foi possivel buscar o CEP agora.');
            } finally {
              if (context.mounted) {
                setStateDialog(() => workSiteCepLookupBusy = false);
              }
            }
          }

          return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180, maxHeight: 860),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              editing == null ? 'Nova NFS-e' : 'Editar NFS-e',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: AppBrandColors.ink,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Formulario fiscal organizado em uma unica tela: cliente, servico, cabecalho e validacoes no mesmo fluxo.',
                              style: TextStyle(
                                color: AppBrandColors.softText,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF2FF),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'Competencia ${_competenceController.text.trim()}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: SingleChildScrollView(
                      child: AppDesktopSplit(
                        breakpoint: 960,
                        sidebarFlex: 5,
                        contentFlex: 6,
                        sidebar: Column(
                          children: [
                            AppWorkspaceCard(
                              title: 'Tomador do servico',
                              subtitle:
                                  'Dados cadastrais do tomador com apoio de busca por CNPJ. O CEP fica apenas para ajuste manual.',
                              child: Column(
                                children: [
                                  StreamBuilder<
                                    QuerySnapshot<Map<String, dynamic>>
                                  >(
                                    stream: FirebaseFirestore.instance
                                        .collection('invoice_customers')
                                        .where(
                                          'companyId',
                                          isEqualTo: sessao.companyId,
                                        )
                                        .snapshots(),
                                    builder: (context, snapshot) {
                                      final customers =
                                          (snapshot.data?.docs ?? const [])
                                              .map(
                                                (doc) => <String, dynamic>{
                                                  'id': doc.id,
                                                  ...doc.data(),
                                                },
                                              )
                                              .toList()
                                            ..sort(
                                              (a, b) =>
                                                  (b['updatedAtIso']
                                                              ?.toString() ??
                                                          '')
                                                      .compareTo(
                                                        a['updatedAtIso']
                                                                ?.toString() ??
                                                            '',
                                                      ),
                                            );
                                      if (customers.isEmpty) {
                                        return const SizedBox.shrink();
                                      }
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
                                        child: DropdownButtonFormField<String>(
                                          initialValue:
                                              customers.any(
                                                (customer) =>
                                                    customer['id'] ==
                                                    selectedCustomerId,
                                              )
                                              ? selectedCustomerId
                                              : null,
                                          decoration: const InputDecoration(
                                            labelText: 'Tomador salvo',
                                          ),
                                          items: customers
                                              .take(20)
                                              .map(
                                                (customer) => DropdownMenuItem(
                                                  value: customer['id']
                                                      ?.toString(),
                                                  child: Text(
                                                    customer['legalName']
                                                                ?.toString()
                                                                .trim()
                                                                .isNotEmpty ==
                                                            true
                                                        ? customer['legalName']
                                                              .toString()
                                                        : customer['tradeName']
                                                                  ?.toString() ??
                                                              '-',
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                          onChanged: (value) {
                                            Map<String, dynamic>? selected;
                                            for (final customer in customers) {
                                              if (customer['id'] == value) {
                                                selected = customer;
                                                break;
                                              }
                                            }
                                            if (selected == null) return;
                                            _applyCustomerToControllers(
                                              customer: selected,
                                              clientController:
                                                  clientController,
                                              tradeNameController:
                                                  tradeNameController,
                                              documentController:
                                                  documentController,
                                              municipalRegistrationController:
                                                  municipalRegistrationController,
                                              stateRegistrationController:
                                                  stateRegistrationController,
                                              emailController: emailController,
                                              phoneController: phoneController,
                                              zipCodeController:
                                                  zipCodeController,
                                              streetController:
                                                  streetController,
                                              numberController:
                                                  numberController,
                                              complementController:
                                                  complementController,
                                              neighborhoodController:
                                                  neighborhoodController,
                                              cityController: cityController,
                                              stateController: stateController,
                                            );
                                            setStateDialog(() {
                                              selectedCustomerId = value;
                                            });
                                          },
                                        ),
                                      );
                                    },
                                  ),
                                  StreamBuilder<
                                    QuerySnapshot<Map<String, dynamic>>
                                  >(
                                    stream: FirebaseFirestore.instance
                                        .collection('tasks')
                                        .where(
                                          'companyId',
                                          isEqualTo: sessao.companyId,
                                        )
                                        .snapshots(),
                                    builder: (context, snapshot) {
                                      final currentCustomerId =
                                          _sharedFiscalCustomerId(
                                            documentController.text,
                                          );
                                      final tasks =
                                          (snapshot.data?.docs ?? const [])
                                              .map(
                                                (doc) => <String, dynamic>{
                                                  'id': doc.id,
                                                  ...doc.data(),
                                                },
                                              )
                                              .where((task) {
                                                if (currentCustomerId
                                                    .isEmpty) {
                                                  return true;
                                                }
                                                final taskCustomerId =
                                                    task['clienteId']
                                                        ?.toString()
                                                        .trim() ??
                                                    '';
                                                final taskCustomerDocument =
                                                    _onlyDigits(
                                                      task['clienteDocumento']
                                                              ?.toString() ??
                                                          '',
                                                    );
                                                return taskCustomerId ==
                                                        currentCustomerId ||
                                                    taskCustomerDocument ==
                                                        currentCustomerId;
                                              })
                                              .toList()
                                            ..sort(
                                              (a, b) =>
                                                  (b['dataExecucao']
                                                              ?.toString() ??
                                                          '')
                                                      .compareTo(
                                                        a['dataExecucao']
                                                                ?.toString() ??
                                                            '',
                                                      ),
                                            );
                                      if (tasks.isEmpty) {
                                        return const SizedBox.shrink();
                                      }
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
                                        child: DropdownButtonFormField<String>(
                                          initialValue:
                                              tasks.any(
                                                (task) =>
                                                    task['id'] ==
                                                    selectedTaskId,
                                              )
                                              ? selectedTaskId
                                              : null,
                                          decoration: const InputDecoration(
                                            labelText: 'Tarefa de origem',
                                          ),
                                          items: tasks.take(20).map((task) {
                                            final name = task['nome']
                                                ?.toString()
                                                .trim();
                                            final client = task['clienteNome']
                                                ?.toString()
                                                .trim();
                                            return DropdownMenuItem(
                                              value: task['id']?.toString(),
                                              child: Text(
                                                '${(name == null || name.isEmpty) ? task['id'] : name}${(client == null || client.isEmpty) ? '' : ' - $client'}',
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (value) {
                                            Map<String, dynamic>? selected;
                                            for (final task in tasks) {
                                              if (task['id'] == value) {
                                                selected = task;
                                                break;
                                              }
                                            }
                                            if (selected == null) return;
                                            applyTaskToInvoice(selected);
                                            setStateDialog(() {
                                              selectedTaskId = value;
                                              selectedTaskData = selected;
                                              final taskCustomerId =
                                                  selected!['clienteId']
                                                      ?.toString()
                                                      .trim() ??
                                                  '';
                                              if (taskCustomerId.isNotEmpty) {
                                                selectedCustomerId =
                                                    taskCustomerId;
                                              }
                                              refreshFiscalAutomationHintsOnly();
                                            });
                                          },
                                        ),
                                      );
                                    },
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: documentController,
                                          onChanged: (_) => setStateDialog(
                                            () {},
                                          ),
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            CpfCnpjInputFormatter(),
                                          ],
                                          maxLength: 18,
                                          decoration: const InputDecoration(
                                            labelText: 'CNPJ / CPF do tomador',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      FilledButton.icon(
                                        onPressed: lookupBusy
                                            ? null
                                            : () async {
                                                final digits = _onlyDigits(
                                                  documentController.text,
                                                );
                                                if (digits.length != 14) {
                                                  _msg(
                                                    'Informe um CNPJ valido com 14 digitos.',
                                                  );
                                                  return;
                                                }
                                                setStateDialog(
                                                  () => lookupBusy = true,
                                                );
                                                try {
                                                  final result =
                                                      await _registryLookup
                                                          .lookupCnpj(digits);
                                                  clientController.text =
                                                      result['legalName']
                                                          ?.toString() ??
                                                      clientController.text;
                                                  tradeNameController.text =
                                                      result['tradeName']
                                                          ?.toString() ??
                                                      tradeNameController.text;
                                                  emailController.text =
                                                      result['email']
                                                          ?.toString() ??
                                                      emailController.text;
                                                  phoneController.text =
                                                      result['phone']
                                                          ?.toString() ??
                                                      phoneController.text;
                                                  zipCodeController.text =
                                                      result['zipCode']
                                                          ?.toString() ??
                                                      zipCodeController.text;
                                                  streetController.text =
                                                      result['street']
                                                          ?.toString() ??
                                                      streetController.text;
                                                  numberController.text =
                                                      result['number']
                                                          ?.toString() ??
                                                      numberController.text;
                                                  complementController.text =
                                                      result['complement']
                                                          ?.toString() ??
                                                      complementController.text;
                                                  neighborhoodController.text =
                                                      result['neighborhood']
                                                          ?.toString() ??
                                                      neighborhoodController
                                                          .text;
                                                  cityController.text =
                                                      result['city']
                                                          ?.toString() ??
                                                      cityController.text;
                                                  stateController.text =
                                                      result['state']
                                                          ?.toString() ??
                                                      stateController.text;
                                                  stateRegistrationController
                                                          .text =
                                                      result['stateRegistration']
                                                          ?.toString() ??
                                                      stateRegistrationController
                                                          .text;
                                                  municipalRegistrationController
                                                          .text =
                                                      result['municipalRegistration']
                                                          ?.toString() ??
                                                      municipalRegistrationController
                                                          .text;
                                                  _msg(
                                                    'Dados do CNPJ carregados.',
                                                  );
                                                } on FirebaseFunctionsException catch (
                                                  error
                                                ) {
                                                  _msg(
                                                    error.message
                                                                ?.trim()
                                                                .isNotEmpty ==
                                                            true
                                                        ? error.message!
                                                        : 'Nao foi possivel buscar o CNPJ agora.',
                                                  );
                                                } catch (_) {
                                                  _msg(
                                                    'Nao foi possivel buscar o CNPJ agora.',
                                                  );
                                                } finally {
                                                  if (context.mounted) {
                                                    setStateDialog(
                                                      () => lookupBusy = false,
                                                    );
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
                                    controller: clientController,
                                    onChanged: (_) => setStateDialog(
                                      () {},
                                    ),
                                    decoration: const InputDecoration(
                                      labelText:
                                          'Razao social / nome do tomador',
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: tradeNameController,
                                    decoration: const InputDecoration(
                                      labelText: 'Nome fantasia',
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller:
                                              municipalRegistrationController,
                                          decoration: const InputDecoration(
                                            labelText: 'Inscricao municipal',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: TextField(
                                          controller:
                                              stateRegistrationController,
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
                                          controller: emailController,
                                          decoration: const InputDecoration(
                                            labelText: 'Email',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: TextField(
                                          controller: phoneController,
                                          decoration: const InputDecoration(
                                            labelText: 'Telefone',
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
                                          decoration: const InputDecoration(
                                            labelText: 'CEP',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      const SizedBox.shrink(),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: streetController,
                                    decoration: const InputDecoration(
                                      labelText: 'Logradouro',
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: numberController,
                                          decoration: const InputDecoration(
                                            labelText: 'Numero',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: TextField(
                                          controller: complementController,
                                          decoration: const InputDecoration(
                                            labelText: 'Complemento',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: neighborhoodController,
                                    decoration: const InputDecoration(
                                      labelText: 'Bairro',
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: cityController,
                                          onChanged: (_) => setStateDialog(
                                            () {},
                                          ),
                                          decoration: const InputDecoration(
                                            labelText: 'Cidade',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      SizedBox(
                                        width: 110,
                                        child: TextField(
                                          controller: stateController,
                                          onChanged: (_) => setStateDialog(
                                            () {},
                                          ),
                                          decoration: const InputDecoration(
                                            labelText: 'UF',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Consumer(
                              builder: (context, ref, _) {
                                final catalog = ref
                                    .watch(fiscalServiceCatalogProvider);
                                final fiscalServices = [
                                  for (final item in catalog)
                                    if (item.active) item,
                                ]..sort(
                                    (a, b) => a.name
                                        .toLowerCase()
                                        .compareTo(b.name.toLowerCase()),
                                  );
                                return Column(
                                  children: [
                                    if (companyServiceOptions.isNotEmpty) ...[
                                      AppWorkspaceCard(
                                        title:
                                            'Atividades do CNPJ do prestador',
                                        subtitle:
                                            'Selecione uma atividade/CNAE da empresa para preencher codigo e descricao base do servico.',
                                        child: DropdownButtonFormField<String>(
                                          initialValue:
                                              companyServiceOptions.any(
                                                (item) =>
                                                    item.code ==
                                                    selectedCompanyActivityCode,
                                              )
                                              ? selectedCompanyActivityCode
                                              : null,
                                          decoration: const InputDecoration(
                                            labelText:
                                                'Atividade vinculada ao CNPJ',
                                          ),
                                          items: companyServiceOptions
                                              .map(
                                                (item) => DropdownMenuItem(
                                                  value: item.code,
                                                  child: Text(item.label),
                                                ),
                                              )
                                              .toList(),
                                          onChanged: (value) {
                                            final selected =
                                                companyServiceOptions
                                                    .where(
                                                      (item) =>
                                                          item.code == value,
                                                    )
                                                    .firstOrNull;
                                            if (selected == null) return;
                                            final automation =
                                                _inferFiscalAutomation(
                                                  companyData: companyData,
                                                  complianceMatrix:
                                                      complianceMatrix,
                                                  cnaeCode: selected.code,
                                                  activityDescription:
                                                      selected.description,
                                                  serviceCode:
                                                      selected.serviceCode,
                                                  cityOfIncidence:
                                                      serviceCityController
                                                          .text,
                                                  fiscalCostBearer:
                                                      fiscalCostBearer,
                                                  currentTaxRateText:
                                                      taxRateController.text,
                                                );
                                            serviceController.text =
                                                selected.description;
                                            serviceCodeController.text =
                                                selected.serviceCode;
                                            municipalServiceCodeController
                                                    .text =
                                                selected.serviceCode;
                                            cnaeController.text = selected.code;
                                            setStateDialog(() {
                                              selectedCompanyActivityCode =
                                                  value;
                                              fiscalAutomation = automation;
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                    ],
                                    if (fiscalServices.isNotEmpty) ...[
                                      AppWorkspaceCard(
                                        title: 'Servico fiscal salvo',
                                        subtitle:
                                            'Use um modelo para preencher codigos e textos. Aliquota ISS, INSS e retencoes permanecem manuais no bloco Tributacao e totais.',
                                        child: DropdownButtonFormField<String>(
                                          initialValue:
                                              fiscalServices.any(
                                                (item) =>
                                                    item.id ==
                                                    selectedFiscalServiceId,
                                              )
                                              ? selectedFiscalServiceId
                                              : null,
                                          decoration: const InputDecoration(
                                            labelText:
                                                'Modelo de servico fiscal',
                                          ),
                                          items: fiscalServices
                                              .where((item) => item.active)
                                              .map(
                                                (item) => DropdownMenuItem(
                                                  value: item.id,
                                                  child: Text(
                                                    '${item.serviceCode} - ${item.name}',
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                          onChanged: (value) {
                                            FiscalServiceItem? selected;
                                            for (final item in fiscalServices) {
                                              if (item.id == value) {
                                                selected = item;
                                                break;
                                              }
                                            }
                                            if (selected == null) return;
                                            final selectedService = selected;
                                            final automation =
                                                _inferFiscalAutomation(
                                                  companyData: companyData,
                                                  complianceMatrix:
                                                      complianceMatrix,
                                                  cnaeCode:
                                                      selectedService.cnae,
                                                  activityDescription:
                                                      selectedService.name,
                                                  serviceCode:
                                                      selectedService
                                                          .serviceCode,
                                                  cityOfIncidence: selectedService
                                                      .cityOfIncidence,
                                                  fiscalCostBearer:
                                                      fiscalCostBearer,
                                                  currentTaxRateText:
                                                      taxRateController.text,
                                                );
                                            _applyFiscalServiceToControllers(
                                              item: selectedService,
                                              serviceController:
                                                  serviceController,
                                              serviceComplementController:
                                                  serviceComplementController,
                                              serviceCodeController:
                                                  serviceCodeController,
                                              municipalServiceCodeController:
                                                  municipalServiceCodeController,
                                              cnaeController: cnaeController,
                                              serviceCityController:
                                                  serviceCityController,
                                              amountController:
                                                  amountController,
                                              taxRegimeController:
                                                  taxRegimeController,
                                              operationNatureController:
                                                  operationNatureController,
                                            );
                                            setStateDialog(() {
                                              selectedFiscalServiceId = value;
                                              fiscalAutomation = automation;
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                    ],
                                    InvoiceServiceSection(
                                      serviceCodeController:
                                          serviceCodeController,
                                      municipalServiceCodeController:
                                          municipalServiceCodeController,
                                      cnaeController: cnaeController,
                                      serviceCityController:
                                          serviceCityController,
                                      serviceController: serviceController,
                                      serviceComplementController:
                                          serviceComplementController,
                                      fiscalPaymentBankInfoController:
                                          fiscalPaymentBankInfoController,
                                      amountController: amountController,
                                      onFormChanged: () {
                                        setStateDialog(
                                          refreshFiscalAutomationHintsOnly,
                                        );
                                      },
                                      onServiceBaseChanged: () {
                                        setStateDialog(
                                          refreshFiscalAutomationHintsOnly,
                                        );
                                      },
                                      onServiceComplementChanged: () {
                                        setStateDialog(
                                          refreshFiscalAutomationHintsOnly,
                                        );
                                      },
                                      onServiceCodeChanged: (_) {
                                        setStateDialog(
                                          refreshFiscalAutomationHintsOnly,
                                        );
                                      },
                                      onServiceCityChanged: (_) {
                                        setStateDialog(
                                          refreshFiscalAutomationHintsOnly,
                                        );
                                      },
                                    ),
                                    if (useNationalEmission &&
                                        focusNationalServiceCodeRequiresCno(
                                          serviceCodeController.text,
                                        )) ...[
                                      const SizedBox(height: 12),
                                      InvoiceWorkSiteSection(
                                        workSiteNameController:
                                            workSiteNameController,
                                        workSiteCnoController:
                                            workSiteCnoController,
                                        workSiteZipCodeController:
                                            workSiteZipCodeController,
                                        workSiteStreetController:
                                            workSiteStreetController,
                                        workSiteNumberController:
                                            workSiteNumberController,
                                        workSiteComplementController:
                                            workSiteComplementController,
                                        workSiteNeighborhoodController:
                                            workSiteNeighborhoodController,
                                        workSiteCityController:
                                            workSiteCityController,
                                        workSiteStateController:
                                            workSiteStateController,
                                        cnoHelperText:
                                            'Obrigatorio para emissao NFSe Nacional com este codigo (grupo obra).',
                                        onFieldChanged: () =>
                                            setStateDialog(() {}),
                                        onWorkSiteCepSearch: searchWorkSiteCep,
                                        workSiteCepLoading: workSiteCepLookupBusy,
                                      ),
                                    ],
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                        content: Column(
                          children: [
                            Column(
                              children: [
                                InvoiceEmitterCard(
                                  companyData: companyData,
                                  title: 'Emitente da nota',
                                ),
                                const SizedBox(height: 12),
                                InvoiceFiscalHeaderSection(
                                  status: status,
                                  officialNumberController:
                                      officialNumberController,
                                  portalController: portalController,
                                  issueDateLabel: _formatDate(issueDate),
                                  serviceDateLabel: _formatDate(serviceDate),
                                  onStatusChanged: (value) {
                                    if (value != null) {
                                      setStateDialog(() => status = value);
                                    }
                                  },
                                  onIssueDatePressed: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: issueDate,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2100),
                                    );
                                    if (picked != null) {
                                      setStateDialog(() => issueDate = picked);
                                    }
                                  },
                                  onServiceDatePressed: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: serviceDate,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2100),
                                    );
                                    if (picked != null) {
                                      setStateDialog(
                                        () => serviceDate = picked,
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            InvoiceTaxSection(
                              deductionsController: deductionsController,
                              taxRateController: taxRateController,
                              inssRateController: inssRateController,
                              otherRetentionsController:
                                  otherRetentionsController,
                              taxRegimeController: taxRegimeController,
                              operationNatureController:
                                  operationNatureController,
                              issRetained: issRetained,
                              onIssRetainedChanged: (value) {
                                setStateDialog(() {
                                  issRetained = value;
                                  issRetentionListenable.value = value;
                                  operationNatureController
                                      .text = _operationNatureDisplayLabel(
                                    fiscalAutomation.operationNatureLabel,
                                    rawValue:
                                        fiscalAutomation.operationNatureCode,
                                    issRetained: issRetained,
                                  );
                                });
                              },
                              inssRetained: inssRetained,
                              onInssRetainedChanged: (value) {
                                setStateDialog(() {
                                  inssRetained = value;
                                  inssRetentionListenable.value = value;
                                });
                              },
                              totalsPreview: AnimatedBuilder(
                                animation: Listenable.merge([
                                  amountController,
                                  deductionsController,
                                  taxRateController,
                                  inssRateController,
                                  otherRetentionsController,
                                  issRetentionListenable,
                                  inssRetentionListenable,
                                  fiscalCostBearerListenable,
                                ]),
                                builder: (context, _) =>
                                    _buildInvoiceTotalsPreview(
                                      amountText: amountController.text,
                                      deductionsText: deductionsController.text,
                                      taxRateText: taxRateController.text,
                                      inssRateText: inssRateController.text,
                                      otherRetentionsText:
                                          otherRetentionsController.text,
                                      issRetained: issRetained,
                                      inssRetained: inssRetained,
                                      fiscalCostBearer: fiscalCostBearer,
                                    ),
                              ),
                              fiscalCostBearer: fiscalCostBearer,
                              onFiscalCostBearerChanged: (value) {
                                if (value != null) {
                                  setStateDialog(() {
                                    fiscalCostBearer = value;
                                    fiscalCostBearerListenable.value = value;
                                    refreshFiscalAutomationHintsOnly();
                                  });
                                }
                              },
                            ),
                            if (useNationalEmission) ...[
                              const SizedBox(height: 12),
                              AppWorkspaceCard(
                                title: 'Simples Nacional (NFS-e Nacional)',
                                subtitle:
                                    'Dados do prestador na DPS. Devem coincidir com o Simples/Receita (evita E0160). Deixe em automatico se o regime da empresa no cadastro bater com a Receita.',
                                child: DropdownButtonFormField<int?>(
                                  // ignore: deprecated_member_use
                                  value: dpsSimplesNacionalOverride,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Opcao na DPS (opSimpNac)',
                                  ),
                                  items: const [
                                    DropdownMenuItem<int?>(
                                      value: null,
                                      child: Text('Automatico (regime do emitente)'),
                                    ),
                                    DropdownMenuItem<int?>(
                                      value: 1,
                                      child: Text('1 Nao optante'),
                                    ),
                                    DropdownMenuItem<int?>(
                                      value: 2,
                                      child: Text('2 MEI'),
                                    ),
                                    DropdownMenuItem<int?>(
                                      value: 3,
                                      child: Text('3 Simples Nacional ME/EPP'),
                                    ),
                                  ],
                                  onChanged: (v) {
                                    setStateDialog(() {
                                      dpsSimplesNacionalOverride = v;
                                    });
                                  },
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            AppWorkspaceCard(
                              title: 'Automacao juridica do ISS',
                              subtitle:
                                  'Texto de apoio; a retencao do ISS na nota e definida so no bloco Tributacao e totais (interruptor).',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(bottom: 8),
                                    child: Text(
                                      'A retencao do ISS nao e mais aplicada automaticamente ao escolher atividade ou modelo de servico.',
                                      style: TextStyle(
                                        color: AppBrandColors.softText,
                                        fontWeight: FontWeight.w600,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: AppBrandColors.border,
                                      ),
                                    ),
                                    child: Text(
                                      fiscalAutomation.summary,
                                      style: const TextStyle(
                                        color: AppBrandColors.ink,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    fiscalAutomation.legalReasoning,
                                    style: const TextStyle(
                                      color: AppBrandColors.softText,
                                      height: 1.4,
                                    ),
                                  ),
                                  if (fiscalCostBearer == 'customer') ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF7ED),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: const Color(0xFFF5D0A9),
                                        ),
                                      ),
                                      child: Text(
                                        fiscalAutomation
                                            .customerCostExplanation,
                                        style: const TextStyle(
                                          color: AppBrandColors.ink,
                                          height: 1.45,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            AppWorkspaceCard(
                              title: 'Validacao rapida',
                              subtitle:
                                  'Checklist operacional antes de salvar ou emitir. Retencao do ISS e manual em Tributacao e totais.',
                              child: AnimatedBuilder(
                                animation: Listenable.merge([
                                  clientController,
                                  documentController,
                                  serviceController,
                                  serviceComplementController,
                                  serviceCodeController,
                                  municipalServiceCodeController,
                                  serviceCityController,
                                  amountController,
                                  streetController,
                                  neighborhoodController,
                                  cityController,
                                  stateController,
                                  taxRegimeController,
                                  operationNatureController,
                                  workSiteCnoController,
                                  workSiteNameController,
                                  workSiteZipCodeController,
                                  workSiteStreetController,
                                  workSiteNumberController,
                                  workSiteNeighborhoodController,
                                  workSiteCityController,
                                  workSiteStateController,
                                ]),
                                builder: (context, _) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _invoiceHintLine(
                                        'Tomador preenchido',
                                        clientController.text
                                            .trim()
                                            .isNotEmpty,
                                      ),
                                      _invoiceHintLine(
                                        'Documento informado',
                                        _onlyDigits(
                                                  documentController.text,
                                                ).length ==
                                                11 ||
                                            _onlyDigits(
                                                  documentController.text,
                                                ).length ==
                                                14,
                                      ),
                                      _invoiceHintLine(
                                        'Servico preenchido',
                                        serviceController.text
                                            .trim()
                                            .isNotEmpty,
                                      ),
                                      _invoiceHintLine(
                                        'Codigo fiscal do servico',
                                        serviceCodeController.text
                                                .trim()
                                                .isNotEmpty ||
                                            municipalServiceCodeController
                                                .text
                                                .trim()
                                                .isNotEmpty,
                                      ),
                                      _invoiceHintLine(
                                        'Municipio da incidencia informado',
                                        serviceCityController.text
                                            .trim()
                                            .isNotEmpty,
                                      ),
                                      _invoiceHintLine(
                                        'Valor informado',
                                        (_parseCurrencyToCents(
                                                  amountController.text,
                                                ) ??
                                                0) >
                                            0,
                                      ),
                                      _invoiceHintLine(
                                        'Endereco principal preenchido',
                                        streetController.text
                                                .trim()
                                                .isNotEmpty &&
                                            neighborhoodController.text
                                                .trim()
                                                .isNotEmpty &&
                                            cityController.text
                                                .trim()
                                                .isNotEmpty &&
                                            stateController.text
                                                .trim()
                                                .isNotEmpty,
                                      ),
                                      _invoiceHintLine(
                                        'Regime ou natureza fiscal informados',
                                        taxRegimeController.text
                                                .trim()
                                                .isNotEmpty ||
                                            operationNatureController.text
                                                .trim()
                                                .isNotEmpty,
                                      ),
                                      _invoiceHintLine(
                                        'Codigo e municipio para base do calculo do ISS',
                                        hasAutomaticIssBase(),
                                      ),
                                      if (useNationalEmission &&
                                          focusNationalServiceCodeRequiresCno(
                                            serviceCodeController.text,
                                          )) ...[
                                        _invoiceHintLine(
                                          'CNO da obra (obrigatorio para este codigo nacional)',
                                          workSiteCnoController.text
                                              .trim()
                                              .isNotEmpty,
                                        ),
                                        _invoiceHintLine(
                                          'Dados da obra: nome e identificacao',
                                          workSiteNameController.text
                                              .trim()
                                              .isNotEmpty,
                                        ),
                                        _invoiceHintLine(
                                          'Endereco completo da obra (CEP, rua, numero, bairro, cidade, UF)',
                                          workSiteZipCodeController.text
                                                  .trim()
                                                  .isNotEmpty &&
                                              workSiteStreetController.text
                                                  .trim()
                                                  .isNotEmpty &&
                                              workSiteNumberController.text
                                                  .trim()
                                                  .isNotEmpty &&
                                              workSiteNeighborhoodController
                                                  .text
                                                  .trim()
                                                  .isNotEmpty &&
                                              workSiteCityController.text
                                                  .trim()
                                                  .isNotEmpty &&
                                              workSiteStateController.text
                                                  .trim()
                                                  .isNotEmpty,
                                        ),
                                      ],
                                      _invoiceHintLine(
                                        'Emitente com CNPJ e inscricao municipal',
                                        _onlyDigits(
                                                  companyData['cnpj']
                                                          ?.toString() ??
                                                      '',
                                                ).length ==
                                                14 &&
                                            (companyData['inscricaoMunicipal']
                                                    ?.toString()
                                                    .trim()
                                                    .isNotEmpty ??
                                                false),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    color: const Color(0xFFE8F0FE),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Emissao oficial (pre-check alinhado a Focus)',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppBrandColors.ink,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Builder(
                            builder: (context) {
                              final d = buildCurrentInvoiceDocument();
                              if (d == null) {
                                return const Text(
                                  'Informe o valor do serviço para listar o que ainda falta para a Focus/Sefin.',
                                  style: TextStyle(
                                    color: AppBrandColors.softText,
                                    fontSize: 13,
                                  ),
                                );
                              }
                              final r = evaluateFocusOfficialIssueReadiness(
                                invoiceData: d,
                                companySettings: companySettings,
                                focusNfseNationalMode: useNationalEmission,
                              );
                              if (r.isReady) {
                                return const Text(
                                  'Pronta: sem pendencias do pre-check (mesma regra do servidor).',
                                  style: TextStyle(
                                    color: Color(0xFF1B5E20),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                );
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Ajuste antes de «Salvar e emitir»:',
                                    style: TextStyle(
                                      color: AppBrandColors.softText,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  for (final m in r.missing)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        ' - $m',
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancelar'),
                      ),
                      const Spacer(),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final invoiceId = await saveInvoiceRecord(
                            forOfficialEmission: true,
                          );
                          if (invoiceId == null) {
                            return;
                          }
                          final emitted = await _emitInvoiceOfficial(
                            sessao: sessao,
                            invoiceId: invoiceId,
                            silentSuccess: true,
                          );
                          if (!emitted || !context.mounted) {
                            return;
                          }
                          Navigator.of(context).pop();
                          _msg('Nota emitida oficialmente.');
                        },
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: const Text('Salvar e emitir'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final invoiceId = await saveInvoiceRecord();
                          if (invoiceId == null) return;
                          if (!context.mounted) return;
                          Navigator.of(context).pop();
                          _msg('Nota de servico salva.');
                        },
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Salvar nota'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
        },
      ),
    );

    issRetentionListenable.dispose();
    inssRetentionListenable.dispose();
    fiscalCostBearerListenable.dispose();

    clientController.dispose();
    tradeNameController.dispose();
    documentController.dispose();
    municipalRegistrationController.dispose();
    stateRegistrationController.dispose();
    emailController.dispose();
    phoneController.dispose();
    zipCodeController.dispose();
    streetController.dispose();
    numberController.dispose();
    complementController.dispose();
    neighborhoodController.dispose();
    cityController.dispose();
    stateController.dispose();
    serviceController.dispose();
    serviceComplementController.dispose();
    fiscalPaymentBankInfoController.dispose();
    serviceCodeController.dispose();
    municipalServiceCodeController.dispose();
    cnaeController.dispose();
    serviceCityController.dispose();
    amountController.dispose();
    deductionsController.dispose();
    taxRateController.dispose();
    otherRetentionsController.dispose();
    taxRegimeController.dispose();
    operationNatureController.dispose();
    officialNumberController.dispose();
    portalController.dispose();
    workSiteNameController.dispose();
    workSiteCnoController.dispose();
    workSiteZipCodeController.dispose();
    workSiteStreetController.dispose();
    workSiteNumberController.dispose();
    workSiteComplementController.dispose();
    workSiteNeighborhoodController.dispose();
    workSiteCityController.dispose();
    workSiteStateController.dispose();
  }

  Widget _invoiceHintLine(String label, bool done) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle_outline : Icons.radio_button_unchecked,
            color: done ? const Color(0xFF2E7D32) : AppBrandColors.softText,
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  Future<void> _saveInvoiceCustomer({
    required Session sessao,
    required InvoiceCustomer customer,
  }) async {
    final nowIso = DateTime.now().toIso8601String();
    await FirebaseFirestore.instance
        .collection('invoice_customers')
        .doc(customer.id)
        .set({
          ...customer.toMap(),
          'companyId': sessao.companyId,
          'createdAtIso': customer.createdAtIso.isEmpty
              ? nowIso
              : customer.createdAtIso,
          'updatedAtIso': nowIso,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<bool> _emitInvoiceOfficial({
    required Session sessao,
    required String invoiceId,
    bool silentSuccess = false,
  }) async {
    try {
      final callable = _fiscalFunctions.httpsCallable(
        'fiscalIssueServiceInvoice',
      );
      final response = await callable.call(<String, dynamic>{
        'invoiceId': invoiceId,
      });
      final data = response.data;
      final map = data is Map
          ? data.map((key, value) => MapEntry(key.toString(), value))
          : <String, dynamic>{};
      if (!silentSuccess) {
        final officialNumber = map['officialNumber']?.toString().trim() ?? '';
        _msg(
          officialNumber.isEmpty
              ? 'Emissao oficial concluida.'
              : 'NFS-e autorizada: $officialNumber',
        );
      }
      return true;
    } on FirebaseFunctionsException catch (e) {
      _msg(e.message ?? 'Nao foi possivel emitir oficialmente a NFS-e.');
      return false;
    } catch (_) {
      _msg('Nao foi possivel emitir oficialmente a NFS-e.');
      return false;
    }
  }

  Future<bool> _cancelInvoiceOfficial({
    required Session sessao,
    required String invoiceId,
    required String reason,
  }) async {
    try {
      final callable = _fiscalFunctions.httpsCallable(
        'fiscalCancelServiceInvoice',
      );
      await callable.call(<String, dynamic>{
        'invoiceId': invoiceId,
        'reason': reason,
      });
      _msg('Cancelamento fiscal registrado.');
      return true;
    } on FirebaseFunctionsException catch (e) {
      _msg(e.message ?? 'Nao foi possivel cancelar a NFS-e.');
      return false;
    } catch (_) {
      _msg('Nao foi possivel cancelar a NFS-e.');
      return false;
    }
  }

  Future<bool> _refreshInvoiceOfficialStatus({
    required Session sessao,
    required String invoiceId,
    bool silentSuccess = false,
  }) async {
    try {
      final callable = _fiscalFunctions.httpsCallable(
        'fiscalRefreshServiceInvoiceStatus',
      );
      final response = await callable.call(<String, dynamic>{
        'invoiceId': invoiceId,
      });
      final data = response.data;
      final map = data is Map
          ? data.map((key, value) => MapEntry(key.toString(), value))
          : <String, dynamic>{};
      if (!silentSuccess) {
        final status = map['status']?.toString().trim() ?? '';
        _msg(
          status.isEmpty
              ? 'Status oficial atualizado.'
              : 'Status oficial atualizado: ${_invoiceStatusLabel(status)}',
        );
      }
      return true;
    } on FirebaseFunctionsException catch (e) {
      _msg(
        e.message ?? 'Nao foi possivel consultar o status oficial da NFS-e.',
      );
      return false;
    } catch (_) {
      _msg('Nao foi possivel consultar o status oficial da NFS-e.');
      return false;
    }
  }

  Future<bool> _createFinanceReceivableFromInvoice({
    required Session sessao,
    required String invoiceId,
    required Map<String, dynamic> invoiceData,
  }) async {
    try {
      final existingMovementId =
          invoiceData['financeMovementId']?.toString().trim() ?? '';
      if (existingMovementId.isNotEmpty) {
        _msg('Esta nota ja possui lancamento financeiro vinculado.');
        return false;
      }

      final amountCents = (invoiceData['billing'] as Map?)?['finalAmountCents'];
      final grossCents =
          (amountCents as num?)?.toInt() ??
          (invoiceData['amountCents'] as num?)?.toInt() ??
          0;
      if (grossCents <= 0) {
        _msg('Nao foi possivel gerar financeiro para nota sem valor valido.');
        return false;
      }

      final sourceTask =
          (invoiceData['sourceTask'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{};
      final movementRef = FirebaseFirestore.instance
          .collection('finance_movements')
          .doc();
      final issueDate = _toDate(invoiceData['issueDate']);
      final dueDate = invoiceData['serviceDate'] == null
          ? issueDate
          : _toDate(invoiceData['serviceDate']);
      final clientName = invoiceData['clientName']?.toString().trim() ?? '-';
      final serviceDescription =
          invoiceData['serviceDescription']?.toString().trim() ?? '-';

      await movementRef.set({
        'companyId': sessao.companyId,
        'ownerUserId': '__COMPANY__',
        'title': 'NFS-e $clientName',
        'category': 'client_income',
        'type': 'INCOME',
        'amountCents': grossCents,
        'date': Timestamp.fromDate(issueDate),
        'dueDate': Timestamp.fromDate(dueDate),
        'paymentStatus': 'PENDING',
        'notes':
            'Origem fiscal: nota $invoiceId | Servico: $serviceDescription${sourceTask['id']?.toString().trim().isNotEmpty == true ? ' | Tarefa: ${sourceTask['id']}' : ''}',
        'sourceModule': 'fiscal',
        'sourceInvoiceId': invoiceId,
        'sourceTaskId': sourceTask['id']?.toString(),
        'sourceCustomerId': invoiceData['customerId']?.toString(),
        'sourceCustomerName': clientName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('service_invoices')
          .doc(invoiceId)
          .set({
            'financeMovementId': movementRef.id,
            'financeLinkedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      await _writeAuditLog(
        sessao: sessao,
        action: 'invoice_linked_to_finance',
        entityPath: 'service_invoices',
        entityId: invoiceId,
        after: {'financeMovementId': movementRef.id, 'sourceModule': 'fiscal'},
      );

      _msg('Conta a receber criada no financeiro.');
      return true;
    } catch (_) {
      _msg('Nao foi possivel criar o lancamento financeiro da nota.');
      return false;
    }
  }

  Future<void> _reconcileProcessingInvoices({
    required Session sessao,
    required List<String> invoiceIds,
    bool silentSuccess = false,
  }) async {
    if (_reconcilingProcessingInvoices || invoiceIds.isEmpty) {
      return;
    }
    _reconcilingProcessingInvoices = true;
    try {
      final callable = _fiscalFunctions.httpsCallable(
        'fiscalReconcileProcessingInvoices',
      );
      final response = await callable.call(<String, dynamic>{
        'invoiceIds': invoiceIds,
      });
      final data = response.data;
      final map = data is Map
          ? data.map((key, value) => MapEntry(key.toString(), value))
          : <String, dynamic>{};
      if (!silentSuccess) {
        final updatedCount = map['updatedCount'];
        final failedCount = map['failedCount'];
        _msg(
          'Conciliacao fiscal concluida. Atualizadas: ${updatedCount ?? 0} | falhas: ${failedCount ?? 0}.',
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (!silentSuccess) {
        _msg(
          e.message ?? 'Nao foi possivel reconciliar notas em processamento.',
        );
      }
    } catch (_) {
      if (!silentSuccess) {
        _msg('Nao foi possivel reconciliar notas em processamento.');
      }
    } finally {
      _reconcilingProcessingInvoices = false;
    }
  }

  Future<String?> _askCancellationReason() async {
    final controller = TextEditingController();
    String? result;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar NFS-e'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Motivo do cancelamento',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
          ElevatedButton(
            onPressed: () {
              result = controller.text.trim();
              Navigator.of(context).pop();
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  void _applyCustomerToControllers({
    required Map<String, dynamic> customer,
    required TextEditingController clientController,
    required TextEditingController tradeNameController,
    required TextEditingController documentController,
    required TextEditingController municipalRegistrationController,
    required TextEditingController stateRegistrationController,
    required TextEditingController emailController,
    required TextEditingController phoneController,
    required TextEditingController zipCodeController,
    required TextEditingController streetController,
    required TextEditingController numberController,
    required TextEditingController complementController,
    required TextEditingController neighborhoodController,
    required TextEditingController cityController,
    required TextEditingController stateController,
  }) {
    clientController.text =
        customer['legalName']?.toString() ?? clientController.text;
    tradeNameController.text =
        customer['tradeName']?.toString() ?? tradeNameController.text;
    documentController.text =
        customer['document']?.toString() ?? documentController.text;
    municipalRegistrationController.text =
        customer['municipalRegistration']?.toString() ??
        municipalRegistrationController.text;
    stateRegistrationController.text =
        customer['stateRegistration']?.toString() ??
        stateRegistrationController.text;
    emailController.text =
        customer['email']?.toString() ?? emailController.text;
    phoneController.text =
        customer['phone']?.toString() ?? phoneController.text;
    zipCodeController.text =
        customer['zipCode']?.toString() ?? zipCodeController.text;
    streetController.text =
        customer['street']?.toString() ?? streetController.text;
    numberController.text =
        customer['number']?.toString() ?? numberController.text;
    complementController.text =
        customer['complement']?.toString() ?? complementController.text;
    neighborhoodController.text =
        customer['neighborhood']?.toString() ?? neighborhoodController.text;
    cityController.text = customer['city']?.toString() ?? cityController.text;
    stateController.text =
        customer['state']?.toString() ?? stateController.text;
  }

  void _applyFiscalServiceToControllers({
    required FiscalServiceItem item,
    required TextEditingController serviceController,
    required TextEditingController serviceComplementController,
    required TextEditingController serviceCodeController,
    required TextEditingController municipalServiceCodeController,
    required TextEditingController cnaeController,
    required TextEditingController serviceCityController,
    required TextEditingController amountController,
    required TextEditingController taxRegimeController,
    required TextEditingController operationNatureController,
  }) {
    final official = item.officialDescription.trim().isNotEmpty
        ? item.officialDescription.trim()
        : item.name;
    serviceController.text = official;
    serviceComplementController.text = '';
    serviceCodeController.text = item.serviceCode;
    municipalServiceCodeController.text = item.municipalServiceCode;
    cnaeController.text = item.cnae;
    serviceCityController.text = item.cityOfIncidence;
    taxRegimeController.text = item.taxRegime;
    operationNatureController.text = _operationNatureDisplayLabel(
      item.operationNature,
    );
    if (item.defaultAmountCents > 0) {
      amountController.text = _currencyInput(item.defaultAmountCents);
    }
  }

  Future<void> _openFiscalServiceDialog({
    required Session sessao,
    required Map<String, dynamic> companySettings,
    required _FiscalRealIntegrationSetup realIntegration,
    FiscalServiceItem? editing,
  }) async {
    final nameController = TextEditingController(text: editing?.name ?? '');
    final officialDescriptionController = TextEditingController(
      text: (editing != null && editing.officialDescription.trim().isNotEmpty)
          ? editing.officialDescription
          : (editing?.name ?? ''),
    );
    final serviceCodeController = TextEditingController(
      text: editing?.serviceCode ?? '',
    );
    final municipalCodeController = TextEditingController(
      text: editing?.municipalServiceCode ?? '',
    );
    final cnaeController = TextEditingController(text: editing?.cnae ?? '');
    final cityController = TextEditingController(
      text: editing?.cityOfIncidence ?? '',
    );
    final taxRegimeController = TextEditingController(
      text: editing?.taxRegime ?? '',
    );
    final operationNatureController = TextEditingController(
      text: _operationNatureDisplayLabel(editing?.operationNature),
    );
    final amountController = TextEditingController(
      text: editing == null || editing.defaultAmountCents <= 0
          ? ''
          : _currencyInput(editing.defaultAmountCents),
    );
    var active = editing?.active ?? true;
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Text(
            editing == null ? 'Novo servico fiscal' : 'Editar servico fiscal',
          ),
          content: SizedBox(
            width: 640,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nome do servico',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: officialDescriptionController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Descricao oficial para a nota (DPS)',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: serviceCodeController,
                          decoration: const InputDecoration(
                            labelText: 'Codigo do servico',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: municipalCodeController,
                          decoration: const InputDecoration(
                            labelText: 'Codigo municipal',
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
                          controller: cnaeController,
                          decoration: const InputDecoration(labelText: 'CNAE'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: cityController,
                          decoration: const InputDecoration(
                            labelText: 'Municipio da incidencia',
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
                          controller: taxRegimeController,
                          decoration: const InputDecoration(
                            labelText: 'Regime tributario',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Valor padrao (R\$)',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: operationNatureController,
                    decoration: const InputDecoration(
                      labelText: 'Natureza da operacao',
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: active,
                    onChanged: (value) => setStateDialog(() => active = value),
                    title: const Text('Ativo no emissor'),
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
              onPressed: saving
                  ? null
                  : () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  _msg(
                    'Informe o nome do servico fiscal.',
                    messageContext: ctx,
                  );
                  return;
                }
                final off = officialDescriptionController.text.trim();
                final amount =
                    _parseCurrencyToCents(amountController.text) ?? 0;
                final normalized = _normalizeFiscalServiceItemForRoute(
                  item: FiscalServiceItem(
                    id:
                        editing?.id ??
                        DateTime.now().microsecondsSinceEpoch.toString(),
                    companyId: sessao.companyId,
                    name: name,
                    serviceCode: serviceCodeController.text.trim(),
                    municipalServiceCode: municipalCodeController.text.trim(),
                    cnae: cnaeController.text.trim(),
                    cityOfIncidence: cityController.text.trim(),
                    taxRegime: taxRegimeController.text.trim(),
                    operationNature: operationNatureController.text.trim(),
                    officialDescription: off.isNotEmpty ? off : name,
                    defaultAmountCents: amount,
                    active: active,
                  ),
                  companySettings: companySettings,
                  setup: realIntegration,
                );
                if (normalized.errorMessage != null) {
                  _msg(normalized.errorMessage!, messageContext: ctx);
                  return;
                }
                setStateDialog(() {
                  saving = true;
                });
                try {
                  await ref
                      .read(fiscalServiceCatalogProvider.notifier)
                      .save(normalized.item!, isNew: editing == null);
                } catch (e) {
                  final message = AppErrorMapper.messageFrom(
                    e,
                    fallback:
                        'Nao foi possivel salvar o servico fiscal. Verifique conexao e permissoes.',
                  );
                  if (!ctx.mounted) {
                    _msg(message);
                    return;
                  }
                  setStateDialog(() {
                    saving = false;
                  });
                  _msg(message, messageContext: ctx);
                  return;
                }
                if (!mounted) return;
                Navigator.of(context, rootNavigator: true).pop();
                _msg('Servico fiscal salvo.');
              },
              child: Text(saving ? 'Salvando...' : 'Salvar'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    officialDescriptionController.dispose();
    serviceCodeController.dispose();
    municipalCodeController.dispose();
    cnaeController.dispose();
    cityController.dispose();
    taxRegimeController.dispose();
    operationNatureController.dispose();
    amountController.dispose();
  }

  /// Base unica para tela, Firestore e emissao Focus (ISS/INSS/liquido).
  ({
    int taxableBaseCents,
    int issAmountCents,
    int inssAmountCents,
    int netAmountCents,
    int fiscalCostAmountCents,
    int finalAmountCents,
  }) _computeServiceInvoiceTaxAmounts({
    required int grossAmountCents,
    required int deductionsCents,
    required int otherRetentionsCents,
    required double issRatePercent,
    required double inssRatePercent,
    required bool issRetained,
    required bool inssRetained,
    required String fiscalCostBearer,
  }) {
    final taxableBase = grossAmountCents - deductionsCents;
    final base = taxableBase < 0 ? 0 : taxableBase;
    final iss = base <= 0 ? 0 : ((base * issRatePercent) / 100).round();
    final inss = (!inssRetained || base <= 0)
        ? 0
        : ((base * inssRatePercent) / 100).round();
    final netAfterIss = issRetained ? base - iss : base;
    var net = netAfterIss - inss - otherRetentionsCents;
    if (net < 0) net = 0;
    final fiscalCost = iss + inss + otherRetentionsCents;
    var finalAmt = fiscalCostBearer == 'customer'
        ? grossAmountCents + fiscalCost
        : grossAmountCents;
    if (finalAmt < 0) finalAmt = 0;
    return (
      taxableBaseCents: base,
      issAmountCents: iss,
      inssAmountCents: inss,
      netAmountCents: net,
      fiscalCostAmountCents: fiscalCost < 0 ? 0 : fiscalCost,
      finalAmountCents: finalAmt,
    );
  }

  Widget _buildInvoiceTotalsPreview({
    required String amountText,
    required String deductionsText,
    required String taxRateText,
    required String inssRateText,
    required String otherRetentionsText,
    required bool issRetained,
    required bool inssRetained,
    required String fiscalCostBearer,
  }) {
    final gross = _parseCurrencyToCents(amountText) ?? 0;
    final deductions = _parseCurrencyToCents(deductionsText) ?? 0;
    final otherRetentions = _parseCurrencyToCents(otherRetentionsText) ?? 0;
    final t = _computeServiceInvoiceTaxAmounts(
      grossAmountCents: gross,
      deductionsCents: deductions,
      otherRetentionsCents: otherRetentions,
      issRatePercent: _parsePercent(taxRateText),
      inssRatePercent: _parsePercent(inssRateText),
      issRetained: issRetained,
      inssRetained: inssRetained,
      fiscalCostBearer: fiscalCostBearer,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Totais (mesma regra do salvamento e da Focus: valor_iss, valor_cp, valor_liquido).',
          style: TextStyle(
            color: AppBrandColors.softText,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _summaryChip('Base calculo', _formatCurrency(t.taxableBaseCents)),
            _summaryChip('ISS (monetario)', _formatCurrency(t.issAmountCents)),
            _summaryChip('INSS/CP (monetario)', _formatCurrency(t.inssAmountCents)),
            _summaryChip(
              'Outras retencoes',
              _formatCurrency(otherRetentions < 0 ? 0 : otherRetentions),
            ),
            _summaryChip(
              'Custo fiscal',
              _formatCurrency(t.fiscalCostAmountCents),
            ),
            _summaryChip(
              'Valor final da nota',
              _formatCurrency(t.finalAmountCents),
            ),
            _summaryChip('Valor liquido', _formatCurrency(t.netAmountCents)),
          ],
        ),
      ],
    );
  }

  Map<String, dynamic> _buildEmitterPayload(Map<String, dynamic> companyData) {
    final addressLine = [
      companyData['endereco']?.toString().trim(),
      companyData['rua']?.toString().trim(),
      companyData['cidade']?.toString().trim(),
      companyData['estado']?.toString().trim(),
    ].whereType<String>().where((part) => part.isNotEmpty).join(' | ');
    return {
      'legalName':
          companyData['razaoSocial']?.toString().trim().isNotEmpty == true
          ? companyData['razaoSocial'].toString().trim()
          : companyData['nomeFantasia']?.toString().trim() ?? '',
      'tradeName': companyData['nomeFantasia']?.toString().trim() ?? '',
      'cnpj': companyData['cnpj']?.toString().trim() ?? '',
      'document': companyData['cnpj']?.toString().trim() ?? '',
      'stateRegistration':
          companyData['inscricaoEstadual']?.toString().trim() ?? '',
      'municipalRegistration':
          companyData['inscricaoMunicipal']?.toString().trim() ?? '',
      'email': companyData['email']?.toString().trim() ?? '',
      'phone': companyData['telefone']?.toString().trim() ?? '',
      'zipCode': companyData['cep']?.toString().trim() ?? '',
      'street': companyData['rua']?.toString().trim() ?? '',
      'number': companyData['numero']?.toString().trim() ?? '',
      'complement': companyData['complemento']?.toString().trim() ?? '',
      'neighborhood': companyData['bairro']?.toString().trim() ?? '',
      'city': companyData['cidade']?.toString().trim() ?? '',
      'state': companyData['estado']?.toString().trim() ?? '',
      'addressLine': addressLine,
      'mainCnae': companyData['mainCnae']?.toString().trim() ?? '',
      'mainCnaeDescription':
          companyData['mainCnaeDescription']?.toString().trim() ?? '',
      'legalNature': companyData['legalNature']?.toString().trim() ?? '',
      'taxRegime': _inferTaxRegime(companyData),
      'fiscalPaymentBankInfo':
          companyData['fiscalPaymentBankInfo']?.toString().trim() ?? '',
    };
  }

  String _inferTaxRegime(Map<String, dynamic> companyData) {
    final explicit = companyData['regimeTributario']?.toString().trim() ?? '';
    if (explicit.isNotEmpty) return explicit;
    final legalNature =
        companyData['legalNature']?.toString().toLowerCase() ?? '';
    final companySize =
        companyData['companySize']?.toString().toLowerCase() ?? '';
    if (legalNature.contains('mei')) return 'MEI / Simples Nacional';
    if (companySize.contains('micro') || companySize.contains('pequeno')) {
      return 'Simples Nacional';
    }
    return 'Regime a validar com contador';
  }

  bool _companyIsServiceBusiness(Map<String, dynamic> companyData) {
    if (companyData['inscricaoEstadualDispensada'] == true) return true;
    final businessCategory =
        companyData['businessCategory']?.toString().trim().toLowerCase() ?? '';
    if (businessCategory == 'service') return true;
    final mainCnaeDescription =
        companyData['mainCnaeDescription']?.toString().trim().toLowerCase() ??
        '';
    return mainCnaeDescription.contains('servic');
  }

  String _normalizeServiceCodeFromCnae(String value) {
    final digits = _onlyDigits(value);
    if (digits.isEmpty) return '';
    if (digits.length <= 5) return digits;
    return digits.substring(0, 5);
  }

  Future<void> _prepareFiscalBaseFromCompany({
    required Session sessao,
    required Map<String, dynamic> companyData,
    required Map<String, dynamic> companySettings,
    required _FiscalRealIntegrationSetup current,
  }) async {
    final cnpj = _onlyDigits(companyData['cnpj']);
    if (cnpj.length != 14) {
      _msg('Cadastre um CNPJ valido da empresa para preparar o fiscal.');
      return;
    }

    try {
      final settingsBefore = await FirebaseFirestore.instance
          .collection('company_settings')
          .doc(sessao.companyId)
          .get();
      final previousFeatures =
          (settingsBefore.data()?['fiscalFeatures'] as Map?)
              ?.cast<String, dynamic>() ??
          <String, dynamic>{};
      final result = await _registryLookup.lookupCnpj(cnpj);
      final inferredServiceBusiness = _companyIsServiceBusiness({
        ...companyData,
        'mainCnaeDescription':
            result['mainCnaeDescription']?.toString().trim().isNotEmpty == true
            ? result['mainCnaeDescription']
            : companyData['mainCnaeDescription'],
      });
      final mergedCompanyData = {
        ...companyData,
        'cnpj': companyData['cnpj']?.toString().trim().isNotEmpty == true
            ? companyData['cnpj']
            : cnpj,
        'razaoSocial': result['legalName']?.toString().trim().isNotEmpty == true
            ? result['legalName']
            : companyData['razaoSocial'],
        'nomeFantasia':
            result['tradeName']?.toString().trim().isNotEmpty == true
            ? result['tradeName']
            : companyData['nomeFantasia'],
        'email': result['email']?.toString().trim().isNotEmpty == true
            ? result['email']
            : companyData['email'],
        'telefone': result['phone']?.toString().trim().isNotEmpty == true
            ? result['phone']
            : companyData['telefone'],
        'cep': result['zipCode']?.toString().trim().isNotEmpty == true
            ? result['zipCode']
            : companyData['cep'],
        'rua': result['street']?.toString().trim().isNotEmpty == true
            ? result['street']
            : companyData['rua'],
        'numero': result['number']?.toString().trim().isNotEmpty == true
            ? result['number']
            : companyData['numero'],
        'complemento':
            result['complement']?.toString().trim().isNotEmpty == true
            ? result['complement']
            : companyData['complemento'],
        'bairro': result['neighborhood']?.toString().trim().isNotEmpty == true
            ? result['neighborhood']
            : companyData['bairro'],
        'cidade': result['city']?.toString().trim().isNotEmpty == true
            ? result['city']
            : companyData['cidade'],
        'estado': result['state']?.toString().trim().isNotEmpty == true
            ? result['state']
            : companyData['estado'],
        'inscricaoEstadual':
            result['stateRegistration']?.toString().trim().isNotEmpty == true
            ? result['stateRegistration']
            : companyData['inscricaoEstadual'],
        'inscricaoMunicipal':
            result['municipalRegistration']?.toString().trim().isNotEmpty ==
                true
            ? result['municipalRegistration']
            : companyData['inscricaoMunicipal'],
        'mainCnae': result['mainCnae']?.toString().trim().isNotEmpty == true
            ? result['mainCnae']
            : companyData['mainCnae'],
        'mainCnaeDescription':
            result['mainCnaeDescription']?.toString().trim().isNotEmpty == true
            ? result['mainCnaeDescription']
            : companyData['mainCnaeDescription'],
        'secondaryCnaes': (result['secondaryCnaes'] as List?) ?? const [],
        'legalNature':
            result['legalNature']?.toString().trim().isNotEmpty == true
            ? result['legalNature']
            : companyData['legalNature'],
        'companySize':
            result['companySize']?.toString().trim().isNotEmpty == true
            ? result['companySize']
            : companyData['companySize'],
        'status': result['status']?.toString().trim().isNotEmpty == true
            ? result['status']
            : companyData['status'],
        'businessCategory': inferredServiceBusiness
            ? 'service'
            : (companyData['businessCategory']?.toString().trim().isNotEmpty ==
                      true
                  ? companyData['businessCategory']
                  : 'mixed'),
        'inscricaoEstadualDispensada': inferredServiceBusiness,
        'inscricaoMunicipalObrigatoria': inferredServiceBusiness,
      };
      mergedCompanyData['regimeTributario'] = _inferTaxRegime(
        mergedCompanyData,
      );

      final setup = current.copyWith(
        environment: current.environment.trim().isEmpty
            ? 'homologacao'
            : current.environment,
        provider: current.provider.trim().isEmpty
            ? 'Prefeitura / integrador a definir'
            : current.provider,
        focusNfseApi: current.focusNfseApi.trim().isEmpty
            ? 'municipal'
            : current.focusNfseApi,
        municipalCode: current.municipalCode.trim().isNotEmpty
            ? current.municipalCode
            : _normalizeServiceCodeFromCnae(mergedCompanyData['mainCnae']),
        lastHomologationNote: current.lastHomologationNote.trim().isEmpty
            ? 'Base automatica criada a partir do CNPJ da empresa. Validar certificado, municipio e provedor antes da emissao oficial.'
            : current.lastHomologationNote,
      );

      final mergedFiscalSettings = {
        ...?settingsBefore.data(),
        ...companySettings,
      };

      final autoDefaults = _FiscalAutoDefaults.fromData(
        companyData: mergedCompanyData,
        companySettings: mergedFiscalSettings,
        realIntegration: setup,
        savedServices: const <FiscalServiceItem>[],
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(sessao.userId)
          .set({
            'companyData': mergedCompanyData,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('company_settings')
          .doc(sessao.companyId)
          .set({
            'companyId': sessao.companyId,
            'fiscalRealIntegration': setup.toMap(),
            'fiscalAutoDefaults': autoDefaults.toMap(),
            'fiscalFeatures': {
              ...previousFeatures,
              'enableOfficialInvoicePrep': true,
              'enableRealInvoiceIntegration': setup.isPrepared,
            },
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      final generatedServices = _buildGeneratedFiscalServices(
        companyId: sessao.companyId,
        companyData: mergedCompanyData,
        autoDefaults: autoDefaults,
        companySettings: mergedFiscalSettings,
        setup: setup,
      );
      final complianceMatrix = _buildComplianceMatrix(
        setup: setup,
        companyData: mergedCompanyData,
        generatedServices: generatedServices,
      );
      for (final item in generatedServices) {
        final normalized = _normalizeFiscalServiceItemForRoute(
          item: item,
          companySettings: mergedFiscalSettings,
          setup: setup,
        );
        if (normalized.item == null) continue;
        await ref
            .read(fiscalServiceCatalogProvider.notifier)
            .save(normalized.item!);
      }

      await FirebaseFirestore.instance
          .collection('company_settings')
          .doc(sessao.companyId)
          .set({
            'companyId': sessao.companyId,
            'fiscalComplianceMatrix': complianceMatrix.toMap(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      await _refreshCompanyProvisioning(
        successMessage:
            'Base fiscal desta empresa preparada e automacao de provisionamento reprocessada.',
      );
    } catch (_) {
      _msg('Nao foi possivel preparar a base fiscal pelo CNPJ agora.');
    }
  }

  Future<void> _previewInvoicePdf({
    required Map<String, dynamic> companyData,
    required Map<String, dynamic> data,
  }) async {
    try {
      final service =
          (data['service'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{};
      final tax =
          (data['tax'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          build: (_) => [
            pw.Text(
              'Documento auxiliar de NFS-e / Nota de servico',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              'Empresa: ${companyData['nomeFantasia'] ?? companyData['razaoSocial'] ?? '-'}',
            ),
            pw.Text('CNPJ: ${companyData['cnpj'] ?? '-'}'),
            pw.Text('Cliente: ${data['clientName'] ?? '-'}'),
            pw.Text('CPF/CNPJ cliente: ${data['clientDocument'] ?? '-'}'),
            if ((((data['sourceTask'] as Map?)?['id']?.toString().trim() ?? '')
                .isNotEmpty))
              pw.Text('Origem operacional: ${_invoiceSourceTaskLabel(data)}'),
            pw.Text(
              'Descricao do servico: ${data['serviceDescription'] ?? '-'}',
            ),
            if ((service['serviceCode']?.toString().trim() ?? '').isNotEmpty)
              pw.Text('Codigo do servico: ${service['serviceCode']}'),
            if ((service['municipalServiceCode']?.toString().trim() ?? '')
                .isNotEmpty)
              pw.Text('Codigo municipal: ${service['municipalServiceCode']}'),
            if ((service['cnae']?.toString().trim() ?? '').isNotEmpty)
              pw.Text('CNAE: ${service['cnae']}'),
            if ((service['cityOfIncidence']?.toString().trim() ?? '')
                .isNotEmpty)
              pw.Text('Municipio da incidencia: ${service['cityOfIncidence']}'),
            pw.Text(
              'Valor: ${_formatCurrency((data['amountCents'] as num?)?.toInt() ?? 0)}',
            ),
            pw.Text(
              'Base de calculo: ${_formatCurrency((tax['taxableBaseCents'] as num?)?.toInt() ?? 0)}',
            ),
            pw.Text(
              'ISS estimado: ${_formatCurrency((tax['issAmountCents'] as num?)?.toInt() ?? 0)}',
            ),
            if ((tax['taxRegime']?.toString().trim() ?? '').isNotEmpty)
              pw.Text('Regime tributario: ${tax['taxRegime']}'),
            if ((tax['operationNature']?.toString().trim() ?? '').isNotEmpty ||
                (tax['operationNatureLabel']?.toString().trim() ?? '')
                    .isNotEmpty)
              pw.Text(
                'Natureza da operacao: ${_operationNatureDisplayLabel(tax['operationNatureLabel']?.toString(), rawValue: tax['operationNature']?.toString())}',
              ),
            pw.Text(
              'Data do servico: ${_formatDate(_toDate(data['serviceDate']))}',
            ),
            pw.Text(
              'Data de emissao: ${_formatDate(_toDate(data['issueDate']))}',
            ),
            pw.Text(
              'Status: ${_invoiceStatusLabel(data['status']?.toString())}',
            ),
            pw.Text('Numero oficial: ${_invoiceOfficialNumber(data).isEmpty ? '-' : _invoiceOfficialNumber(data)}'),
            pw.Text('Portal oficial: ${data['officialPortalUrl'] ?? '-'}'),
            if ((data['financeMovementId']?.toString().trim() ?? '').isNotEmpty)
              pw.Text('Financeiro vinculado: ${data['financeMovementId']}'),
            pw.SizedBox(height: 12),
            pw.Text(
              'Observacao: este documento serve como espelho operacional interno. A emissao fiscal oficial depende do ambiente oficial da prefeitura/NFS-e.',
            ),
          ],
        ),
      );
      await Printing.layoutPdf(onLayout: (_) => pdf.save());
    } catch (_) {
      _msg('Nao foi possivel gerar o PDF da nota.');
    }
  }

  Future<void> _openUrl(String? url) async {
    final parsed = Uri.tryParse(url ?? '');
    if (parsed == null) {
      _msg('Link do portal invalido.');
      return;
    }
    await launchUrl(parsed, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final sessao = ref.watch(sessionProvider);
    final runtimeSummary = ref.watch(companyRuntimeSummaryProvider).valueOrNull;
    final summaryFiscal =
        (runtimeSummary?['fiscal'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};

    int summaryCount(String key) {
      final value = summaryFiscal[key];
      if (value is num) return value.toInt();
      return 0;
    }

    int summaryCents(String key) {
      final value = summaryFiscal[key];
      if (value is num) return value.toInt();
      return 0;
    }

    if (sessao == null) {
      return const Scaffold(body: Center(child: Text('Sem sessao ativa.')));
    }
    if (sessao.role == Role.employee) {
      ref.read(shellPageChromeProvider.notifier).state = const ShellPageChrome();
      return const Scaffold(
        body: Center(
          child: Text('Modulo fiscal disponivel apenas para empresa/gerencia.'),
        ),
      );
    }

    final competence = _competenceController.text.trim();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(sessao.userId)
          .snapshots(),
      builder: (context, companyUserSnapshot) {
        final userCompanyData =
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
            final settingsCompanyData =
                (companySettings['companyData'] as Map?)
                    ?.cast<String, dynamic>() ??
                <String, dynamic>{};
            final hasConfiguredCompanyData = settingsCompanyData.isNotEmpty;
            final companyData = sessao.role == Role.accountant
                ? (hasConfiguredCompanyData
                      ? <String, dynamic>{...settingsCompanyData}
                      : <String, dynamic>{...userCompanyData})
                : <String, dynamic>{...userCompanyData, ...settingsCompanyData};
            final fiscalSettings = _FiscalSettings.fromSettings(
              companySettings,
            );
            final realIntegration = _FiscalRealIntegrationSetup.fromSettings(
              companySettings,
            );
            final canConfigureModule =
                !sessao.isDemo &&
                (sessao.role == Role.owner ||
                    sessao.role == Role.manager ||
                    sessao.role == Role.accountant);
            /// Provedor/ambiente/API global Focus: so a empresa suprema altera; demais
            /// empresas completam certificado, matriz, homologacao e sync por CNPJ.
            final canEditGlobalFiscalIntegration = hasSupremePlatformAccess(sessao);
            final canManageInvoices =
                !sessao.isDemo &&
                (sessao.role == Role.owner ||
                    sessao.role == Role.manager ||
                    sessao.role == Role.accountant);
            final companyProfile =
                companySettings['companyOperationalProfile']?.toString() ??
                'small_business';
            ref.read(shellPageChromeProvider.notifier).state = ShellPageChrome(
              header: AppWorkspaceHeader(
                title: 'Fiscal',
                subtitle:
                    'Emita notas, confira dados fiscais da empresa e acompanhe as notas em um lugar so.',
                chips: [
                  AppHeaderChip(_companyProfileLabel(companyProfile)),
                  AppHeaderChip('Competencia $competence'),
                  AppHeaderChip(
                    fiscalSettings.enableOfficialInvoicePrep
                        ? 'NFS-e ativa'
                        : 'NFS-e desligada',
                  ),
                  AppHeaderChip(realIntegration.readinessLabel),
                ],
              ),
            );

            return AppGradientBackground(
              child: AppPageLayout(
                child: ListView(
                    children: [
                      AppWorkspaceCard(
                        title: 'Resumo fiscal',
                        subtitle:
                            'Veja rapido como esta a parte fiscal da empresa e o que falta para emitir.',
                        child: Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            AppMetricCard(
                              label: 'Perfil',
                              value: _companyProfileLabel(companyProfile),
                              caption: 'Perfil operacional da empresa',
                            ),
                            AppMetricCard(
                              label: 'Competencia',
                              value: competence,
                              caption: 'Recorte fiscal atual',
                            ),
                            AppMetricCard(
                              label: 'NFS-e',
                              value: fiscalSettings.enableOfficialInvoicePrep
                                  ? 'Ativa'
                                  : 'Desligada',
                              caption: 'Preparacao da emissao oficial',
                            ),
                            AppMetricCard(
                              label: 'Integracao',
                              value: realIntegration.readinessLabel,
                              caption: 'Estado da camada real',
                            ),
                            if (summaryFiscal.isNotEmpty) ...[
                              AppMetricCard(
                                label: 'Aprovadas (Sefin / Focus)',
                                value: summaryCount(
                                  'approvedInvoicesCount',
                                ).toString(),
                                caption: 'Notas autorizadas com numero oficial',
                              ),
                              AppMetricCard(
                                label: 'Valor bruto (registradas)',
                                value: _formatCurrency(
                                  summaryCents('emittedGrossAmountCents'),
                                ),
                                caption:
                                    'Soma de emitidas e aprovadas com numero',
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      FocusIncomingXmlSection(session: sessao),
                      const SizedBox(height: 16),
                      AppDesktopSplit(
                        sidebar: Column(
                          children: [
                            _buildSettingsCard(
                              sessao: sessao,
                              settings: fiscalSettings,
                              canConfigureModule: canConfigureModule,
                              canEditGlobalFiscalIntegration:
                                  canEditGlobalFiscalIntegration,
                            ),
                            const SizedBox(height: 12),
                            _buildRealIntegrationCard(
                              sessao: sessao,
                              companyData: companyData,
                              companySettings: companySettings,
                              setup: realIntegration,
                              canConfigureModule: canConfigureModule,
                              canEditGlobalFiscalIntegration:
                                  canEditGlobalFiscalIntegration,
                            ),
                            const SizedBox(height: 12),
                            _buildFiscalPaymentReceiptCard(
                              sessao: sessao,
                              companyData: companyData,
                              fiscalSettings: fiscalSettings,
                              canManageInvoices: canManageInvoices,
                            ),
                            const SizedBox(height: 12),
                            AppWorkspaceCard(
                              title: 'Competencia fiscal',
                              subtitle:
                                  'Navegue entre meses para conferencia, checklist e emissao.',
                              child: _buildCompetenceHeader(competence),
                            ),
                          ],
                        ),
                        content: Column(
                          children: [
                            AppWorkspaceCard(
                              title: 'Resumo fiscal',
                              child: _buildOverviewCards(
                                sessao: sessao,
                                competence: competence,
                                summaryFiscal: summaryFiscal,
                              ),
                            ),
                            if (fiscalSettings.enableOfficialInvoicePrep) ...[
                              const SizedBox(height: 16),
                              AppWorkspaceCard(
                                title: 'NFS-e oficial',
                                child: _buildInvoiceSection(
                                  sessao: sessao,
                                  companyData: companyData,
                                  companySettings: companySettings,
                                  realIntegration: realIntegration,
                                  competence: competence,
                                  canManageInvoices: canManageInvoices,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCompetenceHeader(String competence) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppBrandColors.border),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              final parsed = _parseCompetence(competence);
              if (parsed == null) return;
              final date = DateTime(parsed.$1, parsed.$2 - 1, 1);
              setState(() {
                _competenceController.text =
                    '${date.year}-${date.month.toString().padLeft(2, '0')}';
              });
            },
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Text(
              competence,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
          IconButton(
            onPressed: () {
              final parsed = _parseCompetence(competence);
              if (parsed == null) return;
              final date = DateTime(parsed.$1, parsed.$2 + 1, 1);
              setState(() {
                _competenceController.text =
                    '${date.year}-${date.month.toString().padLeft(2, '0')}';
              });
            },
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard({
    required Session sessao,
    required _FiscalSettings settings,
    required bool canConfigureModule,
    required bool canEditGlobalFiscalIntegration,
  }) {
    final canEditFocusIntegration =
        canConfigureModule && canEditGlobalFiscalIntegration;
    return AppWorkspaceCard(
      title: 'Modo fiscal',
      subtitle: canEditGlobalFiscalIntegration
          ? 'Nivel de operacao fiscal e integracao com a plataforma.'
          : 'A integracao com a Focus fica na empresa suprema. Aqui a empresa liga a preparacao de NFS-e e segue o provisionamento, sincronizacao e emissao.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Simples'),
                selected: settings.mode == _FiscalMode.simple,
                onSelected: canConfigureModule
                    ? (_) =>
                          _saveFiscalSettings(sessao, settings.simplePreset())
                    : null,
              ),
              ChoiceChip(
                label: const Text('Completo'),
                selected: settings.mode == _FiscalMode.advanced,
                onSelected: canConfigureModule
                    ? (_) =>
                          _saveFiscalSettings(sessao, settings.advancedPreset())
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _featureToggle(
                label: 'NFS-e oficial',
                value: settings.enableOfficialInvoicePrep,
                onChanged: canConfigureModule
                    ? (value) => _saveFiscalSettings(
                        sessao,
                        settings.copyWith(enableOfficialInvoicePrep: value),
                      )
                    : null,
              ),
              _featureToggle(
                label: 'Integracao real (Focus)',
                value: settings.enableRealInvoiceIntegration,
                onChanged: canEditFocusIntegration
                    ? (value) => _saveFiscalSettings(
                        sessao,
                        settings.copyWith(enableRealInvoiceIntegration: value),
                      )
                    : null,
              ),
            ],
          ),
          if (canConfigureModule && !canEditGlobalFiscalIntegration) ...[
            const SizedBox(height: 8),
            const Text(
              'A «Integracao real (Focus)» so a empresa suprema liga. Ative a preparacao de NFS-e acima, '
              'conclua o provisionamento, sincronize e emita.',
              style: TextStyle(
                color: AppBrandColors.softText,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (!canConfigureModule)
            OutlinedButton.icon(
              onPressed: () =>
                  _openFiscalSettingsRequestDialog(sessao, settings),
              icon: const Icon(Icons.lock_clock_outlined),
              label: const Text('Solicitar ajuste sensivel'),
            ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('period_closes')
                .where('companyId', isEqualTo: sessao.companyId)
                .snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? const [];
              final pending = docs
                  .where(
                    (doc) =>
                        doc.data()['module']?.toString() ==
                            'fiscal_settings_change' &&
                        doc.data()['status']?.toString() == 'PENDING_APPROVAL',
                  )
                  .toList();
              final resolved =
                  docs
                      .where(
                        (doc) =>
                            doc.data()['module']?.toString() ==
                                'fiscal_settings_change' &&
                            (doc.data()['status']?.toString() == 'APPROVED' ||
                                doc.data()['status']?.toString() == 'REJECTED'),
                      )
                      .toList()
                    ..sort(
                      (a, b) => _toDate(
                        b.data()['resolvedAt'],
                      ).compareTo(_toDate(a.data()['resolvedAt'])),
                    );

              if (pending.isEmpty && resolved.isEmpty) {
                return const SizedBox.shrink();
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'Solicitacoes fiscais',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  for (final doc in pending)
                    _buildFiscalSettingsRequestTile(
                      sessao: sessao,
                      doc: doc,
                      canConfigureModule: canConfigureModule,
                    ),
                  for (final doc in resolved.take(6))
                    _buildFiscalSettingsResolvedTile(doc.data()),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCards({
    required Session sessao,
    required String competence,
    required Map<String, dynamic> summaryFiscal,
  }) {
    if (summaryFiscal.isNotEmpty) {
      int count(String key) {
        final value = summaryFiscal[key];
        if (value is num) return value.toInt();
        return 0;
      }

      int cents(String key) {
        final value = summaryFiscal[key];
        if (value is num) return value.toInt();
        return 0;
      }

      final draftCount = count('draftInvoicesCount');
      final approvedCount = count('approvedInvoicesCount');
      final canceledCount = count('canceledInvoicesCount');
      final processingCount = count('processingInvoicesCount');
      final totalInvoices = draftCount +
          approvedCount +
          canceledCount +
          processingCount;

      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _summaryChip('Notas no sistema', totalInvoices.toString()),
          _summaryChip('Rascunhos', draftCount.toString()),
          _summaryChip('Aprovadas / autorizadas', approvedCount.toString()),
          _summaryChip('Em processamento', processingCount.toString()),
          _summaryChip('Canceladas', canceledCount.toString()),
          _summaryChip(
            'Valor bruto (registradas)',
            _formatCurrency(cents('emittedGrossAmountCents')),
          ),
          _summaryChip('Operacao', 'Resumo agregado'),
        ],
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('service_invoices')
          .where('companyId', isEqualTo: sessao.companyId)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        final competenceDocs = docs.where((doc) {
          final referenceDate = _invoiceReferenceDate(doc.data());
          final currentCompetence =
              '${referenceDate.year}-${referenceDate.month.toString().padLeft(2, '0')}';
          return currentCompetence == competence;
        }).toList();
        var grossOfficialCents = 0;
        var approvedWithOfficial = 0;
        var draftCount = 0;
        var canceledCount = 0;
        var processingCount = 0;
        for (final doc in competenceDocs) {
          final d = doc.data();
          final st = (d['status']?.toString() ?? 'DRAFT').toUpperCase();
          if (st == 'CANCELED' || st == 'CANCELLED') {
            canceledCount++;
            continue;
          }
          if (_fiscalStatusIsApprovedOrLegacyEmitted(st) &&
              _mapHasOfficialNfsNumber(d)) {
            approvedWithOfficial++;
            grossOfficialCents += _invoiceGrossAmount(d);
            continue;
          }
          if (_mapIsFiscalEmissionProcessing(d)) {
            processingCount++;
            continue;
          }
          draftCount++;
        }
        final customers = docs
            .where(
              (doc) => ((doc.data()['clientDocument']?.toString() ?? '')
                  .trim()
                  .isNotEmpty),
            )
            .map((doc) => doc.data()['clientDocument'].toString())
            .toSet()
            .length;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _summaryChip(
              'Notas na competencia',
              competenceDocs.length.toString(),
            ),
            _summaryChip('Rascunhos', draftCount.toString()),
            _summaryChip(
              'Aprovadas / autorizadas',
              approvedWithOfficial.toString(),
            ),
            _summaryChip('Em processamento', processingCount.toString()),
            _summaryChip('Canceladas', canceledCount.toString()),
            _summaryChip(
              'Valor bruto (registradas)',
              _formatCurrency(grossOfficialCents),
            ),
            _summaryChip('Tomadores', customers.toString()),
            _summaryChip('Operacao', 'Fiscal web'),
          ],
        );
      },
    );
  }

  /// Numero de NFS-e no documento ou espelhado em [officialResponse] (Focus).
  bool _mapHasOfficialNfsNumber(Map<String, dynamic> d) {
    return _invoiceOfficialNumber(d).isNotEmpty;
  }

  String _invoiceOfficialNumber(Map<String, dynamic> d) {
    final direct = d['officialNumber']?.toString().trim() ?? '';
    if (direct.isNotEmpty) {
      return direct;
    }
    final raw = d['officialResponse'];
    if (raw is! Map) {
      return '';
    }
    final m = Map<String, dynamic>.from(raw);
    return _extractFocusOfficialNumber(m);
  }

  String _extractFocusOfficialNumber(Map<String, dynamic> m) {
    for (final k in [
      'numero_nfse',
      'numeroNfse',
      'numero_nfse_substituida',
      'numero_nfse_substituta',
      'numero_nfs_e',
      'numero_nfs',
      'numeroNfs',
      'numeroNota',
      'numero_nota',
      'numeroNotaFiscal',
      'numero_nota_fiscal',
      'numero',
      'nNF',
      'nNFSe',
      'nfseNumber',
      'numeroDPS',
      'numeroDps',
      'numero_dps',
      'num_dps',
      'numDps',
      'invoiceNumber',
      'nfse_numero',
    ]) {
      final value = m[k]?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }
    for (final nest in [
      'nfse',
      'Nfse',
      'nfs_e',
      'nfs-e',
      'nota',
      'notaFiscal',
      'nota_fiscal',
      'notaFiscalServico',
      'nota_fiscal_servico',
      'dps',
      'DPS',
      'nfe',
      'Nfe',
      'dados_nfse',
      'dps_gerada',
      'resposta',
      'response',
      'body',
      'data',
    ]) {
      final sub = m[nest];
      if (sub is Map) {
        final value = _extractFocusOfficialNumber(
          Map<String, dynamic>.from(sub),
        );
        if (value.isNotEmpty) {
          return value;
        }
      }
    }
    return '';
  }

  bool _mapIsFiscalEmissionProcessing(Map<String, dynamic> d) {
    final s = (d['status']?.toString() ?? '').toUpperCase();
    final last = (d['lastEmissionAttemptStatus']?.toString() ?? '').toUpperCase();
    if (_fiscalStatusIsApprovedOrLegacyEmitted(s) && !_mapHasOfficialNfsNumber(d)) {
      return true;
    }
    if (s == 'PROCESSANDO' ||
        s == 'PROCESSING' ||
        s.startsWith('PROCESSANDO_') ||
        s.startsWith('PROCESSING_')) {
      return true;
    }
    if (last == 'PROCESSING' || last.startsWith('PROCESSING_')) {
      return true;
    }
    return false;
  }

  Widget _buildFiscalSettingsRequestTile({
    required Session sessao,
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
    required bool canConfigureModule,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Ajuste sensivel do modulo fiscal'),
      subtitle: Text(
        'Solicitado por ${doc.data()['requestedByUserName'] ?? '-'} em '
        '${_formatDateTime(_toDate(doc.data()['requestedAt']))}\n'
        '${_requestedFiscalSummary(doc.data())}\n'
        'Obs: ${doc.data()['note'] ?? '-'}',
      ),
      isThreeLine: true,
      trailing: canConfigureModule
          ? Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => _resolveFiscalSettingsRequest(
                    sessao: sessao,
                    requestId: doc.id,
                    approve: false,
                  ),
                  child: const Text('Rejeitar'),
                ),
                ElevatedButton(
                  onPressed: () => _resolveFiscalSettingsRequest(
                    sessao: sessao,
                    requestId: doc.id,
                    approve: true,
                  ),
                  child: const Text('Aprovar'),
                ),
              ],
            )
          : const Text('Aguardando dono'),
    );
  }

  Widget _buildFiscalSettingsResolvedTile(Map<String, dynamic> data) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        data['status']?.toString() == 'APPROVED'
            ? Icons.verified_outlined
            : Icons.cancel_outlined,
      ),
      title: Text(
        'Historico fiscal: ${data['status'] == 'APPROVED' ? 'Aprovado' : 'Rejeitado'}',
      ),
      subtitle: Text(
        'Solicitado por ${data['requestedByUserName'] ?? '-'}\n'
        'Resolvido por ${data['resolvedByUserName'] ?? '-'} em ${_formatDateTime(_toDate(data['resolvedAt']))}\n'
        'Comentario: ${data['resolutionComment'] ?? '-'}',
      ),
      isThreeLine: true,
    );
  }

  String _invoiceSourceTaskLabel(Map<String, dynamic> data) {
    final sourceTask = (data['sourceTask'] as Map?)?.cast<String, dynamic>();
    final taskName = sourceTask?['name']?.toString().trim() ?? '';
    final taskId = sourceTask?['id']?.toString().trim() ?? '';
    if (taskName.isNotEmpty) return taskName;
    if (taskId.isNotEmpty) return 'tarefa $taskId';
    return '-';
  }

  Widget _buildFiscalServiceCatalogCard({
    required Session sessao,
    required bool canManageInvoices,
    required Map<String, dynamic> companySettings,
    required _FiscalRealIntegrationSetup realIntegration,
  }) {
    final items = ref.watch(fiscalServiceCatalogProvider);
    final activeItems = [for (final i in items) if (i.active) i];
    final inactiveItems = [for (final i in items) if (!i.active) i];
    return AppWorkspaceCard(
      title: 'Servicos fiscais',
      subtitle:
          'Na emissao da nota so entram modelos ativos. Inativos ficam arquivados ate reativar.',
      trailing: canManageInvoices
          ? OutlinedButton.icon(
              onPressed: () => _openFiscalServiceDialog(
                sessao: sessao,
                companySettings: companySettings,
                realIntegration: realIntegration,
              ),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Novo servico'),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (activeItems.isEmpty && inactiveItems.isEmpty)
            const Text('Nenhum servico fiscal cadastrado ainda.')
          else ...[
            if (activeItems.isNotEmpty) ...[
              Text(
                'Ativos para emissao (${activeItems.length})',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              ...activeItems
                  .take(8)
                  .map(
                    (item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.inventory_2_outlined),
                      title: Text(item.name),
                      subtitle: Text(
                        'Codigo: ${item.serviceCode.isEmpty ? '-' : item.serviceCode} | CNAE: ${item.cnae.isEmpty ? '-' : item.cnae}\n'
                        'Municipio: ${item.cityOfIncidence.isEmpty ? '-' : item.cityOfIncidence} | Regime: ${item.taxRegime.isEmpty ? '-' : item.taxRegime}',
                      ),
                      isThreeLine: true,
                      trailing: canManageInvoices
                          ? Wrap(
                              spacing: 4,
                              children: [
                                IconButton(
                                  tooltip: 'Editar',
                                  onPressed: () => _openFiscalServiceDialog(
                                    sessao: sessao,
                                    companySettings: companySettings,
                                    realIntegration: realIntegration,
                                    editing: item,
                                  ),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  tooltip: 'Excluir',
                                  onPressed: () => ref
                                      .read(
                                        fiscalServiceCatalogProvider.notifier,
                                      )
                                      .remove(item.id),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            )
                          : null,
                    ),
                  ),
            ] else
              const Text(
                'Nenhum servico ativo. Ative um modelo abaixo ou crie outro em Novo servico.',
              ),
            if (inactiveItems.isNotEmpty) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showInactiveFiscalServices = !_showInactiveFiscalServices;
                  });
                },
                icon: Icon(
                  _showInactiveFiscalServices
                      ? Icons.expand_less
                      : Icons.expand_more,
                ),
                label: Text(
                  _showInactiveFiscalServices
                      ? 'Ocultar inativos'
                      : 'Mostrar inativos (${inactiveItems.length})',
                ),
              ),
              if (_showInactiveFiscalServices) ...[
                const SizedBox(height: 4),
                ...inactiveItems
                    .take(8)
                    .map(
                      (item) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.pause_circle),
                        title: Text(item.name),
                        subtitle: Text(
                          'Inativo (nao aparece no emissor) — Codigo: ${item.serviceCode.isEmpty ? '-' : item.serviceCode}',
                        ),
                        trailing: canManageInvoices
                            ? Wrap(
                                spacing: 4,
                                children: [
                                  IconButton(
                                    tooltip: 'Editar',
                                    onPressed: () => _openFiscalServiceDialog(
                                      sessao: sessao,
                                      companySettings: companySettings,
                                      realIntegration: realIntegration,
                                      editing: item,
                                    ),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
                                    tooltip: 'Excluir',
                                    onPressed: () => ref
                                        .read(
                                          fiscalServiceCatalogProvider
                                              .notifier,
                                        )
                                        .remove(item.id),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              )
                            : null,
                      ),
                    ),
              ],
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildInvoiceSection({
    required Session sessao,
    required Map<String, dynamic> companyData,
    required Map<String, dynamic> companySettings,
    required _FiscalRealIntegrationSetup realIntegration,
    required String competence,
    required bool canManageInvoices,
  }) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('service_invoices')
          .where('companyId', isEqualTo: sessao.companyId)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        _maybeAdjustCompetenceToLatestInvoices(docs, competence);
        final monthInvoices = docs.where((doc) {
          final referenceDate = _invoiceReferenceDate(doc.data());
          return '${referenceDate.year}-${referenceDate.month.toString().padLeft(2, '0')}' ==
              competence;
        }).toList();
        final approved = monthInvoices
            .where(
              (doc) =>
                  _fiscalStatusIsApprovedOrLegacyEmitted(
                    doc.data()['status']?.toString(),
                  ) &&
                  _mapHasOfficialNfsNumber(doc.data()),
            )
            .toList();
        final processingInvoiceIds =
            monthInvoices
                .where((doc) {
                  final status = (doc.data()['status']?.toString() ?? '')
                      .toUpperCase();
                  final attempt =
                      (doc.data()['lastEmissionAttemptStatus']?.toString() ??
                              '')
                          .toUpperCase();
                  return _mapIsFiscalEmissionProcessing(doc.data()) ||
                      status.startsWith('PROCESSANDO_') ||
                      status.startsWith('PROCESSING_') ||
                      attempt.startsWith('PROCESSING_');
                })
                .map((doc) => doc.id)
                .toList()
              ..sort();
        final processingSignature =
            '$competence|${processingInvoiceIds.join(',')}';
        if (canManageInvoices &&
            processingInvoiceIds.isNotEmpty &&
            !_autoReconciledProcessingKeys.contains(processingSignature)) {
          _autoReconciledProcessingKeys.add(processingSignature);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _reconcileProcessingInvoices(
              sessao: sessao,
              invoiceIds: processingInvoiceIds,
              silentSuccess: true,
            );
          });
        }
        final officialMissing = monthInvoices
            .where(
              (doc) =>
                  _fiscalStatusIsApprovedOrLegacyEmitted(
                    doc.data()['status']?.toString(),
                  ) &&
                  !_mapHasOfficialNfsNumber(doc.data()),
            )
            .length;
        final portalMissing = approved
            .where(
              (doc) =>
                  (doc.data()['officialPortalUrl']?.toString().trim() ?? '')
                      .isEmpty,
            )
            .length;
        final draftDocs = monthInvoices.where((doc) {
          final status =
              (doc.data()['status']?.toString().toUpperCase() ?? 'DRAFT');
          return !_fiscalStatusIsApprovedOrLegacyEmitted(
                doc.data()['status']?.toString(),
              ) &&
              status != 'CANCELED' &&
              status != 'CANCELLED';
        }).toList();
        final approvedDocs = monthInvoices
            .where(
              (doc) => _fiscalStatusIsApprovedOrLegacyEmitted(
                doc.data()['status']?.toString(),
              ),
            )
            .toList();
        final canceledDocs = monthInvoices.where((doc) {
          final st = (doc.data()['status']?.toString().toUpperCase() ?? '');
          return st == 'CANCELED' || st == 'CANCELLED';
        }).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInvoiceActionsRow(
              sessao: sessao,
              companyData: companyData,
              companySettings: companySettings,
              realIntegration: realIntegration,
              competence: competence,
              canManageInvoices: canManageInvoices,
              processingInvoiceIds: processingInvoiceIds,
            ),
            const SizedBox(height: 8),
            const Text(
              'Conferencia operacional antes da emissao oficial por prefeitura, padrao nacional ou integrador fiscal.',
            ),
            const SizedBox(height: 12),
            _buildInvoiceSummaryChips(
              monthInvoicesCount: monthInvoices.length,
              approvedCount: approved.length,
              officialMissing: officialMissing,
              portalMissing: portalMissing,
            ),
            const SizedBox(height: 12),
            _buildFiscalServiceCatalogCard(
              sessao: sessao,
              canManageInvoices: canManageInvoices,
              companySettings: companySettings,
              realIntegration: realIntegration,
            ),
            const SizedBox(height: 12),
            _buildCompletedServicesForInvoiceCard(
              sessao: sessao,
              companyData: companyData,
              companySettings: companySettings,
              realIntegration: realIntegration,
              linkedInvoices: docs,
              canManageInvoices: canManageInvoices,
            ),
            const SizedBox(height: 12),
            _buildInvoiceNotesCard(
              title: 'Rascunhos e em preparo',
              subtitle:
                  'Notas que ainda nao foram autorizadas nesta competencia. Edite, emita ou exclua antes da validacao oficial.',
              emptyText:
                  'Nenhuma nota em rascunho ou processamento nesta competencia.',
              docs: draftDocs,
              sessao: sessao,
              companyData: companyData,
              companySettings: companySettings,
              realIntegration: realIntegration,
              canManageInvoices: canManageInvoices,
            ),
            const SizedBox(height: 12),
            _buildInvoiceNotesCard(
              title: 'Aprovadas / autorizadas',
              subtitle:
                  'Registros com emissao ou aprovacao oficial na competencia selecionada.',
              emptyText: 'Nenhuma nota aprovada ou autorizada nesta competencia.',
              docs: approvedDocs,
              sessao: sessao,
              companyData: companyData,
              companySettings: companySettings,
              realIntegration: realIntegration,
              canManageInvoices: canManageInvoices,
            ),
            const SizedBox(height: 12),
            _buildInvoiceNotesCard(
              title: 'Canceladas',
              subtitle:
                  'Notas com status de cancelamento fiscal nesta competencia.',
              emptyText: 'Nenhuma nota cancelada nesta competencia.',
              docs: canceledDocs,
              sessao: sessao,
              companyData: companyData,
              companySettings: companySettings,
              realIntegration: realIntegration,
              canManageInvoices: canManageInvoices,
            ),
            const SizedBox(height: 12),
            AppDesktopSplit(
              breakpoint: 980,
              sidebar: InvoiceEmitterCard(companyData: companyData),
              content: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('invoice_customers')
                    .where('companyId', isEqualTo: sessao.companyId)
                    .snapshots(),
                builder: (context, customerSnapshot) {
                  final customers = customerSnapshot.data?.docs ?? const [];
                  final orderedCustomers = [...customers]
                    ..sort(
                      (a, b) => (b.data()['updatedAtIso']?.toString() ?? '')
                          .compareTo(
                            a.data()['updatedAtIso']?.toString() ?? '',
                          ),
                    );
                  return InvoiceCustomerPortfolioCard(
                    customers: orderedCustomers
                        .map(
                          (doc) => <String, dynamic>{
                            'id': doc.id,
                            ...doc.data(),
                          },
                        )
                        .toList(),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInvoiceNotesCard({
    required String title,
    required String subtitle,
    required String emptyText,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    required Session sessao,
    required Map<String, dynamic> companyData,
    required Map<String, dynamic> companySettings,
    required _FiscalRealIntegrationSetup realIntegration,
    required bool canManageInvoices,
  }) {
    final countLabel =
        '${docs.length} registro(s) nesta competencia.';
    return AppWorkspaceCard(
      title: title,
      subtitle: subtitle,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          expandedAlignment: Alignment.topLeft,
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          shape: const RoundedRectangleBorder(),
          collapsedShape: const RoundedRectangleBorder(),
          title: Text(
            docs.isEmpty
                ? '$countLabel Toque para ver.'
                : '$countLabel Toque para ver as notas.',
            style: const TextStyle(
              color: AppBrandColors.softText,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              height: 1.35,
            ),
          ),
          children: [
            if (docs.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(emptyText),
              )
            else
              ..._buildInvoiceList(
                sessao: sessao,
                companyData: companyData,
                companySettings: companySettings,
                realIntegration: realIntegration,
                canManageInvoices: canManageInvoices,
                monthInvoices: docs,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedServicesForInvoiceCard({
    required Session sessao,
    required Map<String, dynamic> companyData,
    required Map<String, dynamic> companySettings,
    required _FiscalRealIntegrationSetup realIntegration,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> linkedInvoices,
    required bool canManageInvoices,
  }) {
    final linkedTaskIds = linkedInvoices
        .map((doc) {
          final data = doc.data();
          final sourceTask = (data['sourceTask'] as Map?)
              ?.cast<String, dynamic>();
          return (sourceTask?['id']?.toString().trim() ??
              data['sourceTaskId']?.toString().trim() ??
              '');
        })
        .where((id) => id.isNotEmpty)
        .toSet();

    return AppWorkspaceCard(
      title: 'Servicos concluidos para nota',
      subtitle:
          'Servicos finalizados da empresa que ainda nao foram vinculados a uma nota fiscal.',
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('tasks')
            .where('companyId', isEqualTo: sessao.companyId)
            .where('status', isEqualTo: 'finalizado')
            .snapshots(),
        builder: (context, snapshot) {
          final tasks = snapshot.data?.docs ?? const [];
          final finalized =
              tasks.where((doc) {
                final data = doc.data();
                final status = data['status']?.toString() ?? '';
                return status == 'finalizado' &&
                    !linkedTaskIds.contains(doc.id);
              }).toList()..sort((a, b) {
                final aDate = _toDate(a.data()['dataExecucao']);
                final bDate = _toDate(b.data()['dataExecucao']);
                return bDate.compareTo(aDate);
              });

          return ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: Text(
              'Servicos concluidos',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              finalized.isEmpty
                  ? 'Nenhum servico pendente de nota.'
                  : '${finalized.length} servico(s) aguardando geracao de nota.',
            ),
            children: [
              if (finalized.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Nenhum servico concluido pendente no momento.',
                    ),
                  ),
                )
              else
                for (final doc in finalized.take(12))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.task_alt_outlined),
                    title: Text(doc.data()['nome']?.toString() ?? 'Servico'),
                    subtitle: Text(
                      'Cliente: ${doc.data()['clienteNome']?.toString().trim().isNotEmpty == true ? doc.data()['clienteNome'] : '-'}\n'
                      'Valor: ${_formatCurrency((doc.data()['valorTotalCents'] as num?)?.toInt() ?? 0)}',
                    ),
                    isThreeLine: true,
                    trailing: canManageInvoices
                        ? FilledButton.tonalIcon(
                            onPressed: () => _openInvoiceDialog(
                              sessao: sessao,
                              companyData: companyData,
                              companySettings: companySettings,
                              realIntegration: realIntegration,
                              initialTaskData: {'id': doc.id, ...doc.data()},
                            ),
                            icon: const Icon(Icons.receipt_long_outlined),
                            label: const Text('Gerar nota'),
                          )
                        : null,
                  ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInvoiceActionsRow({
    required Session sessao,
    required Map<String, dynamic> companyData,
    required Map<String, dynamic> companySettings,
    required _FiscalRealIntegrationSetup realIntegration,
    required String competence,
    required bool canManageInvoices,
    required List<String> processingInvoiceIds,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.spaceBetween,
      children: [
        if (canManageInvoices)
          OutlinedButton.icon(
            onPressed: () => _openInvoiceDialog(
              sessao: sessao,
              companyData: companyData,
              companySettings: companySettings,
              realIntegration: realIntegration,
            ),
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Nova NFS-e'),
          ),
        ElevatedButton.icon(
          onPressed: () => _exportFiscalSummaryPdf(
            sessao: sessao,
            companyData: companyData,
            realIntegration: realIntegration,
            competence: competence,
          ),
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('PDF contador'),
        ),
        if (canManageInvoices && processingInvoiceIds.isNotEmpty)
          OutlinedButton.icon(
            onPressed: () => _reconcileProcessingInvoices(
              sessao: sessao,
              invoiceIds: processingInvoiceIds,
            ),
            icon: const Icon(Icons.sync_outlined),
            label: Text(
              'Conciliar ${processingInvoiceIds.length} em processamento',
            ),
          ),
      ],
    );
  }

  Widget _buildInvoiceSummaryChips({
    required int monthInvoicesCount,
    required int approvedCount,
    required int officialMissing,
    required int portalMissing,
  }) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _summaryChip('Notas do mes', monthInvoicesCount.toString()),
        _summaryChip('Aprovadas/autorizadas', approvedCount.toString()),
        _summaryChip('Sem numero oficial', officialMissing.toString()),
        _summaryChip('Sem link oficial', portalMissing.toString()),
      ],
    );
  }

  /// Rascunhos e canceladas **sem** numero oficial (sem validade perante a
  /// prefeitura) podem ser excluidas sem risco de conflito fiscal.
  bool _invoiceDeletableAsNonFiscal(Map<String, dynamic> data) {
    final s = (data['status']?.toString() ?? 'DRAFT').toUpperCase();
    if (s == 'DRAFT') {
      return true;
    }
    if (s == 'CANCELED') {
      return _invoiceOfficialNumber(data).isEmpty;
    }
    return false;
  }

  Future<void> _deleteServiceInvoiceIfAllowed({
    required Session sessao,
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    if (data['companyId']?.toString() != sessao.companyId) {
      return;
    }
    if (!_invoiceDeletableAsNonFiscal(data)) {
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir nota?'),
        content: const Text(
          'Apenas rascunhos e notas canceladas sem numero oficial podem ser excluidas. '
          'Esta acao nao pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok != true) {
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('service_invoices')
          .doc(docId)
          .delete();
      if (!mounted) {
        return;
      }
      _msg('Nota excluida do sistema.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _msg(AppErrorMapper.messageFrom(error));
    }
  }

  List<Widget> _buildInvoiceList({
    required Session sessao,
    required Map<String, dynamic> companyData,
    required Map<String, dynamic> companySettings,
    required _FiscalRealIntegrationSetup realIntegration,
    required bool canManageInvoices,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> monthInvoices,
  }) {
    if (monthInvoices.isEmpty) {
      return const [Text('Nenhuma nota de servico encontrada na competencia.')];
    }

    return monthInvoices.take(8).map((doc) {
      final data = doc.data();
      final officialStatus = data['status']?.toString();
      final lastAttemptStatus =
          data['lastEmissionAttemptStatus']?.toString().trim().toUpperCase() ??
          '';
      final lastEmissionError =
          data['lastEmissionError']?.toString().trim() ?? '';
      final financeMovementId =
          data['financeMovementId']?.toString().trim() ?? '';
      final sourceTaskLabel = _invoiceSourceTaskLabel(data);
      final subtitleLines = <String>[
        'Status: ${_invoiceStatusLabel(officialStatus)} | Numero oficial: ${_invoiceOfficialNumber(data).isEmpty ? 'pendente' : _invoiceOfficialNumber(data)}',
        'Valor bruto: ${_formatCurrency(_invoiceGrossAmount(data))}',
        'Servico: ${data['serviceDescription']?.toString() ?? '-'}',
        if (((data['sourceTask'] as Map?)?['id']?.toString().trim() ?? '')
            .isNotEmpty)
          'Origem: $sourceTaskLabel',
        if (financeMovementId.isNotEmpty) 'Financeiro: vinculado',
      ];
      if (lastAttemptStatus == 'FAILED' ||
          lastAttemptStatus == 'CANCEL_FAILED') {
        subtitleLines.add(
          'Falha oficial: ${lastEmissionError.isEmpty ? 'verificar tentativa mais recente' : lastEmissionError}',
        );
      }
      if (lastAttemptStatus == 'QUERY_FAILED') {
        subtitleLines.add(
          'Falha na consulta oficial: ${lastEmissionError.isEmpty ? 'verificar tentativa mais recente' : lastEmissionError}',
        );
      }
      final statusIcon = Icon(
        lastAttemptStatus == 'FAILED' ||
                lastAttemptStatus == 'CANCEL_FAILED' ||
                lastAttemptStatus == 'QUERY_FAILED'
            ? Icons.error_outline
            : lastAttemptStatus == 'PROCESSING'
            ? Icons.sync_outlined
            : Icons.receipt_long_outlined,
        color:
            lastAttemptStatus == 'FAILED' ||
                lastAttemptStatus == 'CANCEL_FAILED' ||
                lastAttemptStatus == 'QUERY_FAILED'
            ? AppBrandColors.gold
            : lastAttemptStatus == 'PROCESSING'
            ? AppBrandColors.primary
            : null,
      );
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppBrandColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: statusIcon,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      data['clientName']?.toString() ?? '-',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                      maxLines: 4,
                      softWrap: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                subtitleLines.join('\n'),
                style: const TextStyle(
                  color: AppBrandColors.softText,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                alignment: WrapAlignment.start,
                children: [
                  IconButton(
                    tooltip: 'PDF',
                    onPressed: () => _previewInvoicePdf(
                      companyData: companyData,
                      data: data,
                    ),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                  ),
                  IconButton(
                    tooltip: 'Editar',
                    onPressed: canManageInvoices
                        ? () => _openInvoiceDialog(
                              sessao: sessao,
                              companyData: companyData,
                              companySettings: companySettings,
                              realIntegration: realIntegration,
                              editing: doc,
                            )
                        : null,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'Consultar status oficial',
                    onPressed: canManageInvoices
                        ? () => _refreshInvoiceOfficialStatus(
                              sessao: sessao,
                              invoiceId: doc.id,
                            )
                        : null,
                    icon: const Icon(Icons.sync_outlined),
                  ),
                  IconButton(
                    tooltip: 'Emitir oficial',
                    onPressed: canManageInvoices &&
                            !_fiscalStatusIsApprovedOrLegacyEmitted(
                              doc.data()['status']?.toString(),
                            )
                        ? () => _emitInvoiceOfficial(
                              sessao: sessao,
                              invoiceId: doc.id,
                            )
                        : null,
                    icon: const Icon(Icons.cloud_upload_outlined),
                  ),
                  IconButton(
                    tooltip: 'Cancelar oficial',
                    onPressed: canManageInvoices &&
                            _fiscalStatusIsApprovedOrLegacyEmitted(
                              doc.data()['status']?.toString(),
                            )
                        ? () async {
                              final reason = await _askCancellationReason();
                              if (reason == null || reason.trim().isEmpty) {
                                return;
                              }
                              await _cancelInvoiceOfficial(
                                sessao: sessao,
                                invoiceId: doc.id,
                                reason: reason,
                              );
                            }
                        : null,
                    icon: const Icon(Icons.cancel_outlined),
                  ),
                  IconButton(
                    tooltip: 'Gerar no financeiro',
                    onPressed: canManageInvoices
                        ? () => _createFinanceReceivableFromInvoice(
                              sessao: sessao,
                              invoiceId: doc.id,
                              invoiceData: data,
                            )
                        : null,
                    icon: Icon(
                      financeMovementId.isNotEmpty
                          ? Icons.account_balance_wallet
                          : Icons.post_add_outlined,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Portal oficial',
                    onPressed: () =>
                        _openUrl(data['officialPortalUrl']?.toString()),
                    icon: const Icon(Icons.open_in_new_outlined),
                  ),
                  if (canManageInvoices && _invoiceDeletableAsNonFiscal(data))
                    IconButton(
                      tooltip: 'Excluir (rascunho ou sem validade fiscal)',
                      onPressed: () => _deleteServiceInvoiceIfAllowed(
                            sessao: sessao,
                            docId: doc.id,
                            data: data,
                          ),
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Color(0xFFB91C1C),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  // ignore: unused_element
  Widget _buildPayrollSection({
    required Session sessao,
    required String competence,
    required List<Employee> employees,
    required List<Payment> payments,
    required _FiscalSettings fiscalSettings,
  }) {
    final eligibleForThirteenth = employees.where((employee) {
      final admissionDate = employee.admissionDate;
      if (admissionDate == null) return false;
      final competenceDate = _parseCompetence(competence);
      if (competenceDate == null) return false;
      final endOfMonth = DateTime(competenceDate.$1, competenceDate.$2 + 1, 0);
      return admissionDate.isBefore(endOfMonth);
    }).length;
    final vacationAttention = employees.where((employee) {
      final admissionDate = employee.admissionDate;
      if (admissionDate == null) return false;
      return DateTime.now().difference(admissionDate).inDays >= 330;
    }).length;
    final payrollBase = payments
        .where((payment) => payment.competencia == competence)
        .fold<int>(0, (total, payment) => total + payment.valorCents);
    final thirteenthEmployees = employees.where((employee) {
      final admissionDate = employee.admissionDate;
      if (admissionDate == null) return false;
      final competenceDate = _parseCompetence(competence);
      if (competenceDate == null) return false;
      final endOfMonth = DateTime(competenceDate.$1, competenceDate.$2 + 1, 0);
      return admissionDate.isBefore(endOfMonth) ||
          admissionDate.isAtSameMomentAs(endOfMonth);
    }).toList()..sort((a, b) => a.nomeCompleto.compareTo(b.nomeCompleto));
    final vacationEmployees = employees.where((employee) {
      final admissionDate = employee.admissionDate;
      if (admissionDate == null) return false;
      return DateTime.now().difference(admissionDate).inDays >= 330;
    }).toList()..sort((a, b) => a.nomeCompleto.compareTo(b.nomeCompleto));

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('fiscal_competence_checks')
          .doc('${sessao.companyId}_$competence')
          .snapshots(),
      builder: (context, snapshot) {
        final checkData = snapshot.data?.data() ?? <String, dynamic>{};
        final checks = _FiscalCompetenceChecks.fromMap(checkData);
        return AppWorkspaceCard(
          title: 'Folha oficial e encargos',
          subtitle:
              'Resumo preparatorio para contador, eSocial e rotina oficial. Os valores de encargos aqui sao estimativas operacionais.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _summaryChip('Base da folha', _formatCurrency(payrollBase)),
                  _summaryChip(
                    '13 elegiveis',
                    fiscalSettings.enableThirteenthSalary
                        ? eligibleForThirteenth.toString()
                        : 'Desligado',
                  ),
                  _summaryChip(
                    'Ferias em atencao',
                    fiscalSettings.enableVacation
                        ? vacationAttention.toString()
                        : 'Desligado',
                  ),
                  _summaryChip(
                    'Beneficios',
                    fiscalSettings.enableBenefits ? 'Controlar' : 'Desligado',
                  ),
                  _summaryChip(
                    'Rescisao',
                    fiscalSettings.enableTermination
                        ? 'Controlar'
                        : 'Desligado',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Checklist mensal',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              _buildCompetenceCheckTile(
                title: 'Conferencia de NFS-e pronta para envio',
                value: checks.invoiceConferenceDone,
                onChanged: (value) => _saveFiscalCompetenceChecks(
                  sessao: sessao,
                  competence: competence,
                  checks: checks.copyWith(invoiceConferenceDone: value),
                ),
              ),
              _buildCompetenceCheckTile(
                title: 'Conferencia da folha pronta para contador',
                value: checks.payrollConferenceDone,
                onChanged: (value) => _saveFiscalCompetenceChecks(
                  sessao: sessao,
                  competence: competence,
                  checks: checks.copyWith(payrollConferenceDone: value),
                ),
              ),
              _buildCompetenceCheckTile(
                title: 'Eventos eSocial preparados',
                value: checks.esocialPrepared,
                onChanged: (value) => _saveFiscalCompetenceChecks(
                  sessao: sessao,
                  competence: competence,
                  checks: checks.copyWith(esocialPrepared: value),
                ),
              ),
              _buildCompetenceCheckTile(
                title: 'Guias e documentos fiscais separados',
                value: checks.taxDocumentsPrepared,
                onChanged: (value) => _saveFiscalCompetenceChecks(
                  sessao: sessao,
                  competence: competence,
                  checks: checks.copyWith(taxDocumentsPrepared: value),
                ),
              ),
              if (fiscalSettings.enableThirteenthSalary) ...[
                const SizedBox(height: 12),
                _buildEmployeeFollowUpSection(
                  title: '13 salario por funcionario',
                  subtitle:
                      'Marque quem ja foi conferido nesta competencia para envio ao contador ou fechamento interno.',
                  employees: thirteenthEmployees,
                  reviewedEmployeeIds: checks.thirteenthReviewedEmployeeIds,
                  emptyState:
                      'Nenhum funcionario elegivel para 13 salario nesta competencia.',
                  onToggle: (employeeId, reviewed) {
                    final updated = reviewed
                        ? [...checks.thirteenthReviewedEmployeeIds, employeeId]
                        : checks.thirteenthReviewedEmployeeIds
                              .where((id) => id != employeeId)
                              .toList();
                    return _saveFiscalCompetenceChecks(
                      sessao: sessao,
                      competence: competence,
                      checks: checks.copyWith(
                        thirteenthReviewedEmployeeIds: updated,
                      ),
                    );
                  },
                ),
              ],
              if (fiscalSettings.enableVacation) ...[
                const SizedBox(height: 12),
                _buildEmployeeFollowUpSection(
                  title: 'Ferias em acompanhamento',
                  subtitle:
                      'Mostra funcionarios com maior tempo de casa para revisar programacao, recibos e repasse ao contador.',
                  employees: vacationEmployees,
                  reviewedEmployeeIds: checks.vacationReviewedEmployeeIds,
                  emptyState:
                      'Nenhum funcionario em faixa de atencao para ferias agora.',
                  onToggle: (employeeId, reviewed) {
                    final updated = reviewed
                        ? [...checks.vacationReviewedEmployeeIds, employeeId]
                        : checks.vacationReviewedEmployeeIds
                              .where((id) => id != employeeId)
                              .toList();
                    return _saveFiscalCompetenceChecks(
                      sessao: sessao,
                      competence: competence,
                      checks: checks.copyWith(
                        vacationReviewedEmployeeIds: updated,
                      ),
                    );
                  },
                ),
              ],
              if (fiscalSettings.enableTermination) ...[
                const SizedBox(height: 12),
                _buildNotesSection(
                  title: 'Rescisao',
                  subtitle:
                      'Use este campo para registrar desligamentos, documentos pendentes e envio ao contador.',
                  value: checks.terminationNotes,
                  actionLabel: 'Editar observacoes',
                  onEdit: () => _openCompetenceNotesDialog(
                    competence: competence,
                    title: 'Observacoes de rescisao',
                    initialValue: checks.terminationNotes,
                    onSave: (value) => _saveFiscalCompetenceChecks(
                      sessao: sessao,
                      competence: competence,
                      checks: checks.copyWith(terminationNotes: value),
                    ),
                  ),
                ),
              ],
              if (fiscalSettings.enableBenefits) ...[
                const SizedBox(height: 12),
                _buildNotesSection(
                  title: 'Beneficios',
                  subtitle:
                      'Anote vales, descontos, convenios ou repasses que precisam seguir para o fechamento mensal.',
                  value: checks.benefitsNotes,
                  actionLabel: 'Editar observacoes',
                  onEdit: () => _openCompetenceNotesDialog(
                    competence: competence,
                    title: 'Observacoes de beneficios',
                    initialValue: checks.benefitsNotes,
                    onSave: (value) => _saveFiscalCompetenceChecks(
                      sessao: sessao,
                      competence: competence,
                      checks: checks.copyWith(benefitsNotes: value),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompetenceCheckTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      title: Text(title),
    );
  }

  Widget _buildEmployeeFollowUpSection({
    required String title,
    required String subtitle,
    required List<Employee> employees,
    required List<String> reviewedEmployeeIds,
    required String emptyState,
    required Future<void> Function(String employeeId, bool reviewed) onToggle,
  }) {
    final reviewedCount = employees
        .where((employee) => reviewedEmployeeIds.contains(employee.id))
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(subtitle),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _summaryChip('Total', employees.length.toString()),
            _summaryChip('Conferidos', reviewedCount.toString()),
            _summaryChip(
              'Pendentes',
              (employees.length - reviewedCount).toString(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (employees.isEmpty)
          Text(emptyState)
        else
          ...employees.map((employee) {
            final reviewed = reviewedEmployeeIds.contains(employee.id);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppBrandColors.border),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x120F172A),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: SwitchListTile(
                value: reviewed,
                onChanged: (value) => onToggle(employee.id, value),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Text(employee.nomeCompleto),
                subtitle: Text(
                  'Cargo: ${employee.cargo ?? '-'}\n'
                  'Admissao: ${employee.admissionDate == null ? '-' : _formatDate(employee.admissionDate!)}\n'
                  'Remuneracao: ${_employeeCompensationLabel(employee)}',
                ),
                isThreeLine: true,
              ),
            );
          }),
      ],
    );
  }

  Widget _buildNotesSection({
    required String title,
    required String subtitle,
    required String value,
    required String actionLabel,
    required VoidCallback onEdit,
  }) {
    return AppWorkspaceCard(
      title: title,
      subtitle: subtitle,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value.trim().isEmpty ? 'Sem observacoes registradas.' : value),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_note_outlined),
              label: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveFiscalSettings(
    Session sessao,
    _FiscalSettings settings,
  ) async {
    final before = await FirebaseFirestore.instance
        .collection('company_settings')
        .doc(sessao.companyId)
        .get();
    try {
      await FirebaseFirestore.instance
          .collection('company_settings')
          .doc(sessao.companyId)
          .set({
            'companyId': sessao.companyId,
            'fiscalMode': settings.mode.name,
            'fiscalFeatures': settings.toMap(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      await _writeAuditLog(
        sessao: sessao,
        action: 'settings_update',
        entityPath: 'company_settings',
        entityId: sessao.companyId,
        before: before.data(),
        after: {
          'fiscalMode': settings.mode.name,
          'fiscalFeatures': settings.toMap(),
        },
      );
      _msg('Configuracao fiscal atualizada.');
    } catch (_) {
      _msg('Nao foi possivel salvar a configuracao fiscal.');
    }
  }

  Widget _buildFiscalPaymentReceiptCard({
    required Session sessao,
    required Map<String, dynamic> companyData,
    required _FiscalSettings fiscalSettings,
    required bool canManageInvoices,
  }) {
    if (!fiscalSettings.enableOfficialInvoicePrep) {
      return const SizedBox.shrink();
    }
    _ensureFiscalPaymentReceiptController(
      companyId: sessao.companyId,
      companyData: companyData,
    );
    final c = _fiscalPaymentReceiptController!;
    return AppWorkspaceCard(
      title: 'Recebimento na NFS-e',
      subtitle:
          'Instrucoes de pagamento e dados bancarios vao para o fim do texto da discriminacao do servico '
          '(corpo da nota na Focus). Podem ser editados tambem ao abrir Nova NFS-e.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: c,
            enabled: canManageInvoices,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Dados para o tomador efetuar o pagamento',
              alignLabelWithHint: true,
              helperText:
                  'Ex.: Pix (chave), banco, agencia, conta, favorecido, prazo.',
            ),
          ),
          if (!canManageInvoices) ...[
            const SizedBox(height: 8),
            Text(
              'Somente perfis com permissao de emissao podem alterar este texto.',
              style: TextStyle(
                color: AppBrandColors.softText,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: canManageInvoices
                  ? () => _persistFiscalPaymentReceiptNote(
                        sessao: sessao,
                        companyData: companyData,
                      )
                  : null,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Gravar na empresa'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRealIntegrationCard({
    required Session sessao,
    required Map<String, dynamic> companyData,
    required Map<String, dynamic> companySettings,
    required _FiscalRealIntegrationSetup setup,
    required bool canConfigureModule,
    required bool canEditGlobalFiscalIntegration,
  }) {
    final complianceMatrix = _FiscalComplianceMatrix.fromSettings(
      companySettings,
      setup,
    );
    final focusProvisioning =
        (companySettings['focusProvisioning'] as Map?)
            ?.cast<String, dynamic>() ??
        <String, dynamic>{};
    final certificate =
        (companySettings['fiscalCertificate'] as Map?)
            ?.cast<String, dynamic>() ??
        <String, dynamic>{};
    final readiness = _buildFiscalOperationalReadiness(
      setup: setup,
      certificate: certificate,
      companySettings: companySettings,
    );
    final checklist = _FiscalHomologationChecklist.fromSettings(
      companySettings,
    );
    final score = (setup.readinessScore * 100).round();
    return AppWorkspaceCard(
      title: 'Emissao fiscal real',
      subtitle: canEditGlobalFiscalIntegration
          ? 'Integracao global (ambiente, provedor, API, tokens) pela sua empresa suprema. Inscricao municipal, '
              'codigo municipal, CNAE, matriz e preparacao pelo CNPJ sao individuais por empresa cadastrada.'
          : 'Integracao global (ambiente, provedor, API Focus, URL, tokens): apenas a suprema altera — nao confundir '
              'com dados cadastrais desta empresa (inscricao municipal, CNAE, codigos, matriz). '
              'Matriz fiscal, preparar pelo CNPJ, checklist e automacao desta empresa estao liberados com permissao.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!canEditGlobalFiscalIntegration) ...[
            Card(
              elevation: 0,
              color: const Color(0xFFE8EAF6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFC5CAE9)),
              ),
              child: const ListTile(
                leading: Icon(Icons.lock_outline, color: Color(0xFF303F9F)),
                title: Text(
                  'Integracao global travada',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  'So a suprema altera ambiente, provedor, API Focus, URL e tokens (uma base para todas as empresas). '
                  'Nesta empresa continuam livres: inscricao municipal, CNAE, matriz fiscal, preparacao pelo CNPJ e checklist. '
                  'Em «Configurar emissao real» aparecem os globais (leitura) e o que for local: codigo da emissao, certificado e observacoes.',
                  style: TextStyle(height: 1.35),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          _buildRealIntegrationSummary(
            score: score,
            environmentLabel: setup.environmentLabel,
            providerLabel: setup.providerLabel,
            readiness: readiness,
          ),
          const SizedBox(height: 12),
          Text(
            setup.summary,
            style: const TextStyle(color: AppBrandColors.softText, height: 1.4),
          ),
          const SizedBox(height: 12),
          _buildRealIntegrationDetails(
            setup: setup,
            certificate: certificate,
            readiness: readiness,
          ),
          const SizedBox(height: 12),
          _buildOperationalReadinessCard(readiness),
          if (setup.provider.trim().toLowerCase().contains('focus') ||
              focusProvisioning.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildFocusProvisioningCard(focusProvisioning),
          ],
          const SizedBox(height: 12),
          _buildHomologationChecklistCard(
            sessao: sessao,
            setup: setup,
            companySettings: companySettings,
            readiness: readiness,
            checklist: checklist,
            canConfigureModule: canConfigureModule,
          ),
          const SizedBox(height: 12),
          _buildComplianceMatrixCard(complianceMatrix),
          const SizedBox(height: 12),
          _buildRealIntegrationActions(
            sessao: sessao,
            companyData: companyData,
            companySettings: companySettings,
            setup: setup,
            complianceMatrix: complianceMatrix,
            canConfigureModule: canConfigureModule,
            canEditGlobalFiscalIntegration: canEditGlobalFiscalIntegration,
          ),
        ],
      ),
    );
  }

  Widget _buildRealIntegrationSummary({
    required int score,
    required String environmentLabel,
    required String providerLabel,
    required _FiscalOperationalReadiness readiness,
  }) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _summaryChip('Readiness', '$score%'),
        _summaryChip('Ambiente', environmentLabel),
        _summaryChip('Provedor', providerLabel),
        _summaryChip('Operacao', readiness.stageLabel),
      ],
    );
  }

  Widget _buildRealIntegrationDetails({
    required _FiscalRealIntegrationSetup setup,
    required Map<String, dynamic> certificate,
    required _FiscalOperationalReadiness readiness,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppBrandColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Certificado: ${setup.certificateRef.isEmpty ? 'pendente' : setup.certificateRef}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '${setup.usesFocusNationalApi ? 'Codigo fiscal nacional' : 'Codigo municipal'}: ${setup.municipalCode.isEmpty ? '-' : setup.municipalCode}',
          ),
          const SizedBox(height: 6),
          Text(
            'Endpoint fiscal: ${setup.apiBaseUrl.isEmpty ? '-' : setup.apiBaseUrl}',
          ),
          const SizedBox(height: 6),
          Text(
            'Token API: ${_tokenApiStatusLine(setup)}',
          ),
          const SizedBox(height: 6),
          Text(
            'Certificado digital: ${(certificate['fileName']?.toString().trim() ?? '').isEmpty ? 'nao enviado' : certificate['fileName']}',
          ),
          const SizedBox(height: 6),
          Text(
            'Validade certificado: ${(certificate['validUntil']?.toString().trim() ?? '').isEmpty ? 'pendente' : certificate['validUntil']}',
          ),
          const SizedBox(height: 6),
          Text(
            'Homologacao: ${setup.lastHomologationNote.isEmpty ? 'sem observacao registrada' : setup.lastHomologationNote}',
          ),
          const SizedBox(height: 6),
          Text(
            'Liberacao de producao: ${readiness.canOperateInProduction ? 'apta' : 'bloqueada'}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: readiness.canOperateInProduction
                  ? AppBrandColors.accent
                  : AppBrandColors.gold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationalReadinessCard(_FiscalOperationalReadiness readiness) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: readiness.isBlocked
            ? const Color(0xFFFFF7ED)
            : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: readiness.isBlocked
              ? const Color(0xFFF5C28B)
              : const Color(0xFFB7E4C7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            readiness.title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            readiness.description,
            style: const TextStyle(color: AppBrandColors.softText, height: 1.4),
          ),
          if (readiness.blockers.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Bloqueios atuais',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            ...readiness.blockers.map(
              (blocker) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 3),
                      child: Icon(
                        Icons.error_outline,
                        size: 16,
                        color: AppBrandColors.gold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(blocker)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFocusProvisioningCard(Map<String, dynamic> provisioning) {
    final status = provisioning['status']?.toString().trim() ?? 'PENDING';
    final focusCompanyId =
        provisioning['focusCompanyId']?.toString().trim() ?? '';
    final lastError = provisioning['lastError']?.toString().trim() ?? '';
    final missing =
        (provisioning['missing'] as List?)
            ?.map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList() ??
        const <String>[];
    final tone = _focusProvisioningTone(status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tone.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Provisionamento automatico Focus',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: tone.foreground,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _focusProvisioningStatusLabel(status),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: tone.foreground,
            ),
          ),
          if (focusCompanyId.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Empresa Focus ID: $focusCompanyId'),
          ],
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Pendencias: ${missing.join(', ')}',
              style: const TextStyle(height: 1.4),
            ),
          ],
          if (lastError.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Ultimo erro: $lastError',
              style: const TextStyle(height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  _ProvisioningTone _focusProvisioningTone(String status) {
    switch (status) {
      case 'SYNCED':
        return const _ProvisioningTone(
          background: Color(0xFFF0FDF4),
          border: Color(0xFFB7E4C7),
          foreground: Color(0xFF166534),
        );
      case 'ERROR':
        return const _ProvisioningTone(
          background: Color(0xFFFEF2F2),
          border: Color(0xFFFECACA),
          foreground: Color(0xFF991B1B),
        );
      case 'SKIPPED':
        return const _ProvisioningTone(
          background: Color(0xFFF8FAFC),
          border: AppBrandColors.border,
          foreground: AppBrandColors.softText,
        );
      default:
        return const _ProvisioningTone(
          background: Color(0xFFFFF7ED),
          border: Color(0xFFF5C28B),
          foreground: Color(0xFF9A3412),
        );
    }
  }

  String _focusProvisioningStatusLabel(String status) {
    switch (status) {
      case 'SYNCED':
        return 'Empresa provisionada automaticamente na Focus.';
      case 'ERROR':
        return 'A automacao tentou sincronizar a empresa, mas a Focus retornou erro.';
      case 'SKIPPED':
        return 'Provisionamento automatico ignorado para esta configuracao.';
      case 'PENDING':
        return 'Automacao ativa, aguardando dados obrigatorios para sincronizar.';
      default:
        return 'Provisionamento automatico em analise.';
    }
  }

  Widget _buildHomologationChecklistCard({
    required Session sessao,
    required _FiscalRealIntegrationSetup setup,
    required Map<String, dynamic> companySettings,
    required _FiscalOperationalReadiness readiness,
    required _FiscalHomologationChecklist checklist,
    required bool canConfigureModule,
  }) {
    final canEditChecklistSwitches = canConfigureModule;
    final certificate =
        (companySettings['fiscalCertificate'] as Map?)
            ?.cast<String, dynamic>() ??
        <String, dynamic>{};
    final hasFocusSync =
        (companySettings['focusCompanyId']?.toString().trim() ?? '').isNotEmpty;
    final helperItems = <_ChecklistTileConfig>[
      _ChecklistTileConfig(
        value: checklist.companyBaseReviewed,
        title: 'Cadastro base revisado',
        subtitle:
            'Confirme emitente, CNPJ, inscricao municipal, endereco e municipio.',
        onChanged: (value) => _saveFiscalHomologationChecklist(
          sessao: sessao,
          checklist: checklist.copyWith(companyBaseReviewed: value),
        ),
      ),
      _ChecklistTileConfig(
        value: checklist.certificateValidated,
        title: 'Certificado validado',
        subtitle: (certificate['validUntil']?.toString().trim() ?? '').isEmpty
            ? 'Envie e valide a vigencia do certificado digital.'
            : 'Certificado com validade registrada em ${certificate['validUntil']}.',
        onChanged: (value) => _saveFiscalHomologationChecklist(
          sessao: sessao,
          checklist: checklist.copyWith(certificateValidated: value),
        ),
      ),
      _ChecklistTileConfig(
        value: checklist.matrixValidated,
        title: 'Matriz fiscal conferida',
        subtitle:
            'Revise municipio base, ISS padrao, regras por servico e CNAE.',
        onChanged: (value) => _saveFiscalHomologationChecklist(
          sessao: sessao,
          checklist: checklist.copyWith(matrixValidated: value),
        ),
      ),
      _ChecklistTileConfig(
        value: checklist.providerConnectionValidated,
        title: 'Conexao com provedor validada',
        subtitle: setup.provider.trim().toLowerCase().contains('focus')
            ? hasFocusSync
                  ? 'Empresa sincronizada com a Focus. Validar retorno e credenciais.'
                  : 'Sincronize a empresa com a Focus e valide as credenciais.'
            : 'Valide token, endpoint e retorno basico do integrador.',
        onChanged: (value) => _saveFiscalHomologationChecklist(
          sessao: sessao,
          checklist: checklist.copyWith(providerConnectionValidated: value),
        ),
      ),
      _ChecklistTileConfig(
        value: checklist.pilotInvoiceValidated,
        title: 'Emissao piloto validada',
        subtitle:
            'Confirme emissao real, numero oficial, portal e retorno operacional da primeira nota.',
        onChanged: (value) => _saveFiscalHomologationChecklist(
          sessao: sessao,
          checklist: checklist.copyWith(pilotInvoiceValidated: value),
        ),
      ),
      _ChecklistTileConfig(
        value: checklist.productionAuthorized,
        title: 'Producao autorizada',
        subtitle: readiness.canOperateInProduction
            ? 'Empresa pronta para operar oficialmente em producao.'
            : 'A autorizacao final deve ser marcada apenas quando o readiness estiver sem bloqueios.',
        onChanged: readiness.canOperateInProduction
            ? (value) => _saveFiscalHomologationChecklist(
                sessao: sessao,
                checklist: checklist.copyWith(productionAuthorized: value),
              )
            : null,
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppBrandColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Checklist assistido de homologacao',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            canEditChecklistSwitches
                ? 'Checklist por empresa (cadastro, certificado, matriz, conexao, piloto). '
                    'Feche pendencias reais antes de autorizar producao. O backend pode exigir itens concluidos para emissao oficial.'
                : 'Sem permissao para alterar o checklist com este acesso. Pedido de ajuste pode ser feito ao responsavel da empresa.',
            style: const TextStyle(color: AppBrandColors.softText, height: 1.4),
          ),
          if (!canEditChecklistSwitches) ...[
            const SizedBox(height: 10),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline, size: 20, color: Color(0xFF303F9F)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Edicao do checklist exige permissao de configuracao fiscal nesta empresa.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _summaryChip(
                'Concluidos',
                '${checklist.completedCount}/${checklist.totalCount}',
              ),
              _summaryChip(
                'Pendentes',
                (checklist.totalCount - checklist.completedCount).toString(),
              ),
              _summaryChip(
                'Producao',
                checklist.productionAuthorized
                    ? 'Autorizada'
                    : 'Nao autorizada',
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...helperItems.map(
            (item) => SwitchListTile(
              value: item.value,
              onChanged: canEditChecklistSwitches ? item.onChanged : null,
              contentPadding: EdgeInsets.zero,
              title: Text(item.title),
              subtitle: Text(item.subtitle),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComplianceMatrixCard(_FiscalComplianceMatrix complianceMatrix) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppBrandColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Matriz fiscal ativa',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Municipio: ${complianceMatrix.municipalityName.isEmpty ? '-' : complianceMatrix.municipalityName}'
            ' | Codigo: ${complianceMatrix.municipalityCode.isEmpty ? '-' : complianceMatrix.municipalityCode}',
          ),
          const SizedBox(height: 6),
          Text(
            'ISS padrao: ${complianceMatrix.defaultIssRateText} | Regras de servico: ${complianceMatrix.rules.length}',
          ),
          const SizedBox(height: 6),
          Text(
            complianceMatrix.summary,
            style: const TextStyle(color: AppBrandColors.softText, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildRealIntegrationActions({
    required Session sessao,
    required Map<String, dynamic> companyData,
    required Map<String, dynamic> companySettings,
    required _FiscalRealIntegrationSetup setup,
    required _FiscalComplianceMatrix complianceMatrix,
    required bool canConfigureModule,
    required bool canEditGlobalFiscalIntegration,
  }) {
    final canOpenEmissionConfigDialog = canConfigureModule;
    final configButton = FilledButton.icon(
      onPressed: canOpenEmissionConfigDialog
          ? () => _openRealIntegrationDialog(sessao: sessao, current: setup)
          : null,
      icon: const Icon(Icons.hub_outlined),
      label: const Text('Configurar emissao real'),
    );
    final canEditCompanyFiscalPrep = canConfigureModule;
    final canCompanyFiscalActions = canConfigureModule;
    const fiscalPrepLockedHint =
        'Requer permissao para configurar o modulo fiscal nesta empresa.';

    final String? emissionConfigTooltip = !canConfigureModule
        ? 'Sem permissao para editar a configuracao fiscal com este acesso.'
        : (!canEditGlobalFiscalIntegration
              ? 'Ambiente, provedor, API Focus e URL base vêm da empresa suprema (somente leitura). '
                  'Aqui voce complementa codigo fiscal, certificado e observacoes desta empresa.'
              : null);
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          emissionConfigTooltip == null
              ? configButton
              : Tooltip(message: emissionConfigTooltip, child: configButton),
          Tooltip(
            message: canEditCompanyFiscalPrep
                ? 'Matriz fiscal desta empresa (municipio base, ISS, regras por servico/CNAE).'
                : fiscalPrepLockedHint,
            child: OutlinedButton.icon(
              onPressed: canEditCompanyFiscalPrep
                  ? () => _openComplianceMatrixDialog(
                        sessao: sessao,
                        setup: setup,
                        current: complianceMatrix,
                      )
                  : null,
              icon: const Icon(Icons.rule_folder_outlined),
              label: const Text('Matriz fiscal'),
            ),
          ),
          Tooltip(
            message: 'Certificado e documentos para o provisionamento na Focus.',
            child: OutlinedButton.icon(
              onPressed: canCompanyFiscalActions
                  ? () => _uploadDigitalCertificate(sessao)
                  : null,
              icon: const Icon(Icons.workspace_premium_outlined),
              label: const Text('Subir certificado'),
            ),
          ),
          Tooltip(
            message: canEditCompanyFiscalPrep
                ? 'Preenche cadastro e base fiscal desta empresa a partir do CNPJ (dados individuais).'
                : fiscalPrepLockedHint,
            child: OutlinedButton.icon(
              onPressed: canEditCompanyFiscalPrep
                  ? () => _prepareFiscalBaseFromCompany(
                        sessao: sessao,
                        companyData: companyData,
                        companySettings: companySettings,
                        current: setup,
                      )
                  : null,
              icon: const Icon(Icons.auto_fix_high_outlined),
              label: const Text('Preparar pelo CNPJ'),
            ),
          ),
          Tooltip(
            message: canEditCompanyFiscalPrep
                ? 'Reprocessar automacao de provisionamento Focus apenas para esta empresa.'
                : fiscalPrepLockedHint,
            child: OutlinedButton.icon(
              onPressed: canEditCompanyFiscalPrep
                  ? () => _refreshCompanyProvisioning(
                        successMessage:
                            'Automacao de provisionamento desta empresa reprocessada com sucesso.',
                      )
                  : null,
              icon: const Icon(Icons.settings_suggest_outlined),
              label: const Text('Reprocessar automacao'),
            ),
          ),
          if (setup.provider.trim().toLowerCase().contains('focus'))
            Tooltip(
              message:
                  'Sincronize esta empresa com a Focus apos o cadastro e a documentacao.',
              child: OutlinedButton.icon(
                onPressed: canCompanyFiscalActions
                    ? () => _syncFocusCompany(sessao: sessao)
                    : null,
                icon: const Icon(Icons.sync_outlined),
                label: const Text('Sincronizar Focus'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _saveRealIntegrationSetup(
    Session sessao,
    _FiscalRealIntegrationSetup setup,
  ) async {
    final before = await FirebaseFirestore.instance
        .collection('company_settings')
        .doc(sessao.companyId)
        .get();
    final previousFeatures =
        (before.data()?['fiscalFeatures'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    try {
      await FirebaseFirestore.instance
          .collection('company_settings')
          .doc(sessao.companyId)
          .set({
            'companyId': sessao.companyId,
            'fiscalRealIntegration': setup.toMap(),
            'fiscalFeatures': {
              ...previousFeatures,
              'enableRealInvoiceIntegration': setup.isPrepared,
            },
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      await _writeAuditLog(
        sessao: sessao,
        action: 'real_invoice_setup_updated',
        entityPath: 'company_settings',
        entityId: sessao.companyId,
        before: before.data(),
        after: {
          'fiscalRealIntegration': setup.toMap(),
          'enableRealInvoiceIntegration': setup.isPrepared,
        },
      );
      await _refreshCompanyProvisioning(
        successMessage:
            'Base de emissao fiscal real atualizada e automacao reprocessada.',
      );
    } catch (_) {
      _msg('Nao foi possivel salvar a base de emissao real.');
    }
  }

  Future<void> _openComplianceMatrixDialog({
    required Session sessao,
    required _FiscalRealIntegrationSetup setup,
    required _FiscalComplianceMatrix current,
  }) async {
    final municipalityNameController = TextEditingController(
      text: current.municipalityName,
    );
    final municipalityCodeController = TextEditingController(
      text: current.municipalityCode,
    );
    final providerController = TextEditingController(text: current.provider);
    final defaultIssRateController = TextEditingController(
      text: current.defaultIssRateText,
    );
    final customerCostLegalTextController = TextEditingController(
      text: current.customerCostLegalText,
    );
    final generalLegalTextController = TextEditingController(
      text: current.generalLegalText,
    );

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Matriz fiscal por municipio/provedor'),
        content: SizedBox(
          width: 700,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: municipalityNameController,
                  decoration: const InputDecoration(
                    labelText: 'Municipio base da matriz',
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: municipalityCodeController,
                        decoration: const InputDecoration(
                          labelText: 'Codigo municipal',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: providerController,
                        decoration: const InputDecoration(
                          labelText: 'Provedor',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: defaultIssRateController,
                  decoration: const InputDecoration(
                    labelText: 'Aliquota ISS padrao (%)',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: generalLegalTextController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Texto juridico padrao da matriz',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: customerCostLegalTextController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Texto juridico do acrescimo ao tomador',
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Regras por servico herdadas automaticamente: ${current.rules.length}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
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
              final next = current.copyWith(
                municipalityName: municipalityNameController.text.trim(),
                municipalityCode: municipalityCodeController.text.trim(),
                provider: providerController.text.trim().isEmpty
                    ? setup.provider
                    : providerController.text.trim(),
                defaultIssRateText: defaultIssRateController.text.trim(),
                generalLegalText: generalLegalTextController.text.trim(),
                customerCostLegalText: customerCostLegalTextController.text
                    .trim(),
              );
              await _saveComplianceMatrix(sessao, next);
              if (!ctx.mounted) return;
              Navigator.of(ctx).pop();
            },
            child: const Text('Salvar matriz'),
          ),
        ],
      ),
    );

    municipalityNameController.dispose();
    municipalityCodeController.dispose();
    providerController.dispose();
    defaultIssRateController.dispose();
    customerCostLegalTextController.dispose();
    generalLegalTextController.dispose();
  }

  Future<void> _saveComplianceMatrix(
    Session sessao,
    _FiscalComplianceMatrix matrix,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('company_settings')
          .doc(sessao.companyId)
          .set({
            'companyId': sessao.companyId,
            'fiscalComplianceMatrix': matrix.toMap(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      _msg('Matriz fiscal atualizada.');
    } catch (_) {
      _msg('Nao foi possivel salvar a matriz fiscal.');
    }
  }

  Future<void> _uploadDigitalCertificate(Session sessao) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      withData: true,
      allowedExtensions: const ['pfx', 'p12'],
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      _msg('Nao foi possivel ler o certificado digital.');
      return;
    }

    final passwordController = TextEditingController();
    final loginResponsavelController = TextEditingController();
    final senhaResponsavelController = TextEditingController();
    bool confirm = false;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Salvar certificado digital'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Arquivo selecionado: ${file.name}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Senha do certificado',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: loginResponsavelController,
                decoration: const InputDecoration(
                  labelText: 'Login da prefeitura (se houver)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: senhaResponsavelController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Senha da prefeitura (se houver)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              confirm = true;
              Navigator.of(context).pop();
            },
            child: const Text('Salvar certificado'),
          ),
        ],
      ),
    );

    if (!confirm) {
      passwordController.dispose();
      loginResponsavelController.dispose();
      senhaResponsavelController.dispose();
      return;
    }

    try {
      final extension = (file.extension ?? 'pfx').toLowerCase();
      final storagePath =
          'companies/${sessao.companyId}/fiscal/certificates/certificate.$extension';
      final refStorage = FirebaseStorage.instance.ref(storagePath);
      await refStorage.putData(
        bytes,
        SettableMetadata(
          contentType: 'application/x-pkcs12',
          customMetadata: {
            'companyId': sessao.companyId,
            'uploadedBy': sessao.userId,
            'originalName': file.name,
          },
        ),
      );

      await FirebaseFirestore.instance
          .collection('company_settings')
          .doc(sessao.companyId)
          .set({
            'companyId': sessao.companyId,
            'fiscalCertificate': {
              'storagePath': storagePath,
              'fileName': file.name,
              'extension': extension,
              'uploadedAt': FieldValue.serverTimestamp(),
              'uploadedByUserId': sessao.userId,
            },
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('fiscal_secure')
          .doc(sessao.companyId)
          .set({
            'companyId': sessao.companyId,
            'fiscalCertificateSecrets': {
              'password': passwordController.text.trim(),
              'loginResponsavel': loginResponsavelController.text.trim(),
              'senhaResponsavel': senhaResponsavelController.text.trim(),
            },
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      await _writeAuditLog(
        sessao: sessao,
        action: 'fiscal_certificate_uploaded',
        entityPath: 'company_settings',
        entityId: sessao.companyId,
        after: {'storagePath': storagePath, 'fileName': file.name},
      );

      await _refreshCompanyProvisioning(
        successMessage:
            'Certificado salvo e automacao fiscal reprocessada com sucesso.',
      );
    } catch (_) {
      _msg('Nao foi possivel salvar o certificado digital.');
    } finally {
      passwordController.dispose();
      loginResponsavelController.dispose();
      senhaResponsavelController.dispose();
    }
  }

  Future<void> _syncFocusCompany({required Session sessao}) async {
    try {
      final callable = _fiscalFunctions.httpsCallable('fiscalSyncFocusCompany');
      final response = await callable.call();
      final data = response.data;
      final map = data is Map
          ? data.map((key, value) => MapEntry(key.toString(), value))
          : <String, dynamic>{};
      final focusCompanyId = map['focusCompanyId']?.toString().trim() ?? '';
      final validUntil = map['certificadoValidoAte']?.toString().trim() ?? '';
      _msg(
        focusCompanyId.isEmpty
            ? 'Empresa sincronizada com a Focus NFe.'
            : 'Focus sincronizada. Empresa ID $focusCompanyId${validUntil.isEmpty ? '' : ' | certificado ate $validUntil'}',
      );
    } on FirebaseFunctionsException catch (e) {
      _msg(e.message ?? 'Nao foi possivel sincronizar com a Focus NFe.');
    } catch (_) {
      _msg('Nao foi possivel sincronizar com a Focus NFe.');
    }
  }

  Future<void> _refreshCompanyProvisioning({
    String? successMessage,
    String? fallbackErrorMessage,
  }) async {
    try {
      final callable = _fiscalFunctions.httpsCallable(
        'fiscalRefreshCompanyProvisioning',
      );
      final response = await callable.call();
      final data = response.data;
      final map = data is Map
          ? data.map((key, value) => MapEntry(key.toString(), value))
          : <String, dynamic>{};
      final status = map['focusProvisioningStatus']?.toString().trim() ?? '';
      final focusCompanyId = map['focusCompanyId']?.toString().trim() ?? '';
      final missing =
          (map['focusProvisioningMissing'] as List?)
              ?.map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList() ??
          const <String>[];
      final error = map['focusProvisioningError']?.toString().trim() ?? '';

      if (status == 'SYNCED') {
        _msg(
          successMessage ??
              (focusCompanyId.isEmpty
                  ? 'Provisionamento automatico da Focus concluido.'
                  : 'Provisionamento automatico concluido. Empresa Focus ID $focusCompanyId.'),
        );
        return;
      }

      if (status == 'PENDING') {
        final pendencias = missing.isEmpty
            ? 'dados pendentes'
            : missing.join(', ');
        _msg('Automacao fiscal reprocessada. Pendencias atuais: $pendencias.');
        return;
      }

      if (status == 'ERROR') {
        _msg(
          error.isEmpty
              ? (fallbackErrorMessage ??
                    'A automacao fiscal foi reprocessada, mas a Focus rejeitou a sincronizacao.')
              : 'A automacao fiscal foi reprocessada, mas a Focus retornou: $error',
        );
        return;
      }

      if ((successMessage ?? '').trim().isNotEmpty) {
        _msg(successMessage!.trim());
      }
    } on FirebaseFunctionsException catch (e) {
      _msg(
        e.message ??
            fallbackErrorMessage ??
            'Nao foi possivel reprocessar a automacao fiscal da empresa.',
      );
    } catch (_) {
      _msg(
        fallbackErrorMessage ??
            'Nao foi possivel reprocessar a automacao fiscal da empresa.',
      );
    }
  }

  Future<void> _saveFiscalHomologationChecklist({
    required Session sessao,
    required _FiscalHomologationChecklist checklist,
  }) async {
    final settingsRef = FirebaseFirestore.instance
        .collection('company_settings')
        .doc(sessao.companyId);
    final before = await settingsRef.get();
    try {
      await settingsRef.set({
        'companyId': sessao.companyId,
        'fiscalHomologationChecklist': checklist.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _writeAuditLog(
        sessao: sessao,
        action: 'fiscal_homologation_checklist_update',
        entityPath: 'company_settings',
        entityId: sessao.companyId,
        before: before.data(),
        after: {'fiscalHomologationChecklist': checklist.toMap()},
      );
    } catch (_) {
      _msg('Nao foi possivel salvar o checklist de homologacao.');
    }
  }

  Future<void> _saveFiscalCompetenceChecks({
    required Session sessao,
    required String competence,
    required _FiscalCompetenceChecks checks,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('fiscal_competence_checks')
          .doc('${sessao.companyId}_$competence')
          .set({
            'companyId': sessao.companyId,
            'competence': competence,
            ...checks.toMap(),
            'updatedByUserId': sessao.userId,
            'updatedByUserName': sessao.nome,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (_) {
      _msg('Nao foi possivel salvar o checklist fiscal.');
    }
  }

  Future<void> _openCompetenceNotesDialog({
    required String competence,
    required String title,
    required String initialValue,
    required Future<void> Function(String value) onSave,
  }) async {
    final controller = TextEditingController(text: initialValue);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Observacoes da competencia',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              await onSave(controller.text.trim());
              if (!context.mounted) return;
              Navigator.of(context).pop();
              _msg('Observacoes salvas para $competence.');
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _exportFiscalSummaryPdf({
    required Session sessao,
    required Map<String, dynamic> companyData,
    required _FiscalRealIntegrationSetup realIntegration,
    required String competence,
  }) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('service_invoices')
          .where('companyId', isEqualTo: sessao.companyId)
          .get();
      final competenceInvoices =
          snapshot.docs.where((doc) {
            final referenceDate = _invoiceReferenceDate(doc.data());
            return '${referenceDate.year}-${referenceDate.month.toString().padLeft(2, '0')}' ==
                competence;
          }).toList()..sort(
            (a, b) => _invoiceReferenceDate(
              b.data(),
            ).compareTo(_invoiceReferenceDate(a.data())),
          );
      final invoiceCount = competenceInvoices.length;
      final officialMissing = competenceInvoices
          .where(
            (doc) =>
                _invoiceOfficialNumber(doc.data()).isEmpty,
          )
          .length;
      final portalMissing = competenceInvoices
          .where(
            (doc) => (doc.data()['officialPortalUrl']?.toString().trim() ?? '')
                .isEmpty,
          )
          .length;
      var grossAmountOfficialCents = 0;
      for (final doc in competenceInvoices) {
        final d = doc.data();
        if (_fiscalStatusIsApprovedOrLegacyEmitted(d['status']?.toString()) &&
            _invoiceOfficialNumber(d).isNotEmpty) {
          grossAmountOfficialCents += _invoiceGrossAmount(d);
        }
      }
      final netAmount = competenceInvoices.fold<int>(
        0,
        (total, doc) =>
            total +
            ((((doc.data()['tax'] as Map?)?['netAmountCents'] as num?)
                    ?.toInt()) ??
                (_invoiceGrossAmount(doc.data()))),
      );
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (context) => [
            pw.Text(
              'Resumo fiscal / contador - competencia $competence',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18),
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              'Empresa: ${companyData['razaoSocial'] ?? companyData['nomeFantasia'] ?? '-'}',
            ),
            pw.Text('CNPJ: ${companyData['cnpj'] ?? '-'}'),
            pw.Text('CNAE principal: ${companyData['mainCnae'] ?? '-'}'),
            pw.Text(
              'Descricao CNAE: ${companyData['mainCnaeDescription'] ?? '-'}',
            ),
            pw.Text(
              'Regime tributario: ${companyData['regimeTributario'] ?? _inferTaxRegime(companyData)}',
            ),
            pw.Text('Provedor configurado: ${realIntegration.providerLabel}'),
            pw.Text('Ambiente: ${realIntegration.environmentLabel}'),
            pw.SizedBox(height: 12),
            pw.Bullet(text: 'Notas monitoradas: $invoiceCount'),
            pw.Bullet(text: 'Notas sem numero oficial: $officialMissing'),
            pw.Bullet(text: 'Notas sem portal oficial: $portalMissing'),
            pw.Bullet(
              text:
                  'Valor bruto (emitidas com numero oficial): ${_formatCurrency(grossAmountOfficialCents)}',
            ),
            pw.Bullet(
              text: 'Valor liquido total: ${_formatCurrency(netAmount)}',
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              'Documento preparatorio para conferencia interna e envio ao contador por PDF, email ou WhatsApp.',
            ),
            pw.SizedBox(height: 14),
            pw.Text(
              'Notas da competencia',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
            ),
            pw.SizedBox(height: 8),
            if (competenceInvoices.isEmpty)
              pw.Text('Nenhuma nota cadastrada nesta competencia.')
            else
              ...competenceInvoices.map((doc) {
                final data = doc.data();
                final service =
                    (data['service'] as Map?)?.cast<String, dynamic>() ??
                    <String, dynamic>{};
                final tax =
                    (data['tax'] as Map?)?.cast<String, dynamic>() ??
                    <String, dynamic>{};
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 10),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        '${data['clientName'] ?? '-'} - ${_formatCurrency((data['amountCents'] as num?)?.toInt() ?? 0)}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text('Documento: ${data['clientDocument'] ?? '-'}'),
                      pw.Text('Servico: ${data['serviceDescription'] ?? '-'}'),
                      pw.Text(
                        'Codigo servico: ${service['serviceCode'] ?? '-'} | CNAE: ${service['cnae'] ?? '-'}',
                      ),
                      pw.Text(
                        'ISS: ${_formatCurrency((tax['issAmountCents'] as num?)?.toInt() ?? 0)} | Liquido: ${_formatCurrency((tax['netAmountCents'] as num?)?.toInt() ?? ((data['amountCents'] as num?)?.toInt() ?? 0))}',
                      ),
                      pw.Text(
                        'Status: ${_invoiceStatusLabel(data['status']?.toString())} | Numero oficial: ${_invoiceOfficialNumber(data).isNotEmpty ? _invoiceOfficialNumber(data) : 'pendente'}',
                      ),
                      if ((((data['sourceTask'] as Map?)?['id']
                                  ?.toString()
                                  .trim() ??
                              '')
                          .isNotEmpty))
                        pw.Text('Origem: ${_invoiceSourceTaskLabel(data)}'),
                      if ((data['financeMovementId']?.toString().trim() ?? '')
                          .isNotEmpty)
                        pw.Text('Financeiro: ${data['financeMovementId']}'),
                    ],
                  ),
                );
              }),
          ],
        ),
      );
      await Printing.layoutPdf(onLayout: (_) async => pdf.save());
      _msg('Resumo fiscal gerado em PDF.');
    } catch (_) {
      _msg('Nao foi possivel gerar o resumo fiscal.');
    }
  }

  Future<void> _openFiscalSettingsRequestDialog(
    Session sessao,
    _FiscalSettings settings,
  ) async {
    var mode = settings.mode;
    var enableOfficialInvoicePrep = settings.enableOfficialInvoicePrep;
    final noteController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Solicitar ajuste fiscal'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<_FiscalMode>(
                  initialValue: mode,
                  decoration: const InputDecoration(labelText: 'Modo'),
                  items: const [
                    DropdownMenuItem(
                      value: _FiscalMode.simple,
                      child: Text('Simples'),
                    ),
                    DropdownMenuItem(
                      value: _FiscalMode.advanced,
                      child: Text('Completo'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => mode = value);
                    }
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: enableOfficialInvoicePrep,
                  onChanged: (value) =>
                      setDialogState(() => enableOfficialInvoicePrep = value),
                  title: const Text('NFS-e oficial'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: noteController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Motivo da solicitacao',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final requestId =
                    '${sessao.companyId}_fiscal_settings_${DateTime.now().millisecondsSinceEpoch}';
                await FirebaseFirestore.instance
                    .collection('period_closes')
                    .doc(requestId)
                    .set({
                      'companyId': sessao.companyId,
                      'module': 'fiscal_settings_change',
                      'competence': 'SETTINGS',
                      'status': 'PENDING_APPROVAL',
                      'requestedByUserId': sessao.userId,
                      'requestedByUserName': sessao.nome,
                      'requestedAt': FieldValue.serverTimestamp(),
                      'note': noteController.text.trim(),
                      'proposedFiscalMode': mode.name,
                      'proposedFiscalFeatures': {
                        'enableOfficialInvoicePrep': enableOfficialInvoicePrep,
                        'enableRealInvoiceIntegration': false,
                        'enablePayrollTaxPrep': false,
                        'enableThirteenthSalary': false,
                        'enableVacation': false,
                        'enableTermination': false,
                        'enableBenefits': false,
                      },
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                await _writeAuditLog(
                  sessao: sessao,
                  action: 'settings_change_requested',
                  entityPath: 'period_closes',
                  entityId: requestId,
                  after: {
                    'module': 'fiscal_settings_change',
                    'note': noteController.text.trim(),
                  },
                );
                if (!context.mounted) return;
                Navigator.of(context).pop();
                _msg('Solicitacao fiscal enviada para aprovacao do dono.');
              },
              child: const Text('Solicitar'),
            ),
          ],
        ),
      ),
    );

    noteController.dispose();
  }

  Future<void> _resolveFiscalSettingsRequest({
    required Session sessao,
    required String requestId,
    required bool approve,
  }) async {
    try {
      final requestRef = FirebaseFirestore.instance
          .collection('period_closes')
          .doc(requestId);
      final snapshot = await requestRef.get();
      final data = snapshot.data();
      if (data == null) {
        _msg('Solicitacao nao encontrada.');
        return;
      }
      final resolutionComment = await _askResolutionComment(approve: approve);
      if (resolutionComment == null) return;
      if (!approve) {
        await requestRef.set({
          'status': 'REJECTED',
          'resolvedByUserId': sessao.userId,
          'resolvedByUserName': sessao.nome,
          'resolutionComment': resolutionComment,
          'resolvedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        await _writeAuditLog(
          sessao: sessao,
          action: 'settings_change_rejected',
          entityPath: 'period_closes',
          entityId: requestId,
          after: {'status': 'REJECTED', 'resolutionComment': resolutionComment},
        );
        _msg('Solicitacao rejeitada.');
        return;
      }

      final settingsRef = FirebaseFirestore.instance
          .collection('company_settings')
          .doc(sessao.companyId);
      final before = await settingsRef.get();
      final features =
          (data['proposedFiscalFeatures'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{};
      await settingsRef.set({
        'companyId': sessao.companyId,
        'fiscalMode': data['proposedFiscalMode']?.toString() ?? 'simple',
        'fiscalFeatures': features,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await requestRef.set({
        'status': 'APPROVED',
        'resolvedByUserId': sessao.userId,
        'resolvedByUserName': sessao.nome,
        'resolutionComment': resolutionComment,
        'resolvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _writeAuditLog(
        sessao: sessao,
        action: 'settings_change_approved',
        entityPath: 'company_settings',
        entityId: sessao.companyId,
        before: before.data(),
        after: {
          'fiscalMode': data['proposedFiscalMode']?.toString() ?? 'simple',
          'fiscalFeatures': features,
          'resolutionComment': resolutionComment,
        },
      );
      _msg('Configuracao fiscal aprovada e aplicada.');
    } catch (_) {
      _msg('Nao foi possivel resolver a solicitacao fiscal.');
    }
  }

  Future<void> _writeAuditLog({
    required Session sessao,
    required String action,
    required String entityPath,
    required String entityId,
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('audit_logs').add({
        'companyId': sessao.companyId,
        'actorUserId': sessao.userId,
        'actorRole': sessao.role.name,
        'module': 'fiscal',
        'action': action,
        'entityPath': entityPath,
        'entityId': entityId,
        'before': before,
        'after': after,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Nao bloqueia o fluxo principal.
    }
  }

  Future<String?> _askResolutionComment({required bool approve}) async {
    final controller = TextEditingController();
    String? result;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(approve ? 'Aprovar solicitacao' : 'Rejeitar solicitacao'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Comentario da decisao'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              result = controller.text.trim();
              Navigator.of(context).pop();
            },
            child: Text(approve ? 'Aprovar' : 'Rejeitar'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Widget _featureToggle({
    required String label,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return FilterChip(
      label: Text(label),
      selected: value,
      onSelected: onChanged,
    );
  }

  Widget _summaryChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD3DDF3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF51627E)),
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  String _requestedFiscalSummary(Map<String, dynamic> data) {
    final mode = data['proposedFiscalMode']?.toString() ?? 'simple';
    final features =
        (data['proposedFiscalFeatures'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    final active = <String>[
      if (features['enableOfficialInvoicePrep'] == true) 'NFS-e',
      if (features['enableRealInvoiceIntegration'] == true) 'integracao real',
    ];
    return 'Modo ${mode == 'advanced' ? 'completo' : 'simples'} | Recursos: ${active.isEmpty ? 'nenhum ativo' : active.join(', ')}';
  }

  String _invoiceStatusLabel(String? status) {
    return switch ((status ?? 'DRAFT').toUpperCase()) {
      'EMITTED' => 'Aprovada',
      'APPROVED' => 'Aprovada',
      'CANCELED' => 'Cancelada',
      'CANCELLED' => 'Cancelada',
      'PROCESSANDO' => 'Processando',
      'PROCESSING' => 'Processando',
      'FAILED' => 'Falha',
      'REJECTED' => 'Rejeitada',
      _ => 'Rascunho',
    };
  }

  bool _invoiceIsOfficiallyIssued(Map<String, dynamic> data) {
    final status = (data['status']?.toString() ?? '').toUpperCase();
    if (status == 'CANCELED' || status == 'CANCELLED') {
      return false;
    }
    if (status == 'EMITTED' || status == 'APPROVED') {
      return true;
    }
    return _invoiceOfficialNumber(data).isNotEmpty;
  }

  bool _invoiceIsCanceled(Map<String, dynamic> data) {
    final status = (data['status']?.toString() ?? '').toUpperCase();
    return status == 'CANCELED' || status == 'CANCELLED';
  }

  int _invoiceGrossAmount(Map<String, dynamic> data) {
    final service = data['service'] as Map?;
    return (data['amountCents'] as num?)?.toInt() ??
        (service?['grossAmountCents'] as num?)?.toInt() ??
        0;
  }

  String? _invoiceDerivedStatus(Map<String, dynamic> data) {
    return data['status']?.toString();
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

  DateTime _invoiceReferenceDate(Map<String, dynamic> data) {
    final officialIssuedAt = data['officialIssuedAt'];
    if (officialIssuedAt is Timestamp) return officialIssuedAt.toDate();
    if (officialIssuedAt is DateTime) return officialIssuedAt;
    if (officialIssuedAt is String) {
      final parsed = DateTime.tryParse(officialIssuedAt);
      if (parsed != null) return parsed;
    }
    final issueDate = data['issueDate'];
    if (issueDate is Timestamp) return issueDate.toDate();
    if (issueDate is DateTime) return issueDate;
    if (issueDate is String) {
      final parsed = DateTime.tryParse(issueDate);
      if (parsed != null) return parsed;
    }
    final serviceDate = data['serviceDate'];
    if (serviceDate is Timestamp) return serviceDate.toDate();
    if (serviceDate is DateTime) return serviceDate;
    if (serviceDate is String) {
      final parsed = DateTime.tryParse(serviceDate);
      if (parsed != null) return parsed;
    }
    final createdAt = data['createdAt'];
    if (createdAt is Timestamp) return createdAt.toDate();
    if (createdAt is DateTime) return createdAt;
    if (createdAt is String) {
      final parsed = DateTime.tryParse(createdAt);
      if (parsed != null) return parsed;
    }
    return DateTime.now();
  }

  String _formatDateTime(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final h = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return '$d/$m/${date.year} $h:$min';
  }

  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }

  void _maybeAdjustCompetenceToLatestInvoices(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String competence,
  ) {
    if (docs.isEmpty) return;
    final hasCurrentCompetence = docs.any((doc) {
      final referenceDate = _invoiceReferenceDate(doc.data());
      final docCompetence =
          '${referenceDate.year}-${referenceDate.month.toString().padLeft(2, '0')}';
      return docCompetence == competence;
    });
    if (hasCurrentCompetence) return;

    final latestReference = docs
        .map((doc) => _invoiceReferenceDate(doc.data()))
        .toList()
      ..sort((a, b) => b.compareTo(a));
    final latest = latestReference.first;
    final latestCompetence =
        '${latest.year}-${latest.month.toString().padLeft(2, '0')}';
    if (latestCompetence == competence || latestCompetence == _lastAutoCompetence) {
      return;
    }
    _lastAutoCompetence = latestCompetence;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _competenceController.text = latestCompetence;
      });
    });
  }

  String _onlyDigits(String input) {
    return input.replaceAll(RegExp(r'\D'), '');
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

  double _parsePercent(String value) {
    final normalized = value.trim().replaceAll('%', '').replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0;
  }

  /// BRL: `R$ 1.234,56` (separador de milhar como no padrao BR).
  String _formatCurrency(int cents) {
    final absCents = cents.abs();
    final reais = absCents ~/ 100;
    final cent = (absCents % 100).toString().padLeft(2, '0');
    final reaisStr = reais.toString();
    final out = StringBuffer();
    for (var i = 0; i < reaisStr.length; i++) {
      if (i > 0 && (reaisStr.length - i) % 3 == 0) {
        out.write('.');
      }
      out.write(reaisStr[i]);
    }
    final main = out.toString();
    if (cents < 0) {
      return '- R\$ $main,$cent';
    }
    return 'R\$ $main,$cent';
  }

  String _employeeCompensationLabel(Employee employee) {
    final amount = employee.salaryAmountCents == null
        ? '-'
        : _formatCurrency(employee.salaryAmountCents!);
    return switch (employee.compensationType) {
      EmployeeCompensationType.daily => 'Diaria $amount',
      EmployeeCompensationType.weekly => 'Semanal $amount',
      EmployeeCompensationType.commission =>
        employee.commissionPercent == null
            ? 'Comissao'
            : 'Comissao ${employee.commissionPercent!.toStringAsFixed(2)}%',
      EmployeeCompensationType.monthly => 'Mensal $amount',
    };
  }

  void _msg(String text, {BuildContext? messageContext}) {
    if (!mounted) return;
    (messageContext ?? context).showUserMessage(text);
  }

  /// Nunca exibir o segredo; credencial global na infra (Functions / env).
  String _tokenApiStatusLine(_FiscalRealIntegrationSetup setup) {
    if (setup.usesPlatformFocusToken) {
      return 'gerenciada pela plataforma (valor nao exibido)';
    }
    if (setup.apiToken.trim().isEmpty) {
      return 'nao informado';
    }
    return 'definido no cadastro (valor nao exibido por seguranca)';
  }

  _FiscalOperationalReadiness _buildFiscalOperationalReadiness({
    required _FiscalRealIntegrationSetup setup,
    required Map<String, dynamic> certificate,
    required Map<String, dynamic> companySettings,
  }) {
    final blockers = <String>[];
    final certificateFile = certificate['fileName']?.toString().trim() ?? '';
    final certificateValidUntil =
        certificate['validUntil']?.toString().trim() ?? '';
    final focusCompanyId =
        companySettings['focusCompanyId']?.toString().trim() ?? '';

    if (setup.provider.trim().isEmpty) {
      blockers.add('Definir o provedor fiscal da empresa.');
    }
    if (setup.environment.trim().isEmpty) {
      blockers.add('Definir o ambiente de operacao fiscal.');
    }
    if (setup.municipalCode.trim().isEmpty) {
      blockers.add(
        setup.usesFocusNationalApi
            ? 'Informar o codigo fiscal nacional/base da emissao.'
            : 'Informar o codigo municipal base da emissao.',
      );
    }
    if (setup.apiToken.trim().isEmpty && !setup.usesPlatformFocusToken) {
      blockers.add('Informar o token/API key da integracao fiscal.');
    }
    if (setup.provider.trim().toLowerCase().contains('focus') &&
        focusCompanyId.isEmpty) {
      blockers.add(
        'Sincronizar a empresa com a Focus NFe antes da operacao oficial.',
      );
    }
    if (certificateFile.isEmpty) {
      blockers.add('Enviar o certificado digital da empresa.');
    }
    if (setup.certificateRef.trim().isEmpty) {
      blockers.add('Registrar a referencia operacional do certificado.');
    }
    if (certificateValidUntil.isEmpty) {
      blockers.add('Validar a vigencia do certificado digital.');
    }
    if (setup.lastHomologationNote.trim().isEmpty) {
      blockers.add('Registrar a observacao/checklist de homologacao.');
    }

    final canOperateInProduction =
        setup.environment.trim().toLowerCase() == 'producao' &&
        blockers.isEmpty;
    if (setup.environment.trim().toLowerCase() == 'producao' &&
        !canOperateInProduction) {
      blockers.insert(
        0,
        'A empresa esta em producao sem readiness completo para emissao oficial.',
      );
    }

    if (blockers.isEmpty) {
      return _FiscalOperationalReadiness(
        stageLabel: canOperateInProduction
            ? 'Producao liberada'
            : 'Homologacao pronta',
        title: canOperateInProduction
            ? 'Empresa apta para operacao oficial'
            : 'Base pronta para homologacao controlada',
        description: canOperateInProduction
            ? 'A configuracao fiscal minima da empresa esta consistente para emissao oficial em producao.'
            : 'A estrutura minima esta pronta. O proximo passo seguro e concluir homologacao assistida antes de operar em producao.',
        blockers: const [],
      );
    }

    return _FiscalOperationalReadiness(
      stageLabel: setup.environment.trim().toLowerCase() == 'producao'
          ? 'Producao bloqueada'
          : 'Homologacao pendente',
      title: 'Emissao oficial bloqueada por readiness incompleto',
      description:
          'A integracao fiscal existe, mas ainda faltam criterios operacionais minimos para tratar a empresa como pronta para emissao oficial segura.',
      blockers: blockers,
    );
  }
}

enum _FiscalMode { simple, advanced }

class _FiscalSettings {
  const _FiscalSettings({
    required this.mode,
    required this.enableOfficialInvoicePrep,
    required this.enableRealInvoiceIntegration,
    required this.enablePayrollTaxPrep,
    required this.enableThirteenthSalary,
    required this.enableVacation,
    required this.enableTermination,
    required this.enableBenefits,
  });

  factory _FiscalSettings.fromSettings(Map<String, dynamic> companySettings) {
    final mode =
        (companySettings['fiscalMode']?.toString() ?? 'simple') == 'advanced'
        ? _FiscalMode.advanced
        : _FiscalMode.simple;
    final raw = companySettings['fiscalFeatures'];
    final features = raw is Map
        ? raw.map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{};
    final fallback = mode == _FiscalMode.simple
        ? const _FiscalSettings(
            mode: _FiscalMode.simple,
            enableOfficialInvoicePrep: true,
            enableRealInvoiceIntegration: false,
            enablePayrollTaxPrep: true,
            enableThirteenthSalary: false,
            enableVacation: false,
            enableTermination: false,
            enableBenefits: false,
          )
        : const _FiscalSettings(
            mode: _FiscalMode.advanced,
            enableOfficialInvoicePrep: true,
            enableRealInvoiceIntegration: false,
            enablePayrollTaxPrep: true,
            enableThirteenthSalary: true,
            enableVacation: true,
            enableTermination: true,
            enableBenefits: true,
          );
    return fallback.copyWith(
      enableOfficialInvoicePrep:
          features['enableOfficialInvoicePrep'] as bool? ??
          fallback.enableOfficialInvoicePrep,
      enableRealInvoiceIntegration:
          features['enableRealInvoiceIntegration'] as bool? ??
          fallback.enableRealInvoiceIntegration,
      enablePayrollTaxPrep:
          features['enablePayrollTaxPrep'] as bool? ??
          fallback.enablePayrollTaxPrep,
      enableThirteenthSalary:
          features['enableThirteenthSalary'] as bool? ??
          fallback.enableThirteenthSalary,
      enableVacation:
          features['enableVacation'] as bool? ?? fallback.enableVacation,
      enableTermination:
          features['enableTermination'] as bool? ?? fallback.enableTermination,
      enableBenefits:
          features['enableBenefits'] as bool? ?? fallback.enableBenefits,
    );
  }

  final _FiscalMode mode;
  final bool enableOfficialInvoicePrep;
  final bool enableRealInvoiceIntegration;
  final bool enablePayrollTaxPrep;
  final bool enableThirteenthSalary;
  final bool enableVacation;
  final bool enableTermination;
  final bool enableBenefits;

  _FiscalSettings copyWith({
    _FiscalMode? mode,
    bool? enableOfficialInvoicePrep,
    bool? enableRealInvoiceIntegration,
    bool? enablePayrollTaxPrep,
    bool? enableThirteenthSalary,
    bool? enableVacation,
    bool? enableTermination,
    bool? enableBenefits,
  }) {
    return _FiscalSettings(
      mode: mode ?? this.mode,
      enableOfficialInvoicePrep:
          enableOfficialInvoicePrep ?? this.enableOfficialInvoicePrep,
      enableRealInvoiceIntegration:
          enableRealInvoiceIntegration ?? this.enableRealInvoiceIntegration,
      enablePayrollTaxPrep: enablePayrollTaxPrep ?? this.enablePayrollTaxPrep,
      enableThirteenthSalary:
          enableThirteenthSalary ?? this.enableThirteenthSalary,
      enableVacation: enableVacation ?? this.enableVacation,
      enableTermination: enableTermination ?? this.enableTermination,
      enableBenefits: enableBenefits ?? this.enableBenefits,
    );
  }

  _FiscalSettings simplePreset() {
    return const _FiscalSettings(
      mode: _FiscalMode.simple,
      enableOfficialInvoicePrep: true,
      enableRealInvoiceIntegration: false,
      enablePayrollTaxPrep: true,
      enableThirteenthSalary: false,
      enableVacation: false,
      enableTermination: false,
      enableBenefits: false,
    );
  }

  _FiscalSettings advancedPreset() {
    return const _FiscalSettings(
      mode: _FiscalMode.advanced,
      enableOfficialInvoicePrep: true,
      enableRealInvoiceIntegration: false,
      enablePayrollTaxPrep: true,
      enableThirteenthSalary: true,
      enableVacation: true,
      enableTermination: true,
      enableBenefits: true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enableOfficialInvoicePrep': enableOfficialInvoicePrep,
      'enableRealInvoiceIntegration': enableRealInvoiceIntegration,
      'enablePayrollTaxPrep': enablePayrollTaxPrep,
      'enableThirteenthSalary': enableThirteenthSalary,
      'enableVacation': enableVacation,
      'enableTermination': enableTermination,
      'enableBenefits': enableBenefits,
    };
  }
}

class _FiscalRealIntegrationSetup {
  const _FiscalRealIntegrationSetup({
    required this.environment,
    required this.provider,
    required this.focusNfseApi,
    required this.municipalCode,
    required this.certificateRef,
    required this.apiBaseUrl,
    required this.apiToken,
    required this.lastHomologationNote,
    this.usesPlatformFocusToken = false,
  });

  factory _FiscalRealIntegrationSetup.fromSettings(
    Map<String, dynamic> companySettings,
  ) {
    final raw = companySettings['fiscalRealIntegration'];
    final map = raw is Map
        ? raw.map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{};
    return _FiscalRealIntegrationSetup(
      environment: map['environment']?.toString() ?? '',
      provider: map['provider']?.toString() ?? '',
      focusNfseApi: map['focusNfseApi']?.toString() ?? '',
      municipalCode: map['municipalCode']?.toString() ?? '',
      certificateRef: map['certificateRef']?.toString() ?? '',
      apiBaseUrl: map['apiBaseUrl']?.toString() ?? '',
      apiToken: map['apiToken']?.toString() ?? '',
      lastHomologationNote: map['lastHomologationNote']?.toString() ?? '',
      usesPlatformFocusToken: focusFiscalSetupUsesPlatformToken(map),
    );
  }

  final String environment;
  final String provider;
  final String focusNfseApi;
  final String municipalCode;
  final String certificateRef;
  final String apiBaseUrl;
  final String apiToken;
  final String lastHomologationNote;
  /// Token global no backend (FOCUS_API_TOKEN nas Functions) — nunca mostrar o valor.
  final bool usesPlatformFocusToken;

  _FiscalRealIntegrationSetup copyWith({
    String? environment,
    String? provider,
    String? focusNfseApi,
    String? municipalCode,
    String? certificateRef,
    String? apiBaseUrl,
    String? apiToken,
    bool? usesPlatformFocusToken,
    String? lastHomologationNote,
  }) {
    return _FiscalRealIntegrationSetup(
      environment: environment ?? this.environment,
      provider: provider ?? this.provider,
      focusNfseApi: focusNfseApi ?? this.focusNfseApi,
      municipalCode: municipalCode ?? this.municipalCode,
      certificateRef: certificateRef ?? this.certificateRef,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      apiToken: apiToken ?? this.apiToken,
      lastHomologationNote: lastHomologationNote ?? this.lastHomologationNote,
      usesPlatformFocusToken: usesPlatformFocusToken ?? this.usesPlatformFocusToken,
    );
  }

  bool get _hasEffectiveFocusToken =>
      apiToken.trim().isNotEmpty || usesPlatformFocusToken;

  double get readinessScore {
    final isFocus = provider.trim().toLowerCase().contains('focus');
    final tokenSlot = isFocus
        ? (_hasEffectiveFocusToken ? '1' : '')
        : apiToken;
    final filled = [
      environment,
      provider,
      if (isFocus) focusNfseApi,
      municipalCode,
      certificateRef,
      apiBaseUrl,
      tokenSlot,
      lastHomologationNote,
    ].where((value) => value.trim().isNotEmpty).length;
    return filled / 7;
  }

  bool get isPrepared => _hasEffectiveFocusToken && readinessScore >= 0.7;

  bool get usesFocusNationalApi =>
      focusNfseApi.trim().toLowerCase() == 'national';

  String get apiTokenMasked {
    if (apiToken.trim().isEmpty) return '';
    final value = apiToken.trim();
    if (value.length <= 6) return '***';
    return '${value.substring(0, 3)}***${value.substring(value.length - 3)}';
  }

  String get readinessLabel =>
      isPrepared ? 'Integracao real preparada' : 'Preparando integracao real';

  String get environmentLabel =>
      environment.trim().isEmpty ? 'Pendente' : environment.trim();

  String get providerLabel => provider.trim().isEmpty
      ? 'Nao definido'
      : usesFocusNationalApi
      ? '${provider.trim()} / NFSe Nacional'
      : provider.trim();

  String get summary {
    if (isPrepared) {
      return 'Base estrutural pronta para iniciar integracoes reais de NFS-e com homologacao, certificados e endpoint definidos.';
    }
    return 'Preencha ambiente, provedor, modalidade Focus, codigo fiscal, certificado e observacoes de homologacao para iniciar a emissao oficial com seguranca.';
  }

  Map<String, dynamic> toMap() {
    return {
      'environment': environment,
      'provider': provider,
      'focusNfseApi': focusNfseApi,
      'municipalCode': municipalCode,
      'certificateRef': certificateRef,
      'apiBaseUrl': apiBaseUrl,
      'apiToken': apiToken,
      'usesPlatformFocusToken': usesPlatformFocusToken,
      'lastHomologationNote': lastHomologationNote,
    };
  }
}

class _FiscalHomologationChecklist {
  const _FiscalHomologationChecklist({
    required this.companyBaseReviewed,
    required this.certificateValidated,
    required this.matrixValidated,
    required this.providerConnectionValidated,
    required this.pilotInvoiceValidated,
    required this.productionAuthorized,
  });

  factory _FiscalHomologationChecklist.fromSettings(
    Map<String, dynamic> companySettings,
  ) {
    final raw = companySettings['fiscalHomologationChecklist'];
    final map = raw is Map
        ? raw.map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{};
    return _FiscalHomologationChecklist(
      companyBaseReviewed: map['companyBaseReviewed'] as bool? ?? false,
      certificateValidated: map['certificateValidated'] as bool? ?? false,
      matrixValidated: map['matrixValidated'] as bool? ?? false,
      providerConnectionValidated:
          map['providerConnectionValidated'] as bool? ?? false,
      pilotInvoiceValidated: map['pilotInvoiceValidated'] as bool? ?? false,
      productionAuthorized: map['productionAuthorized'] as bool? ?? false,
    );
  }

  final bool companyBaseReviewed;
  final bool certificateValidated;
  final bool matrixValidated;
  final bool providerConnectionValidated;
  final bool pilotInvoiceValidated;
  final bool productionAuthorized;

  int get completedCount => [
    companyBaseReviewed,
    certificateValidated,
    matrixValidated,
    providerConnectionValidated,
    pilotInvoiceValidated,
    productionAuthorized,
  ].where((value) => value).length;

  int get totalCount => 6;

  _FiscalHomologationChecklist copyWith({
    bool? companyBaseReviewed,
    bool? certificateValidated,
    bool? matrixValidated,
    bool? providerConnectionValidated,
    bool? pilotInvoiceValidated,
    bool? productionAuthorized,
  }) {
    return _FiscalHomologationChecklist(
      companyBaseReviewed: companyBaseReviewed ?? this.companyBaseReviewed,
      certificateValidated: certificateValidated ?? this.certificateValidated,
      matrixValidated: matrixValidated ?? this.matrixValidated,
      providerConnectionValidated:
          providerConnectionValidated ?? this.providerConnectionValidated,
      pilotInvoiceValidated:
          pilotInvoiceValidated ?? this.pilotInvoiceValidated,
      productionAuthorized: productionAuthorized ?? this.productionAuthorized,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyBaseReviewed': companyBaseReviewed,
      'certificateValidated': certificateValidated,
      'matrixValidated': matrixValidated,
      'providerConnectionValidated': providerConnectionValidated,
      'pilotInvoiceValidated': pilotInvoiceValidated,
      'productionAuthorized': productionAuthorized,
    };
  }
}

class _ChecklistTileConfig {
  const _ChecklistTileConfig({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.onChanged,
  });

  final bool value;
  final String title;
  final String subtitle;
  final ValueChanged<bool>? onChanged;
}

class _FiscalOperationalReadiness {
  const _FiscalOperationalReadiness({
    required this.stageLabel,
    required this.title,
    required this.description,
    required this.blockers,
  });

  final String stageLabel;
  final String title;
  final String description;
  final List<String> blockers;

  bool get isBlocked => blockers.isNotEmpty;
  bool get canOperateInProduction =>
      !isBlocked && stageLabel == 'Producao liberada';
}

class _FiscalAutoDefaults {
  const _FiscalAutoDefaults({
    required this.defaultServiceDescription,
    required this.defaultServiceCode,
    required this.defaultMunicipalServiceCode,
    required this.defaultCnae,
    required this.defaultCityOfIncidence,
    required this.defaultTaxRegime,
    required this.defaultOperationNature,
    required this.defaultIssRate,
  });

  factory _FiscalAutoDefaults.fromData({
    required Map<String, dynamic> companyData,
    required Map<String, dynamic> companySettings,
    required _FiscalRealIntegrationSetup realIntegration,
    required List<FiscalServiceItem> savedServices,
  }) {
    final activeService = savedServices
        .where((item) => item.active)
        .firstOrNull;
    final raw = companySettings['fiscalAutoDefaults'];
    final settings = raw is Map
        ? raw.map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{};
    final mainCnae = companyData['mainCnae']?.toString().trim() ?? '';
    final serviceDescription =
        activeService?.name ??
        settings['defaultServiceDescription']?.toString() ??
        companyData['mainCnaeDescription']?.toString() ??
        'Prestacao de servicos';
    var serviceCode =
        activeService?.serviceCode ??
        settings['defaultServiceCode']?.toString() ??
        _normalizeServiceCode(mainCnae);
    var municipalServiceCode =
        activeService?.municipalServiceCode ??
        settings['defaultMunicipalServiceCode']?.toString() ??
        realIntegration.municipalCode;
    final routeType = _effectiveFiscalRouteType(
      companySettings: companySettings,
      setup: realIntegration,
    );
    if (activeService == null && routeType == 'focus_national') {
      final suggested = _suggestNationalTaxDottedForCatalog(
        cnaeRaw: mainCnae,
        serviceNameOrDescription: serviceDescription,
      );
      if (suggested.isNotEmpty) {
        serviceCode = suggested;
        municipalServiceCode = '';
      }
    }
    final cnae =
        activeService?.cnae ?? settings['defaultCnae']?.toString() ?? mainCnae;
    final cityOfIncidence =
        activeService?.cityOfIncidence ??
        settings['defaultCityOfIncidence']?.toString() ??
        companyData['cidade']?.toString() ??
        '';
    final taxRegime =
        activeService?.taxRegime ??
        settings['defaultTaxRegime']?.toString() ??
        companyData['regimeTributario']?.toString() ??
        _inferTaxRegimeStatic(companyData);
    final operationNature =
        activeService?.operationNature ??
        settings['defaultOperationNature']?.toString() ??
        'Tributacao no municipio';
    final issRate =
        settings['defaultIssRate']?.toString().trim().isNotEmpty == true
        ? settings['defaultIssRate'].toString().trim()
        : '5,00';

    return _FiscalAutoDefaults(
      defaultServiceDescription: serviceDescription.trim().isEmpty
          ? 'Prestacao de servicos'
          : serviceDescription.trim(),
      defaultServiceCode: serviceCode.trim(),
      defaultMunicipalServiceCode: municipalServiceCode.trim(),
      defaultCnae: cnae.trim(),
      defaultCityOfIncidence: cityOfIncidence.trim(),
      defaultTaxRegime: taxRegime.trim(),
      defaultOperationNature: operationNature.trim(),
      defaultIssRate: issRate,
    );
  }

  final String defaultServiceDescription;
  final String defaultServiceCode;
  final String defaultMunicipalServiceCode;
  final String defaultCnae;
  final String defaultCityOfIncidence;
  final String defaultTaxRegime;
  final String defaultOperationNature;
  final String defaultIssRate;

  Map<String, dynamic> toMap() {
    return {
      'defaultServiceDescription': defaultServiceDescription,
      'defaultServiceCode': defaultServiceCode,
      'defaultMunicipalServiceCode': defaultMunicipalServiceCode,
      'defaultCnae': defaultCnae,
      'defaultCityOfIncidence': defaultCityOfIncidence,
      'defaultTaxRegime': defaultTaxRegime,
      'defaultOperationNature': defaultOperationNature,
      'defaultIssRate': defaultIssRate,
    };
  }

  static String _normalizeServiceCode(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    return digits.length <= 5 ? digits : digits.substring(0, 5);
  }

  static String _inferTaxRegimeStatic(Map<String, dynamic> companyData) {
    final explicit = companyData['regimeTributario']?.toString().trim() ?? '';
    if (explicit.isNotEmpty) return explicit;
    final legalNature =
        companyData['legalNature']?.toString().toLowerCase() ?? '';
    final companySize =
        companyData['companySize']?.toString().toLowerCase() ?? '';
    if (legalNature.contains('mei')) return 'MEI / Simples Nacional';
    if (companySize.contains('micro') || companySize.contains('pequeno')) {
      return 'Simples Nacional';
    }
    return 'Regime a validar com contador';
  }
}

class _CompanyServiceOption {
  const _CompanyServiceOption({required this.code, required this.description});

  final String code;
  final String description;

  String get serviceCode {
    final digits = code.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    return digits.length <= 5 ? digits : digits.substring(0, 5);
  }

  String get label {
    final prefix = code.isEmpty ? 'Sem codigo' : code;
    return '$prefix - ${description.isEmpty ? 'Atividade sem descricao' : description}';
  }
}

class _FiscalAutomationResult {
  const _FiscalAutomationResult({
    required this.issRateText,
    required this.issRetained,
    required this.inssRetained,
    required this.operationNatureCode,
    required this.operationNatureLabel,
    required this.serviceDescription,
    required this.summary,
    required this.legalReasoning,
    required this.customerCostExplanation,
  });

  final String issRateText;
  final bool issRetained;
  final bool inssRetained;
  final String operationNatureCode;
  final String operationNatureLabel;
  final String serviceDescription;
  final String summary;
  final String legalReasoning;
  final String customerCostExplanation;
}

class _FiscalComplianceRule {
  const _FiscalComplianceRule({
    required this.cnae,
    required this.serviceCode,
    required this.municipalServiceCode,
    required this.serviceDescription,
    required this.issRateText,
    required this.issRetained,
    required this.operationNature,
    required this.legalReasoning,
    required this.customerCostLegalText,
    required this.cityOfIncidence,
  });

  factory _FiscalComplianceRule.fromMap(Map<String, dynamic> map) {
    return _FiscalComplianceRule(
      cnae: map['cnae']?.toString() ?? '',
      serviceCode: map['serviceCode']?.toString() ?? '',
      municipalServiceCode: map['municipalServiceCode']?.toString() ?? '',
      serviceDescription: map['serviceDescription']?.toString() ?? '',
      issRateText: map['issRateText']?.toString() ?? '5,00',
      issRetained: map['issRetained'] == true,
      operationNature: map['operationNature']?.toString() ?? '',
      legalReasoning: map['legalReasoning']?.toString() ?? '',
      customerCostLegalText: map['customerCostLegalText']?.toString() ?? '',
      cityOfIncidence: map['cityOfIncidence']?.toString() ?? '',
    );
  }

  final String cnae;
  final String serviceCode;
  final String municipalServiceCode;
  final String serviceDescription;
  final String issRateText;
  final bool issRetained;
  final String operationNature;
  final String legalReasoning;
  final String customerCostLegalText;
  final String cityOfIncidence;

  Map<String, dynamic> toMap() {
    return {
      'cnae': cnae,
      'serviceCode': serviceCode,
      'municipalServiceCode': municipalServiceCode,
      'serviceDescription': serviceDescription,
      'issRateText': issRateText,
      'issRetained': issRetained,
      'operationNature': operationNature,
      'legalReasoning': legalReasoning,
      'customerCostLegalText': customerCostLegalText,
      'cityOfIncidence': cityOfIncidence,
    };
  }

  int matchScore({
    required String selectedCnae,
    required String selectedServiceCode,
    required String selectedDescription,
  }) {
    var score = 0;
    final normalizedDescription = selectedDescription.trim().toLowerCase();
    if (cnae.trim().isNotEmpty && cnae.trim() == selectedCnae.trim()) {
      score += 5;
    }
    if (serviceCode.trim().isNotEmpty &&
        serviceCode.trim() == selectedServiceCode.trim()) {
      score += 4;
    }
    if (municipalServiceCode.trim().isNotEmpty &&
        municipalServiceCode.trim() == selectedServiceCode.trim()) {
      score += 2;
    }
    if (serviceDescription.trim().isNotEmpty &&
        normalizedDescription.isNotEmpty &&
        normalizedDescription.contains(
          serviceDescription.trim().toLowerCase(),
        )) {
      score += 1;
    }
    return score;
  }
}

class _FiscalComplianceMatrix {
  const _FiscalComplianceMatrix({
    required this.municipalityName,
    required this.municipalityCode,
    required this.provider,
    required this.defaultIssRateText,
    required this.generalLegalText,
    required this.customerCostLegalText,
    required this.rules,
  });

  factory _FiscalComplianceMatrix.fromSettings(
    Map<String, dynamic> companySettings,
    _FiscalRealIntegrationSetup setup,
  ) {
    final raw = companySettings['fiscalComplianceMatrix'];
    final map = raw is Map
        ? raw.map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{};
    final rulesRaw = map['rules'];
    final rules = rulesRaw is Iterable
        ? rulesRaw
              .whereType<Map>()
              .map(
                (item) => _FiscalComplianceRule.fromMap(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ),
              )
              .toList()
        : const <_FiscalComplianceRule>[];
    return _FiscalComplianceMatrix(
      municipalityName: map['municipalityName']?.toString() ?? '',
      municipalityCode:
          (map['municipalityCode']?.toString() ?? setup.municipalCode).trim(),
      provider: (map['provider']?.toString() ?? setup.provider).trim(),
      defaultIssRateText: (map['defaultIssRateText']?.toString() ?? '5,00')
          .trim(),
      generalLegalText:
          (map['generalLegalText']?.toString() ?? '').trim().isEmpty
          ? _defaultGeneralLegalText()
          : map['generalLegalText'].toString().trim(),
      customerCostLegalText:
          (map['customerCostLegalText']?.toString() ?? '').trim().isEmpty
          ? _defaultCustomerCostLegalText()
          : map['customerCostLegalText'].toString().trim(),
      rules: rules,
    );
  }

  final String municipalityName;
  final String municipalityCode;
  final String provider;
  final String defaultIssRateText;
  final String generalLegalText;
  final String customerCostLegalText;
  final List<_FiscalComplianceRule> rules;

  _FiscalComplianceMatrix copyWith({
    String? municipalityName,
    String? municipalityCode,
    String? provider,
    String? defaultIssRateText,
    String? generalLegalText,
    String? customerCostLegalText,
    List<_FiscalComplianceRule>? rules,
  }) {
    return _FiscalComplianceMatrix(
      municipalityName: municipalityName ?? this.municipalityName,
      municipalityCode: municipalityCode ?? this.municipalityCode,
      provider: provider ?? this.provider,
      defaultIssRateText: defaultIssRateText ?? this.defaultIssRateText,
      generalLegalText: generalLegalText ?? this.generalLegalText,
      customerCostLegalText:
          customerCostLegalText ?? this.customerCostLegalText,
      rules: rules ?? this.rules,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'municipalityName': municipalityName,
      'municipalityCode': municipalityCode,
      'provider': provider,
      'defaultIssRateText': defaultIssRateText,
      'generalLegalText': generalLegalText,
      'customerCostLegalText': customerCostLegalText,
      'rules': [for (final rule in rules) rule.toMap()],
    };
  }

  String get summary =>
      'A matriz fiscal aplica base juridica nacional, ISS padrao do municipio base e regras por servico/CNAE para reduzir preenchimento manual na emissao.';

  _FiscalComplianceRule? resolve({
    required String cnaeCode,
    required String serviceCode,
    required String activityDescription,
    required String cityOfIncidence,
  }) {
    _FiscalComplianceRule? best;
    var bestScore = 0;
    final normalizedCity = _normalizeFiscalText(cityOfIncidence);
    for (final rule in rules) {
      final score =
          rule.matchScore(
            selectedCnae: cnaeCode,
            selectedServiceCode: serviceCode,
            selectedDescription: activityDescription,
          ) +
          ((normalizedCity.isNotEmpty &&
                  _normalizeFiscalText(rule.cityOfIncidence) == normalizedCity)
              ? 3
              : 0);
      if (score > bestScore) {
        bestScore = score;
        best = rule;
      }
    }
    return bestScore > 0 ? best : null;
  }
}

bool _fiscalNormalizedSuggestsIssRetention(String normalized) {
  return normalized.contains('construcao') ||
      normalized.contains('obra') ||
      normalized.contains('engenharia') ||
      normalized.contains('limpeza') ||
      normalized.contains('conservacao') ||
      normalized.contains('vigil') ||
      normalized.contains('seguranca') ||
      normalized.contains('guarda') ||
      normalized.contains('armazen') ||
      normalized.contains('estacion') ||
      normalized.contains('guincho') ||
      normalized.contains('monitoramento') ||
      normalized.contains('rastreamento');
}

bool _suggestInssRetainedHeuristic({
  required Map<String, dynamic> companyData,
  required String normalized,
  required String serviceCode,
  required bool isRetentionException,
  required bool municipalException,
}) {
  final regime =
      companyData['regimeTributario']?.toString().toLowerCase() ?? '';
  if (regime.contains('mei')) {
    return false;
  }
  if (municipalException) {
    return true;
  }
  if (isRetentionException) {
    return true;
  }
  final digits = serviceCode.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length < 4) {
    return false;
  }
  var six = digits;
  if (six.length < 6) {
    if (six.length == 4) {
      six = '00$six';
    } else if (six.length == 5) {
      six = '0$six';
    } else {
      return false;
    }
  } else {
    six = six.substring(0, 6);
  }
  return kFocusNationalObraRequiredTaxCodeDigits.contains(six);
}

_FiscalAutomationResult _inferFiscalAutomation({
  required Map<String, dynamic> companyData,
  required _FiscalComplianceMatrix complianceMatrix,
  required String cnaeCode,
  required String activityDescription,
  required String serviceCode,
  required String cityOfIncidence,
  required String fiscalCostBearer,
  required String currentTaxRateText,
}) {
  final description = activityDescription.trim().isEmpty
      ? 'prestacao de servicos'
      : activityDescription.trim();
  final rule = complianceMatrix.resolve(
    cnaeCode: cnaeCode,
    serviceCode: serviceCode,
    activityDescription: description,
    cityOfIncidence: cityOfIncidence,
  );
  if (rule != null) {
    final operationNatureCode = _normalizeOperationNatureCode(
      rule.operationNature,
      issRetained: rule.issRetained,
    );
    final normalizedRule =
        '${cnaeCode.toLowerCase()} ${description.toLowerCase()} ${serviceCode.toLowerCase()}';
    final serviceCodeRaw = serviceCode.trim();
    final municipalExRule =
        serviceCodeRaw == '7.02' || serviceCodeRaw == '7.05';
    final retentionExRule = _fiscalNormalizedSuggestsIssRetention(normalizedRule);
    return _FiscalAutomationResult(
      issRateText: rule.issRateText.trim().isEmpty
          ? complianceMatrix.defaultIssRateText
          : rule.issRateText,
      issRetained: rule.issRetained,
      inssRetained: _suggestInssRetainedHeuristic(
        companyData: companyData,
        normalized: normalizedRule,
        serviceCode: serviceCode,
        isRetentionException: retentionExRule,
        municipalException: municipalExRule,
      ),
      operationNatureCode: operationNatureCode,
      operationNatureLabel: rule.operationNature.trim().isEmpty
          ? _operationNatureLabelFromCode(operationNatureCode)
          : _operationNatureDisplayLabel(
              rule.operationNature,
              issRetained: rule.issRetained,
            ),
      serviceDescription: rule.serviceDescription.trim().isEmpty
          ? 'Prestacao de servicos de $description vinculada ao CNAE $cnaeCode e ao codigo de servico ${serviceCode.trim().isEmpty ? 'a validar' : serviceCode}.'
          : rule.serviceDescription,
      summary:
          'Automacao aplicada pela matriz fiscal ativa para este servico/CNAE.',
      legalReasoning: rule.legalReasoning.trim().isEmpty
          ? complianceMatrix.generalLegalText
          : rule.legalReasoning,
      customerCostExplanation: fiscalCostBearer == 'customer'
          ? (rule.customerCostLegalText.trim().isEmpty
                ? complianceMatrix.customerCostLegalText
                : rule.customerCostLegalText)
          : 'Sem transferencia de custo fiscal ao tomador: o prestador absorve os encargos da emissao na sua propria composicao economica.',
    );
  }
  final normalized =
      '${cnaeCode.toLowerCase()} ${description.toLowerCase()} ${serviceCode.toLowerCase()}';
  final regime =
      companyData['regimeTributario']?.toString().toLowerCase() ?? '';
  final isMei = regime.contains('mei');
  final providerCity = _normalizeFiscalText(
    companyData['cidade']?.toString() ??
        companyData['municipio']?.toString() ??
        '',
  );
  final incidenceCity = _normalizeFiscalText(cityOfIncidence);

  final isRetentionException = _fiscalNormalizedSuggestsIssRetention(normalized);
  final serviceCodeNormalized = serviceCode.trim();
  final municipalException =
      serviceCodeNormalized == '7.02' || serviceCodeNormalized == '7.05';
  final issRetained =
      !isMei &&
      (municipalException
          ? incidenceCity.isNotEmpty && incidenceCity != providerCity
          : isRetentionException);

  String suggestedRate = currentTaxRateText.trim().isEmpty
      ? complianceMatrix.defaultIssRateText
      : currentTaxRateText.trim();
  if (suggestedRate.isEmpty ||
      suggestedRate == '5,00' ||
      suggestedRate == complianceMatrix.defaultIssRateText) {
    if (normalized.contains('software') ||
        normalized.contains('desenvolvimento') ||
        normalized.contains('consultoria') ||
        normalized.contains('marketing') ||
        normalized.contains('design') ||
        normalized.contains('suporte')) {
      suggestedRate = '2,00';
    } else if (normalized.contains('saude') ||
        normalized.contains('clinica') ||
        normalized.contains('odont') ||
        normalized.contains('educa') ||
        normalized.contains('treinamento')) {
      suggestedRate = '3,00';
    } else {
      suggestedRate = complianceMatrix.defaultIssRateText.isEmpty
          ? '5,00'
          : complianceMatrix.defaultIssRateText;
    }
  }

  final operationNatureCode = issRetained ? '2' : '1';
  final operationNatureLabel = _operationNatureLabelFromCode(
    operationNatureCode,
  );
  final retentionText = issRetained
      ? 'retido pelo tomador'
      : 'recolhido pelo prestador';
  final serviceDescription =
      'Prestacao de servicos de $description, vinculada ao CNAE $cnaeCode, '
      'com ISS $retentionText e enquadramento operacional automatico para emissao da NFS-e.';
  final summary = issRetained
      ? 'Criterio nacional de apoio: hipotese de ISS retido pelo tomador; confirme no interruptor em Tributos.'
      : 'Criterio nacional de apoio: hipotese de ISS a cargo do prestador; confirme no interruptor em Tributos.';
  final legalReasoning = issRetained
      ? 'Analise de apoio com base na LC 116/2003 (arts. 3, 6 e correlatos). A retencao efetiva e escolhida em Tributacao e totais.'
      : 'Analise de apoio pela regra geral da LC 116/2003. A retencao efetiva e escolhida em Tributacao e totais.';
  final customerCostExplanation = fiscalCostBearer == 'customer'
      ? 'Acrescimo fiscal transferido ao tomador por previsao contratual e composicao expressa do preco do servico. O valor adicional representa o custo tributario e operacional da emissao fiscal, discriminado para dar transparencia juridica, economica e documental ao tomador.'
      : 'Sem transferencia de custo fiscal ao tomador: o prestador absorve os encargos da emissao na sua propria composicao economica.';

  return _FiscalAutomationResult(
    issRateText: suggestedRate,
    issRetained: issRetained,
    inssRetained: _suggestInssRetainedHeuristic(
      companyData: companyData,
      normalized: normalized,
      serviceCode: serviceCode,
      isRetentionException: isRetentionException,
      municipalException: municipalException,
    ),
    operationNatureCode: operationNatureCode,
    operationNatureLabel: operationNatureLabel,
    serviceDescription: serviceDescription,
    summary: summary,
    legalReasoning: legalReasoning,
    customerCostExplanation: customerCostExplanation,
  );
}

List<_CompanyServiceOption> _companyServiceOptions(
  Map<String, dynamic> companyData,
) {
  final items = <_CompanyServiceOption>[];
  final mainCode = (companyData['mainCnae']?.toString().trim() ?? '').isEmpty
      ? '4321-5/000'
      : companyData['mainCnae']?.toString().trim() ?? '';
  final mainDescription =
      (companyData['mainCnaeDescription']?.toString().trim() ?? '').isEmpty
      ? 'Instalacao e manutencao eletrica'
      : companyData['mainCnaeDescription']?.toString().trim() ?? '';
  if (mainCode.isNotEmpty || mainDescription.isNotEmpty) {
    items.add(
      _CompanyServiceOption(
        code: mainCode,
        description: mainDescription.isEmpty
            ? 'Servico principal do CNPJ'
            : mainDescription,
      ),
    );
  }
  final secondaryRaw = companyData['secondaryCnaes'];
  if (secondaryRaw is Iterable) {
    for (final raw in secondaryRaw) {
      if (raw is! Map) continue;
      final code = raw['code']?.toString().trim() ?? '';
      final description = raw['description']?.toString().trim() ?? '';
      if (code.isEmpty && description.isEmpty) continue;
      items.add(_CompanyServiceOption(code: code, description: description));
    }
  }
  final seen = <String>{};
  return [
    for (final item in items)
      if (seen.add('${item.code}|${item.description}')) item,
  ];
}

_FiscalComplianceMatrix _buildComplianceMatrix({
  required _FiscalRealIntegrationSetup setup,
  required Map<String, dynamic> companyData,
  required List<FiscalServiceItem> generatedServices,
}) {
  final rules = [
    for (final service in generatedServices)
      _buildComplianceRuleFromService(
        service: service,
        companyData: companyData,
        defaultProvider: setup.provider,
      ),
  ];
  final municipalityName = [
    companyData['cidade']?.toString().trim() ?? '',
    companyData['municipio']?.toString().trim() ?? '',
    companyData['addressCity']?.toString().trim() ?? '',
  ].firstWhere((value) => value.isNotEmpty, orElse: () => '');
  return _FiscalComplianceMatrix(
    municipalityName: municipalityName,
    municipalityCode: setup.municipalCode.trim(),
    provider: setup.provider.trim(),
    defaultIssRateText: rules.firstOrNull?.issRateText ?? '5,00',
    generalLegalText: _defaultGeneralLegalText(),
    customerCostLegalText: _defaultCustomerCostLegalText(),
    rules: rules,
  );
}

_FiscalComplianceRule _buildComplianceRuleFromService({
  required FiscalServiceItem service,
  required Map<String, dynamic> companyData,
  required String defaultProvider,
}) {
  final serviceCode = service.serviceCode.trim();
  final dCode = serviceCode.replaceAll(RegExp(r'\D'), '');
  final head4 = dCode.length >= 4 ? dCode.substring(0, 4) : '';
  final text =
      '${service.cnae.toLowerCase()} ${service.name.toLowerCase()} ${serviceCode.toLowerCase()}';
  final regime =
      companyData['regimeTributario']?.toString().toLowerCase() ?? '';
  final isMei = regime.contains('mei');
  final manualPreset = _manualCompliancePresetForServiceCode(serviceCode);
  final is702 =
      serviceCode == '7.02' || serviceCode == '07.02' || head4 == '0702';
  final is705 =
      serviceCode == '7.05' || serviceCode == '07.05' || head4 == '0705';
  final hasRetentionProfile =
      is702 ||
      is705 ||
      text.contains('construcao') ||
      text.contains('obra') ||
      text.contains('engenharia') ||
      text.contains('limpeza') ||
      text.contains('conservacao') ||
      text.contains('vigil') ||
      text.contains('seguranca') ||
      text.contains('guarda') ||
      text.contains('armazen') ||
      text.contains('estacion') ||
      text.contains('guincho') ||
      text.contains('monitoramento') ||
      text.contains('rastreamento');
  final issRetained = !isMei && hasRetentionProfile;
  var issRateText = manualPreset?.issRateText ?? '5,00';
  if (manualPreset == null &&
      (text.contains('software') ||
          text.contains('desenvolvimento') ||
          text.contains('consultoria') ||
          text.contains('marketing') ||
          text.contains('design') ||
          text.contains('suporte'))) {
    issRateText = '2,00';
  } else if (manualPreset == null &&
      (text.contains('saude') ||
          text.contains('clinica') ||
          text.contains('odont') ||
          text.contains('educa') ||
          text.contains('treinamento'))) {
    issRateText = '3,00';
  }
  final providerText = defaultProvider.trim().isEmpty
      ? 'provedor municipal configurado'
      : defaultProvider.trim();
  return _FiscalComplianceRule(
    cnae: service.cnae,
    serviceCode: serviceCode,
    municipalServiceCode: service.municipalServiceCode,
    serviceDescription:
        manualPreset?.serviceDescription ??
        'Prestacao de servicos de ${service.name}, vinculada ao CNAE ${service.cnae.isEmpty ? 'a validar' : service.cnae}, com classificacao automatica para emissao da NFS-e.',
    issRateText: issRateText,
    issRetained: issRetained,
    operationNature:
        manualPreset?.operationNature ??
        (issRetained
            ? 'ISS com recolhimento no local da incidencia/tomador conforme regra parametrizada'
            : 'ISS no estabelecimento do prestador conforme regra ordinaria parametrizada'),
    legalReasoning:
        manualPreset?.legalReasoning ??
        (issRetained
            ? 'Regra automatica com base na LC 116/2003, considerando hipoteses de incidencia fora do estabelecimento e responsabilidade de retencao quando aplicavel, com uso operacional no provedor $providerText.'
            : _defaultGeneralLegalText()),
    customerCostLegalText: _defaultCustomerCostLegalText(),
    cityOfIncidence: service.cityOfIncidence,
  );
}

class _ManualFiscalPreset {
  const _ManualFiscalPreset({
    required this.issRateText,
    required this.serviceDescription,
    required this.operationNature,
    required this.legalReasoning,
  });

  final String issRateText;
  final String serviceDescription;
  final String operationNature;
  final String legalReasoning;
}

const _kPreset1401 = _ManualFiscalPreset(
  issRateText: '5,00',
  serviceDescription:
      'Servico classificado no item 14.01 da lista da LC 116/2003 para manutencao, limpeza tecnica, revisao, carga, recarga, conserto, restauracao e conservacao de maquinas, aparelhos, equipamentos, motores e sistemas eletricos.',
  operationNature:
      'Usar em manutencao e conservacao de equipamentos e sistemas eletricos, sem enquadrar a atividade como nova obra civil.',
  legalReasoning:
      'Enquadramento sugerido no item 14.01 da lista de servicos da LC 116/2003, aplicavel a manutencao, revisao, conserto e conservacao de equipamentos e objetos de terceiros.',
);
const _kPreset702 = _ManualFiscalPreset(
  issRateText: '5,00',
  serviceDescription:
      'Servico classificado no item 7.02 da lista da LC 116/2003 para execucao, por administracao, empreitada ou subempreitada, de obras e instalacoes eletricas vinculadas a construcao civil, obras hidraulicas ou outras obras semelhantes.',
  operationNature:
      'Usar quando houver execucao de obra ou instalacao eletrica por empreitada/subempreitada, com analise de retencao e local da incidencia conforme contrato e municipio.',
  legalReasoning:
      'Enquadramento sugerido no item 7.02 da lista de servicos da LC 116/2003, aplicavel a execucao de obras e instalacoes por administracao, empreitada ou subempreitada.',
);
const _kPreset705 = _ManualFiscalPreset(
  issRateText: '5,00',
  serviceDescription:
      'Servico classificado no item 7.05 da lista da LC 116/2003 para reparacao, conservacao e reforma de edificios, redes, paineis, estruturas e instalacoes, quando a atividade principal for intervencao em estrutura ja existente.',
  operationNature:
      'Usar em reparo, conservacao e reforma de instalacoes ou edificacoes existentes, quando nao houver caracterizacao de obra nova completa.',
  legalReasoning:
      'Enquadramento sugerido no item 7.05 da lista de servicos da LC 116/2003, aplicavel a reparacao, conservacao e reforma de edificios e congeneres.',
);

_ManualFiscalPreset? _manualCompliancePresetForLc116Head4(String head4) {
  switch (head4) {
    case '1401':
      return _kPreset1401;
    case '0702':
      return _kPreset702;
    case '0705':
      return _kPreset705;
  }
  return null;
}

_ManualFiscalPreset? _manualCompliancePresetForServiceCode(String serviceCode) {
  final d = serviceCode.replaceAll(RegExp(r'\D'), '');
  if (d.length >= 4) {
    final fromD = _manualCompliancePresetForLc116Head4(d.substring(0, 4));
    if (fromD != null) {
      return fromD;
    }
  }
  switch (serviceCode.trim()) {
    case '14.01':
      return _kPreset1401;
    case '7.02':
      return _kPreset702;
    case '7.05':
      return _kPreset705;
  }
  return null;
}

String _defaultGeneralLegalText() {
  return 'Automacao aplicada pela regra geral nacional da Lei Complementar 116/2003: fora das excecoes legais, o ISS permanece devido no estabelecimento do prestador. Em regime do Simples Nacional, a retencao exige analise da LC 123/2006 e da regulamentacao municipal aplicavel.';
}

String _defaultCustomerCostLegalText() {
  return 'Acrescimo fiscal transferido ao tomador por previsao contratual, composicao expressa do preco do servico e destaque informativo no documento fiscal. O valor adicional representa o custo tributario e operacional da emissao, informado para assegurar transparencia juridica, economica e documental ao tomador.';
}

String _normalizeOperationNatureCode(
  String? value, {
  bool issRetained = false,
}) {
  final text = (value ?? '').trim();
  if (text.isEmpty) {
    return issRetained ? '2' : '1';
  }
  if (RegExp(r'^[0-9]+$').hasMatch(text)) {
    return text;
  }
  final normalized = _normalizeFiscalText(text);
  if (normalized.contains('foradomunicipio') ||
      normalized.contains('localdaexecucao') ||
      normalized.contains('localdaincidencia') ||
      normalized.contains('tomador')) {
    return '2';
  }
  return issRetained ? '2' : '1';
}

String _operationNatureLabelFromCode(String? code) {
  return switch ((code ?? '').trim()) {
    '2' => 'Tributacao fora do municipio',
    '3' => 'Isencao',
    '4' => 'Imune',
    '5' => 'Exigibilidade suspensa por decisao judicial',
    '6' => 'Exigibilidade suspensa por procedimento administrativo',
    '7' => 'Nao incidencia',
    _ => 'Tributacao no municipio',
  };
}

String _operationNatureDisplayLabel(
  String? preferredLabel, {
  String? rawValue,
  bool issRetained = false,
}) {
  final label = preferredLabel?.trim() ?? '';
  if (label.isNotEmpty && !RegExp(r'^[0-9]+$').hasMatch(label)) {
    return label;
  }
  final raw = rawValue?.trim() ?? '';
  if (raw.isNotEmpty && !RegExp(r'^[0-9]+$').hasMatch(raw)) {
    return raw;
  }
  return _operationNatureLabelFromCode(
    _normalizeOperationNatureCode(
      raw.isNotEmpty ? raw : label,
      issRetained: issRetained,
    ),
  );
}

String _normalizeFiscalText(String value) {
  return value
      .toLowerCase()
      .replaceAll(' ', '')
      .replaceAll('-', '')
      .replaceAll('/', '')
      .replaceAll('.', '')
      .replaceAll(',', '')
      .replaceAll('(', '')
      .replaceAll(')', '')
      .replaceAll('ã', 'a')
      .replaceAll('á', 'a')
      .replaceAll('à', 'a')
      .replaceAll('â', 'a')
      .replaceAll('é', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ô', 'o')
      .replaceAll('õ', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ç', 'c')
      .trim();
}

String _nationalCatalogCodeOrFallback({
  required String cnaeRaw,
  required String fallbackCnae,
  required String description,
}) {
  var s = _suggestNationalTaxDottedForCatalog(
    cnaeRaw: cnaeRaw,
    serviceNameOrDescription: description,
  );
  if (s.isNotEmpty) {
    return s;
  }
  s = _suggestNationalTaxDottedForCatalog(
    cnaeRaw: fallbackCnae,
    serviceNameOrDescription: description,
  );
  if (s.isNotEmpty) {
    return s;
  }
  return '17.10.01';
}

String _suggestNationalTaxDottedForCatalog({
  required String cnaeRaw,
  required String serviceNameOrDescription,
}) {
  final cnae = cnaeRaw.replaceAll(RegExp(r'\D'), '');
  if (cnae.length < 4) {
    return '';
  }
  final desc = _normalizeFiscalText(serviceNameOrDescription);
  if (cnae.startsWith('4321500')) {
    if (desc.contains('instal')) {
      return '07.02.02';
    }
    final isPredial =
        desc.contains('predial') ||
        desc.contains('edific') ||
        desc.contains('imovel') ||
        desc.contains('condomin') ||
        desc.contains('quadro') ||
        desc.contains('instalac');
    if (desc.contains('manut') && isPredial) {
      return '07.05.01';
    }
    if (desc.contains('manut') ||
        desc.contains('conserv') ||
        desc.contains('repar')) {
      return '14.01.01';
    }
    return '14.01.01';
  }
  final p2 = cnae.substring(0, 2);
  if (p2 == '62') {
    return '01.05.01';
  }
  if (p2 == '70' || p2 == '69' || p2 == '65' || p2 == '74') {
    return '17.10.01';
  }
  if (p2 == '86') {
    return '10.01.01';
  }
  if (p2 == '85') {
    return '08.02.01';
  }
  if (p2 == '47') {
    return '17.10.01';
  }
  if (p2 == '95') {
    return '14.01.01';
  }
  if (p2 == '43' || p2 == '45' || p2 == '46') {
    return '14.01.01';
  }
  return '17.10.01';
}

List<FiscalServiceItem> _fixedElectricalFiscalServices({
  required String companyId,
  required _FiscalAutoDefaults autoDefaults,
  required bool useNationalTaxDotted,
}) {
  const cnae = '4321-5/000';
  String sc(String municipalLc, String nationalDotted) =>
      useNationalTaxDotted ? nationalDotted : municipalLc;
  String ms(String municipalLc) => useNationalTaxDotted ? '' : municipalLc;
  return [
    (
      '14.01',
      '14.01.01',
      'Manutencao e conservacao de equipamentos e sistemas eletricos',
      'Aplicar quando o servico principal for manutencao corretiva, preventiva, limpeza tecnica, revisao ou conservacao de paineis, quadros, motores, equipamentos e sistemas eletricos ja existentes.',
    ),
    (
      '7.02',
      '07.02.02',
      'Execucao de obras e instalacoes eletricas por empreitada ou subempreitada',
      'Aplicar quando houver execucao de obra, ampliacao, montagem ou instalacao eletrica vinculada a construcao civil, reforma estrutural, infraestrutura predial ou entrega por empreitada/subempreitada.',
    ),
    (
      '7.05',
      '07.05.01',
      'Reparo, conservacao e reforma de edificacoes com foco eletrico',
      'Aplicar quando o servico for reparo, conservacao ou reforma em edificacoes, redes, paineis e infraestrutura instalada, sem caracterizar nova obra completa.',
    ),
  ]
      .map(
        (item) => FiscalServiceItem(
          id: 'fixed_service_${sc(item.$1, item.$2).replaceAll(RegExp(r'[^0-9A-Za-z]'), '_')}',
          companyId: companyId,
          name: item.$3,
          officialDescription: item.$3,
          serviceCode: sc(item.$1, item.$2),
          municipalServiceCode: ms(item.$1),
          cnae: cnae,
          cityOfIncidence: autoDefaults.defaultCityOfIncidence,
          taxRegime: autoDefaults.defaultTaxRegime,
          operationNature: item.$4,
          defaultAmountCents: 0,
          active: true,
        ),
      )
      .toList();
}

List<FiscalServiceItem> _buildGeneratedFiscalServices({
  required String companyId,
  required Map<String, dynamic> companyData,
  required _FiscalAutoDefaults autoDefaults,
  required Map<String, dynamic> companySettings,
  required _FiscalRealIntegrationSetup setup,
}) {
  final routeType = _effectiveFiscalRouteType(
    companySettings: companySettings,
    setup: setup,
  );
  final useNational = routeType == 'focus_national';
  final options = _companyServiceOptions(companyData);
  final fixedServices = _fixedElectricalFiscalServices(
    companyId: companyId,
    autoDefaults: autoDefaults,
    useNationalTaxDotted: useNational,
  );
  if (options.isEmpty) {
    return [
      FiscalServiceItem(
        id: 'auto_primary_service',
        companyId: companyId,
        name: autoDefaults.defaultServiceDescription,
        officialDescription: autoDefaults.defaultServiceDescription,
        serviceCode: autoDefaults.defaultServiceCode,
        municipalServiceCode: useNational
            ? ''
            : autoDefaults.defaultMunicipalServiceCode,
        cnae: autoDefaults.defaultCnae,
        cityOfIncidence: autoDefaults.defaultCityOfIncidence,
        taxRegime: autoDefaults.defaultTaxRegime,
        operationNature: autoDefaults.defaultOperationNature,
        defaultAmountCents: 0,
        active: true,
      ),
      ...fixedServices,
    ];
  }
  final generated = [
    for (var i = 0; i < options.length; i++)
      FiscalServiceItem(
        id: i == 0 ? 'auto_primary_service' : 'auto_cnae_$i',
        companyId: companyId,
        name: options[i].description,
        officialDescription: options[i].description,
        serviceCode: useNational
            ? _nationalCatalogCodeOrFallback(
                cnaeRaw: options[i].code,
                fallbackCnae: companyData['mainCnae']?.toString() ?? '',
                description: options[i].description,
              )
            : options[i].serviceCode,
        municipalServiceCode: useNational ? '' : options[i].serviceCode,
        cnae: options[i].code,
        cityOfIncidence: autoDefaults.defaultCityOfIncidence,
        taxRegime: autoDefaults.defaultTaxRegime,
        operationNature: autoDefaults.defaultOperationNature,
        defaultAmountCents: 0,
        active: true,
      ),
    ...fixedServices,
  ];
  final seen = <String>{};
  return [
    for (final item in generated)
      if (seen.add('${item.serviceCode}|${item.cnae}|${item.name}')) item,
  ];
}

class _FiscalServiceNormalizationResult {
  const _FiscalServiceNormalizationResult({this.item, this.errorMessage});

  final FiscalServiceItem? item;
  final String? errorMessage;
}

String _effectiveFiscalRouteType({
  required Map<String, dynamic> companySettings,
  required _FiscalRealIntegrationSetup setup,
}) {
  final routing =
      (companySettings['fiscalRouting'] as Map?)?.cast<String, dynamic>() ??
      const <String, dynamic>{};
  final routeType = routing['routeType']?.toString().trim() ?? '';
  if (routeType.isNotEmpty) return routeType;
  if (setup.usesFocusNationalApi) return 'focus_national';
  if (setup.provider.toLowerCase().contains('focus')) return 'focus_municipal';
  return 'manual_review';
}

String _normalizeCnaeForFiscalCatalog(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';
  return digits.length <= 7 ? digits : digits.substring(0, 7);
}

String _normalizeMunicipalListServiceCode(String value) {
  var digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';
  if (digits.length == 3) digits = '0$digits';
  if (digits.length != 4) return '';
  return '${digits.substring(0, 2)}.${digits.substring(2, 4)}';
}

String _normalizeNationalTaxServiceCode(String value) {
  var digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';
  if (digits.length == 4) digits = '00$digits';
  if (digits.length == 5) digits = '0$digits';
  if (digits.length != 6) return '';
  return '${digits.substring(0, 2)}.${digits.substring(2, 4)}.${digits.substring(4, 6)}';
}

_FiscalServiceNormalizationResult _normalizeFiscalServiceItemForRoute({
  required FiscalServiceItem item,
  required Map<String, dynamic> companySettings,
  required _FiscalRealIntegrationSetup setup,
}) {
  final routeType = _effectiveFiscalRouteType(
    companySettings: companySettings,
    setup: setup,
  );
  if (routeType == 'manual_review') {
    return const _FiscalServiceNormalizationResult(
      errorMessage:
          'A rota fiscal desta empresa ainda esta em revisao manual. Defina a rota da Focus antes de ativar servicos para emissao.',
    );
  }

  final normalizedCnae = _normalizeCnaeForFiscalCatalog(item.cnae);
  if (normalizedCnae.isEmpty || normalizedCnae.length != 7) {
    return const _FiscalServiceNormalizationResult(
      errorMessage:
          'Informe um CNAE valido com 7 digitos para o servico fiscal.',
    );
  }

  if (routeType == 'focus_national') {
    final nationalCode = _normalizeNationalTaxServiceCode(item.serviceCode);
    if (nationalCode.isEmpty) {
      return const _FiscalServiceNormalizationResult(
        errorMessage:
            'No fluxo Focus NFSe Nacional, o servico fiscal precisa ter codigo de tributacao nacional com 6 digitos no padrao XX.XX.XX.',
      );
    }
    final municipalCodeDigits = item.municipalServiceCode.replaceAll(
      RegExp(r'\D'),
      '',
    );
    return _FiscalServiceNormalizationResult(
      item: FiscalServiceItem(
        id: item.id,
        companyId: item.companyId,
        name: item.name.trim(),
        serviceCode: nationalCode,
        municipalServiceCode: municipalCodeDigits,
        cnae: normalizedCnae,
        cityOfIncidence: item.cityOfIncidence.trim(),
        issRateText: item.issRateText,
        taxRegime: item.taxRegime.trim(),
        operationNature: item.operationNature.trim(),
        officialDescription: item.officialDescription.trim(),
        defaultAmountCents: item.defaultAmountCents,
        active: item.active,
        issRateSource: item.issRateSource,
        issRateReviewedAtIso: item.issRateReviewedAtIso,
        inssRetainedDefault: item.inssRetainedDefault,
        inssRatePercentText: item.inssRatePercentText,
        inssRuleSource: item.inssRuleSource,
      ),
    );
  }

  final municipalListCode = _normalizeMunicipalListServiceCode(
    item.serviceCode,
  );
  if (municipalListCode.isEmpty) {
    return const _FiscalServiceNormalizationResult(
      errorMessage:
          'No fluxo Focus municipal, o codigo do servico deve seguir a lista da LC 116 no padrao XX.XX.',
    );
  }
  if (item.municipalServiceCode.trim().isEmpty) {
    return const _FiscalServiceNormalizationResult(
      errorMessage:
          'No fluxo Focus municipal, informe o codigo tributario do municipio para o servico fiscal.',
    );
  }
  return _FiscalServiceNormalizationResult(
    item: FiscalServiceItem(
      id: item.id,
      companyId: item.companyId,
      name: item.name.trim(),
      serviceCode: municipalListCode,
      municipalServiceCode: item.municipalServiceCode.trim(),
      cnae: normalizedCnae,
      cityOfIncidence: item.cityOfIncidence.trim(),
      issRateText: item.issRateText,
      taxRegime: item.taxRegime.trim(),
      operationNature: item.operationNature.trim(),
      officialDescription: item.officialDescription.trim(),
      defaultAmountCents: item.defaultAmountCents,
      active: item.active,
      issRateSource: item.issRateSource,
      issRateReviewedAtIso: item.issRateReviewedAtIso,
      inssRetainedDefault: item.inssRetainedDefault,
      inssRatePercentText: item.inssRatePercentText,
      inssRuleSource: item.inssRuleSource,
    ),
  );
}

class _FiscalCompetenceChecks {
  const _FiscalCompetenceChecks({
    required this.invoiceConferenceDone,
    required this.payrollConferenceDone,
    required this.esocialPrepared,
    required this.taxDocumentsPrepared,
    required this.thirteenthReviewedEmployeeIds,
    required this.vacationReviewedEmployeeIds,
    required this.terminationNotes,
    required this.benefitsNotes,
  });

  factory _FiscalCompetenceChecks.fromMap(Map<String, dynamic> map) {
    return _FiscalCompetenceChecks(
      invoiceConferenceDone: map['invoiceConferenceDone'] as bool? ?? false,
      payrollConferenceDone: map['payrollConferenceDone'] as bool? ?? false,
      esocialPrepared: map['esocialPrepared'] as bool? ?? false,
      taxDocumentsPrepared: map['taxDocumentsPrepared'] as bool? ?? false,
      thirteenthReviewedEmployeeIds: _stringListFromDynamic(
        map['thirteenthReviewedEmployeeIds'],
      ),
      vacationReviewedEmployeeIds: _stringListFromDynamic(
        map['vacationReviewedEmployeeIds'],
      ),
      terminationNotes: map['terminationNotes']?.toString() ?? '',
      benefitsNotes: map['benefitsNotes']?.toString() ?? '',
    );
  }

  final bool invoiceConferenceDone;
  final bool payrollConferenceDone;
  final bool esocialPrepared;
  final bool taxDocumentsPrepared;
  final List<String> thirteenthReviewedEmployeeIds;
  final List<String> vacationReviewedEmployeeIds;
  final String terminationNotes;
  final String benefitsNotes;

  _FiscalCompetenceChecks copyWith({
    bool? invoiceConferenceDone,
    bool? payrollConferenceDone,
    bool? esocialPrepared,
    bool? taxDocumentsPrepared,
    List<String>? thirteenthReviewedEmployeeIds,
    List<String>? vacationReviewedEmployeeIds,
    String? terminationNotes,
    String? benefitsNotes,
  }) {
    return _FiscalCompetenceChecks(
      invoiceConferenceDone:
          invoiceConferenceDone ?? this.invoiceConferenceDone,
      payrollConferenceDone:
          payrollConferenceDone ?? this.payrollConferenceDone,
      esocialPrepared: esocialPrepared ?? this.esocialPrepared,
      taxDocumentsPrepared: taxDocumentsPrepared ?? this.taxDocumentsPrepared,
      thirteenthReviewedEmployeeIds:
          thirteenthReviewedEmployeeIds ?? this.thirteenthReviewedEmployeeIds,
      vacationReviewedEmployeeIds:
          vacationReviewedEmployeeIds ?? this.vacationReviewedEmployeeIds,
      terminationNotes: terminationNotes ?? this.terminationNotes,
      benefitsNotes: benefitsNotes ?? this.benefitsNotes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'invoiceConferenceDone': invoiceConferenceDone,
      'payrollConferenceDone': payrollConferenceDone,
      'esocialPrepared': esocialPrepared,
      'taxDocumentsPrepared': taxDocumentsPrepared,
      'thirteenthReviewedEmployeeIds': thirteenthReviewedEmployeeIds,
      'vacationReviewedEmployeeIds': vacationReviewedEmployeeIds,
      'terminationNotes': terminationNotes,
      'benefitsNotes': benefitsNotes,
    };
  }
}

class _ProvisioningTone {
  const _ProvisioningTone({
    required this.background,
    required this.border,
    required this.foreground,
  });

  final Color background;
  final Color border;
  final Color foreground;
}

List<String> _stringListFromDynamic(dynamic value) {
  if (value is Iterable) {
    return value.map((item) => item.toString()).toList();
  }
  return const [];
}
