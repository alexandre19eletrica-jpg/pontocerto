import 'package:flutter/material.dart';
import 'package:pontocerto/core/theme/app_branding.dart';

class InvoiceEmitterCard extends StatelessWidget {
  const InvoiceEmitterCard({
    super.key,
    required this.companyData,
    this.title = 'Emitente',
    this.subtitle,
  });

  final Map<String, dynamic> companyData;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final stateRegistrationLabel = _stateRegistrationLabel(companyData);
    final municipalRegistrationLabel = _municipalRegistrationLabel(companyData);
    final serviceBusiness = companyData['inscricaoEstadualDispensada'] == true;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD6E3FA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: const TextStyle(color: AppBrandColors.softText, height: 1.35),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            companyData['razaoSocial']?.toString().trim().isNotEmpty == true
                ? companyData['razaoSocial'].toString()
                : companyData['nomeFantasia']?.toString() ?? '-',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text('CNPJ: ${companyData['cnpj'] ?? '-'}'),
          Text('IE: $stateRegistrationLabel'),
          Text('IM: $municipalRegistrationLabel'),
          if (serviceBusiness &&
              municipalRegistrationLabel ==
                  'Pendente para empresa de prestacao de servicos') ...[
            const SizedBox(height: 8),
            const Text(
              'Pendencia fiscal: informe a inscricao municipal para concluir a homologacao e emitir NFS-e.',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            _companyAddressLine(companyData),
            style: const TextStyle(color: AppBrandColors.softText),
          ),
        ],
      ),
    );
  }
}

String _stateRegistrationLabel(Map<String, dynamic> companyData) {
  if (companyData['inscricaoEstadualDispensada'] == true) {
    return 'Dispensada para prestacao de servicos';
  }
  final value = companyData['inscricaoEstadual']?.toString().trim() ?? '';
  return value.isEmpty ? '-' : value;
}

String _municipalRegistrationLabel(Map<String, dynamic> companyData) {
  final value = companyData['inscricaoMunicipal']?.toString().trim() ?? '';
  if (value.isNotEmpty) return value;
  if (companyData['inscricaoMunicipalObrigatoria'] == true ||
      companyData['inscricaoEstadualDispensada'] == true) {
    return 'Pendente para empresa de prestacao de servicos';
  }
  return '-';
}

class InvoiceCustomerPortfolioCard extends StatelessWidget {
  const InvoiceCustomerPortfolioCard({
    super.key,
    required this.customers,
    this.onSelect,
  });

  final List<Map<String, dynamic>> customers;
  final ValueChanged<Map<String, dynamic>>? onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD6E3FA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tomadores recentes',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 8),
          if (customers.isEmpty)
            const Text(
              'Os tomadores salvos das notas aparecerao aqui para acelerar as proximas emissoes.',
              style: TextStyle(color: AppBrandColors.softText),
            )
          else
            ...customers.take(5).map(
              (customer) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.apartment_outlined),
                title: Text(
                  customer['legalName']?.toString().trim().isNotEmpty == true
                      ? customer['legalName'].toString()
                      : customer['tradeName']?.toString() ?? '-',
                ),
                subtitle: Text(
                  '${customer['document'] ?? '-'}\n${customer['city'] ?? '-'} - ${customer['state'] ?? '-'}',
                ),
                isThreeLine: true,
                trailing: onSelect == null
                    ? null
                    : TextButton(
                        onPressed: () => onSelect!(customer),
                        child: const Text('Usar'),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

String _companyAddressLine(Map<String, dynamic> companyData) {
  final parts = <String>[
    if ((companyData['endereco']?.toString().trim().isNotEmpty ?? false))
      companyData['endereco'].toString(),
    if ((companyData['rua']?.toString().trim().isNotEmpty ?? false))
      companyData['rua'].toString(),
    if ((companyData['cidade']?.toString().trim().isNotEmpty ?? false))
      companyData['cidade'].toString(),
    if ((companyData['estado']?.toString().trim().isNotEmpty ?? false))
      companyData['estado'].toString(),
  ];
  return parts.isEmpty ? '-' : parts.join(' | ');
}
