# Documentacao Oficial do Projeto

Data base: 07/05/2026
Projeto: Ponto Certo

Versao local atual de referencia: `1.0.88+1059`

## Objetivo

Este arquivo e o ponto de entrada oficial da documentacao do projeto.
Ele existe para evitar dispersao, duplicidade e uso de documento antigo como referencia principal.

## Fonte oficial unica

Toda leitura do sistema deve partir destes 4 documentos:

1. [OFICIAL_01_PARTE_VISUAL_DO_SISTEMA.md](/C:/Users/hp/pontocerto/docs/OFICIAL_01_PARTE_VISUAL_DO_SISTEMA.md)
2. [OFICIAL_02_PARTE_FUNCIONAL_DO_SISTEMA.md](/C:/Users/hp/pontocerto/docs/OFICIAL_02_PARTE_FUNCIONAL_DO_SISTEMA.md)
3. [OFICIAL_03_ARQUITETURA_TECNICA_COMPLETA_DO_SISTEMA.md](/C:/Users/hp/pontocerto/docs/OFICIAL_03_ARQUITETURA_TECNICA_COMPLETA_DO_SISTEMA.md)
4. [OFICIAL_04_MEMORIA_E_REGISTRO_ATUAL_DO_SISTEMA.md](/C:/Users/hp/pontocerto/docs/OFICIAL_04_MEMORIA_E_REGISTRO_ATUAL_DO_SISTEMA.md)

## Como usar

### Para entender como o sistema deve parecer

Use:

- `OFICIAL_01_PARTE_VISUAL_DO_SISTEMA.md`

### Para entender o que o sistema realmente entrega

Use:

- `OFICIAL_02_PARTE_FUNCIONAL_DO_SISTEMA.md`

### Para entender como o sistema e construido

Use:

- `OFICIAL_03_ARQUITETURA_TECNICA_COMPLETA_DO_SISTEMA.md`

### Para saber o estado atual, historico recente e criterio de registro

Use:

- `OFICIAL_04_MEMORIA_E_REGISTRO_ATUAL_DO_SISTEMA.md`

### Para manter o assistente alinhado

Use como base principal:

- `OFICIAL_01_PARTE_VISUAL_DO_SISTEMA.md`
- `OFICIAL_02_PARTE_FUNCIONAL_DO_SISTEMA.md`
- `OFICIAL_03_ARQUITETURA_TECNICA_COMPLETA_DO_SISTEMA.md`
- `OFICIAL_04_MEMORIA_E_REGISTRO_ATUAL_DO_SISTEMA.md`

O prompt e a memoria operacional do assistente passam a ser derivados desses documentos oficiais.

## Documentos operacionais de apoio

Esses arquivos continuam importantes, mas passam a ser subordinados aos 4 oficiais:

- [PROMPT_ASSISTENTE_PONTO_CERTO.md](/C:/Users/hp/pontocerto/docs/PROMPT_ASSISTENTE_PONTO_CERTO.md)
- [CONTINUIDADE_ATUAL.md](/C:/Users/hp/pontocerto/docs/registro_continuidade/CONTINUIDADE_ATUAL.md)
- [MEMORIA_VIVA_SISTEMA.md](/C:/Users/hp/pontocerto/docs/registro_continuidade/MEMORIA_VIVA_SISTEMA.md)
- [ESTADO_ATUAL_DO_SISTEMA.md](/C:/Users/hp/pontocerto/docs/registro_continuidade/ESTADO_ATUAL_DO_SISTEMA.md)
- [ALINHAMENTO_MODULOS_E_PERMISSOES.md](/C:/Users/hp/pontocerto/docs/registro_continuidade/ALINHAMENTO_MODULOS_E_PERMISSOES.md)
- [MATRIZ_ACESSO_PONTO_CERTO.txt](/C:/Users/hp/pontocerto/docs/registro_continuidade/MATRIZ_ACESSO_PONTO_CERTO.txt)

## Regra de governanca documental

Quando houver mudanca relevante:

1. atualizar o documento oficial correspondente
2. atualizar os documentos operacionais derivados
3. registrar a rodada em `CONTINUIDADE_ATUAL.md`

## Regra oficial de comandos operacionais

Para pedidos de publicacao, build ou entrega operacional, o padrao oficial passa a ser:

- **nao reinventar o que ja funciona**: para deploy web + Cloud Functions + Hosting usar **somente** o **«Comando unico (padrao historico)»** mais abaixo, validado na pratica; **nao** orientar variantes (outros scripts, sequencias paralelas, chamadas `powershell -File ...` dentro do PowerShell, etc.) salvo **falha objetiva** desse fluxo **e** atualizacao **neste documento** com o novo comando ja testado
- ferramentas auxiliares no repo (`scripts/publish_all.ps1`, etc.) existem para quem optar; na **orientacao ao operador** e ao **assistente**, o referencial continua sendo **uma linha**: o comando historico oficial
- entregar sempre um unico comando completo
- o comando deve vir em sequencia corrida, sem opcoes paralelas para escolher
- antes de `firebase deploy`, ter sessao valida no Firebase CLI (`firebase login` quando a ferramenta pedir ou conta errada)
- o comando deve incluir, quando aplicavel:
- limpeza de cache
- restauracao de dependencias
- build web
- deploy de `functions` e `hosting`
- geracao do `AAB`
- copia final do `AAB` para a area de trabalho

Objetivo dessa regra:

- evitar erro de execucao por quebra manual de linha
- evitar perda de etapa entre build, deploy e pacote Android
- padronizar a entrega operacional final do projeto

### Publicacao apenas Hosting (alteracao so em Flutter web)

Quando nao houver mudanca em Cloud Functions, pode usar:

```powershell
Set-Location c:\Users\hp\pontocerto; flutter build web --release; firebase deploy --only hosting
```

### Comando unico (padrao historico — web + functions + hosting)

Uma **unica** linha no PowerShell, com **`;`** entre etapas (evitar `&&` em PowerShell antigo). O projeto Firebase usa o **default** de `.firebaserc` (`pontocerto-e1dab`). Ajuste os caminhos se o clone nao estiver em `c:\Users\hp\pontocerto`.

Copie **somente** a linha do bloco (sem `PS C:\...>`).

```powershell
Set-Location c:\Users\hp\pontocerto; flutter pub get; flutter build web --release; Set-Location functions; npm run build; Set-Location c:\Users\hp\pontocerto; firebase deploy --only functions,hosting
```

Primeira vez em cada maquina na pasta `functions`, se faltar `node_modules`:

```powershell
Set-Location c:\Users\hp\pontocerto\functions; npm install
```

Opcional **Play Store** (rodada com versao ja atualizada no `pubspec`):

```powershell
Set-Location c:\Users\hp\pontocerto; flutter build appbundle --release
```

Automacao extra no repo (analise, icons, `NODE_OPTIONS`, etc.): `scripts/publish_all.ps1` — **nao** substitui o comando oficial acima; use so se quiser esse fluxo assistido.

## Regra de precedencia

Se houver conflito entre documentos:

- os 4 documentos `OFICIAL_*` prevalecem
- depois prevalecem os documentos de continuidade vivos
- documentos antigos e snapshots servem apenas como historico
