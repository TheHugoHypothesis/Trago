# Descoberta do Trago

Data: 18/10/2026. Estado: análise concluída dos materiais disponíveis; proposta comercial e requisitos aguardam aprovação.

## 1. Instruções confirmadas

| ID | Instrução | Origem |
| --- | --- | --- |
| U-01 | Produto orientado a produção, Web e Android; preservar originais; especificação e aprovação antes de implementação substancial | Prompt inicial |
| U-02 | Produto comercial com PF **e empresas desde o início** | Resposta à clarificação nesta sessão |
| U-03 | Pesquisar meios de integração; não integrar agora; permitir integração futura | Mesma resposta |
| U-04 | Priorizar arquitetura; orquestração depois; não executar `agy` agora | Orientação mais recente |
| U-05 | Arquitetura aprovada; evitar perguntas; foco em codificação e preparação de agentes paralelos Codex/agy/pi | Aprovação posterior |
| U-06 | Configurar agentes e builds em Podman instalado | Orientação posterior durante a implementação |
| U-07 | Entregar comandos imediatos para três tarefas distintas; agy com skip-permissions; preservar identidade visual; MVP e testes essenciais; handoff se faltar quota/contexto | Última orientação |

## 2. Inventário recursivo e integridade

A pasta `InitialAssets/` contém exatamente três arquivos, sem subpastas ou arquivos ocultos encontrados. Não há código, datasets, protótipo navegável, arquivos de design editáveis ou contratos. O PNG e a figura do relatório representam o mesmo desenho de três telas. As imagens não demonstram implementação Android nem iOS.

| ID | Fonte | Características | Leitura realizada |
| --- | --- | --- | --- |
| S-01 | [Design.png](../../InitialAssets/Design.png) | 1.691.588 bytes; PNG RGB 1536×1024 | Inspeção visual integral das três telas |
| S-02 | [slides-Trago-v2.pdf](../../InitialAssets/slides-Trago-v2.pdf) | 34.019.844 bytes; 8 páginas; PDF formado por imagens | Metadados, tentativa de extração textual sem texto útil e inspeção visual das 8 páginas renderizadas |
| S-03 | [Trago_Analise_de_Ideias_por_Pessoas_Externas.pdf](../../InitialAssets/Trago_Analise_de_Ideias_por_Pessoas_Externas.pdf) | 1.865.783 bytes; 3 páginas | Texto integral extraído; figura da página 2 inspecionada visualmente |

SHA-256 dos originais:

```text
46c3fd7a9882ff8a4cb3be24d1a00c660ca2bc242da1a5fbe79cfc979374b90d  Design.png
c18088f37e4a7bc1a5ffb5cd7baf44f804f8b957b58cd33737d11b6ace64af67  Trago_Analise_de_Ideias_por_Pessoas_Externas.pdf
2e1e486bd5bb0b78bfd13f5cdcf83b8dd406e3528c5d7590ba1cbb05248305d7  slides-Trago-v2.pdf
```

Os três arquivos estavam não rastreados pelo Git na auditoria inicial. Preservar e versionar são ações diferentes: não foram adicionados ao índice. Avaliar Git LFS e direitos de uso antes de publicar o PDF de 34 MB ou as imagens.

## 3. Produto e problema

Trago é uma proposta de marketplace de crowd-shipping internacional. Compradores procuram produtos no exterior; viajantes oferecem capacidade disponível. A plataforma pretende reduzir custo logístico, incerteza tributária e demora, remunerando o viajante e cobrando intermediação. [S-02, pp. 2–4, 6–7; S-03, p. 1]

Três pilares propostos nos materiais: matching de rota/data; cálculo antecipado de tributos, câmbio e tarifas; pagamento retido e liberação após entrega. O pitch acrescenta mercado corporativo, relatórios fiscais e alcance global. São intenções de produto, não capacidades existentes. [S-02, pp. 4–8]

Não há descrição de assinatura ou planos recorrentes. O modelo de receita apresentado é percentual sobre transações e frete. [S-02, p. 7]

## 4. Evidência de validação e limites

O relatório informa 48 entrevistas: 8 idosos, 10 estudantes, 15 adultos de 20–40 anos, 5 viajantes internacionais e 10 jogadores. A soma confere. Cada integrante entrevistou um grupo usando os mockups. [S-03, pp. 1–3]

