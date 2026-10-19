# Pesquisa de integrações possíveis

Pesquisa em 18/10/2026. Estado: **candidatos e contratos conceituais; nenhuma integração ativada**. U-03 autoriza pesquisa, não criação de contas, contratos com fornecedores, SDKs, credenciais, webhooks ou chamadas autenticadas. Fontes são documentação dos próprios serviços e órgãos; nenhum sandbox de fornecedor foi executado.

## 1. Como decidir

Escolher primeiro o regime operacional e as responsabilidades PF/PJ, depois a capacidade necessária e o fornecedor. Checklist de seleção: aceitação formal da atividade; países/moedas; PF e PJ; representação; retenção e liberação; disputas e saldo negativo; documentos; limites e SLA; sandbox; segurança de eventos; custos fixos/por operação; tratamento de dados e portabilidade. Dados comerciais e preços não foram cotados; não há recomendação de contratação.

## 2. Pagamentos, split e retenção

| Candidato | Capacidade documentada | Forma de integração | Limitação relevante para Trago |
| --- | --- | --- | --- |
| Asaas | Split entre contas, subcontas e funcionalidade denominada Conta Escrow | API; webhooks de cobrança/split; consulta/liberação de garantia | Há término automático da garantia por data e outras formas de liberação; evento de split não significa saldo disponível. A semântica precisa ser compatível com entrega/disputa |
| Pagar.me | Pedidos com múltiplos recebedores e regras de split | API de pedidos/recebedores; credenciamento | Documentação limita split a clientes PSP e contas configuradas para adquirência Pagar.me; split não demonstra escrow por entrega |
| Mercado Pago | Split 1:1 com checkout hospedado ou transparente; 1:N em modalidade comercial específica | OAuth do vendedor; API; notificações a validar na especificação | 1:N e configuração de liberação exigem contato comercial segundo pré-requisitos. Reembolso pode depender do saldo do vendedor; não prova retenção exigida |
| Stripe Connect | Cobranças e transferências separadas em regiões suportadas; repasse manual | API; connected accounts; eventos | Stripe afirma não oferecer escrow. Repasse manual tem limite temporal por país; Brasil e cross-border precisam validação do modelo e das capacidades contratadas |

Fontes primárias:

