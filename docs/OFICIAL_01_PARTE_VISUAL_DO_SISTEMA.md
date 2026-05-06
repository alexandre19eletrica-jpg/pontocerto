# Parte Visual Oficial do Sistema

Data base: 23/04/2026
Projeto: Ponto Certo

## Objetivo

Este documento define a referencia visual oficial do sistema.
Ele existe para evitar divergencia entre:

- telas reais
- vitrines comerciais
- demos internas
- novas implementacoes de UI

## Principio visual central

O sistema deve parecer:

- operacional
- profissional
- direto
- claro
- orientado a decisao

Nao deve parecer:

- conceitual demais
- ornamental
- confuso
- publicitario dentro da area operacional

## Estrutura visual oficial

### 1. Hierarquia

Toda tela deve seguir esta ordem:

1. titulo claro da area
2. subtitulo curto com contexto operacional
3. resumo ou cards de estado
4. acoes primarias
5. lista, tabela, timeline, formulario ou fluxo principal

### 2. Cards

Cards sao a unidade visual principal da operacao.

No modulo `Documentos`, a leitura oficial deve ser em lista de solicitacoes separadas, com expansao por pedido.
Evitar painel duplo, mistura de anexos entre pedidos e redundancia de cards no mesmo fluxo.

Regra:

- cada card deve representar uma responsabilidade clara
- cabecalho empilhado, sem disputar lateral com conteudo
- evitar cards gigantes que virem paginas dentro da pagina
- preferir grade horizontal responsiva antes de blocos verticais longos

### 3. Grid e responsividade

O sistema e web-first, mas deve manter leitura limpa no app.

Regra:

- desktop: leitura horizontal priorizada
- tablet: reorganizacao por blocos, sem colapso brusco
- mobile/app: empilhamento limpo, sem esconder contexto

### 4. Linguagem visual dos modulos

- `Financeiro`: leitura executiva, caixa, cobranca, clareza de saldo
- `Fiscal`: seguranca operacional, status, emissao, prontidao
- `Funcionarios`: consulta e organizacao de equipe
- `Trabalhista`: competencia, documentos, pagamentos e regularizacao
- `Tarefas` e `Ordens de servico`: execucao, andamento, evidencias
- `Contador`: carteira, perfil fiscal, faturamento e fiscal
- `Plataforma`: gestao suprema, governanca e observabilidade

No modulo `Fiscal`, a faixa principal de acoes da NFS-e deve concentrar:

- criacao de nova nota
- exportacao do resumo fiscal em PDF
- conciliacao de notas em processamento
- limpeza em lote de notas invalidas da competencia atual

A limpeza em lote deve aparecer como acao secundaria, com rotulo objetivo e contagem de itens elegiveis.

Nos emails voltados para escritorio contabil e contador parceiro, a comunicacao institucional deve:

- manter tom direto e profissional
- deixar claro que a mensagem vem do fundador e desenvolvedor do sistema
- reforcar origem real do produto em dor operacional de emissao fiscal, organizacao empresarial e rotina de servicos/obras
- evitar copy generica de software sem contexto humano real

## Estilo oficial

### Tipografia

- titulo forte e curto
- subtitulo funcional
- texto de apoio sem juridiquês visual
- evitar excesso de texto em caixa alta

### Cor

- cor deve indicar estado, nao decorar tela
- verde: sucesso, pronto, autorizado
- amarelo/laranja: atencao, pendencia, processamento
- vermelho: bloqueio, erro, risco
- azul: navegacao, contexto e leitura institucional

### Iconografia

- icones devem reforcar modulo ou acao real
- nao usar icone so para enfeite
- o mesmo conceito deve manter o mesmo icone nas areas equivalentes

## Regra para vitrines e paginas de venda

A pagina de vendas e obrigada a refletir o sistema real.

Ela tambem deve ser responsiva e adaptativa por ambiente:

