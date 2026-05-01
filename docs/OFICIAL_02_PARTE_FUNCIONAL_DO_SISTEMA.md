# Parte Funcional Oficial do Sistema

Data base: 23/04/2026
Projeto: Ponto Certo

## Objetivo

Este documento define o que o sistema faz de verdade hoje.
Ele e a referencia oficial para produto, suporte, vendas, assistente e continuidade.

## Estrutura funcional do sistema

O Ponto Certo e um sistema multiempresa com operacao principal web e app operacional para funcionario.

Versao local atual de referencia:

- `1.0.78+1048`

Na frente comercial publica atual, o contato principal priorizado e o **escritorio contabil**.

O fluxo publico inicial agora aponta para **Cadastrar escritorio de contabilidade**.
A empresa continua usando o mesmo cadastro operacional ja existente, mas esse passo passa a acontecer depois, a partir do ambiente do escritorio.

## Modulos principais da empresa

- Painel
- Assistente
- Ideias
- Financeiro
- Fiscal
- Faturamento
- Clientes
- Tarefas
- Ordens de servico
- Funcionarios
- Ponto
- Justificativas
- Trabalhista
- Propostas
- Contratos
- Documentos
- Banco de servicos
- Banco de materiais

## Modulos supremos da plataforma

- Plataforma
- Observabilidade
- Governanca comercial global
- Administracao global de empresas

### Governanca comercial e financeira global

O painel supremo deve manter rastreio operacional para impedir cadastro ou cobranca perdida:

- pre-cadastros e onboardings comerciais
- webhooks Asaas `unmatched`, agora tratados como cadastro financeiro sem vinculo, podendo envolver empresa ou escritorio
- cobranca pendente/falha/vencida de escritorio contabil
- empresas que aguardam o contador vincular pelo fluxo dele
- falha automatica na cobranca de implantacao
- ciclo visivel do cadastro: lead -> cobranca/pagamento -> onboarding -> empresa criada -> contador/escritorio informado -> cobranca recorrente

Regra funcional: a plataforma nao deve tratar o contador como se fosse owner alternativo. O contador vincula empresas ao proprio escritorio pelo fluxo dele.

## Perfis oficiais

### Owner

- acesso total aos modulos da propria empresa

### Manager

- operacao ampliada da propria empresa
- sem acesso supremo

### Accountant

Escopo real atual:

- carteira vinculada
- perfil fiscal
- cadastrar empresa
- home do contador
- assistente
- ideias
- faturamento
- fiscal
- contratos em leitura
- documentos em leitura

Fora do escopo atual:

- relatorios
- trabalhista
- observabilidade direta
- plataforma suprema

### Employee

- app operacional
- ponto
- justificativas
- rotina leve definida pela empresa

## Login oficial

O login deve ser unico em comportamento e especifico por perfil:

- empresa entra por `/login-empresa`
- contador entra por `/login-contador`
- funcionario entra por `/login-funcionario` quando o ambiente permitir esse acesso

Ao autenticar com sucesso, o sistema deve atualizar sessao e roteador imediatamente. O usuario nao deve precisar atualizar a pagina para o sistema reconhecer a sessao.

## Funcionalidade fiscal oficial

### Emissao de nota

O sistema possui operacao real de nota fiscal de servico com integracao oficial.

Capacidades:

- rascunho
- emissao
- cancelamento
- consulta de status
- conciliacao de processamento
- limpeza em lote de notas canceladas, rascunhos e notas com erro de emissao, desde que nao tenham financeiro vinculado e nao possuam emissao oficial ativa

### NFSe Nacional / Focus

Estado funcional atual:

- emissao real operacional
- notas autorizadas pela Focus/Sefin devem ser registradas no sistema com status final `APPROVED`
- `EMITTED` fica apenas como compatibilidade de leitura para registros antigos; novas autorizações oficiais devem entrar como `APPROVED`
- o resumo fiscal materializado deve usar `approvedInvoicesCount` para notas autorizadas e `emittedGrossAmountCents` para o valor bruto dessas notas autorizadas/registradas
- o numero oficial da NFS-e deve ser buscado em `officialNumber` e tambem nos campos da resposta Focus (`officialResponse`), incluindo formatos como `numero_nfse`, `numeroNfse`, `numero_nfs_e`, `numeroDps`, `numero_nota_fiscal` e objetos aninhados (`nfse`, `notaFiscal`, `dados_nfse`, `dps`, etc.)
- notas autorizadas sem numero oficial devem ser tratadas como pendencia de consulta/registro, nao como nota plenamente registrada
- caso `Simples Nacional + ISS retido` validado
- caso `Simples Nacional + ISS sem retencao` ajustado para nao enviar aliquota indevida no payload real
- `pAliq` passou a ser enviado corretamente
- `cTribMun` automatico indevido foi removido do fluxo nacional
- a aliquota pode permanecer preenchida na tela para apoio operacional, mas o envio real respeita a retencao aplicavel

