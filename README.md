# Trago

Protótipo acadêmico de marketplace entre compradores e viajantes. As contas e viagens de exemplo não têm verificação de identidade. A API e o Flutter oferecem cadastro, login, restauração e logout de sessões JWT com expiração.

![Design Conceitual](InitialAssets/Design.png)

### Lean Canvas (`InitialAssets/LeanCanvas.png`)

![Lean Canvas Trago!](InitialAssets/LeanCanvas.png)

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
  - Consulta opcional de câmbio e clima em APIs públicas, com valores de exemplo identificados quando a consulta falha.
  - Catálogo curado de produtos internacionais com fotos reais (`assets/images/products/`), comparativo de preço EUA vs. Brasil e percentual de economia.
  - Cards de viagens de exemplo com avaliações ilustrativas e sem verificação documental.
- **Estimativa e solicitação (`DraftScreen`)**:
  - Estimativa ilustrativa de valores, sem cálculo fiscal oficial, NF-e ou garantia aduaneira.
  - Solicitação gravada na API somente quando ela responde com sucesso. O envio pendente não reserva capacidade; a reserva ocorre apenas após aceite confirmado.
- **Publicar Viagem (`PublishScreen`)**:
  - Interface para viajantes ofertarem espaço disponível na mala (`kg`), definirem preço por kg e visualizarem o ganho potencial estimado.
- **Minhas Solicitações e Perfil (`OrdersScreen`)**:
  - Acompanhamento dos estados `PENDING`, `ACCEPTED` e `REJECTED` confirmados pela API.
- **Solicitações recebidas (`IncomingRequestsScreen`)**:
  - Caixa de entrada do viajante com detalhe, aceite e rejeição. O aceite confirmado reserva capacidade, mas não confirma pagamento ou custódia.