- no computador/navegador largo, priorizar leitura horizontal, blocos lado a lado, cards de prova e chamadas de acao visiveis sem excesso de rolagem
- no celular/navegador estreito, empilhar secoes, aumentar area de toque, reduzir colunas, preservar a ordem da narrativa e evitar textos espremidos
- a mesma rota `/vendas` deve se ajustar automaticamente pela largura disponivel e pela plataforma de navegacao, sem exigir pagina separada para mobile
- imagens comerciais devem ter corte seguro, legenda/contexto quando necessario e nao podem quebrar a leitura em telas pequenas
- CTAs principais devem continuar acessiveis no mobile e no desktop
- copy e imagens da landing devem vender apenas o que o sistema real entrega hoje, sem prometer modulo, permissao ou integracao inexistente
- nas landings publicas de vendas dirigidas a **empresa** e a **contador** (rotas dedicadas no marketing), os CTAs para **WhatsApp comercial** devem abrir a conversa de forma fiavel no **navegador** — o clique nao pode “morrer silenciosamente” por bloqueio de janela; uso de **`AnchorElement` + `click()`** sintetico ligado ao `wa.me` **na mesma aba** (`target: _self`), com eventos Pixel/callables **depois** de um pequeno atraso quando necessario (`vendas_whatsapp_button.dart`)

Ela nao pode:

- prometer menus que o perfil nao acessa
- mostrar escopo ficticio para contador
- sugerir observabilidade direta para perfis sem acesso
- vender relatorios a perfis que hoje nao os usam

Ela pode:

- simplificar a explicacao
- mostrar beneficio
- resumir a jornada

Mas sempre mantendo coerencia com:

- rotas reais
- permissoes reais
- regras de dados reais

## Ambientes visuais por perfil

### Owner

- visao completa da empresa
- acesso executivo e operacional

### Manager

- visao ampliada da operacao
- sem blocos supremos sensiveis

### Accountant

Escopo visual real atual:

- home do contador
- empresas do contador
- documentos em formato de lista suspensa por pedido para contador, empresa e funcionario no app
- perfil fiscal
- cadastrar empresa
- faturamento
- fiscal
- ideias
- contratos e documentos em leitura

Nao incluir no visual do contador hoje:

- relatorios
- trabalhista
- observabilidade direta
- plataforma suprema

### Employee

- app com foco em ponto, justificativas e rotina leve
- sem visual web administrativo

## Componentes compartilhados

As decisoes visuais devem respeitar os componentes-base do projeto:

- `AppWorkspaceCard`
- `HeroBanner`
- `AppHorizontalCardGrid`
- **shell lateral unico (persistente no painel)**: o menu nao e recriado a cada troca de rota; o conteudo muda, o lateral mantem a mesma instancia
- `AppUserMessage` / avisos: mensagens operacionais (OK) aparecem num **Overlay** no **Navigator** raiz, por cima do conteudo (incluindo `SelectionArea` no web) — o browser pode precisar de hard refresh (Ctrl+F5) apos deploy
- banners e cards de resumo

## Login visual oficial

As telas de entrada devem ser limpas, rapidas e sem estado intermediario confuso:

- `login-empresa`: acesso de owner/manager da empresa
- `login-contador`: acesso do escritorio/contador, indo para a carteira do contador
- `login-funcionario`: acesso operacional do funcionario quando permitido pela plataforma

Depois de autenticar, a tela nao deve aparentar erro nem exigir atualizar o navegador. A sessao e o roteador devem sincronizar antes da navegacao final.

## Plataforma e governanca visual

No painel supremo, alertas de governanca devem aparecer como blocos claros de atencao/erro, sem esconder o pipeline:

- webhook Asaas sem cadastro financeiro vinculado
- cobranca pendente do escritorio contabil
- empresa aguardando vinculo feito pelo contador
- falha automatica na cobranca de implantacao

Esses alertas servem para impedir cadastro perdido no sistema e devem ficar visiveis no `Pipeline comercial`.

## Atualizacao visual (03/05/2026)

