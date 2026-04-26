# Convenção de nome do AAB (Android App Bundle)

## Regra

- Ao preparar o ficheiro para upload na **Google Play**, o artefacto deve ser copiado (ou guardado) com o nome:

  `pontocerto-<versionName>-<versionCode>.aab`

- Onde `<versionName>` e `<versionCode>` vêm do `pubspec.yaml`, linha `version: X.Y.Z+BUILD` (ex.: `1.0.82+1053` → nome `pontocerto-1.0.82-1053.aab`).
- O separador no nome do ficheiro é **hífen** entre versão e build (evita `+` no nome do ficheiro no Windows).
- A **versão** no `pubspec` deve **sempre subir** em relação à última publicada na Play (nome `X.Y.Z` e `versionCode` maiores do que a release anterior), conforme [versionamento Android](https://developer.android.com/studio/publish/versioning).

## Onde a versão vive

- Ficheiro: `pubspec.yaml`  
- Formato: `version: <versionName>+<versionCode>` (ex. `1.0.82+1053`).

## Automático

- Script: `scripts/build_android_release.ps1` com `-CopyToDesktop` gera o bundle e copia com este nome para a **Área de trabalho** (ajustar `flutter.bat` no script, se o teu PC usar outro caminho).

## Exemplo

| pubspec        | ficheiro na área de trabalho   |
|----------------|---------------------------------|
| 1.0.82+1053    | `pontocerto-1.0.82-1053.aab`   |
| 1.0.83+1054    | `pontocerto-1.0.83-1054.aab`   |