### Integrações e Pacotes (`pub.dev`)
- [`flutter_map`](https://pub.dev/packages/flutter_map) & [`latlong2`](https://pub.dev/packages/latlong2): Mapa interativo de rotas internacionais, cálculo de distância geodésica em km e arcos de voo.
- **ExchangeRate Open API** (`open.er-api.com`): Cotação comercial em tempo real (`USD/BRL`, `EUR/BRL`, `GBP/BRL`) para o simulador tributário.
- **Open-Meteo API** (`api.open-meteo.com`): Meteorologia ao vivo nos aeroportos de origem e destino.
- [`url_launcher`](https://pub.dev/packages/url_launcher) e [`share_plus`](https://pub.dev/packages/share_plus): Abertura de links de produtos e compartilhamento de estimativas rotuladas como simulação.

---

## Execução Rápida via Podman

Todo o ambiente de banco de dados PostgreSQL e API backend roda isolado em containers Podman:

```bash
# Gere um segredo aleatório e exporte AUTH_JWT_SECRET antes de iniciar.
# Exemplo Bash:
export AUTH_JWT_SECRET="$(node -p "require('node:crypto').randomBytes(48).toString('base64')")"
make up

# Verificar status da saúde da API
curl http://localhost:3001/health

# Executar a suíte de testes do Backend e do Flutter
make backend-test
make flutter-test

# Executar a aplicação Flutter em emulador Android (modo demo)
cd mobile
flutter run --dart-define=TRAGO_DEMO_MODE=true --dart-define=API_BASE_URL=http://10.0.2.2:3001

# Parar os containers
make down
```

---

## Pipeline de CI/CD (GitHub Actions)

O workflow em [`.github/workflows/ci-cd.yml`](.github/workflows/ci-cd.yml) executa automaticamente em cada `push` e `pull_request` na branch `main`:

1. **`backend-ci`**: Sobe um serviço PostgreSQL 17, instala dependências Node.js, valida o build TypeScript (`npm run build`) e executa os testes de contrato e integração (`npm test`).
2. **`flutter-ci`**: Configura o SDK do Flutter, valida o código, executa os testes e compila um APK release. Sem `TRAGO_API_BASE_URL`, produz uma versão de demonstração isolada; com a variável configurada, exige uma URL HTTPS para a API real.
3. **`release-apk`**: após os testes, publica o APK em GitHub Releases nos pushes da `main` e em tags `v*`, mantendo o comportamento de distribuição existente no projeto.
4. **`container-cd`**: Valida a construção da imagem OCI do backend (`containers/Containerfile.backend`).

### Configuração e limites da demonstração

`TRAGO_DEMO_MODE=true` habilita os tokens sintéticos `dev:*` somente no ramo de demonstração e mostra um banner específico. O backend requer `TRAGO_DEMO_AUTH=true` e `NODE_ENV=development` (ou `test`); rejeita essa configuração em produção. No modo normal, o Flutter mostra cadastro/login e usa apenas o JWT real. `API_BASE_URL` é obrigatório: use `http://localhost:3001` no desktop/iOS Simulator, `http://10.0.2.2:3001` no emulador Android e o IP da máquina host em aparelho físico. Para um APK release integrado, configure a variável de repositório `TRAGO_API_BASE_URL` com a URL HTTPS pública do backend. Enquanto ela não estiver configurada, o workflow publica uma versão demonstrativa, sem identidade real de produção.

O backend permite CORS para `http://localhost:3000` e `http://127.0.0.1:3000` fora de produção. Defina `CORS_ORIGINS` como lista de origens separadas por vírgula quando necessário; em produção, o padrão é nenhuma origem. CORS não substitui autenticação.

Para testar no PowerShell após iniciar PostgreSQL e a API, execute `cd backend; npm ci; $env:DATABASE_URL='postgresql://trago:tragopassword@localhost:5432/trago'; npm run check`. No Flutter, use `cd mobile; flutter pub get; flutter analyze; flutter test`. Veja [o relatório de implementação](docs/IMPLEMENTATION_STATUS.md) para o estado verificado e as limitações.

## Autenticação, contas, viagens, decisões e capacidade (T04–T09)

`POST /v1/auth/register` recebe `email`, `password` (12 a 128 caracteres) e `displayName`. `POST /v1/auth/login` recebe email e senha. Ambos retornam uma sessão JWT Bearer. `GET /v1/auth/me` identifica o usuário da sessão; `POST /v1/auth/logout` revoga essa sessão no PostgreSQL. Senhas usam Argon2id. A sessão expira em 15 minutos por padrão.

Configure `AUTH_JWT_SECRET` com um segredo aleatório de pelo menos 32 bytes; `AUTH_TOKEN_TTL_SECONDS` aceita 60 a 86400 segundos. Sem segredo válido a API recusa iniciar. No PowerShell, gere para a sessão atual com `$env:AUTH_JWT_SECRET = node -p "require('node:crypto').randomBytes(48).toString('base64')"`. Para compose, as variáveis também podem estar em `.env`, a partir de `.env.example` (nunca commitar o segredo). Preserve o segredo entre reinícios para manter as sessões válidas.

O cadastro cria uma única conta pessoal vinculada ao usuário. `POST /v1/me/accounts/organizations` cria uma conta empresarial e `POST /v1/me/accounts/{accountId}/members` permite que somente o titular conceda acesso a outro usuário já cadastrado. Todas as consultas e operações com `accountId` repetem a autorização no backend. O mesmo JWT pode criar pedidos e publicar viagens pelo endpoint existente; a API deriva a identidade da sessão.

Viagens reais usam `POST /v1/trips` com `Idempotency-Key`. A busca pública exclui viagens canceladas e expiradas; `GET /v1/me/trips` lista as viagens do titular. Detalhes, edição e cancelamento estão em `/v1/trips/{id}` e `/v1/trips/{id}/cancel`. Cancelar preserva pedidos existentes e impede novos pedidos; edição é recusada quando já há pedido associado.

Solicitações nascem `PENDING`. O viajante consulta `GET /v1/me/incoming-requests` e decide em `/v1/purchase-requests/{id}/accept` ou `/reject`; o comprador acompanha pela conta autorizada. O backend valida a titularidade pela sessão, bloqueia viagem e pedido em ordem fixa e audita cada mudança terminal. O aceite reserva atomicamente o peso em gramas; saldo insuficiente retorna 422 e repetir o aceite não desconta novamente. Rejeição não consome capacidade. O aceite continua sem representar pagamento, custódia ou confirmação de transporte.

O Flutter guarda o token com `flutter_secure_storage`, revalida a sessão em `/v1/auth/me`, carrega e alterna apenas contas autorizadas e limpa dados privados em 401/logout. No Android o backup do armazenamento foi desabilitado; iOS usa Keychain, macOS usa Keychain sem Data Protection, e Web exige HTTPS ou localhost. Detalhes e limitações estão no [relatório](docs/IMPLEMENTATION_STATUS.md).
