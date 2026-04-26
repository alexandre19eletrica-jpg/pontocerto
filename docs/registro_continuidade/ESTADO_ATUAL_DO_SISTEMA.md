# Estado Atual Do Sistema

Data de consolidacao: 23/04/2026 (narrativa + referencias; numeros de versao/config em tempo real: ver abaixo)

**Estado minimo verificavel (versao, Firebase, URLs a partir do repo)**: [../ESTADO_SISTEMA_VERIFICAVEL_GERADO.md](../ESTADO_SISTEMA_VERIFICAVEL_GERADO.md) — apos subir `version:` no `pubspec` ou deploy relevante, regenerar com `dart run tool/estado_sistema.dart` e rever esta pagina se mudou o produto.

## Visao geral

O `Ponto Certo` funciona hoje como uma base SaaS multiempresa com foco `web-first` para operacao administrativa, comercial, fiscal e de escritorio contabil, mantendo `mobile-light` para uso rapido na rotina operacional.

Em `08/04/2026`, tres ajustes operacionais passaram a fazer parte do estado real:

- a landing `/vendas` foi reorganizada para leitura melhor no desktop, com hero e bloco fiscal em eixo vertical e fundos claros puxados para azul claro
- `Funcionarios` passou a ficar focado em leitura, enquanto o cadastro do colaborador e os documentos opcionais do registro ficaram concentrados em `Trabalhista`
- os lancamentos de pagamento agora aceitam classificacao manual por `diaria`, `semanal`, `mensal` ou `comissao`

Em `08/04/2026`, a regra de baixa no momento do lancamento passou a fazer parte do estado real:

- pagamentos individuais e em massa agora aceitam `Marcar como pago ao lancar`
- quando marcado, o pagamento nasce como `PAID` e gera reflexo imediato no financeiro da empresa na data atual
- quando nao marcado, o operador pode informar uma `Data prevista do pagamento` para manter a previsao sem baixar a despesa
- esse comportamento foi alinhado entre `Financeiro`, `Trabalhista`, `Pagamentos`, `paymentsCreate` e `paymentsCreateBulk`

Em `08/04/2026`, o comportamento da competencia da folha foi corrigido no estado real:

- lancamentos `semanais`, `diarios` e `comissao` passaram a somar dentro da mesma competencia, em vez de bloquear no primeiro registro
- lancamento `mensal` continua sendo o fechamento unico do periodo para aquele funcionario
- o calculo semanal passou a considerar as semanas realmente trabalhadas no mes
- o resumo da folha e a permissao de fechamento passaram a olhar o total acumulado da competencia por funcionario

Arquitetura principal:

- frontend em `Flutter`
- gerenciamento de estado com `Riverpod`
- navegacao com `GoRouter`
- autenticacao, banco, storage e hosting via `Firebase`
- backend sensivel em `Cloud Functions`
- protecao multi-tenant e por papel em `Firestore Rules`

Entradas principais:

- app: `lib/main.dart`
- rotas: `lib/core/router/app_router.dart`
- shell/navegacao: `lib/core/navigation/app_shell.dart`
- bootstrap de sessao: `lib/core/auth/session.dart`
- backend: `functions/src/index.ts`
- regras: `firestore.rules`

## Modelo operacional atual

Direcao do produto:

- `Web` concentra operacoes administrativas, comerciais, fiscais, financeiras e configuracoes
- `Android` concentra operacao leve, consulta, ponto, justificativas e acoes rapidas
- integracoes externas sensiveis nao ficam direto no Flutter; passam por backend

Perfis de acesso:

- `owner`
- `manager`
- `employee`
- `accountant`

Regras de acesso:

- `owner` tem acesso completo
- `manager` opera grande parte da empresa, respeitando regras de modulo e governanca
- `employee` usa apenas rotas e dados do proprio escopo
- `accountant` opera carteira vinculada, ambiente fiscal e rotinas proprias de escritorio
- na `web`, acesso de funcionario continua bloqueado e redirecionado para login empresarial

