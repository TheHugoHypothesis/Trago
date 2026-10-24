# Lean Canvas — Trago! (Crowd-Shipping & Importação Distribuída PF/PJ)

![Lean Canvas Trago!](LeanCanvas.png)

> **Arquivos disponíveis em `InitialAssets/`:**
> - [`LeanCanvas.png`](LeanCanvas.png) — Imagem em alta definição (4400×2750 px, 200 DPI)
> - [`LeanCanvas.pdf`](LeanCanvas.pdf) — Versão vetorial para impressão e apresentação
> - [`LeanCanvas.svg`](LeanCanvas.svg) — Gráficos vetoriais escaláveis
> - [`generate_lean_canvas.py`](generate_lean_canvas.py) — Script reprodutível em Python (`matplotlib`) seguindo a paleta de [`Design.png`](Design.png)

---

## Os 9 Blocos do Lean Canvas

### 1. Problema (*Problem*)
- **Fretes internacionais abusivos:** Transportadoras expressas e *couriers* frequentemente cobram tarifas logísticas que superam o preço do próprio produto.
- **Incerteza tributária e surpresas fiscais:** A complexidade das alíquotas de importação gera receio de multas ou retenções inesperadas na Receita Federal (apontado por 100% dos idosos e PMEs nas 48 entrevistas de validação).
- **Prazos longos e burocracia B2B/B2C:** Encomendas retidas em centros alfandegários tradicionais atrasam entregas de consumidores PF e paralisam projetos de PMEs que dependem de protótipos e peças.
- **Alternativas Existentes:**
  - Plataformas C2C informais (*Grabr*) sem suporte fiscal para Pessoa Jurídica (PJ).
  - Redirecionadores postais nos EUA (*UsCloser*, *Zip4Me*).
  - *Couriers* expressos tradicionais (*DHL*, *FedEx*, *UPS*).
  - Importação direta via varejistas internacionais (*Remessa Conforme*).

### 2. Segmentos de Clientes (*Customer Segments*)
- **Compradores PF (Artigos > US$ 30):** Consumidores de eletrônicos, áudio, fotografia e games de alto valor agregado (validado em pesquisa que itens abaixo de US$ 30 não compensam taxas fixas).
- **Compradores PJ / PMEs:** Empresas que necessitam de importação emergencial ou ágil de protótipos, placas embarcadas (ex.: *NVIDIA Jetson*) e peças de reposição com documentação contábil.
- **Viajantes Internacionais Verificados:** Passageiros em rotas de alta densidade (`EUA`, `Europa`, `Japão` → `Brasil`) com franquia de bagagem ociosa.
- **Adotantes Iniciais (*Early Adopters*):**
  - Gamers e entusiastas de tecnologia (20–40 anos).
  - Estudantes e pesquisadores em intercâmbio (ex.: *EACH-USP*).
  - PMEs de engenharia e tecnologia em São Paulo (corredor `NY/Miami → GRU`).

### 3. Proposta de Valor Única (*Unique Value Proposition*)
- **Para Compradores PF (B2C):** Compre produtos internacionais e receba em mãos com viajantes reais, economizando até 60% com cálculo fiscal transparente antes de pagar.
- **Para Empresas & PMEs (B2B):** Importação ágil de insumos, placas, sensores e protótipos com segregação de conta CNPJ e relatórios compatíveis com a contabilidade.
- **Para Viajantes Internacionais:** Monetize cada quilo livre da sua bagagem (`US$ 40` a `US$ 48/kg`) para abater custos da passagem com segurança jurídica.
- **Promessa Central (*Sem Surpresas!*):** Custo total fechado em `US$` e `R$` (*Produto + Frete Viajante + Tributos + Taxa 6%*) com pagamento retido em custódia até a entrega.
- **Conceito de Alto Nível (*High-Level Concept*):** *"O Airbnb do espaço de bagagem aérea com despachante fiscal automatizado (PF/PJ) e custódia segura tipo Mercado Pago."*