- [Asaas — split com Conta Escrow](https://docs.asaas.com/docs/split-para-contas-com-conta-escrow): distingue liquidação, disponibilidade e término da garantia; não documenta webhook específico para mudança da garantia nessa página. Projetar consulta/reconciliação, sem presumir evento inexistente.
- [Asaas — criação de subcontas](https://docs.asaas.com/docs/criacao-de-subcontas): conta-pai PJ e modelos BaaS/não-BaaS têm requisitos diferentes. Não confundir comprador PF com titular da conta-pai.
- [Pagar.me — split](https://docs.pagar.me/docs/pedidos-com-split) e [recebedores](https://docs.pagar.me/reference/recebedores-1): condições de uso, cadastro e estados de credenciamento.
- [Mercado Pago — pré-requisitos](https://www.mercadopago.com.br/developers/pt/docs/split-payments/split-1-1/prerequisites) e [checkout split 1:1](https://www.mercadopago.com.br/developers/pt/docs/split-payments/split-1-1/integration-configuration/integrate-marketplace): OAuth, condições comerciais e comportamento de reembolso.
- [Stripe — cobranças e transferências separadas](https://docs.stripe.com/connect/separate-charges-and-transfers?locale=es-ES) e [repasses manuais](https://docs.stripe.com/connect/manual-payouts): disponibilidade regional não autoriza assumir conta escrow ou pagamentos internacionais irrestritos.

**Avaliação proposta:** Asaas merece diligência pela funcionalidade de garantia descrita; Pagar.me é alternativa de split local; Mercado Pago oferece caminho de marketplace com onboarding OAuth; Stripe oferece modelo flexível de contas/transferências. Nenhum foi validado para a atividade Trago, retenção por toda a viagem ou disputa aduaneira. Não escolher apenas pelo nome escrow ou pela existência de Pix.

Questões obrigatórias antes de selecionar: quem recebe o preço do produto, frete e comissão? Quem financia a compra? Retenção começa quando? O prazo máximo cobre viagem/atrasos/disputas? É possível impedir liberação automática em disputa? Quem assume reembolso e chargeback depois do repasse? Há PF/PJ e CNPJ alfanumérico? Transação é doméstica em BRL ou também cambial? O fornecedor aceita formalmente a atividade e seus riscos?

Portas futuras candidatas, não interfaces implementadas: `CreateCheckout`, `GetPaymentStatus`, `RequestRefund`, `GetReleaseEligibility`, `RequestPayout`, `ReconcilePayment`. Cadastro do recebedor é um caso de uso separado. Capacidade de escrow/hold é descrita explicitamente; adaptador sem suporte retorna indisponibilidade, nunca emula custódia com saldo próprio.

## 3. Login, KYC e representação PJ

| Necessidade | Candidatos pesquisados | Proposta e limites |
| --- | --- | --- |
| Login Web/Android | Cognito; Keycloak | Protocolo OIDC limita acoplamento. Serviço gerenciado reduz operação; Keycloak dá controle e exige manutenção. Não criar realm por empresa por padrão |
| Verificação de identidade | idwall; Serpro Datavalid | Relatórios/validação são entradas para uma política de verificação. Não são autenticação, aceitação aduaneira ou comprovação automática de representação |
| Cadastro e empresa | Consulta CNPJ via serviço contratado; fontes autorizadas e documentos societários | Disponibilidade técnica/comercial de consulta deve ser confirmada. CPF/CNPJ válido não prova que a pessoa pode obrigar a empresa |

Fontes:

- [Cognito User Pools](https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools.html): IdP OIDC para Web/mobile; funcionalidades e planos diferem. Não foi selecionada região/plano.
- [Keycloak — OIDC](https://www.keycloak.org/securing-apps/oidc-layers): descoberta e endpoints padronizados; a operação do servidor seria responsabilidade adicional.
- [idwall — documentação](https://idwall.readme.io/): API de relatórios, matrizes e webhooks. Workflow KYB, poderes, custos, SDK e requisitos exatos ainda precisam diligência comercial/técnica; não inferir cobertura universal.
- [Serpro — Datavalid V5](https://centraldeajuda.serpro.gov.br/duvidas/pt/avisos/datavalidsenatran/): validações cadastrais e biométricas e requisitos de contratação/regulação. A página de documentação técnica tentada não ficou acessível nesta pesquisa; contratos completos não foram verificados.
- [Serpro — jornada de contratação de APIs](https://demonstra.serpro.gov.br/tutoriais/cartilha_do_usuario/html/demo_2.html): fonte histórica que cita Consulta CPF e contratação; requisitos atuais e Consulta CNPJ específica permanecem a confirmar. Não basear aprovação de fornecedor apenas nesse tutorial antigo.

**Compatibilidade já relevante:** a Receita informa emissão do primeiro CNPJ alfanumérico em 31/07/2026. Cadastro, banco, contratos, validadores e integrações devem aceitar o formato atual e os numéricos existentes. Não usar tipo numérico nem remover letras na normalização. [Receita Federal — CNPJ alfanumérico](https://www.gov.br/receitafederal/pt-br/assuntos/noticias/2026/julho/receita-federal-gera-o-primeiro-cnpj-em-formato-alfanumerico).

Portas futuras: `StartVerification`, `GetVerificationStatus`, `VerifyOrganizationAuthority`. Guardar referência, resultado, data, origem e justificativa da decisão; reduzir cópia de biometria/documentos. Biometria não é requisito confirmado e amplia risco de privacidade; só adotar com necessidade e base legal definidas. Usar políticas graduais de acesso; selo de verificado corresponde a evidência específica, não a garantia global.

## 4. Câmbio e cotação

BCB PTAX oferece dados de câmbio por data/período por OData. Pode fundamentar uma cotação de referência, guardando fonte e momento. Não é proposta executável de remessa ou autorização para câmbio, nem determina automaticamente a taxa fiscal aplicável. [BCB — documentação do serviço](https://www.bcb.gov.br/conteudo/dadosabertos/BCBDepin/gnastportal-dados-abertostaxas-de-cambio---todos-os-boletins-diarios.pdf).

Porta futura `GetReferenceFxQuote`; taxa fiscal depende do regime validado; taxa de liquidação pertence ao provedor financeiro/cambial. Definir feriados, dados defasados, validade e indisponibilidade. O produto não deve mostrar zero tributo ou câmbio atual quando a fonte falhar.

Execução cambial/remessa exige parceiro e diligência específicos. Fornecedor ainda não pesquisado em profundidade, por depender de Q-02/Q-04; não há aprovação para câmbio ou pagamentos cross-border. Uma fronteira separada permite pesquisa posterior sem misturar referência PTAX com movimentação financeira.

## 5. Aduana, classificação e importação

O Portal Único Siscomex documenta API REST com XML/JSON, autenticação, perfis e ambientes. Há mecanismo de chaves de acesso geridas pelo usuário, vinculado a poderes de acesso, não uma API pública irrestrita. Integração direta exigiria validar habilitação, representação, certificado/chaves e a operação correspondente. [Introdução](https://docs.portalunico.siscomex.gov.br/introducao-api-publica/) e [chaves de acesso](https://docs.portalunico.siscomex.gov.br/pages/chaves-acesso/).

A publicação de 02/10/2026 trata limites de consulta automatizada à Duimp e alternativas com atualização/notificação. Sua existência reforça a necessidade de respeitar limites e evitar polling indiscriminado. [Siscomex — consultas Duimp](https://www.gov.br/siscomex/pt-br/sistemas-de-comercio-exterior/integre-seu-sistema/limite-de-consultas-automatizadas-a-duimp).

**Alternativa de integração:** parceiro importador/despachante autorizado, inicialmente com processo operacional/documental validado e depois contrato de API/eventos do parceiro. O fato de existir uma API Siscomex não define quem é o importador nem permite aplicar regime de bagagem a encomenda de terceiro.

Portas candidatas: `AssessImportEligibility`, `EstimateImportCosts`, `GetImportOperationStatus`, `AttachImportDocument`. Resultado inclui regime, escopo PF/PJ, fontes, versão, data, entradas e estado `SUPPORTED`, `REQUIRES_REVIEW`, `UNSUPPORTED` ou `INELIGIBLE`. Falta de dados não pode ser convertida em conformidade aprovada.

Não enviar declaração, calcular tributo vinculante, consultar dado protegido ou guardar certificado nesta fase. NCM, finalidade, país/origem, documentos e demais entradas dependem da operação escolhida. Não existe nos assets uma tabela fiscal confiável para implementar.

## 6. Documentação fiscal e contábil

| Caminho | Meio técnico | Questões que continuam abertas |
| --- | --- | --- |
| Focus NFe | API JSON, referências próprias de emissão, fluxo de autorização e webhooks; NF-e/NFS-e e outros documentos | Tipo de documento, emitente, município/regime, certificado, cobertura e credenciamento |
| NFS-e nacional direta | Documentação e APIs oficiais, ambientes próprios | Elegibilidade e regras do emitente, certificados e custos de manutenção de layouts |
| Documentos do importador/parceiro | Recepção de XML/PDF/referência e verificação conforme contrato | Responsabilidade pela emissão e documento hábil em cada operação PF/PJ |

Fontes: [Focus — introdução](https://doc.focusnfe.com.br/reference/introducao), [emissão NFS-e](https://doc.focusnfe.com.br/reference/emitir_nfse), [emissão NF-e](https://doc.focusnfe.com.br/reference/emitir_nfe), [ambientes](https://doc.focusnfe.com.br/reference/ambiente), [NFS-e — documentação oficial](https://www.gov.br/nfse/pt-br/biblioteca/documentacao-tecnica).

Fatura comercial estrangeira, documento aduaneiro, NF-e de mercadoria, NFS-e da intermediação e relatório do pedido têm finalidades diferentes. A qualificação exata cabe à contabilidade/assessoria do modelo aprovado. API de notas não regulariza uma importação nem garante escrituração correta.

Portas candidatas: `RequestServiceInvoice`, `GetFiscalDocumentStatus`, `RetrieveAuthorizedDocument`; recepção de documento de importação é caso separado. Preservar original autorizado, protocolo, vínculo PF/PJ, integridade e histórico de cancelamento/correção. Não conceder acesso ao viajante a toda a documentação empresarial.

Nuvem Fiscal foi considerada na busca, mas a página tentada não foi recuperada. Não foi comparada funcionalmente nem incluída como capacidade comprovada.

## 7. Logística e comunicação

- **Melhor Envio:** API documenta cotação, compra/geração de etiqueta, rastreio, OAuth e sandbox separado. Candidato para trecho doméstico posterior ao desembaraço, conforme cobertura contratada. Não substitui operação internacional nem é rastreio de bagagem/voo. [Processos](https://docs.melhorenvio.com.br/docs/introducao-a-integracao) e [API/sandbox](https://docs.melhorenvio.com.br/reference/introducao-api-melhor-envio).
- **Transportador/parceiro comex:** precisa pesquisa específica depois de corredor/regime escolhido; sem evidência para prometer integração a companhias aéreas ou localização contínua.
- **Firebase Cloud Messaging:** candidato para avisos Android/Web. Push não é estado autoritativo nem prova de entrega; conteúdo mínimo e recuperação do estado via API. [Documentação FCM](https://firebase.google.com/docs/cloud-messaging).
- **Email transacional:** capacidade candidata para avisos, convites e recuperação conforme IdP; fornecedor e custos ainda não selecionados. WhatsApp/SMS ficam fora até requisito de canal e autorização específicos.

Portas futuras por uso: `QuoteDomesticShipment`, `CreateShipmentLabel`, `GetTrackingEvents`, `SendTransactionalNotification`. Evitar armazenar endereço no provedor antes de haver necessidade e autorização. Credenciais e tokens OAuth ficam no servidor, segregados por conta e ambiente.

## 8. Extensão técnica proposta, sem conectores atuais

1. Domínio define comando/resultado mínimo. Não importa SDK do fornecedor.
2. Adaptador futuro converte comando para API externa e mantém vínculo `provider + external_id + account_id`.
3. Configuração distingue `DISABLED`, `TEST_ONLY`, `SANDBOX` e `LIVE`, com regras de startup para impedir configuração ambígua em produção.
4. Segredo fica em secret store do ambiente; repositório e clientes recebem somente nomes/configuração não secreta.
5. Requisições têm timeout, chave de idempotência e correlação. Retentativa respeita capacidade e risco; em cobrança ambígua, consultar/conciliar antes de cobrar novamente.
6. Webhook valida autenticidade pelo mecanismo suportado pelo fornecedor; deduplica, registra e processa transição válida. Não pressupor que todos usam HMAC ou o mesmo cabeçalho.
7. Contract tests usam fixtures sintéticas; sandbox só com aprovação de integração. Produção exige evidências de reembolso, disputa, callback duplicado/fora de ordem, credencial expirada e indisponibilidade.

Não criar portas sem consumidor concreto nem um framework genérico. Estes nomes são orientação para especificações futuras. O primeiro rascunho de solicitação usa apenas banco e contrato próprio.

## 9. Ordem de habilitação proposta

1. Aprovar arquitetura e definir responsabilidade aduaneira/fiscal PF/PJ.
2. Implementar fatia local com dados de teste e contextos PF/PJ, depois de aprovar a especificação.
3. Diligência comercial e técnica de IdP, KYC/KYB, parceiro comex, PSP e fiscal; documentar evidências e custos.
4. Aprovação explícita por integração e ambiente; homologação isolada; não tratar aprovação de arquitetura como autorização para operações externas.
5. Somente então release comercial limitado com suporte, conciliação, resposta a incidentes e documentos exigíveis.
