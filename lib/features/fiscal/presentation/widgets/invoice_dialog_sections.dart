import 'package:flutter/material.dart';
import 'package:pontocerto/core/theme/app_layout.dart';
import 'package:pontocerto/core/utils/formatadores_input.dart';

class InvoiceServiceSection extends StatelessWidget {
  const InvoiceServiceSection({
    super.key,
    required this.serviceCodeController,
    required this.municipalServiceCodeController,
    required this.cnaeController,
    required this.serviceCityController,
    required this.serviceController,
    required this.serviceComplementController,
    required this.fiscalPaymentBankInfoController,
    required this.amountController,
    this.onServiceBaseChanged,
    this.onServiceComplementChanged,
    required this.onServiceCodeChanged,
    required this.onServiceCityChanged,
    this.onFormChanged,
  });

  final TextEditingController serviceCodeController;
  final TextEditingController municipalServiceCodeController;
  final TextEditingController cnaeController;
  final TextEditingController serviceCityController;
  final TextEditingController serviceController;
  final TextEditingController serviceComplementController;
  final TextEditingController fiscalPaymentBankInfoController;
  final TextEditingController amountController;
  final VoidCallback? onServiceBaseChanged;
  final VoidCallback? onServiceComplementChanged;
  final ValueChanged<String> onServiceCodeChanged;
  final ValueChanged<String> onServiceCityChanged;
  final VoidCallback? onFormChanged;

  @override
  Widget build(BuildContext context) {
    return AppWorkspaceCard(
      title: 'Servico prestado',
      subtitle: 'Descricao, codigos e dados operacionais do servico prestado.',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: serviceCodeController,
                  onChanged: (v) {
                    onServiceCodeChanged(v);
                    onFormChanged?.call();
                  },
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Codigo do servico',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: municipalServiceCodeController,
                  onChanged: (_) => onFormChanged?.call(),
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
                  onChanged: (_) => onFormChanged?.call(),
                  decoration: const InputDecoration(
                    labelText: 'CNAE',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: serviceCityController,
                  onChanged: (v) {
                    onServiceCityChanged(v);
                    onFormChanged?.call();
                  },
                  decoration: const InputDecoration(
                    labelText: 'Municipio da incidencia',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: serviceController,
            onChanged: (_) {
              onServiceBaseChanged?.call();
              onFormChanged?.call();
            },
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Descricao fiscal do servico (modelo / oficial)',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: serviceComplementController,
            onChanged: (_) {
              onServiceComplementChanged?.call();
              onFormChanged?.call();
            },
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Informacoes adicionais (abaixo da descricao fiscal)',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: amountController,
            onChanged: (_) => onFormChanged?.call(),
            inputFormatters: [CurrencyPtBrInputFormatter()],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Valor bruto (R\$)',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: fiscalPaymentBankInfoController,
            onChanged: (_) => onFormChanged?.call(),
            maxLines: 3,
            decoration: const InputDecoration(
              labelText:
                  'Dados bancarios para recebimento (texto no fim da descricao da nota)',
              alignLabelWithHint: true,
              helperText:
                  'Igual ao cartao «Recebimento na NFS-e» na pagina Fiscal. Salvar a nota grava tambem no cadastro da empresa.',
            ),
          ),
        ],
      ),
    );
  }
}

class InvoiceWorkSiteSection extends StatelessWidget {
  const InvoiceWorkSiteSection({
    super.key,
    required this.workSiteNameController,
    required this.workSiteCnoController,
    required this.workSiteZipCodeController,
    required this.workSiteStreetController,
    required this.workSiteNumberController,
    required this.workSiteComplementController,
    required this.workSiteNeighborhoodController,
    required this.workSiteCityController,
    required this.workSiteStateController,
    this.cnoHelperText = '',
    this.onFieldChanged,
    this.onWorkSiteCepSearch,
    this.workSiteCepLoading = false,
  });

  final TextEditingController workSiteNameController;
  final TextEditingController workSiteCnoController;
  final TextEditingController workSiteZipCodeController;
  final TextEditingController workSiteStreetController;
  final TextEditingController workSiteNumberController;
  final TextEditingController workSiteComplementController;
  final TextEditingController workSiteNeighborhoodController;
  final TextEditingController workSiteCityController;
  final TextEditingController workSiteStateController;
  final String cnoHelperText;
  final VoidCallback? onFieldChanged;
  final Future<void> Function()? onWorkSiteCepSearch;
  final bool workSiteCepLoading;

