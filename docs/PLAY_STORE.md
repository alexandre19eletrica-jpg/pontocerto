# Publicacao Android (Play Store)

## 1) Definir ID final do app
- ID atual configurado no projeto: `br.com.alexandresousa.pontocerto`.
- Falta baixar no Firebase um novo `android/app/google-services.json` com esse mesmo package name.

## 2) Configurar assinatura de release
1. Copie `android/key.properties.example` para `android/key.properties`.
2. Preencha:
- `storePassword`
- `keyPassword`
- `keyAlias`
- `storeFile` (normalmente `app/upload-keystore.jks`)

Se `android/key.properties` estiver vazio/corrompido, o build release falha com mensagem explicita.

### Fingerprints da chave de upload atual
- SHA1: `EF:B7:62:94:BC:23:D8:5E:E9:53:19:B4:D9:76:08:74:B8:C2:6F:B1`
- SHA256: `62:73:E0:AB:05:E3:4E:EC:0F:A3:21:E2:51:EA:80:B0:A7:48:C7:31:5C:B6:D4:92:19:C0:46:01:A3:7F:07:9F`

## 3) Versionamento
- Ajuste em `pubspec.yaml`:
- `version: X.Y.Z+N`
- `X.Y.Z` = versao visivel na loja
- `N` = build number (sempre deve subir)

## 4) Gerar App Bundle (.aab)
```powershell
flutter clean
flutter pub get
flutter build appbundle --release
```

Arquivo gerado:
- `build/app/outputs/bundle/release/app-release.aab`

## 5) Upload no Play Console
1. Play Console > App > Producao (ou Teste interno).
2. Criar nova versao.
3. Enviar `app-release.aab`.
4. Preencher notas da versao.
5. Revisar e enviar para analise.