### Servicos fiscais

Estado funcional atual:

- o cadastro de `Servicos fiscais` e a fonte oficial para o seletor usado ao emitir nota
- o seletor da nota deve listar apenas servicos fiscais **salvos e ativos** no catalogo da empresa
- modelos fixos/automaticos podem apoiar sugestao/geracao interna, mas nao devem aparecer misturados ao dropdown de servicos salvos
- editar um servico fiscal deve salvar no mesmo documento, fechar o dialogo e exibir aviso operacional de sucesso ou erro
- mensagens de aviso do sistema devem aparecer no topo, por cima da tela/dialogos, e sumir apenas quando o usuario clicar em `OK`

Se voltar erro:

- `E0621`: conferir `pAliq`
- `E0314`: conferir `cTribMun`

## Funcionalidade financeira oficial

- entradas e saidas
- cobrancas
- pagamentos
- dividas
- rastreio de origem fiscal
- no resumo fiscal da competencia, valor bruto e tomadores devem refletir apenas notas oficialmente emitidas e nao canceladas
- notas canceladas, rejeitadas, em rascunho ou em processamento nao podem entrar na soma de valor bruto emitido

## Estrategia comercial publica atual

- a landing e o pre-cadastro publicos estao voltados para escritorio contabil
- no convite trial da plataforma, o unico email obrigatorio e o do escritorio
- empresa e email da empresa podem entrar depois, no cadastro real
- o onboarding principal segue para o escritorio quando o fluxo nasce nesse modelo
- os emails enviados para escritorio contabil e contador parceiro devem apresentar o sistema como iniciativa real de `Bonfim Alexandre Sousa Santos`, desenvolvedor do sistema e empresario dos ramos de obras, construcao civil e servicos eletricos
- essa comunicacao deve explicar que o produto nasceu da dificuldade de emissao de notas, da desorganizacao operacional e do caos recorrente na gestao da propria empresa
- o **WhatsApp comercial** (`wa.me`) nas landings empresa/contador deve abrir sempre que o visitante tocar nos botoes previstos; no **Web**, usar o widget oficial **`Link`** do `url_launcher` (**`followLink`**) ligado aos CTAs secundários e ao rodape; Meta Pixel (`Contact`) e `sales_whatsapp_comercial` disparam **após** o `followLink`, agendados, para nao impedir o navegador de seguir para o `wa.me`

## Funcionalidade de equipe oficial

- funcionarios e acessos
- ponto
- justificativas
- pagamentos
- rotina trabalhista por competencia

Regra atual:

- `Funcionarios` foca em leitura e organizacao
- cadastro operacional e documentos do colaborador ficam concentrados em `Trabalhista`

## Funcionalidade oficial de documentos

- o modulo `Documentos` deixou de ser biblioteca de rascunhos
- agora ele funciona como canal operacional de solicitacoes entre contador, empresa e funcionarios
- cada pedido fica separado por solicitacao, com itens pedidos e arquivos anexados dentro do proprio pedido
- o contador pode abrir pedidos para:
  - empresa
  - um ou mais funcionarios especificos da empresa
- o contador tambem pode anexar documentos no proprio pedido para assinatura, preenchimento ou devolucao posterior
- o botao `Enviar documento` do contador e independente do botao `Solicitar documento`: ele pode criar um envio avulso para a empresa ou para funcionarios especificos, sem depender de solicitacao anterior
- `Solicitar documento` e `Enviar documento` sempre usam a empresa ativa da carteira do contador; para operar outra empresa, o contador deve trocar a empresa antes
- funcionarios listados no dialogo pertencem somente a empresa ativa, evitando mistura de documentos e colaboradores entre empresas
- quando o pedido nasce para a empresa, owner/manager podem encaminhar a solicitacao para funcionarios
- funcionarios veem no app apenas os pedidos encaminhados para eles e podem abrir e enviar PDF, JPG, JPEG e PNG
- o contador precisa conseguir abrir cada arquivo anexado dentro da solicitacao correta

## Regra comercial oficial atual

- entrada publica principal:
  - empresa solicita entrada no sistema
  - a empresa precisa indicar nome e email do contador
  - o contador recebe os dados da empresa e primeiro cadastra o escritorio de contabilidade
  - depois do escritorio cadastrado, o contador cadastra a empresa que o indicou
  - o sistema inteiro entra em teste real gratis por 30 dias
  - nao existe cobranca de implantacao nessa entrada