Escopo atual consolidado do `accountant`:

- `Home`
- `Assistente`
- `Ideias`
- `Faturamento`
- `Fiscal`
- `Contratos` em leitura
- `Documentos` em leitura
- `Empresas do contador`
- `Perfil fiscal do contador`
- `Cadastrar empresa`
- `Seja nosso parceiro`

Fora do escopo atual do contador:

- `Relatorios`
- `Trabalhista`
- `Observabilidade` direta

## Rotas e modulos ativos

Rotas publicas:

- `Inicio`
- `Login empresa`
- `Login funcionario`
- `Login contador`
- `Cadastro empresa`
- `Ativacao da empresa`
- `Vendas`
- `Contratar`
- `Boas-vindas da empresa`
- `Convite do contador`
- `Teste do funcionario`
- `Cadastro teste`

Rotas autenticadas:

- `Home`
- `Assistente`
- `Ideias`
- `Empresas do contador`
- `Perfil fiscal do contador`
- `Seja nosso parceiro`
- `Funcionarios`
- `Tarefas`
- `Ordens de servico`
- `Documentos`
- `Faturamento`
- `Clientes`
- `Catalogo de servicos`
- `Materiais`
- `Jornada Ponto Certo`
- `Trabalhista` tambem passou a concentrar o cadastro operacional do colaborador e os documentos opcionais do registro

## Frente Play Store em andamento

- Em `08/04/2026` entrou no ar uma frente auxiliar para destravar a publicacao Android na Play Store com testadores.
- Essa frente nao substitui a versao web principal nem redefine o produto final; ela serve para captar testadores do app de funcionario enquanto a liberacao da loja exige base de teste.
- O fluxo atual e:
  - pagina publica de cadastro de testador
  - recebimento interno em `Plataforma > Pipeline comercial > Leads de testadores`
  - copia de emails para lista manual de testadores da Play Store
  - inclusao manual do email na lista fechada da Play Store
  - marcacao interna `Marcar na Play Store`
  - liberacao interna `Enviar acesso do teste` com email de senha + link da loja
  - exibicao da tela `Conhecer o sistema real` dentro do app para transformar o tester em potencial cliente
  - liberacao manual posterior de `ambiente real`, refletida no app de teste e por email
- Regra tecnica desta frente:
  - o testador permanece tratado como `lead`, nao como funcionario da empresa real
  - o acesso dele fica isolado em base propria de teste e limitado ao escopo de funcionario
  - ele nao acessa dados, cadastros ou modulos da empresa suprema
  - o painel da plataforma agora permite abrir um resumo individual de uso por lead liberado
  - o email de liberacao usa o link oficial da Play Store `https://play.google.com/store/apps/details?id=br.com.alexandresousa.pontocerto`
  - quando a plataforma libera o ambiente real, o app de teste passa a mostrar um CTA interno para sair do teste e abrir o ambiente oficial
- Regra operacional registrada:
  - depois que a versao Android completa voltar para producao, os testadores dessa fase devem ser migrados para a versao real via novo email oficial
- Em `08/04/2026` o bundle Android desta fase foi inicialmente gerado em `1.0.69+1039`:
  - arquivo de trabalho: `build/app/outputs/bundle/release/app-release.aab`
  - copia inicial nomeada para upload: `C:\Users\hp\Desktop\pontocerto-v1.0.69+1039-teste-playstore-funcionario.aab`
