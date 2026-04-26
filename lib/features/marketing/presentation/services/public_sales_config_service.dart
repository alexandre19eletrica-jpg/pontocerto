import 'package:cloud_functions/cloud_functions.dart';

class PublicSalesConfigService {
  PublicSalesConfigService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  Future<PublicSalesConfig> fetch() async {
    final callable = _functions.httpsCallable('platformGetPublicSalesConfig');
    final result = await callable.call();
    final data = Map<String, dynamic>.from(result.data as Map);
    return PublicSalesConfig.fromMap(
      Map<String, dynamic>.from(
        data['config'] as Map? ?? const <String, dynamic>{},
      ),
    );
  }

  Future<PublicSalesConfig> update(PublicSalesConfig config) async {
    final callable = _functions.httpsCallable(
      'platformUpdatePublicSalesConfig',
    );
    final result = await callable.call(<String, dynamic>{
      'config': config.toMap(),
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return PublicSalesConfig.fromMap(
      Map<String, dynamic>.from(
        data['config'] as Map? ?? const <String, dynamic>{},
      ),
    );
  }
}

class PublicSalesConfig {
  const PublicSalesConfig({
    required this.enabled,
    required this.planSolo,
    required this.planEquipe,
    required this.additionalAccess,
    required this.metaPixelHeadSnippet,
    required this.updatedAtIso,
  });

  final bool enabled;
  final PublicSalesPlan planSolo;
  final PublicSalesPlan planEquipe;
  final PublicSalesPlan additionalAccess;
  /// Codigo de base (HTML) do Meta Pixel, como no Events Manager, para o head.
  final String metaPixelHeadSnippet;
  final String updatedAtIso;

  factory PublicSalesConfig.defaults() {
    return const PublicSalesConfig(
      enabled: true,
      planSolo: PublicSalesPlan(
        title: 'Plano Solo',
        priceLabel: 'R\$ 97,90/mes',
        implantationLabel:
            'Teste real gratis por 30 dias. A empresa precisa indicar o contador para conduzir o cadastro.',
        checkoutUrl: 'https://www.asaas.com/c/zl74djk2gu2sc88p',
      ),
      planEquipe: PublicSalesPlan(
        title: 'Plano Equipe',
        priceLabel: 'R\$ 97,90/mes',
        implantationLabel:
            'Teste real gratis por 30 dias. A empresa precisa indicar o contador para conduzir o cadastro.',
        checkoutUrl: 'https://www.asaas.com/c/twi5txqg1lcqq7gd',
      ),
      additionalAccess: PublicSalesPlan(
        title: 'Acesso app Play Store para funcionario',
        priceLabel: 'R\$ 19,90/mes',
        implantationLabel:
            'Tambem entra no teste real de 30 dias quando a empresa estiver ativa',
        checkoutUrl: '',
      ),
      metaPixelHeadSnippet: '',
      updatedAtIso: '',
    );
  }

  factory PublicSalesConfig.fromMap(Map<String, dynamic> map) {
    return PublicSalesConfig(
      enabled: map['enabled'] != false,
      planSolo: PublicSalesPlan.fromMap(
        Map<String, dynamic>.from(
          map['planSolo'] as Map? ?? const <String, dynamic>{},
        ),
      ),
      planEquipe: PublicSalesPlan.fromMap(
        Map<String, dynamic>.from(
          map['planEquipe'] as Map? ?? const <String, dynamic>{},
        ),
      ),
      additionalAccess: PublicSalesPlan.fromMap(
        Map<String, dynamic>.from(
          map['additionalAccess'] as Map? ?? const <String, dynamic>{},
        ),
      ),
      metaPixelHeadSnippet: map['metaPixelHeadSnippet']?.toString() ?? '',
      updatedAtIso: map['updatedAt']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'planSolo': planSolo.toMap(),
      'planEquipe': planEquipe.toMap(),
      'additionalAccess': additionalAccess.toMap(),
      'metaPixelHeadSnippet': metaPixelHeadSnippet,
    };
  }
}

class PublicSalesPlan {
  const PublicSalesPlan({
    required this.title,
    required this.priceLabel,
    required this.implantationLabel,
    required this.checkoutUrl,
  });

  final String title;
  final String priceLabel;
  final String implantationLabel;
  final String checkoutUrl;

  factory PublicSalesPlan.fromMap(Map<String, dynamic> map) {
    return PublicSalesPlan(
      title: map['title']?.toString() ?? '',
      priceLabel: map['priceLabel']?.toString() ?? '',
      implantationLabel: map['implantationLabel']?.toString() ?? '',
      checkoutUrl: map['checkoutUrl']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'priceLabel': priceLabel,
      'implantationLabel': implantationLabel,
      'checkoutUrl': checkoutUrl,
    };
  }
}