- Idosos: preocupação com complexidade fiscal e multas; precisam de linguagem clara. [p. 2, §3.1]
- Estudantes: incentivo ao viajante não era evidente até visualizar remuneração por kg. [p. 2, §3.2]
- Adultos: bens abaixo de USD 30 pareceram economicamente desvantajosos. Isso não estabelece um preço mínimo universal. [p. 3, §3.3]
- Viajantes: transparência dos componentes e documentação PF/PJ são relevantes. [p. 3, §3.4]
- Jogadores: confiança condicionada ao pagamento liberado após recebimento e validação. [p. 3, §3.5]

Não foram fornecidos roteiros, respostas individuais, dados brutos, consentimentos, pedidos reais, volume de transações, comprovação de economia, parecer jurídico ou contratos de pagamento. Não se pode inferir conversão, representatividade estatística ou validação operacional. A capa do relatório usa 05/10/2026 e o metadado de criação é de 04/10; registrar a diferença sem inferir fraude ou erro substantivo.

## 5. Personas candidatas e fluxos

| Persona | Fluxo principal | Lacunas |
| --- | --- | --- |
| Comprador PF | Informar produto/valor/peso → buscar rota/data → solicitar → analisar custo → pagar → acompanhar → confirmar ou contestar | Quem compra no exterior? Quem é importador? Endereço, entrega e devolução? |
| Representante PJ | Verificar representação → selecionar empresa → solicitar importação → aprovar custo → obter documentos → acompanhar | Poderes de representação, alçadas, importador, regime e documentos exigíveis |
| Viajante | Cadastrar/verificar identidade → anunciar viagem/capacidade/preço → avaliar solicitação → transportar conforme regime aprovado → comprovar entrega → receber | Pré-financiamento, restrições da companhia aérea, responsabilidade e tributação da renda |
| Operação/suporte | Validar exceções → tratar cancelamento/aduana/disputa → conciliar valores e documentos | Não desenhado nas fontes; necessidade inferida para operação comercial |

Papéis de comprador e viajante não precisam ser contas mutuamente exclusivas. Um usuário pode agir pessoalmente ou representar empresas. Empresa compradora não implica empresa operadora de transporte.

## 6. Inventário de requisitos candidatos

| ID | Capacidade | Evidência | Proposta de escopo |
| --- | --- | --- | --- |
| R-01 | Buscar viagens por origem, destino e data; listar tarifa e capacidade | S-01 tela central; S-02 p. 4 | Fluxo inicial, matching determinístico |
| R-02 | Cadastrar produto por link, valor, peso e categoria | S-01 tela direita | Fluxo inicial; sem capturar páginas automaticamente |
| R-03 | Publicar/manter viagem e capacidade | S-01 ação viajante e listagens | Necessário; formulário e regras ainda não descritos |
| R-04 | Discriminar produto, frete, tributos, comissão, câmbio e total | S-01; S-02 p. 4 | Essencial comercial; regras precisam validação |
| R-05 | Retenção e liberação financeira após entrega | S-02 pp. 4/7; S-03 §3.5 | Essencial comercial; modelo/PSP não escolhido |
| R-06 | Histórico/acompanhamento de pedidos | S-01 navegação e etapa 4 | Essencial; estados propostos na arquitetura |
| R-07 | Identidade e indicação de verificação | S-01; S-02 p. 4 | Essencial; não emitir selo sem evidência |
| R-08 | Avaliações/reputação | S-01 | Pode ficar fora da primeira entrega técnica; não fabricar avaliações |
| R-09 | Empresas, representantes e documentos contábeis | U-02; S-02 pp. 5–6; S-03 §3.4 | Desde o início; não adiar PJ |
| R-10 | Notificações | S-01 ícone; S-01 acompanhamento | Canal a validar; inbox primeiro é hipótese |
| R-11 | Cancelamento, reembolso, disputa e suporte | Inferência a partir de R-05/R-06 | Obrigatório antes de transações reais; especificar |
| R-12 | Isolamento PF/PJ e autorização por participante | U-01/U-02; análise de segurança | Obrigatório; detalhes na arquitetura |

## 7. Web e Android

U-01 confirma as duas plataformas; os materiais não distribuem responsabilidades entre elas. Proposta: ambos permitem busca, solicitação, cotação e acompanhamento para PF/PJ. Web favorece gestão de empresa e documentos; Android favorece atuação em viagem e entrega. Essa especialização é hipótese, não bloqueia PJ no Android. Backoffice inicialmente Web e restrito à operação, se aprovado.