- Em `08/04/2026` o hosting foi republicado novamente apos a reautenticacao do Firebase CLI, colocando no ar a correção global de selecao/copia de texto no web.
- Em `08/04/2026` o painel interno da plataforma passou a expor tambem o link publico de `cadastro-teste`, ao lado da landing de vendas.
- Em `08/04/2026` a landing comercial foi atualizada com nova copy orientada a dor, fiscal MEI e entrada por teste do app de funcionario antes da contratacao.
- Em `08/04/2026` a landing comercial tambem recebeu ajuste de layout para desktop e responsividade mais forte para telefone/tablet, com breakpoints explicitos na propria tela.
- Em `08/04/2026` o backend e o painel interno foram ajustados para refletir a semantica correta dessa frente:
  - o sistema nao tenta cadastrar automaticamente o lead em distribuicao externa
  - a liberacao interna envia o acesso somente depois da inclusao manual na Play Store
  - a plataforma consegue consultar UID, login e atividade de cada lead testador liberado
- Em `08/04/2026` a fila de leads passou a destacar melhor o operacional da Play Store:
  - `pendente: incluir email na lista fechada da Play Store`
  - `Play Store liberada e email enviado`
- Em `08/04/2026` a mesma frente ganhou o passo de migracao para o ambiente real:
  - backend novo para `marcar na Play Store` sem enviar acesso antes da hora
  - backend novo para `liberar ambiente real`, com reflexo no lead, no usuario isolado e no email
  - novo `AAB` gerado para essa fase em `C:\Users\hp\Desktop\pontocerto-v1.0.69+1039-teste-playstore-fluxo-real.aab`
- Em `08/04/2026` o painel da plataforma tambem recebeu leitura visual por etapa para os leads testadores, usando cores diferentes para pendente, pronto para envio do teste, teste liberado e ambiente real liberado.
- Em `08/04/2026` a versao Android valida desta rodada foi ajustada para `1.0.70+1040`:
  - bundle atual valido: `C:\Users\hp\Desktop\pontocerto-v1.0.70+1040-teste-playstore-fluxo-real.aab`
  - nota curta atual: `C:\Users\hp\Desktop\nota-curta-play-store-v1.0.70+1040.txt`
- `Propostas`
- `Contratos`
- `Clausulas`
- `Dividas`
- `Pagamentos`
- `Financeiro`
- `Relatorios`
- `Ponto`
- `Justificativas`
- `Configuracoes`
- `Plataforma`
- `Observabilidade`
- `Auditoria`
- `Empresa`
- `Trabalhista`
- `Fiscal`

## O que o sistema ja entrega

### Shell e experiencia web

- shell lateral com navegacao principal
- submenu do `Assistente` com `Historico de conversa`
- painel inicial em formato executivo por perfil
- padrao visual SaaS espalhado para modulos principais
- foco maior em desktop para operacoes pesadas
- fluxos publicos de vendas/onboarding no proprio app web
- landing de vendas ajustada para leitura mais limpa no desktop, com menos branco puro e blocos centrais mais equilibrados

### Financeiro e cobranca

- separacao entre visao da empresa e visao do funcionario
- contas a pagar e a receber
- pagamentos
- classificacao manual do pagamento por diaria, semanal, mensal ou comissao
- dividas e adiantamentos
- movimentos financeiros
- faturamento recorrente
- limpeza controlada
- permissoes operacionais por gerente
- parte critica de escrita via `Cloud Functions`

### Trabalhista e RH

- cadastro de funcionarios com remuneracao e admissao
- folha por competencia
- bloqueio de alteracao em competencia fechada
- holerite, recibos e comprovantes simples
- apoio para `13 salario`, `ferias` e `rescisao`
- fechamento e reabertura com trilha de controle
- contratos com funcionarios e historico relacionado

### Fiscal

- modulo fiscal proprio na web
- formulario de `NFS-e` estruturado
- busca de `CNPJ` e `CEP` via backend
- cadastro reutilizavel de tomadores/clientes
- servicos fiscais configuraveis
- resumo e checklist fiscal por competencia
- homologacao assistida por empresa
- bloqueios de readiness para emissao oficial em producao
- reconsulta e conciliacao de `NFS-e` em processamento
- ligacao operacional com `Tarefas` e `Financeiro`
- rotina fiscal diaria com atalhos oficiais
- base operacional para integracao real com provedor fiscal

