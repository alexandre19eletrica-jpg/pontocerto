// Gera docs/ESTADO_SISTEMA_VERIFICAVEL_GERADO.md a partir de fontes reais (pubspec, Firebase).
// Uso: na raiz do projeto: dart run tool/estado_sistema.dart
import 'dart:convert';
import 'dart:io';

void main() {
  final root = Directory.current;
  if (!File('${root.path}/pubspec.yaml').existsSync()) {
    stderr.writeln('Executar na raiz do projeto (onde esta pubspec.yaml).');
    exit(1);
  }

  final pubspec = File('${root.path}/pubspec.yaml').readAsStringSync();
  final version =
      RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(pubspec)?.group(1) ?? '(nao lida)';

  var project = '(falta .firebaserc)';
  final firebaserc = File('${root.path}/.firebaserc');
  if (firebaserc.existsSync()) {
    final m = jsonDecode(firebaserc.readAsStringSync()) as Map<String, dynamic>?;
    final projects = m?['projects'] as Map<String, dynamic>?;
    project = projects?['default']?.toString() ?? project;
  }

  var site = '(falta firebase.json)';
  var fnRuntime = '(nao lido)';
  final fj = File('${root.path}/firebase.json');
  if (fj.existsSync()) {
    final m = jsonDecode(fj.readAsStringSync()) as Map<String, dynamic>?;
    final hosting = m?['hosting'];
    if (hosting is List && hosting.isNotEmpty) {
      final first = hosting.first;
      if (first is Map && first['site'] != null) {
        site = first['site'].toString();
      }
    } else if (hosting is Map && hosting['site'] != null) {
      site = hosting['site'].toString();
    }
    final fns = m?['functions'];
    if (fns is Map && fns['runtime'] != null) {
      fnRuntime = fns['runtime'].toString();
    }
  }

  var sha = '';
  final gr = Process.runSync('git', ['rev-parse', '--short', 'HEAD'], runInShell: true);
  if (gr.exitCode == 0) {
    sha = gr.stdout.toString().trim();
  }

  final now = DateTime.now().toUtc();
  final iso = now.toIso8601String();
  final urlHosting = 'https://$site.web.app';
  final urlDomain = 'https://gestao-ponto-certo.com';

  final out = StringBuffer()
    ..writeln('# Estado do sistema (verificavel, gerado)')
    ..writeln()
    ..writeln('**Nao edite manualmente**: este ficheiro e recriado por `dart run tool/estado_sistema.dart`.')
    ..writeln()
    ..writeln('## Valores actuais (extraidos do repositorio)')
    ..writeln()
    ..writeln('| Chave | Valor |')
    ..writeln('|--------|--------|')
    ..writeln('| Gerado em (UTC) | $iso |')
    ..writeln('| Versao no `pubspec.yaml` | `$version` |')
    ..writeln('| Projecto Firebase (`.firebaserc` default) | `$project` |')
    ..writeln('| Site Hosting (`firebase.json`) | `$site` |')
    ..writeln('| URL publica do Hosting | $urlHosting |')
    ..writeln('| Dominio de producao (registo operacional) | $urlDomain |')
    ..writeln('| Cloud Functions runtime (`firebase.json`) | `$fnRuntime` |');
  if (sha.isNotEmpty) {
    out.writeln('| Commit (git) | `$sha` |');
  } else {
    out.writeln('| Commit (git) | (repositorio nao e git ou git indisponivel) |');
  }
  out
    ..writeln()
    ..writeln('## O que e "tempo real" na pratica')
    ..writeln()
    ..writeln('- **Isto** reflecte a arvore de codigo e configuracao local no momento do comando (versao, projecto, site).')
    ..writeln('- O **servico em producao** e o que esta no Firebase/Hosting; so um `firebase deploy` (ou a consola) actualiza a nuvem.')
    ..writeln('- Documentacao narrativa (modulos, promessas, riscos) fica em `docs/registro_continuidade/ESTADO_ATUAL_DO_SISTEMA.md` e `docs/OFICIAL_*.md`, e deve ser revista apos entregas relevantes.')
    ..writeln();

  final path = File('${root.path}/docs/ESTADO_SISTEMA_VERIFICAVEL_GERADO.md');
  path.writeAsStringSync(out.toString());
  stdout.writeln('Escrito: ${path.path}');
}
