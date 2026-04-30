import 'package:pontocerto/features/fiscal/domain/focus_national_obra_tax_codes.dart';

/// Espelha [validateInvoiceReadinessForOfficialIssue] em `functions/src/index.ts`
/// (Focus NFe / NFS-e). Ajuste sempre os dois lados juntos.
class FocusOfficialIssueReadiness {
  const FocusOfficialIssueReadiness({required this.missing});

  final List<String> missing;

  bool get isReady => missing.isEmpty;

  String get message => missing.join(', ');
}

String _onlyDigits(Object? v) {
  return v?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '';
}

String _trim(Object? v) => v?.toString().trim() ?? '';

bool _providerIsFocus(String? provider) {
  final t = (provider ?? '').toLowerCase();
  return t.contains('focus');
}

/// Quando o provedor é Focus e não há [apiToken] no documento da empresa, a
/// plataforma usa o token global ([FOCUS_API_TOKEN] nas Functions).
/// Se [apiToken] estiver preenchido (legado), trata-se como token próprio.
bool focusFiscalSetupUsesPlatformToken(Map<String, dynamic> integration) {
  if (!_providerIsFocus(integration['provider']?.toString())) {
    return false;
  }
  if (integration['usesPlatformFocusToken'] == true) {
    return true;
  }
  if (_trim(integration['apiToken']).isNotEmpty) {
    return false;
  }
  return true;
}

/// O chamador passa o mesmo criterio de [useNationalEmission] no app / rota fiscal.
/// Nao re-duplicar aqui: depende de `fiscalRouting.routeType` e Focus NFSe API.

String _emitterInscricaoMunicipal(Map<String, dynamic> emitter) {
  final a = _trim(emitter['inscricaoMunicipal']);
  if (a.isNotEmpty) {
    return a;
  }
  return _trim(emitter['municipalRegistration']);
}

int _focusNationalSimpleOptionCode(String taxRegime) {
  final n = taxRegime.toLowerCase();
  if (n.contains('mei')) {
    return 2;
  }
  if (n.contains('simples')) {
    return 3;
  }
  return 1;
}

int? _focusNationalSimpleTaxRegimeCode(String taxRegime) {
  final n = taxRegime.toLowerCase();
  if (n.contains('simples')) {
    return 1;
  }
  return null;
}

double _asFocusDecimal(Object? v) {
  if (v is num && v.isFinite) {
    return v.toDouble();
  }
  final text = _trim(v);
  if (text.isEmpty) {
    return 0;
  }
  final normalized = text.replaceAll('.', '').replaceAll(',', '.');
  return double.tryParse(normalized) ?? 0;
}

/// Descrição enviada à Focus: base + complemento; opcional bloco bancário (igual TS).
String buildFocusInvoiceServiceDescription({
  required Map<String, dynamic> data,
  required Map<String, dynamic> service,
  required Map<String, dynamic> emitter,
}) {
  final base = _trim(
    data['fiscalServiceBaseDescription'] ??
        service['description'] ??
        data['serviceDescription'],
  );
  final comp = _trim(data['serviceDescriptionComplement']);
  var body = [base, comp].where((e) => e.isNotEmpty).join('\n\n');
  final bank = _trim(emitter['fiscalPaymentBankInfo']);
  if (bank.isNotEmpty) {
    body = body.isNotEmpty ? '$body\n\n$bank' : bank;
  }
  return body;
}

/// `nationalIssSix` — 6 digitos; null se ainda nao resolvido (TS tem heuristicas
/// extras: manter alinhamento quando possivel via codigo de serviço preenchido).
String? _nationalIssSixForReadiness(
  Map<String, dynamic> service,
) {
  final fromService = focusNationalTaxCodeSixDigitsFromServiceField(
    service['serviceCode']?.toString(),
  );
  if (fromService != null) {
    return fromService;
  }
  return focusNationalTaxCodeSixDigitsFromServiceField(
    service['municipalServiceCode']?.toString(),
  );
}

