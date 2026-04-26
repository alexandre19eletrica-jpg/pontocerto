# Play Store via CLI

Data: 13/03/2026

## Estado atual

- O projeto ja gera `AAB` de release corretamente com Flutter.
- O app ja possui integracao Android de atualizacao in-app via `in_app_update`.
- O projeto ainda nao possui automacao pronta de upload para a Play Store por CLI.

## O que o Flutter faz e o que ele nao faz

- `flutter build appbundle --release` gera o arquivo `.aab`.
- O Flutter nao publica esse arquivo sozinho na Google Play.
- Para upload via CLI, voce precisa de uma ferramenta de publicacao:
  - `Google Play Console` manual
  - `fastlane supply`
  - ou `Gradle Play Publisher`

## Bloqueio atual

Hoje nao da para eu subir pela CLI direto daqui porque faltam dois itens do lado da Play Store:

1. habilitar a `Google Play Developer API`
2. fornecer uma `service account JSON key` com permissao no app

Sem essa credencial, nenhuma automacao segura consegue publicar.

## Caminho recomendado para este projeto

Como este ambiente nao tem `Ruby/fastlane`, o caminho mais limpo seria:

1. criar uma `service account` no Google Cloud
2. habilitar a `Google Play Developer API`
3. vincular essa conta ao app no Play Console
4. guardar a chave JSON fora do git
5. usar CLI de publicacao

## Comandos uteis hoje

Gerar bundle:

```powershell
& 'C:\Users\hp\flutter\flutter\bin\flutter.bat' build appbundle --release
```

Arquivo gerado:

```text
build\app\outputs\bundle\release\app-release.aab
```

## Proximo passo quando a credencial existir

Quando voce tiver a chave JSON da service account, eu consigo preparar o fluxo de upload por CLI com seguranca.

O mais provavel sera um destes dois:

- `fastlane supply`
- `Gradle Play Publisher`

## Observacao sobre in-app update

- O app ja usa `in_app_update`.
- Isso melhora a experiencia de atualizacao para quem ja instalou o app pela Play Store.
- Mesmo assim, a versao nova precisa ser publicada na Play Store primeiro.
