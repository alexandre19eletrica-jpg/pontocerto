import 'public_meta_pixel_bootstrap_stub.dart'
    if (dart.library.html) 'public_meta_pixel_bootstrap_web.dart' as impl;

/// Apos o Firebase, na web, busca a landing publica e aplica o codigo de base
/// do Meta Pixel no head, como o Events Manager descreve.
Future<void> schedulePublicMetaPixelFromConfig() =>
    impl.schedulePublicMetaPixelFromConfig();