- Plataforma `/platform-admin/governanca`: **menu em cartões** no topo (hub) com sub-paineis por URL `?v=` (**Funil**, pré-cadastro **empresas** / **escritórios**, **cadastro completo**, **demos**, **links** de campanha); cada fila mantém o comportamento anterior: passo A empresa leve lista bloqueios **explicitos** (**icone apagar cinzento** quando `standaloneDeletionAllowed` falso); passo C mostra dados comerciais + botões **Financeiro cliente**, suspender/restaurar (**Retomar** quando freeze), **Cancelar boletos** e **desactivar cobranca** Asaas quando aplicável; livro demos só contagens; painel **Funil** destaca **page views** e **leads** (incl. pré-cadastro empresa leve); **Links** lista URLs canónicas com cópia.
- Fluxo `/demo-*` quando falha IAM: sem spinner perpetuo — icone estilo offline, texto de erro legivel do servidor, texto curto sobre Token Creator sobre firebase-adminsdk, botoes **Documentacao Firebase** e **Contas Google Cloud** (projeto atual), mais **Voltar**.
- Sucesso `/demo-*` e botoes demo em `/vendas`: apos spinner **Preparando acesso demo...**, entra direto no painel (`/home` empresa, `/accountant-companies` contador) sem passar pela tela de login, desde que sessao Firebase + Riverpod hidratem primeiro.
- Perf web (voltas e interior): iniciar **`initFirebase`** e cache empresa em paralelo, Firestore persistente onde o SDK permite, **`preconnect`/`dns-prefetch`**, Meta Pixel depos do **`window.load`**; transicoes de rota mais leves no browser (**fade padrao** em vez do slide combinado).
- Pagina de vendas `/vendas`: blocos de texto e citacoes com linguagem mais institucional (menos enfase em culpa ou obrigacao sobre qualquer perfil).
- Pre-cadastro comercial (`SalesPreRegistrationPage`): titulos e textos de apoio alinhados ao follow-up comercial/operacional sem checklist longo de condutas do contador.
- Cadastro leve da empresa (`/pre-cadastro-empresa`; alias `/cadastro-empresa`): campos obrigatorios **UF**, **cidade** e **CEP** no formulario leve além dos dados base; botao final descreve solicitacao por e-mail; sem campo de senha no formulario leve e no cadastro publico completo; texto curto persuasivo (nao instructional longo).
- Cadastro leve do escritorio (`/pre-cadastro-escritorio`; alias `/cadastro-escritorio-contabil`): no modo leve, linha UF/cidade/CEP obrigatoria antes de enviar; texto de apoio curto menciona senha por link.
- `/vendas` (landing geral): botoes explicitos lado a lado — teste empresa (`/pre-cadastro-empresa`) e **Cadastrar escritorio de contabilidade** (`/pre-cadastro-escritorio`); as seccoes "Teste sem risco" e fecho repetem o mesmo par.
- `/inicio`: "Criar acesso da empresa" mantem destaque texto; navegacao primeiro, depois pixel de trial empresa.
- `/login-empresa`: link texto "Criar acesso da empresa" para o pre-cadastro.
- `/vendas-empresa`: removido o atalho "Sou contador — cadastro do escritorio"; contadores prosseguem pela rota comercial `/vendas-contador` ou `/cadastro-escritorio-contabil`. A mensagem de que MEI ou quem opera sem contador nao esta obrigado a contratar escritorio pelo produto ficou apenas no texto do cartao sob **Demonstracao gratuita do sistema** (orientacao ao demo/WhatsApp); o restante da landing (heroi sem badge MEI especifico, modelo atual, passo 3, bloco **COMECE O PRE-CADASTRO**, bullets da oferta) usa linguagem neutra sobre integrar contador depois quando fizer sentido, sem repetir o mesmo argumento.
- `/vendas-empresa` e `/vendas-contador`: marcadores (**badges**) e subhead alinhados a mesma linha institucional (demonstracao gratuita antes de primeira adesao; ate trinta dias de uso avaliativo inicial apos adesao formal); sob **Demonstracao gratuita do sistema**, a versao empresa e onde o texto explica opcional escritorio/WhatsApp como canal comercial paralelo aos botoes.
- `/cadastro-empresa` (leve) e pre-cadastro comercial (`SalesPreRegistrationPage`): texto de confirmacao quando o envio por e-mail nao foi concluido.
- `/fiscal`: cartao **Documentos fiscais via Focus** (sinc NF-e / NFS-e nacional recebidas, chips de status sync, lista com download XML) igual ao utilizado na pagina **Declaracoes** do contador; em demo aparece apenas aviso sem botoes de sync.
- Pre-cadastro leve empresa e escritorio (`/pre-cadastro-empresa`, `/pre-cadastro-escritorio`): layout alinhado heroi + logo + cartao de vidro nos dois; linha localizacao com **Estado (UF)** em largura proporcional (flex) e fundo branco nos campos para leitura uniforme; escritorio com mesma linguagem de CTAs; botao Voltar do escritorio leve retorna ao login do contador via `BotaoVoltarApp`.

