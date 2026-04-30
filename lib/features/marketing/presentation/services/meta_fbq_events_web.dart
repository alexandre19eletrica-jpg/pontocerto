// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';

void _appendInline(String source) {
  final el = html.ScriptElement()..text = source;
  if (html.document.body != null) {
    html.document.body!.append(el);
  } else {
    html.document.head?.append(el);
  }
}

bool _hasFbq() {
  // ignore: avoid_dynamic_calls
  return (html.window as dynamic).fbq != null;
}

void _callFbqTrack(String name, [Object? eventParams]) {
  final b = StringBuffer('(function(){var w=window,f=w.fbq;if(!f)return;');
  b.write("f('track',");
  b.write(jsonEncode(name));
  if (eventParams != null) {
    b.write(',');
    b.write(jsonEncode(eventParams));
  }
  b.write(');})();');
  _appendInline(b.toString());
}

void _runWhenFbq(void Function() work) {
  if (_hasFbq()) {
    work();
    return;
  }
  unawaited(
    Future<void>.delayed(const Duration(milliseconds: 500), () {
      if (_hasFbq()) {
        work();
      }
    }),
  );
}

void metaFbqTrackPageView() {
  _callFbqTrack('PageView');
}

void metaFbqBindGoRouter(GoRouter router) {
  var lastPath = '';
  void onRoute() {
    final loc = router.state.matchedLocation;
    if (loc.isEmpty || loc == lastPath) return;
    lastPath = loc;
    _runWhenFbq(() => _callFbqTrack('PageView'));
  }

  router.routerDelegate.addListener(onRoute);
  SchedulerBinding.instance.scheduleFrameCallback((_) {
    onRoute();
  });
}

void metaFbqTrackVendasFunnel() {
  _runWhenFbq(() {
    _callFbqTrack('ViewContent', {
      'content_type': 'product',
      'content_name': 'Ponto_Certo_landing_vendas',
    });
  });
}

void metaFbqTrackCadastroEscritorioView() {
  _runWhenFbq(() {
    _callFbqTrack('ViewContent', {
      'content_type': 'registration',
      'content_name': 'Ponto_Certo_cadastro_escritorio',
    });
  });
}

void metaFbqTrackVendasEmpresaLandingView() {
  _runWhenFbq(() {
    _callFbqTrack('ViewContent', {
      'content_type': 'registration',
      'content_name': 'Ponto_Certo_landing_vendas_empresa_convite',
    });
  });
}

void metaFbqTrackSolicitacaoTesteView() {
  _runWhenFbq(() {
    _callFbqTrack('ViewContent', {
      'content_type': 'registration',
      'content_name': 'Ponto_Certo_solicitacao_teste_30d',
    });
  });
}

void metaFbqTrackCompleteRegistrationEscritorio({
  required String officeId,
  required String contentName,
}) {
  _runWhenFbq(() {
    if (officeId.isNotEmpty) {
      _callFbqTrack('CompleteRegistration', {
        'content_name': contentName,
        'content_ids': <String>[officeId],
        'status': true,
      });
    } else {
      _callFbqTrack('CompleteRegistration', {
        'content_name': contentName,
        'status': true,
      });
    }
  });
}

void metaFbqTrackLeadConviteContadorLandingEmpresa({required String leadId}) {
  _runWhenFbq(() {
    final map = <String, Object?>{
      'content_name': 'Ponto_Certo_convite_contador_landing_empresa',
      'content_category': 'landing_vendas_empresa',
    };
    if (leadId.isNotEmpty) {
      map['content_ids'] = <String>[leadId];
    }
    _callFbqTrack('Lead', map);
  });
}

void metaFbqTrackContactWhatsapp() {
  _runWhenFbq(() {
    _callFbqTrack('Contact', {
      'content_name': 'Ponto_Certo_whatsapp_comercial',
      'content_category': 'whatsapp',
    });
  });
}

void metaFbqTrackStartTrialEscritorio() {
  _runWhenFbq(() {
    _callFbqTrack('StartTrial', {
      'value': 0,
      'currency': 'BRL',
      'predicted_ltv': 0,
      'content_name': 'Ponto_Certo_trial_escritorio_30d',
    });
  });
}

void metaFbqTrackLeadPreCadastro({
  required String leadId,
  required String planCode,
}) {
  _runWhenFbq(() {
    final map = <String, Object?>{
      'content_name': 'Ponto_Certo_pre_cadastro',
      'content_category': planCode,
    };
    if (leadId.isNotEmpty) {
      map['content_ids'] = <String>[leadId];
    }
    _callFbqTrack('Lead', map);
  });
}
