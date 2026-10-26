# API local Trago — T04 a T09

NestJS/Fastify, TypeScript e PostgreSQL. O contrato de entrada e resposta está em `../contracts/http/openapi.json`, usado pelo AJV e pelos testes.

## Execução

Requer Node 22+ e PostgreSQL. A API aplica `migrations/*.sql` em transação, com lock e registro de versão. Não há fallback de banco.

```powershell
cd backend
npm ci
$env:DATABASE_URL = 'postgresql://USER:PASSWORD@127.0.0.1:5432/DATABASE'
$env:AUTH_JWT_SECRET = node -p "require('node:crypto').randomBytes(48).toString('base64')"
$env:AUTH_TOKEN_TTL_SECONDS = '900'
$env:TRAGO_DEMO_AUTH = 'false'
$env:NODE_ENV = 'development'
npm run dev
```

Use um banco local dedicado e substitua os placeholders. Preserve o segredo em ambiente privado entre reinícios; não gere um novo a cada inicialização se precisar conservar sessões. A API escuta a porta 3001. O exemplo `.env.example` da raiz lista as variáveis; Node não carrega `.env` automaticamente. Depois de compilar, Node 22 também aceita `node --env-file=../.env dist/main.js`.

`AUTH_JWT_SECRET` é obrigatório, com no mínimo 32 bytes. `AUTH_TOKEN_TTL_SECONDS` aceita inteiros de 60 a 86400 segundos, padrão 900. Configuração inválida impede inicialização. O JWT usa somente HS256, issuer `trago-api`, audience `trago-client`, `sub` do usuário, `jti` da sessão e expiração obrigatória. Cada acesso verifica assinatura, expiração e sessão ativa no banco.

## Autenticação

| Endpoint | Entrada | Resposta |
|---|---|---|
| `POST /v1/auth/register` | `email`, `password`, `displayName` | 201 com `accessToken`, `tokenType`, `expiresIn`, `user` |
| `POST /v1/auth/login` | `email`, `password` | 200 com o mesmo formato de sessão |
| `GET /v1/auth/me` | `Authorization: Bearer <accessToken>` | 200 com `id`, `email`, `displayName`, `createdAt` |
| `POST /v1/auth/logout` | mesmo header | 204, revoga apenas a sessão apresentada |

- Cadastro exige senha de 12 a 128 caracteres; ela não é aparada nem normalizada. Argon2id usa salt aleatório, 64 MiB, três iterações e paralelismo 1. Senhas e hashes não aparecem nas respostas.
- Email é validado e armazenado em minúsculas, com unicidade no PostgreSQL. Nome deve conter texto e ter até 100 caracteres. Campos extras são rejeitados.
- Cadastro de email duplicado retorna 409. Login com email inexistente ou senha incorreta retorna o mesmo 401 genérico e executa verificação Argon2 em ambos os casos.
- Sessões ficam em `auth_sessions`, sem armazenar o token bruto. Logout e expiração continuam valendo após reiniciar a API. Não há refresh token nesta etapa; após expirar, faça login novamente.
- Respostas de autenticação têm `Cache-Control: no-store`. Em produção, exponha a API por HTTPS.
- Registro: 10 tentativas por IP a cada 15 minutos. Login: 30 por IP e 10 por email no mesmo período. Os contadores são atômicos e compartilhados no PostgreSQL, persistem entre reinícios e retornam 429 após o limite. O IP vem da conexão Fastify; headers encaminhados não são confiados. Ao usar proxy, ajustar a política de proxy confiável e limite por IP antes da implantação. As chaves persistidas são HMACs, não emails/IPs em texto. Contadores com mais de um dia são removidos durante novas tentativas.

`users` contém somente identidades reais cadastradas. Cada cadastro cria, na mesma transação, uma conta `PERSONAL`; a migração `003_account_ownership.sql` também provisiona contas para usuários T04 já existentes. `GET /v1/me/accounts` retorna apenas contas próprias ou com associação ativa. O titular cria uma conta `ORGANIZATION` em `POST /v1/me/accounts/organizations` e concede acesso a um usuário cadastrado em `POST /v1/me/accounts/{accountId}/members`. O MVP não coleta CNPJ nem envia convite por email.

O mesmo usuário autenticado pode criar pedidos com uma conta autorizada e publicar uma viagem. Titularidade, associação e nome do viajante vêm da sessão e do PostgreSQL; IDs enviados pelo cliente são validados novamente. As colunas e tabelas legadas foram preservadas para a demonstração, sem converter fixtures em usuários autenticáveis.

## Gestão de viagens