## Atualizacao visual (06/05/2026)

- **Web/desktop + FAB WhatsApp:** o `builder` do `MaterialApp` usa `Stack` com **`StackFit.expand`** para o conteudo das rotas ocupar toda a viewport (evita erro de layout/branco em browser quando o filho nao recebia restricoes maximas).
- **Pre-cadastro leve empresa e escritorio** (`/pre-cadastro-empresa`, modo leve em `cadastro_empresa_page`; `/pre-cadastro-escritorio` / `AccountingOfficeSignupPage`): **UF, Cidade e CEP** passam a usar **rotulo fixo acima** do campo (`ExternalLabeledField`) e **hints** dentro da caixa (sem label flutuante competindo com o texto); em largura \< **560px** os tres campos **empilham** em coluna para leitura confortavel no telemovel.

## Atualizacao visual (05/05/2026)

- **WhatsApp global (suporte/dúvidas):** botao circular verde da marca (**56dp**), fixo ao canto **inferior-direito** com `SafeArea`, sobre **qualquer rota** (empresa, contador, vendas, pre-cadastro, logins): icone **`FontAwesome` WhatsApp** branco, elevacao discreta e **tooltip** "Suporte e informações no WhatsApp".

## Regra de manutencao

Toda mudanca visual relevante deve responder:

1. isso melhora a leitura operacional?
2. isso continua coerente com o perfil que usa a tela?
3. isso nao promete mais do que a tela realmente entrega?
4. isso continua coerente com a pagina de vendas?

## Regra obrigatoria antes de implementar

Antes de qualquer implementacao que altere fluxo, tela, promessa comercial ou navegacao:

1. descrever primeiro a parte visual esperada neste documento
2. validar a coerencia funcional no `OFICIAL_02`
3. validar a coerencia arquitetural no `OFICIAL_03`
4. so depois executar a implementacao no codigo
5. ao final, registrar a rodada na memoria oficial e na continuidade

## Evolucao visual futura (so planeada)

Qualquer UI nova para **certificadora** (contador) ou para **pre-visualizacao fiscal futura** (IBS/CBS) so entra neste documento **depois** da descricao funcional e antes do codigo — ver [PLANEJAMENTO_SEGURO_CERTIFICADORA_E_REFORMA_FISCAL_IBS_CBS.md](PLANEJAMENTO_SEGURO_CERTIFICADORA_E_REFORMA_FISCAL_IBS_CBS.md) (registo **29/04/2026**; **sem** implementacao nessa data).

## Documentos relacionados

- [OFICIAL_02_PARTE_FUNCIONAL_DO_SISTEMA.md](/C:/Users/hp/pontocerto/docs/OFICIAL_02_PARTE_FUNCIONAL_DO_SISTEMA.md)
- [OFICIAL_03_ARQUITETURA_TECNICA_COMPLETA_DO_SISTEMA.md](/C:/Users/hp/pontocerto/docs/OFICIAL_03_ARQUITETURA_TECNICA_COMPLETA_DO_SISTEMA.md)
- [OFICIAL_04_MEMORIA_E_REGISTRO_ATUAL_DO_SISTEMA.md](/C:/Users/hp/pontocerto/docs/OFICIAL_04_MEMORIA_E_REGISTRO_ATUAL_DO_SISTEMA.md)