### Assistente e observabilidade

- `Assistente Inteligente` via endpoint HTTP
- persistencia de conversa em `assistant_threads/{threadId}/messages/{messageId}`
- historico por login na tela do assistente
- fallback pelo historico quando a resposta principal falha
- observabilidade via `runtime_incidents`
- trilha operacional em `audit_logs`
- em `21/04/2026`, a memoria operacional do assistente foi realinhada ao estado real do sistema
- `Ideias` continua disponivel para contador com leitura operacional; `Observabilidade` direta permanece restrita ao contexto supremo

### Comercial, onboarding e plataforma

- landing `/vendas`
- pre-cadastro comercial em `/contratar`
- convite publico para contador em `/convite-contador`
- onboarding publico em `/boas-vindas-empresa`
- pipeline de implantacao no painel `Plataforma`
- suporte a cobranca recorrente e implantacao assistida

### Ambiente do contador

- carteira em `Empresas do contador`
- `Perfil fiscal do contador` centralizado
- `Cadastrar empresa` como entrada operacional do escritorio
- pagina comercial `Seja nosso parceiro`
- blocos de faturamento, fiscal, assistente, ideias e rotina tributaria no `Home` do contador
- `Contratos` e `Documentos` em leitura coerente com o estado atual das telas
- a carteira atual ja mostra leitura fiscal por empresa e permite trocar empresa sem abrir outro modulo
- a proxima evolucao leve recomendada e adicionar `OK/PENDENTE/ATRASADO`, alertas simples e metricas de pendencia na propria tela `Empresas do contador`

### Ambiente da empresa

- a rota `Empresa` hoje funciona mais como tela de cadastro, configuracao e governanca do que como dashboard executivo
- ela ja concentra:
  - perfil operacional
  - checklist de implantacao
  - DAS do MEI
  - status comercial
  - governanca do contador
- a proxima evolucao leve recomendada e:
  - mensagem curta de situacao
  - historico curto de notas
  - botao principal `Emitir nota`
  - sem mover a experiencia fiscal densa para fora de `/fiscal`

### Operacao compartilhada

- `Clientes` funciona como base compartilhada de tomadores/clientes
- `Tarefas` reaproveita cliente compartilhado
- `Catalogo` alimenta tarefas, propostas e contratos
- `Fiscal` reaproveita `customerId` e pode vincular `tarefa de origem`
- `Financeiro` rastreia receita nascida da nota fiscal
- `Auditoria` registra acoes relevantes

### Relatorios e governanca

- `Reports` ja tem leitura executiva por colaborador com panorama, sinais, quadro operacional, comparativo de competencia e quadros fiscal/financeiro
- continuidade centralizada em `docs/registro_continuidade`
- validacao leve local disponivel quando o ambiente trava
- manual interno de operacao e checklist de release ja existem

## Backend e integracoes

Callables/funcoes relevantes ja implementadas:

- autenticacao e claims:
  - `authSyncClaims`
  - `authSetClaimsForUser`
  - `createEmployeeAccess`
- financeiro:
  - `paymentsCreate`
  - `paymentsMarkPaid`
  - `paymentsConfirm`
  - `paymentsContest`
  - `paymentsCancel`
  - `debtsCreate`
  - `debtsSettle`
  - `debtsCancel`
- fiscal:
  - `fiscalSyncFocusCompany`
  - `fiscalIssueServiceInvoice`
  - `fiscalCancelServiceInvoice`
  - `fiscalRefreshServiceInvoiceStatus`
  - `fiscalReconcileProcessingInvoices`
  - `lookupBrazilCnpj`
  - `lookupBrazilCep`
- plataforma/comercial/assistente:
  - endpoint HTTP do assistente com persistencia de threads
  - `accountantGetPartnerContact`
  - resumos operacionais/materializados usados por telas mais leves

Infra atual:

