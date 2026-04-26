# Termo De Autorizacao De Uso De Celular Proprio

## Finalidade
Este termo registra a autorizacao voluntaria do colaborador para uso do celular proprio
como ferramenta de trabalho no aplicativo PontoCerto.

## Escopo De Uso
- Registro de ponto (entrada e saida).
- Operacoes operacionais permitidas no app pela empresa.
- Registro tecnico de data/hora, versao do termo e identificadores do aceite.

## Declaracao Do Colaborador
Ao autorizar no app, o colaborador declara:
- que o aceite e voluntario, livre e informado;
- que compreende o uso do dispositivo pessoal para fins de trabalho no app;
- que pode revogar o aceite conforme regras da empresa e do sistema.

## Registro De Evidencias
O app registra no Firestore (`device_consents`):
- `employeeId`, `companyId`
- `accepted`, `acceptedAt`, `revokedAt`
- `termsVersion`, `acceptedStatement`
- `acceptedByUid`, `devicePlatform`, `timeZone`, `appVersion`

## Protecao Da Empresa
Este fluxo busca formalizar o consentimento digital do colaborador para uso do aparelho
pessoal no contexto do app, reduzindo risco de contestacao por uso nao autorizado.

## Observacao Juridica
Este documento e o fluxo no app ajudam na governanca e evidencia de consentimento,
mas nao substituem analise juridica formal. Recomenda-se validacao do texto final
com advogado trabalhista da empresa.

## Versao
Termo recomendado no app: `v2.0-2026-03-07`.