/// Avalia se a nota, como no Firestore, passa no pre-check do backend Focus.
FocusOfficialIssueReadiness evaluateFocusOfficialIssueReadiness({
  required Map<String, dynamic> invoiceData,
  required Map<String, dynamic> companySettings,
  required bool focusNfseNationalMode,
}) {
  final missing = <String>[];
  final focusApiIsNational = focusNfseNationalMode;

  final emitter = Map<String, dynamic>.from(
    (invoiceData['emitter'] as Map?)?.map((k, v) => MapEntry(k.toString(), v)) ??
        <String, dynamic>{},
  );
  final customer = Map<String, dynamic>.from(
    (invoiceData['customer'] as Map?)?.map((k, v) => MapEntry(k.toString(), v)) ??
        <String, dynamic>{},
  );
  final service = Map<String, dynamic>.from(
    (invoiceData['service'] as Map?)?.map((k, v) => MapEntry(k.toString(), v)) ??
        <String, dynamic>{},
  );
  final tax = Map<String, dynamic>.from(
    (invoiceData['tax'] as Map?)?.map((k, v) => MapEntry(k.toString(), v)) ??
        <String, dynamic>{},
  );

  final setup = Map<String, dynamic>.from(
    (companySettings['fiscalRealIntegration'] as Map?)
            ?.map((k, v) => MapEntry(k.toString(), v)) ??
        <String, dynamic>{},
  );
  final certificate = Map<String, dynamic>.from(
    (companySettings['fiscalCertificate'] as Map?)
            ?.map((k, v) => MapEntry(k.toString(), v)) ??
        <String, dynamic>{},
  );
  final homologation = Map<String, dynamic>.from(
    (companySettings['fiscalHomologationChecklist'] as Map?)
            ?.map((k, v) => MapEntry(k.toString(), v)) ??
        <String, dynamic>{},
  );

  final provider = _trim(setup['provider']);
  if (provider.isEmpty) {
    missing.add('provedor fiscal');
  }
  if (_providerIsFocus(provider)) {
    if (_trim(setup['apiToken']).isEmpty &&
        !focusFiscalSetupUsesPlatformToken(setup)) {
      missing.add('token da Focus NFe');
    }
  } else if (_trim(setup['apiBaseUrl']).isEmpty) {
    missing.add('Base URL da integracao fiscal');
  }

  final emitterDocument = _onlyDigits(emitter['cnpj'] ?? emitter['document']);
  if (emitterDocument.length != 14) {
    missing.add('CNPJ do emitente');
  }
  if (_emitterInscricaoMunicipal(emitter).isEmpty) {
    missing.add('inscricao municipal do emitente');
  }
  if (_trim(emitter['city']).isEmpty) {
    missing.add('cidade do emitente');
  }
  if (_trim(emitter['state']).isEmpty) {
    missing.add('UF do emitente');
  }

  if (_providerIsFocus(provider)) {
    if (_trim(certificate['storagePath']).isEmpty) {
      missing.add('certificado digital');
    }
    if (_trim(certificate['password']).isEmpty) {
      missing.add('senha do certificado digital');
    }
  }

  final customerDocument = _onlyDigits(customer['document']);
  if (customerDocument.length != 11 && customerDocument.length != 14) {
    missing.add('CPF/CNPJ do tomador');
  }
  if (_trim(customer['legalName'] ?? invoiceData['clientName']).isEmpty) {
    missing.add('razao social/nome do tomador');
  }
  if (_trim(customer['city']).isEmpty) {
    missing.add('cidade do tomador');
  }
  if (_trim(customer['state']).isEmpty) {
    missing.add('UF do tomador');
  }

  final amountCents = num.tryParse('${invoiceData['amountCents'] ?? 0}')?.toInt() ??
      0;
  final serviceGross = num.tryParse('${service['grossAmountCents'] ?? 0}')?.toInt() ??
      0;
  final effective = amountCents > 0 ? amountCents : serviceGross;
  if (effective <= 0) {
    missing.add('valor da nota');
  }

  if (buildFocusInvoiceServiceDescription(
        data: invoiceData,
        service: service,
        emitter: emitter,
      )
      .isEmpty) {
    missing.add('descricao do servico');
  }

  final scPick = _trim(service['serviceCode'] ?? '').isNotEmpty
      ? service['serviceCode']
      : service['municipalServiceCode'];
  if (_onlyDigits(scPick).isEmpty) {
    missing.add('item da lista de servico');
  }
  if (!focusApiIsNational) {
    if (_onlyDigits(service['municipalServiceCode']).isEmpty) {
      missing.add('codigo tributario municipal');
    }
  }

  final nationalIss = _nationalIssSixForReadiness(service);
  if (focusApiIsNational) {
    if (nationalIss == null || nationalIss.length != 6) {
      missing.add('codigo de tributacao nacional do ISS');
    } else {
      if (kFocusNationalObraRequiredTaxCodeDigits.contains(nationalIss)) {
        final workSite = Map<String, dynamic>.from(
          (service['workSite'] as Map?)?.map(
                (k, v) => MapEntry(k.toString(), v),
              ) ??
              (invoiceData['workSite'] as Map?)?.map(
                    (k, v) => MapEntry(k.toString(), v),
                  ) ??
              <String, dynamic>{},
        );
        final cno = _onlyDigits(
          workSite['cno'] ?? workSite['cno_obra'] ?? workSite['cnoObra'] ?? '',
        );
        if (cno.isEmpty) {
          missing.add(
            'CNO da obra obrigatorio para este codigo de tributacao nacional (grupo obra)',
          );
        }
      }
    }
  }

  final taxRegime = _trim(tax['taxRegime']).toLowerCase();
  final issRetained = tax['issRetained'] == true;
  final rawIssRate = _asFocusDecimal(tax['issRate']);
  final simpleOpt = _focusNationalSimpleOptionCode(taxRegime);
  final simpleTax = _focusNationalSimpleTaxRegimeCode(taxRegime);
  final requiresMinRetainedIss = focusApiIsNational &&
      issRetained &&
      simpleOpt == 3 &&
      simpleTax == 1;
  if (requiresMinRetainedIss && rawIssRate < 1.8) {
    missing.add('aliquota minima 1,80% para Simples com ISS retido (NFS-e Nacional)');
  }

  final inssCents = int.tryParse('${tax['inssAmountCents'] ?? 0}') ?? 0;
  if (inssCents < 0) {
    missing.add('valor de INSS nao pode ser negativo');
  }

  // TS: normalizeOperationNatureCode nunca fica vazio; mantemos verificacao leve.
  final environment = _trim(setup['environment']).toLowerCase();
  if (environment == 'producao') {
    if (homologation['companyBaseReviewed'] != true) {
      missing.add('checklist: cadastro base revisado');
    }
    if (homologation['certificateValidated'] != true) {
      missing.add('checklist: certificado validado');
    }
    if (homologation['matrixValidated'] != true) {
      missing.add('checklist: matriz fiscal conferida');
    }
    if (homologation['providerConnectionValidated'] != true) {
      missing.add('checklist: conexao com provedor validada');
    }
    if (homologation['pilotInvoiceValidated'] != true) {
      missing.add('checklist: emissao piloto validada');
    }
    if (homologation['productionAuthorized'] != true) {
      missing.add('checklist: producao autorizada');
    }
  }

  return FocusOfficialIssueReadiness(missing: missing);
}