| Endpoint | Comportamento |
|---|---|
| `POST /v1/trips` | Publica com `Idempotency-Key` e titular obtido da sessão |
| `GET /v1/trips` | Busca somente viagens disponíveis e não expiradas |
| `GET /v1/me/trips` | Lista todas as viagens do usuário, inclusive canceladas/expiradas |
| `GET /v1/trips/{id}` | Detalhe público enquanto disponível; depois, somente para o titular |
| `PATCH /v1/trips/{id}` | Edita viagem disponível, própria e sem pedidos associados |
| `POST /v1/trips/{id}/cancel` | Cancelamento lógico idempotente, preservando pedidos |

Origem e destino precisam ser diferentes, a data deve ser futura no fuso informado, o peso deve ficar entre 1 g e 100 kg e a tarifa deve ser positiva. As respostas expõem capacidade total, reservada e disponível em gramas inteiras. Viagens sem saldo deixam a busca; viagens canceladas/expiradas não aceitam pedidos novos nem novas decisões.

## Solicitações e decisões

| Endpoint | Comportamento |
|---|---|
| `POST /v1/purchase-requests` | Cria uma solicitação `PENDING` para uma conta autorizada |
| `GET /v1/purchase-requests?accountId=...` | Acompanha as solicitações enviadas pela conta PF/PJ autorizada |
| `GET /v1/me/incoming-requests` | Lista solicitações das viagens do usuário autenticado |
| `GET /v1/purchase-requests/{id}` | Detalhe para comprador autorizado ou proprietário da viagem |
| `POST /v1/purchase-requests/{id}/accept` | Transição `PENDING → ACCEPTED` pelo proprietário |
| `POST /v1/purchase-requests/{id}/reject` | Transição `PENDING → REJECTED` pelo proprietário |

As decisões adquirem locks na ordem viagem → pedido, persistem capacidade, pedido e evento de auditoria na mesma transação e derivam o proprietário da sessão. Aceitar incrementa `reserved_capacity_grams` somente se houver saldo; insuficiência retorna `422 CAPACITY_EXCEEDED`. Repetir o mesmo aceite é seguro e não desconta novamente; uma decisão terminal oposta retorna 409. Viagem cancelada ou expirada impede uma nova decisão. O aceite reserva capacidade, mas não confirma pagamento, custódia ou transporte.

`006_trip_capacity_reservations.sql` calcula a reserva de pedidos aceitos antes da T09. Se o legado já exceder a capacidade declarada, a migração falha para exigir correção explícita. Cancelar uma viagem preserva reservas já aceitas; não existe nesta etapa uma transição de cancelamento de pedido que libere o peso.

## Compatibilidade da demonstração

`TRAGO_DEMO_AUTH=true` só é permitido com `NODE_ENV=development` ou `test`. Fora desses ambientes, a API recusa iniciar com demo ativa. Sem essa opção, tokens `dev:*` retornam 401. Mesmo no modo demo, `/v1/auth/me` e `/v1/auth/logout` exigem sessão JWT real. As identidades fixas existentes servem somente às rotas legadas da demonstração.

O compose configura demo explicitamente; a imagem do backend tem defaults `NODE_ENV=production` e `TRAGO_DEMO_AUTH=false`. Use bancos separados para demonstração e implantação.

As rotas de contas, viagens e pedidos preservam autorização a cada acesso, respostas 404 consistentes para recursos privados ausentes ou alheios e idempotência PostgreSQL. `POST /v1/purchase-requests` gera `PENDING`; somente o proprietário da viagem pode decidir. Regras de dinheiro permanecem fora da T09.

`/health` é público. `CORS_ORIGINS` recebe origens separadas por vírgula; por padrão, apenas localhost/127.0.0.1 na porta 3000 em desenvolvimento/teste e nenhuma origem em produção. CORS não substitui autenticação.

## Testes

Com `DATABASE_URL` apontando para PostgreSQL dedicado, execute `npm run check`. Os testes geram seu próprio segredo e senhas aleatórias dentro do processo, validam respostas contra OpenAPI e limpam os usuários/recursos criados. As fixtures de autenticação contêm somente nomes e emails sintéticos.

A suíte verifica os fluxos legados, autenticação, conta PF concorrente, titularidade PF/PJ, isolamento, publicação idempotente, ciclo de viagens e decisões. Os casos T09 incluem saldo insuficiente, aceites simultâneos, repetição, rejeição sem consumo, cancelamento concorrente, rollback integral, consistência do agregado e backfill de pedidos aceitos antes da migração.

Resultados efetivamente executados e limitações estão em `../docs/IMPLEMENTATION_STATUS.md`. Nenhuma integração de pagamento, identidade documental ou rastreio foi adicionada.
