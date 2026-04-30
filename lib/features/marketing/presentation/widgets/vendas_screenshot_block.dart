import 'package:flutter/material.dart';

const _ink = Color(0xFF16202B);
const _muted = Color(0xFF5C6B7A);
const _line = Color(0xFFDCE5EF);

/// Bloco de imagem + título + legenda (mesmo estilo da página `/vendas`).
class VendasScreenshotBlock extends StatelessWidget {
  const VendasScreenshotBlock({
    super.key,
    required this.asset,
    required this.label,
    required this.caption,
  });

  final String asset;
  final String label;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 720;
    final image = Image.asset(
      asset,
      width: double.infinity,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) => Container(
        height: 220,
        alignment: Alignment.center,
        color: const Color(0xFFEAF0F6),
        child: Text(asset, style: const TextStyle(color: _muted)),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFEDF3FA),
            borderRadius: BorderRadius.circular(compact ? 14 : 18),
            border: Border.all(color: _line),
          ),
          child: Padding(
            padding: EdgeInsets.all(compact ? 2 : 6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(compact ? 10 : 14),
              child: image,
            ),
          ),
        ),
        SizedBox(height: compact ? 10 : 12),
        Text(
          label,
          style: TextStyle(
            color: _ink,
            fontSize: compact ? 18 : 18,
            fontWeight: FontWeight.w900,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          caption,
          style: TextStyle(
            color: _muted,
            fontSize: compact ? 16 : 16,
            height: 1.45,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Referência: quais artes usar em cada rota de vendas segmentada.
abstract final class VendasMarketingAssets {
  static const contadorPainel = 'assets/marketing/sales/contador-painel.png';
  static const contadorFiscal = 'assets/marketing/sales/contador-fiscal.png';
  static const relatorios = 'assets/marketing/sales/relatorios.png';

  static const empresaPainel = 'assets/marketing/sales/painel.png';
  static const empresaFiscalEmissao = 'assets/marketing/sales/fiscal-emissao.png';
  static const empresaFinanceiro = 'assets/marketing/sales/financeiro.png';
  static const empresaDocumentos = 'assets/marketing/sales/documentos.png';
}