- empresa: R$ 97,90 por mes
- acesso adicional do app Play Store para funcionario: R$ 19,90 por mes por acesso adicional
- escritorio contabil: R$ 97,90 por mes
- parceria contabil aprovada pode isentar a cobranca do escritorio

## Funcionalidade do contador

O contador nao e um owner alternativo.
Ele opera uma trilha propria.

Trilha oficial atual:

- carteira de empresas vinculadas
- perfil fiscal centralizado
- cadastro de empresa
- faturamento
- fiscal
- ideias
- leitura operacional de contratos/documentos

## Funcionalidade do assistente

O assistente deve responder segundo o escopo real atual.

Regra:

- nao orientar contador como se tivesse `Relatorios`, `Trabalhista` ou `Observabilidade` direta, salvo confirmacao futura
- usar a memoria operacional oficial do projeto

### O que o assistente “ve” em tempo real (tecnico)

- **Nao** ha hoje leitura automatica dos ficheiros `OFICIAL_01`–`04` (Markdown) pela Cloud Function. O backend monta a mensagem de sistema a partir de **instrucoes fixas** em `functions/src/index.ts` (`buildAssistantInstructions`, `buildAssistantFeatureInventory`, guias de rota/modulo) e de **dados reais** no Firestore na chamada: perfil, `company_settings`, resumos de `system_issues` e `runtime_incidents` da empresa, rota/titulo de tela enviados pelo cliente.
- A API **OpenAI** recebe esse texto de sistema + a pergunta do utilizador. Para o assistente “seguir” fielmente os `OFICIAL_*.md`, e preciso manter **este** documento e, quando a verdade de produto mudar, alinhar o codigo (strings no `index.ts`) ou o processo de publicacao; os MD sao a **fonte de verdade documental** para humanos e para copy do `PROMPT_ASSISTENTE_PONTO_CERTO.md`, nao ficheiros embebidos em cada request.

## Navegacao do painel (estado actual)

- **GoRouter** com `ShellRoute`: rotas do painel autenticado partilham **um** `AppRouteShell` com `AppShellScaffold` — menu e scroll do lado estabilizam em relacao a um shell recriado a cada `go` antes desta arquitectura.
- **Avisos globais** (utilizador): nao dependem de `Scaffold` por ecra; o estado e global e a UI desenha-se no `Overlay` do `Navigator` raiz (`appRootNavigatorKey`).

## Regras de coerencia obrigatorias

Toda nova funcionalidade deve manter alinhamento entre:

- rota
- tela
- CTA
- vitrine comercial
- regras de dados
- memoria do assistente

## Regra obrigatoria antes de implementar

Antes de qualquer implementacao nova:

1. descrever a expectativa visual no `OFICIAL_01`
2. descrever a regra funcional aqui no `OFICIAL_02`
3. confirmar a sustentacao tecnica no `OFICIAL_03`
4. implementar no codigo apenas depois dessa descricao oficial
5. salvar a memoria da rodada no `OFICIAL_04` e na `CONTINUIDADE_ATUAL`

## Funcionalidades em planeamento seguro (nao implementadas)

O **que** se pretende fazer em seguranca — certificadora (fluxo contador → estado → encaixe em `company_settings` / fiscal existente) e preparacao **IBS/CBS** sem quebrar emissao — esta **apenas descrito** em [PLANEJAMENTO_SEGURO_CERTIFICADORA_E_REFORMA_FISCAL_IBS_CBS.md](PLANEJAMENTO_SEGURO_CERTIFICADORA_E_REFORMA_FISCAL_IBS_CBS.md). **Nada disto foi ligado a producao** na rodada que registou o plano; implementar so apos `OFICIAL_01`–`03` e aprovacao.

## Documentos relacionados

- [OFICIAL_01_PARTE_VISUAL_DO_SISTEMA.md](/C:/Users/hp/pontocerto/docs/OFICIAL_01_PARTE_VISUAL_DO_SISTEMA.md)
- [OFICIAL_03_ARQUITETURA_TECNICA_COMPLETA_DO_SISTEMA.md](/C:/Users/hp/pontocerto/docs/OFICIAL_03_ARQUITETURA_TECNICA_COMPLETA_DO_SISTEMA.md)
- [OFICIAL_04_MEMORIA_E_REGISTRO_ATUAL_DO_SISTEMA.md](/C:/Users/hp/pontocerto/docs/OFICIAL_04_MEMORIA_E_REGISTRO_ATUAL_DO_SISTEMA.md)