Não há requisito comprovado de funcionamento offline, GPS contínuo, integração aérea, rastreamento em tempo real ou iOS. Android deve tratar perda de conexão e retomada sem duplicar operações; offline completo não faz parte da proposta inicial.

## 8. Modelo de domínio inicial

| Agregado/entidade | Papel proposto | Origem |
| --- | --- | --- |
| User / ExternalIdentity / Profile | Pessoa autenticada e dados mínimos | R-07; hipótese técnica |
| Account | Contexto proprietário PF ou PJ | R-09/R-12; hipótese de modelagem |
| Organization / Membership | Empresa e poderes de cada membro | U-02; hipótese de autorização |
| VerificationCase | Estado e evidência de verificação PF/PJ | R-07/R-09 |
| Trip / Route / Capacity | Rota, data, capacidade em gramas, tarifa | R-01/R-03 |
| PurchaseRequest / Item | Intenção de compra/importação e seus itens | R-02 |
| EligibilityAssessment / Quote / QuoteLine | Enquadramento e componentes da estimativa | R-04; risco aduaneiro |
| Order / Reservation | Compromisso comercial e capacidade reservada | R-05/R-06; além do primeiro rascunho |
| Payment / Transfer / Refund / Dispute | Ciclo financeiro separado de entrega | R-05/R-11 |
| Shipment / DeliveryEvidence | Eventos logísticos e prova de recebimento | R-06/R-11 |
| FiscalDocument / ImportDocument | Documento emitido, recebido e sua finalidade | R-09 |
| AuditEvent / IntegrationEvent | Rastreabilidade de ações e provedores | U-01; hipótese técnica |

São fronteiras candidatas, não tabelas ou classes implementadas.

## 9. Contradições e promessas sem comprovação

1. **Bagagem e terceiros/PJ:** o pitch pressupõe conformidade usando capacidade de bagagem. A Receita inclui encomendas para terceiros e bens destinados a PJ fora do conceito de bagagem. Consequência proposta: não aplicar franquia de viajante ao marketplace; validar modelo de importação e transporte adequado antes de habilitar transações. Isso não estabelece que toda modalidade de crowd-shipping seja ilegal. [S-02 p. 4/6; E-01 abaixo]
2. **Cálculo do mockup:** USD 300 + USD 32 + USD 96 + USD 21 = USD 449 confere. Porém, 6% de USD 332, 428 ou 449 não resulta em USD 21. A base da comissão é desconhecida. USD 32 para 0,8 kg corresponde a USD 40/kg; o viajante escolhido não é mostrado. Não corrigir o original nem copiar sua fórmula como regra. [S-01]
3. **Estimativa versus garantia:** a tela chama tributos de estimados, mas também promete previsibilidade/conformidade. Um cálculo não prova elegibilidade aduaneira. [S-01; S-02 p. 4]
4. **Custódia/risco zero:** confirmação física não elimina produto incorreto, coação, fraude, chargeback ou disputa. Provedor e condições não aparecem nas fontes. [S-02 pp. 4/7]
5. **Operação validada/global:** não há suporte documental para tais afirmações. [S-02 p. 8; S-03]
6. **PF/PJ:** o mockup não detalha PJ, mas U-02 resolve o escopo: ambos desde o início. Isso amplia autorização, fiscal e operação, não pode ser reduzido silenciosamente a cadastro de CNPJ.
7. **Datas:** viagens de dezembro de 2025 no desenho são ilustrativas e anteriores à documentação de outubro de 2026. Não são oferta disponível. [S-01]

## 10. MVP comercial proposto e primeira entrega técnica

**MVP comercial PF/PJ:** cadastro e representação verificáveis; um corredor internacional validado; catálogo restrito de categorias elegíveis; publicar e buscar capacidade; solicitar e aceitar; cotar com bases verificadas; reservar capacidade; cobrança e repasse aprovados; documentação de importação e serviço pertinente; acompanhamento; confirmação e disputa; cancelamento/reembolso; conciliação, suporte e auditoria. Não está autorizado para implementação nem lançamento.

Corredor EUA→São Paulo é candidato baseado no desenho, não decisão. Produtos de maior valor agregado podem melhorar a viabilidade, mas ticket e margem precisam pesquisa. A operação deve ser redesenhada com parceiro/importador se o transporte de terceiros no modelo apresentado não se sustentar.

