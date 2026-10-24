# Trago

Marketplace cross-border para conexão entre compradores (**Pessoa Física** e **Pessoa Jurídica**) e capacidade de transporte internacional disponível com viajantes verificados.

![Design Conceitual](InitialAssets/Design.png)

## Estrutura do Projeto

O repositório mantém uma arquitetura limpa, modular e 100% focada na aplicação mobile em **Flutter** e backend isolado via **Podman**:

```text
Trago/
├── .github/workflows/ # Pipeline de CI/CD automatizado (GitHub Actions)
├── backend/           # API NestJS / Fastify + PostgreSQL (TypeScript)
├── mobile/            # Aplicação Frontend multiplataforma em Flutter (Dart)
├── android/           # Módulo nativo Android (Kotlin + Jetpack Compose)
├── contracts/         # Especificação OpenAPI 3.0 e fixtures de demonstração
├── containers/        # Isolamento Podman (compose.yaml, Containerfile.backend, Containerfile.flutter)
├── docs/              # Documentação de visão de produto e arquitetura
├── InitialAssets/     # Identidade visual (Design.png) e apresentações
└── Makefile           # Comandos simplificados de execução, build e teste
```

---

## Frontend Flutter (`mobile/`)

O aplicativo em `mobile/` foi projetado para o usuário final seguindo a identidade visual em `InitialAssets/Design.png` (paleta Navy `#1B3B5A`, Teal `#329D9C`, Mint `#56C596`, Coral `#F26B5B` e Gold `#F4B942`):

- **Explorar & Catálogo (`ExploreScreen`)**:
  - Mapa interativo de rotas aéreas com **`flutter_map`** + `latlong2` (tiles públicos CartoDB Voyager / OpenStreetMap, arcos geodésicos entre aeroportos `JFK`, `MIA`, `LHR`, `HND`, `CDG` e `GRU`/`GIG`/`CWB`, marcadores interativos e visualização expandida em tela cheia).
  - Barra de cotação cambial ao vivo (`USD`, `EUR`, `GBP` → `BRL`) e clima em tempo real na origem/destino via APIs públicas.
  - Catálogo curado de produtos internacionais com fotos reais (`assets/images/products/`), comparativo de preço EUA vs. Brasil e percentual de economia.
  - Cards de viajantes verificados com retratos reais (`assets/images/travelers/`), avaliação, rota, data e capacidade em kg.
- **Simulador Fiscal & Checkout (`DraftScreen`)**:
  - Alternância instantânea entre **Compra Pessoal (PF - Bagagem Acompanhada)** com isenção de US$ 1.000 e alíquota de 50% sobre o excedente, e **Importação P2B (PJ - Remessa Expressa)** com estimativa de II (60%) + ICMS (18%) e emissão de NF-e de entrada.
  - Geração de **QR Code PIX** interativo (`qr_flutter`) para depósito em garantia (*Escrow*), abertura do link oficial da loja no exterior (`url_launcher`) e compartilhamento do resumo da simulação (`share_plus`).
- **Publicar Viagem (`PublishScreen`)**:
  - Interface para viajantes ofertarem espaço disponível na mala (`kg`), definirem preço por kg e visualizarem o ganho potencial estimado.
- **Minhas Solicitações e Perfil (`OrdersScreen`)**:
  - Acompanhamento de solicitações em estado `DRAFT`, alternância rápida entre perfil **PF** e **PJ**, e criação de novas solicitações.

### Integrações e Pacotes (`pub.dev`)
- [`flutter_map`](https://pub.dev/packages/flutter_map) & [`latlong2`](https://pub.dev/packages/latlong2): Mapa interativo de rotas internacionais, cálculo de distância geodésica em km e arcos de voo.
- **ExchangeRate Open API** (`open.er-api.com`): Cotação comercial em tempo real (`USD/BRL`, `EUR/BRL`, `GBP/BRL`) para o simulador tributário.
- **Open-Meteo API** (`api.open-meteo.com`): Meteorologia ao vivo nos aeroportos de origem e destino.
- [`qr_flutter`](https://pub.dev/packages/qr_flutter), [`url_launcher`](https://pub.dev/packages/url_launcher) e [`share_plus`](https://pub.dev/packages/share_plus): Pagamento via QR Code PIX, inspeção de links de produtos e compartilhamento nativo.

---

## Execução Rápida via Podman

Todo o ambiente de banco de dados PostgreSQL e API backend roda isolado em containers Podman:

```bash
# Iniciar PostgreSQL e Backend via Podman
make up

# Verificar status da saúde da API
curl http://localhost:3001/health

# Executar a suíte de testes do Backend e do Flutter
make backend-test
make flutter-test

# Executar a aplicação Flutter
make flutter-run

# Parar os containers
make down
```

---

## Pipeline de CI/CD (GitHub Actions)

O workflow em [`.github/workflows/ci-cd.yml`](.github/workflows/ci-cd.yml) executa automaticamente em cada `push` e `pull_request` na branch `main`:

1. **`backend-ci`**: Sobe um serviço PostgreSQL 17, instala dependências Node.js, valida o build TypeScript (`npm run build`) e executa os testes de contrato e integração (`npm test`).
2. **`flutter-ci`**: Configura o SDK do Flutter, valida estaticamente o código (`flutter analyze`), executa os testes unitários e de widgets (`flutter test`) e compila os artefatos de produção (**Android APK Release** e **Web Bundle**), publicando-os no GitHub Actions Artifacts.
3. **`container-cd`**: Valida a construção das imagens OCI (`containers/Containerfile.backend` e `containers/Containerfile.flutter`).