### 4. Solução (*Solution*)
- **Smart Matching de Rotas Aéreas:** Conexão determinística entre pedidos de compra e viajantes verificados com franquia ociosa (`JFK`, `MIA`, `LHR`, `HND`, `CDG` → `GRU`, `GIG`, `CWB`).
- **Motor de Automação Fiscal PF & PJ:** Cálculo antecipado de tributos, câmbio comercial ao vivo (`USD`, `EUR`, `GBP` → `BRL`) e emissão de documentação contábil para CNPJ.
- **Custódia Segura (*Escrow* via PIX):** O valor pago pelo comprador fica retido e só é liberado ao viajante após a entrega física confirmada e validada.

### 5. Canais (*Channels*)
- **App Mobile Flutter (Android & Multiplataforma):** Interface leve com mapa interativo global (`flutter_map`), catálogo curado, simulador fiscal e QR Code PIX.
- **Comunidades de Nicho & Milheiros:** Grupos de gamers, fotógrafos, colecionadores, intercambistas e fóruns de viajantes frequentes.
- **Parcerias B2B & Ecossistema de Inovação:** Hubs de startups, laboratórios de hardware/robótica e PMEs que importam componentes críticos.

### 6. Fontes de Receita (*Revenue Streams*)
- **Taxa de Serviço / *Take-Rate* da Plataforma (6% por Transação):** Comissão percentual transparente aplicada sobre o pedido (validada na tela de Cálculo Fiscal do app: ex. `US$ 21` em um pedido de `US$ 300` + frete + tributos).
- **Comissão sobre Intermediação de Capacidade Logística (Frete por Kg):** *Spread* operacional sobre a reserva de espaço na bagagem do viajante (tarifas de `US$ 38/kg` a `US$ 48/kg` conforme rota internacional e urgência).
- **Soluções Corporativas B2B & Serviços de Valor Agregado:** Emissão automatizada de dossiês contábeis para importação empresarial (PJ), gestão de múltiplos representantes por CNPJ e proteção estendida para cargas de alto valor.

### 7. Estrutura de Custos (*Cost Structure*)
- **Infraestrutura Cloud, Containers & APIs Públicas/Comerciais:** Hospedagem da API Backend (`Node.js/Fastify` + `PostgreSQL` isolados em containers), serviços de verificação de identidade (`KYC/KYB`), cotações cambiais e mapas.
- **Processamento Financeiro, Custódia (*Escrow*) & Antifraude:** Taxas de liquidação PIX/cartão junto ao PSP, manutenção das contas-garantia regulamentadas, seguro de transação e prevenção a disputas/chargebacks.
- **Aquisição de Usuários (CAC), Suporte Operacional & Compliance Aduaneiro:** Campanhas para equilibrar oferta de viajantes e demanda de compradores por corredor aéreo, mediação de disputas e assessoria jurídica/contábil PF/PJ.

### 8. Métricas-Chave (*Key Metrics*)
- **GMV & Ticket Médio (> US$ 100):** Volume bruto transacionado por corredor aéreo e economia percentual gerada frente ao varejo local.
- **Conversão do Funil de 4 Etapas:** Taxa de avanço entre `1. Pedido` → `2. Cálculo Fiscal` → `3. Pagamento em Custódia` → `4. Acompanhamento/Entrega`.
- **Liquidez da Malha de Viajantes:** Quilogramas ofertados vs. reservados por rota, tempo médio até *matching* e taxa de entregas concluídas sem disputa (`> 98%`).

### 9. Vantagem Injusta (*Unfair Advantage*)
- **Arquitetura Híbrida Nativa (PF + PJ):** Isolamento estrito de contas pessoais e corporativas desde o banco de dados até a emissão documental para PMEs.
- **Solução do Gargalo Tributário:** Enquanto rivais operam na informalidade, o Trago! integra conformidade aduaneira e transparência fiscal diretamente na experiência de compra.
- **Capital de Giro Positivo & Risco Zero de Estoque:** Zero custo de estoque próprio; a demanda e o depósito em garantia ocorrem antes da execução do transporte.