  @override
  Widget build(BuildContext context) {
    const cepFieldStyle = TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
    );
    return AppWorkspaceCard(
      title: 'Dados da obra',
      subtitle:
          'Obrigatório com codigo nacional do grupo obra: CNO, nome, endereco completo. No celular, o CEP em linha unica fica com fonte grande.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: workSiteNameController,
            onChanged: (_) => onFieldChanged?.call(),
            decoration: const InputDecoration(
              labelText: 'Nome da obra/local',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: workSiteCnoController,
            keyboardType: TextInputType.number,
            onChanged: (_) => onFieldChanged?.call(),
            decoration: InputDecoration(
              labelText: 'CNO (Cadastro Nacional de Obras / CAEPE)',
              helperText: cnoHelperText.isEmpty
                  ? 'Somente numeros, quando a tributacao nacional exigir (grupo obra).'
                  : cnoHelperText,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: workSiteZipCodeController,
            keyboardType: TextInputType.number,
            onChanged: (_) => onFieldChanged?.call(),
            style: cepFieldStyle,
            decoration: const InputDecoration(
              labelText: 'CEP da obra',
              isDense: false,
              contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              border: OutlineInputBorder(),
            ),
          ),
          if (onWorkSiteCepSearch != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: workSiteCepLoading
                  ? null
                  : () => onWorkSiteCepSearch!(),
              icon: workSiteCepLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.travel_explore_outlined, size: 20),
              label: const Text('Buscar CEP e preencher o endereco da obra'),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: workSiteCityController,
                  onChanged: (_) => onFieldChanged?.call(),
                  decoration: const InputDecoration(
                    labelText: 'Municipio da obra',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 100,
                child: TextField(
                  controller: workSiteStateController,
                  onChanged: (_) => onFieldChanged?.call(),
                  decoration: const InputDecoration(
                    labelText: 'UF',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: workSiteStreetController,
                  onChanged: (_) => onFieldChanged?.call(),
                  decoration: const InputDecoration(
                    labelText: 'Logradouro da obra',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: workSiteNumberController,
                  onChanged: (_) => onFieldChanged?.call(),
                  decoration: const InputDecoration(
                    labelText: 'Numero',
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
                  controller: workSiteNeighborhoodController,
                  onChanged: (_) => onFieldChanged?.call(),
                  decoration: const InputDecoration(
                    labelText: 'Bairro da obra',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: workSiteComplementController,
                  onChanged: (_) => onFieldChanged?.call(),
                  decoration: const InputDecoration(
                    labelText: 'Complemento',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class InvoiceFiscalHeaderSection extends StatelessWidget {
  const InvoiceFiscalHeaderSection({
    super.key,
    required this.status,
    required this.officialNumberController,
    required this.portalController,
    required this.issueDateLabel,
    required this.serviceDateLabel,
    required this.onStatusChanged,
    required this.onIssueDatePressed,
    required this.onServiceDatePressed,
  });

  final String status;
  final TextEditingController officialNumberController;
  final TextEditingController portalController;
  final String issueDateLabel;
  final String serviceDateLabel;
  final ValueChanged<String?> onStatusChanged;
  final VoidCallback onIssueDatePressed;
  final VoidCallback onServiceDatePressed;

  @override
  Widget build(BuildContext context) {
    const allowed = {
      'DRAFT',
      'APPROVED',
      'CANCELED',
    };
    final value = allowed.contains(status) ? status : 'DRAFT';
    return AppWorkspaceCard(
      title: 'Cabecalho fiscal',
      subtitle: 'Numero, status e datas da emissao fiscal.',
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            initialValue: value,
            decoration: const InputDecoration(
              labelText: 'Status da nota',
            ),
            items: const [
              DropdownMenuItem(value: 'DRAFT', child: Text('Rascunho')),
              DropdownMenuItem(
                value: 'APPROVED',
                child: Text('Aprovada / autorizada'),
              ),
              DropdownMenuItem(value: 'CANCELED', child: Text('Cancelada')),
            ],
            onChanged: onStatusChanged,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: officialNumberController,
            decoration: const InputDecoration(
              labelText: 'Numero oficial da NFS-e',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: portalController,
            decoration: const InputDecoration(
              labelText: 'Link portal oficial',
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _InvoiceDateTile(
                  label: 'Data de emissao',
                  value: issueDateLabel,
                  onPressed: onIssueDatePressed,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InvoiceDateTile(
                  label: 'Data do servico',
                  value: serviceDateLabel,
                  onPressed: onServiceDatePressed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class InvoiceTaxSection extends StatelessWidget {
  const InvoiceTaxSection({
    super.key,
    required this.deductionsController,
    required this.taxRateController,
    required this.inssRateController,
    required this.otherRetentionsController,
    required this.taxRegimeController,
    required this.operationNatureController,
    required this.issRetained,
    required this.onIssRetainedChanged,
    required this.inssRetained,
    required this.onInssRetainedChanged,
    required this.totalsPreview,
    required this.fiscalCostBearer,
    required this.onFiscalCostBearerChanged,
  });

  final TextEditingController deductionsController;
  final TextEditingController taxRateController;
  final TextEditingController inssRateController;
  final TextEditingController otherRetentionsController;
  final TextEditingController taxRegimeController;
  final TextEditingController operationNatureController;
  final bool issRetained;
  final ValueChanged<bool> onIssRetainedChanged;
  final bool inssRetained;
  final ValueChanged<bool> onInssRetainedChanged;
  final Widget totalsPreview;
  final String fiscalCostBearer;
  final ValueChanged<String?> onFiscalCostBearerChanged;

  @override
  Widget build(BuildContext context) {
    return AppWorkspaceCard(
      title: 'Tributacao e totais',
      subtitle:
          'Aliquota ISS, INSS e retencoes sao manuais neste bloco. O painel "Automacao juridica" so orienta, sem alterar o que voce digitar.',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: deductionsController,
                  inputFormatters: [CurrencyPtBrInputFormatter()],
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Deducoes (R\$)',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: otherRetentionsController,
                  inputFormatters: [CurrencyPtBrInputFormatter()],
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Outras retencoes (R\$)',
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
                  controller: taxRateController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Aliquota ISS (%)',
                    helperText:
                        'Somente o valor que voce informar. Modelos e atividades nao alteram mais esta aliquota. Na emissao, segue a retencao de ISS (interruptor) e a regra do emissor.',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: taxRegimeController,
                  decoration: const InputDecoration(
                    labelText: 'Regime tributario',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: operationNatureController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Natureza da operacao',
              helperText:
                  'Ajuste manual. Modelo de servico ou matriz podem sugerir texto; a sugestao nao substitui a sua aliquota ou retencao.',
            ),
          ),
          SwitchListTile(
            value: issRetained,
            onChanged: onIssRetainedChanged,
            contentPadding: EdgeInsets.zero,
            title: const Text('ISS retido pelo tomador'),
            subtitle: const Text(
              'Selecione quando houver retencao de ISS. Sem essa marcacao, a aliquota pode continuar visivel na tela, mas nao sera enviada na emissao real quando a regra nacional exigir isso.',
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: inssRateController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Aliquota INSS / CP (%) sobre a base',
              helperText:
                  'Base tipica: valor do servico apos deducoes. Ajuste somente com orientacao; padrao 11% em servicos de obra/construcao sujeitos a retencao.',
            ),
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            value: inssRetained,
            onChanged: onInssRetainedChanged,
            contentPadding: EdgeInsets.zero,
            title: const Text('INSS (CP) retido pelo tomador'),
            subtitle: const Text(
              'Marque quando a retencao de INSS/CP for devida. O valor e calculado com a aliquota acima; na emissao real a Focus recebe o valor (valor_cp) quando for maior que zero.',
            ),
          ),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            initialValue: fiscalCostBearer,
            decoration: const InputDecoration(
              labelText: 'Quem absorve o custo fiscal',
            ),
            items: const [
              DropdownMenuItem(
                value: 'provider',
                child: Text('Prestador de servico'),
              ),
              DropdownMenuItem(
                value: 'customer',
                child: Text('Tomador de servico'),
              ),
            ],
            onChanged: onFiscalCostBearerChanged,
          ),
          const SizedBox(height: 8),
          totalsPreview,
        ],
      ),
    );
  }
}

class _InvoiceDateTile extends StatelessWidget {
  const _InvoiceDateTile({
    required this.label,
    required this.value,
    required this.onPressed,
  });

  final String label;
  final String value;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD6E4FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              TextButton(onPressed: onPressed, child: const Text('Alterar')),
            ],
          ),
        ],
      ),
    );
  }
}
