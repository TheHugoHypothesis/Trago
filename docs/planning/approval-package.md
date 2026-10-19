# Pacote de decisão — arquitetura primeiro

Estado atual: **arquitetura aprovada em U-05; implementação local e orquestração autorizadas**. U-06 determina Podman para agentes/builds. Integrações reais, push, merge e deploy continuam sem autorização; agy não foi iniciado. O restante deste documento preserva o pacote apresentado para decisão, não representa o estado operacional atual. Ver [orquestração atual](../engineering/agent-orchestration.md).

## Entendimento do produto

Marketplace internacional ligando compradores PF/PJ a capacidade de transporte, com cotação transparente, documentação e pagamento protegido. As fontes são um desenho de três telas, um pitch de oito slides e um relatório qualitativo de 48 entrevistas. Não há aplicação, prova de transação real ou arquitetura prévia a preservar. [Descoberta](../product/discovery.md).

O principal risco é de modelo: encomendas de terceiros e bens para PJ não se enquadram no conceito de bagagem descrito pela Receita. A proposta exige validar regime, importador e papel do viajante, possivelmente com parceiro comex; não presume que calcular tributos resolva o enquadramento. [Fonte oficial](https://www.gov.br/receitafederal/pt-br/assuntos/aduana-e-comercio-exterior/viagens-internacionais/guia-do-viajante/entrada-no-brasil/bens-do-viajante).

## Aprovação A — direção arquitetural

Proposta para revisar agora:

1. Monólito modular: Next.js/TypeScript, NestJS/Fastify, PostgreSQL, Android Kotlin/Compose; versões/ORM a validar antes de instalar.
2. PF e PJ desde o primeiro fluxo; User, Account, Organization e Membership separados; autorização por recurso/participante.
3. OpenAPI canônico e clientes TS/Kotlin gerados; backend controla regras e valores exatos.
4. OIDC como direção de autenticação; IdP/KYC/KYB não selecionados nem conectados.
5. Limites para futuras integrações financeiras, comex, fiscais, câmbio, logística e notificações; nenhum adaptador externo nesta fase.
6. VS-01 proposta: publicar viagem fictícia, buscar e persistir rascunho privado PF/PJ entre Web e Android. Validar persistência, isolamento, contrato e CI. Não equivale a lançamento comercial.

ADRs com alternativas: [stack](../architecture/decisions/0001-stack-and-boundaries.md), [identidade/contexto](../architecture/decisions/0002-identity-and-ownership.md), [integrações](../architecture/decisions/0003-integration-boundaries.md). [Pesquisa de fornecedores](../architecture/integrations.md).

## MVP comercial proposto

PF/PJ, corredor/categorias validados, onboarding e poderes, oferta e busca, solicitação/aceite, elegibilidade/cotação, reserva, pagamento/repasse aprovados, documentos pertinentes, acompanhamento, disputa/reembolso, suporte e conciliação. Nenhuma dessas capacidades está pronta hoje.

Global, ML, assinatura, carteira/custódia própria, iOS, ERP amplo, crédito e infraestrutura distribuída ficam fora da proposta inicial. Empresas permanecem no escopo. Legalidade operacional, modelo financeiro e documentos são gates comerciais; desenvolvimento local não os resolve.

## Backlog inicial por dependência

| ID | Entrega futura | Depende de | Risco |
| --- | --- | --- | --- |
| B-01 | Aprovar/revisar ADRs e premissas de equipe/orçamento | Decisão do usuário | Médio |
| B-02 | Definir regime/importador/responsabilidades PF/PJ | Produto + assessoria qualificada | Crítico |
| B-03 | Detalhar orquestração/fundação e revisar com agy quando autorizado | B-01; mudança explícita de U-04 para execução | Médio |
| B-04 | Aprovar especificação/contrato de VS-01 e matriz de ferramentas | B-01; sem operação real | Médio |
| B-05 | Implementar fundação e VS-01 com TDD e CI | Aprovação B abaixo, B-03/B-04 | Alto |
| B-06 | Definir preço, documentos, prova de entrega, cancelamento e disputa | B-02; Q-02 a Q-08 | Alto |
| B-07 | Selecionar e homologar integrações em ambiente isolado | B-06; aprovação por serviço | Alto |
| B-08 | MVP transacional PF/PJ e preparação operacional | B-05/B-07; specs aprovadas | Crítico |

Não é um DAG executável; papéis/caminhos/comandos/tempos de cada tarefa serão detalhados na etapa de orquestração. Não atribuir datas sem conhecer equipe e orçamento.

## Aprovações separadas

**A agora:** aceitar/revisar a direção arquitetural documentada. Essa decisão permite detalhar propostas seguintes; não autoriza implementação.

**B depois:** aprovar fundação/orquestração, arquivos e especificação da primeira fatia. Somente então criar policy efetiva, configurar stack/CI e começar código.

**C por integração:** autorizar sandbox e, posteriormente, produção, com requisitos comerciais, privacidade e segurança atendidos. Separada de contratos locais e fakes de teste.

**Merge/push/deploy:** sempre autorização explícita; nenhuma está concedida.

## Arquivos e infraestrutura

Criados agora: apenas documentos em `docs/`, listados no [índice](../README.md), incluindo auditoria JSON de comandos. Todos novos; assets, LICENSE e .gitignore preservados. Sem commit, dependências ou recursos externos.

Arquivos futuros exatos por grupo e conteúdo de policy/templates: [foundation-proposal.md](foundation-proposal.md). Não foi criado AGENTS.md/GEMINI.md nem task runner/Makefile/CI. Infraestrutura a criar agora: nenhuma.

## Decisões ainda necessárias

Para aprovar a direção técnica: confirmar stack frente à experiência da equipe (Q-09). Para detalhar operação comercial: regime/importador (Q-01), compra/adiantamento (Q-02), documentação (Q-03), PSP/retenção (Q-04), fórmula/câmbio (Q-05), corredor/categorias (Q-06), disputas (Q-07), representação (Q-08) e privacidade/cloud (Q-10/Q-11).

Revisão independente: pendente por U-04. Não tratar este pacote como aprovação por outro modelo. Nenhum teste de aplicação ou pipeline foi executado.
