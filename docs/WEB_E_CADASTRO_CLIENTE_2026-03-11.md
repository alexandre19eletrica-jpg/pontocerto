# Web e cadastro de cliente

Data: 11/03/2026

## Decisoes de produto

- Registro de ponto com reconhecimento facial nao entra agora.
- Caminho recomendado para ponto:
  selfie de evidencia + geolocalizacao + trilha de auditoria.
- Consulta automatica por documento:
  - `CNPJ`: preparar fluxo para integracao oficial/futura.
  - `CPF`: manter manual por privacidade e LGPD.

## O que ja ficou pronto no codigo

- Tarefas agora suportam armazenar documento do cliente.
- UI de tarefas preparada para `CPF/CNPJ` com mensagens diferentes para cada caso.
- Uploads de midia migrados para `putData`, removendo dependencia de arquivo local nas telas alteradas.
- Hosting do Firebase ajustado para servir `build/web` com rewrite para SPA.
- Metadados do PWA/web atualizados.

## Bloqueios atuais para publicar em dominio

- `lib/firebase_options.dart` ainda nao possui configuracao `web`.
- Sem isso, o app pode abrir no navegador, mas nao inicializa Firebase para login/dados reais.
- Precisamos criar o app web no Firebase e regenerar o arquivo com FlutterFire.

## Proxima sequencia recomendada

1. Criar app web no projeto Firebase `pontocerto-e1dab`.
2. Rodar FlutterFire para gerar `FirebaseOptions.web`.
3. Fazer `flutter build web`.
4. Publicar no Hosting.
5. Conectar dominio customizado e validar:
   - celular navegador
   - desktop
   - login
   - Firestore
   - Storage
   - Functions

## Observacoes legais

- Biometria/reconhecimento facial exigem tratamento mais rigoroso por LGPD.
- Autofill por CPF sem base legal/autorizacao formal nao deve entrar como consulta automatica.