**Primeira entrega técnica VS-01:** validar contas PF/PJ, autorização, viagem fictícia publicada, busca, solicitação privada persistida e leitura pelas duas plataformas. Sem dinheiro ou transporte reais. É um incremento rumo ao produto comercial, não um MVP comercial pronto. Ver [overview.md](../architecture/overview.md).

**Fora do MVP proposto:** marketplace global irrestrito, iOS, assinatura, crédito, carteira própria, custódia própria, ML de matching, preço dinâmico, ERP completo, múltiplos níveis de alçada, seguro próprio e infraestrutura distribuída. A exclusão precisa aprovação. Documentação PJ e segregação de contas permanecem dentro.

## 11. Hipóteses e decisões abertas

| ID | Questão/hipótese | Responsável pela decisão | Quando bloqueia |
| --- | --- | --- | --- |
| Q-01 | Regime lícito, importador responsável e papel do viajante; parceiro/despachante necessário? | Produto + assessoria aduaneira | Especificação de transporte, tributos e qualquer operação real |
| Q-02 | Quem compra no exterior, detém propriedade e antecipa o custo? | Produto + financeiro/jurídico | Pedidos vinculantes e fluxo financeiro |
| Q-03 | Quais documentos PF/PJ, quem emite, qual finalidade e prazo de guarda? | Contabilidade + jurídico | Fiscal e lançamento comercial |
| Q-04 | Provedor financeiro aceita atividade/PF/PJ, retenção por entrega, duração e disputas? | Produto + financeiro + PSP | Integração e pagamentos |
| Q-05 | Base da comissão, câmbio, spread, taxa de PSP, margem e responsabilidade tributária | Produto + financeiro | Cotação vinculante |
| Q-06 | Corredor, categorias permitidas, transporte de bateria, valor/peso/volume e seguro | Produto + operação | Viagens/pedidos reais |
| Q-07 | Prova de entrega, janela de contestação, silêncio, perda/avaria/aduana, cancelamento | Produto + suporte/jurídico | Reserva/cobrança |
| Q-08 | Como comprovar poderes do representante PJ e revogá-los? Papéis comprador/admin bastam? | Produto + jurídico | Operação PJ; esquema inicial assume dois papéis |
| Q-09 | Equipe, experiência TS/Kotlin/Java, prazo, orçamento mensal e volumes previstos | Usuário | Escolha final de stack, capacidade e custos |
| Q-10 | Cloud, região, IdP, política LGPD, retenção, operadores e transferência de dados | Usuário + privacidade | Serviços externos e dados reais |
| Q-11 | Idade mínima e perfis permitidos; exclusão de categorias/pessoas | Produto + jurídico | Cadastro público e transações |
| A-01 | Português brasileiro como idioma inicial; USD/BRL e EUA→SP como cenário de validação | Hipótese pelos assets | Não autoriza restringir mercado |
| A-02 | Kotlin/Compose e TypeScript são mantíveis pela equipe | Não verificado | Decisão final de stack |
| A-03 | Sem necessidade imediata de offline integral ou push | Não verificado | Escopo de UX Android |

## 12. Fontes externas primárias

Consultadas em 18/10/2026. Representam pesquisa documental; não houve consulta autenticada a APIs nem parecer jurídico.

- **E-01:** [Receita Federal — Bens do Viajante](https://www.gov.br/receitafederal/pt-br/assuntos/aduana-e-comercio-exterior/viagens-internacionais/guia-do-viajante/entrada-no-brasil/bens-do-viajante). Seção sobre bens fora do conceito de bagagem sustenta o conflito com terceiros/PJ.
- **E-02:** [Receita — Perguntas e Respostas](https://www.gov.br/receitafederal/pt-br/assuntos/aduana-e-comercio-exterior/viagens-internacionais/guia-do-viajante/perguntas-e-respostas), questões 1.2 e 1.3. Reforça necessidade de tratamento de importação distinto.
- **E-03:** [Princípios da LGPD — Ministério da Saúde](https://www.gov.br/saude/pt-br/acesso-a-informacao/lgpd/principios). Necessidade, finalidade, segurança e transparência orientam a proposta de dados mínimos; bases legais e retenção concretas continuam abertas.
- Pesquisa de fornecedores e protocolos: [integrações](../architecture/integrations.md), com links por capacidade e limites de evidência.