- `Firebase Hosting` servindo `build/web`
- rewrite SPA configurado em `firebase.json`
- cache control definido para service worker e assets
- projeto ativo local configurado para `pontocerto-e1dab`
- domínio público operacional validado: `https://gestao-ponto-certo.com`
- URL padrão do Hosting também válida: `https://pontocerto-e1dab.web.app`

## Seguranca e governanca

- separacao por `companyId`
- RBAC por `role`
- fallback de claims para `users/{uid}` durante bootstrap
- protecao de configuracoes sensiveis em `company_settings`
- controle de leitura/escrita por tenant nas regras
- auditoria operacional em colecao propria
- parte critica da operacao saindo do cliente e indo para backend

## Maturidade atual

Pontos mais fortes:

- base multiempresa
- estrutura web administrativa robusta
- frente comercial web integrada ao proprio produto
- ambiente do contador separado do fluxo da empresa
- modulo financeiro com backend
- base fiscal em evolucao consistente e ja conectada ao financeiro
- assistente com historico persistido por conversa
- relatorios executivos e reaproveitamento de dados entre modulos
- regras de seguranca relativamente maduras

Pontos que ainda pedem consolidacao:

- varios arquivos grandes e densos em telas centrais
- manutencao dos documentos de continuidade precisa acompanhar mais de perto as entregas
- padronizacao visual ainda incompleta em alguns modulos
- alguns fluxos novos ainda dependem de consolidacao operacional fina
- emissao fiscal oficial ainda precisa de validacao ponta a ponta em ambiente real
- validacao automatica local continua instavel por timeout em comandos pesados
- embora o CLI tenha voltado a operar e o deploy de `functions + hosting` tenha sido confirmado em `08/04/2026`, o ambiente ainda merece monitoramento por histórico recente de timeout e falhas transitórias
- publicacao Android da versao atual nao esta comprovada localmente

## Riscos atuais

- alta concentracao de logica em paginas longas como `Fiscal`, `Tasks` e `Workforce`
- risco de manutencao mais lenta conforme novas frentes entrem sem refino estrutural
- residuos antigos de backup/log podem expor contexto ou causar confusao operacional
- parte do conhecimento do sistema ainda depende de registros manuais em continuidade
- diferenca entre `build local concluido` e `deploy/publicacao confirmados` pode gerar falsa percepcao de entrega em producao
- arquivos grandes continuam capazes de derrubar a compilacao web por erro sintatico localizado, como ocorreu em `fiscal_readiness_page.dart` nesta rodada

## Prioridades recomendadas

### Curto prazo

- validar em ambiente real o historico do assistente apos a correcao da query por login
- decidir/publicar a versao Android `1.0.70+1040`
- consolidar a padronizacao visual do shell web
- manter o fluxo `Clientes -> Tarefas -> Fiscal` consistente

### Medio prazo

- reduzir acoplamento das telas mais longas
- aprofundar validacoes tecnicas do emissor fiscal
- consolidar padrao interno de modulos para empresa, contador e gerencia

### Estrategico

- levar `NFS-e` de camada preparatoria para operacional real
- fortalecer integracoes contabil/fiscais
- reduzir dependencia de memoria manual para continuidade do projeto

## Observacao

Estado de deploy/publicacao confirmado nesta consolidacao:

- `functions + hosting` publicados com sucesso em `08/04/2026`
- domínio principal validado: `https://gestao-ponto-certo.com`
- URL padrão do Hosting validada: `https://pontocerto-e1dab.web.app`
- atalhos fiscais da Home atualizados e publicados em `08/04/2026`:
  - `DASN-SIMEI`
  - `DEFIS`
  - `IRPF`
- release Android da versao `1.0.70+1040` segue pendente de confirmacao/publicacao

Este documento deve ser atualizado quando houver mudancas relevantes na arquitetura, nos modulos, no estado de deploy/publicacao ou no nivel de maturidade do sistema.
