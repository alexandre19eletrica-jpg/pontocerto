// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

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

void metaFbqTrackVendasFunnel() {
  _runWhenFbq(() {
    _callFbqTrack('PageView');
    _callFbqTrack('ViewContent', {
      'content_type': 'product',
      'content_name': 'Ponto_Certo_landing_vendas',
    });
  });
}

void metaFbqTrackCadastroEscritorioView() {
  _runWhenFbq(() {
    _callFbqTrack('PageView');
    _callFbqTrack('ViewContent', {
      'content_type': 'registration',
      'content_name': 'Ponto_Certo_cadastro_escritorio',
    });
  });
}

void metaFbqTrackSolicitacaoTesteView() {
  _runWhenFbq(() {
    _callFbqTrack('PageView');
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
