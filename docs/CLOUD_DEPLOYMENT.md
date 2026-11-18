# Trago Cloud MVP

Diagnóstico e preparação em 17/11/2026. A base é a `main` no merge `e704787` do PR #1. A criação dos serviços e a implantação aguardam aprovação.

## Arquitetura e escopo

Flutter → API NestJS/Fastify no Render via HTTPS → PostgreSQL no Supabase via TLS verificado. O próprio backend continua emitindo JWT, armazenando senhas com Argon2id e verificando as sessões no PostgreSQL. O APK recebe apenas a URL pública da API. O GitHub Actions executa as suítes e produz o APK Android.

| Etapas | Estado |
| --- | --- |
| T00–T03 | Base local, contratos, autorização e idempotência cobertas pela regressão existente |
| T04–T06 | Cadastro, login, revogação de sessão, persistência segura no Flutter e contas PF/PJ com controle de acesso |
| T07–T09 | Gestão de viagens, pedidos, decisões do viajante e reserva de capacidade com transações |
| T10–T12 | Fora do escopo atual. O [backlog de consolidação](CLOUD_MVP_BACKLOG.md) registra a semântica monetária da T10 e as pendências que ainda precisam de escopo aprovado |

O aceite reserva o peso declarado. Valores exibidos são estimativas. Use contas e produtos fictícios nas validações do MVP.

## 1. Preparar o Supabase após aprovação

1. Crie um projeto Free exclusivo para o Trago em uma região próxima da região escolhida para o Render.
2. No painel, abra **Integrations → Data API → Overview** e desative **Enable Data API**. Mantenha `trago` fora da lista de schemas expostos e, se o controle estiver disponível, desative **Automatically expose new tables**. As tabelas incluem hashes de senhas, sessões, contas e pedidos. As migrações do Trago não criam políticas RLS, por isso nenhum schema da aplicação deve ir para a Data API. [Supabase — segurança da Data API](https://supabase.com/docs/guides/api/securing-your-api#disable-the-data-api).
3. Em **Connect**, copie o host e os parâmetros de **Session pooler** (porta 5432) e baixe a CA indicada para esse endpoint. O pooler de sessão funciona por IPv4 e mantém a sessão usada pelo `SET search_path`. A conexão direta gratuita costuma exigir IPv6. Use o DSN da modalidade de sessão para este guia. Habilite a exigência de SSL nas configurações do banco antes do uso pelo MVP. [Conexões PostgreSQL](https://supabase.com/docs/guides/database/connecting-to-postgres) · [SSL enforcement](https://supabase.com/docs/guides/platform/ssl-enforcement).
4. Conecte com `psql` como administrador usando `sslmode=verify-full` e `sslrootcert` com o arquivo baixado. Forneça a senha pelo prompt. Em um projeto novo, execute os comandos abaixo. O prompt de `\password` recebe uma senha aleatória exclusiva, que deve ser guardada no gerenciador de segredos. [Supabase — conexão com psql](https://supabase.com/docs/guides/database/psql).

```sql
CREATE ROLE trago_app NOLOGIN;
GRANT trago_app TO postgres;
CREATE SCHEMA trago AUTHORIZATION trago_app;
REVOKE ALL ON SCHEMA trago FROM PUBLIC, anon, authenticated, service_role;
\password trago_app
ALTER ROLE trago_app LOGIN;
```

5. Use o host do painel e o usuário `trago_app.<PROJECT_REF>` no DSN do pooler. Codifique caracteres reservados na senha para uso na URL. Valide a conexão com esse papel antes de configurar o Render. Ele é dono do schema para aplicar as migrações no boot. Revise se `anon` e `authenticated` não têm `USAGE` no schema com `has_schema_privilege`. Separe projetos e credenciais para dados reais e testes.

### Migrações

As migrações `001` a `006` usam PostgreSQL padrão, incluindo índices parciais, JSONB, PL/pgSQL, chaves estrangeiras e locks transacionais. Não requerem extensões ou privilégios de superusuário. A API configura `search_path` por conexão e aplica os arquivos em uma transação com trava consultiva. A tabela `trago.api_migrations` registra quais arquivos foram aplicados. O deploy só atende requisições depois da inicialização. Se houver dados legados a importar, valide a origem em uma cópia antes. A `006` interrompe e reverte a migração quando os pedidos já aceitos excedem a capacidade declarada.

## 2. Preparar o Render após aprovação

- Crie um **Web Service** Free com runtime **Docker** e o repositório GitHub. Escolha a branch revisada que contém esta preparação. Use a raiz do repositório como contexto, `./containers/Containerfile.backend` como Dockerfile e `/health` como **Health Check Path**. O processo do contêiner roda como usuário `node`. Comece com deploy automático desativado. [Docker no Render](https://render.com/docs/docker).
- Configure as variáveis no painel do Render. O segredo JWT e as credenciais do banco ficam no servidor. Guarde o segredo JWT entre reinícios para manter sessões e contadores. Gere um valor aleatório de 48 bytes fora do Git. Se houver rotação, os JWTs existentes deixam de funcionar.

| Variável | Valor |
| --- | --- |
| `NODE_ENV` | `production` |
| `PORT` | Valor injetado pelo Render. A API escuta em `0.0.0.0` e usa `3001` no ambiente local quando omitido. [Porta no Render](https://render.com/docs/web-services#port-binding) |
| `TRAGO_DEMO_AUTH` | `false`. O backend recusa iniciar em produção com demo ativa |
| `DATABASE_URL` | `postgresql://trago_app.<PROJECT_REF>:<SENHA_CODIFICADA>@<HOST_DO_SESSION_POOLER>:5432/postgres`. Cole sem parâmetros de URL |
| `DATABASE_TLS` | `true`, obrigatório em produção |
| `DATABASE_TLS_CA_FILE` | `/app/certs/prod-ca-2021.crt` na imagem do Render. Para rodar fora do contêiner, use o caminho local ou `DATABASE_TLS_CA` com o PEM completo, uma opção por vez. O driver verifica tanto a cadeia do certificado quanto o hostname. [TLS no node-postgres](https://node-postgres.com/features/ssl) |
| `DATABASE_SCHEMA` | `trago` |
| `AUTH_JWT_SECRET` | Segredo exclusivo do Trago, com pelo menos 32 bytes |
| `AUTH_TOKEN_TTL_SECONDS` | `900` por padrão |
| `AUTH_MAX_CONCURRENT` | Comece com `2` |
| `TRUST_PROXY_HOPS` | Comece com `0` e configure a quantidade de proxies somente após verificar a cadeia real de entrada |
| `CORS_ORIGINS` | Vazio para APK nativo. Para Flutter Web, lista de origens HTTPS exatas separadas por vírgula |

### Controles de operação

- O limite por IP usa o endereço da conexão com `TRUST_PROXY_HOPS=0`. Atrás do Render isso pode agrupar clientes no mesmo IP do proxy. Antes de abrir o MVP, verifique a cadeia de entrada com duas origens distintas. Confirme que cada origem usa seu próprio contador, que variações nos valores enviados pelo cliente à esquerda em `X-Forwarded-For` não criam novos contadores, e que todo tráfego chega pelo mesmo conjunto de proxies confiáveis. Use o menor número de saltos que chega ao IP correto, contando a partir da conexão. Se a topologia variar, mantenha `0` até definir uma regra específica. [Render — IP do cliente](https://render.com/articles/how-render-handles-ddos-attacks#reading-the-true-client-ip) · [Fastify — trustProxy](https://fastify.dev/docs/latest/Reference/Server/#trustproxy).
- Os limites persistem no PostgreSQL por 15 minutos. Cadastro permite 10 tentativas por IP e login permite 30 por IP e 10 por email. Em paralelo, a API admite duas operações de autenticação por processo por padrão. Cada hash ou verificação Argon2id usa cerca de 64 MiB de memória de trabalho e a fila de autenticação é limitada pela rejeição imediata com `503 AUTH_BUSY`. O total do processo inclui o restante do Node. Observe CPU, memória e latência no Render antes de aumentar o limite. O pool PostgreSQL usa até cinco conexões por processo e espera até cinco segundos para obter uma conexão.
- Render Free informa 512 MB de RAM, 0,1 CPU e suspensão após 15 minutos sem tráfego. A retomada costuma levar cerca de um minuto. O Flutter espera até 90 segundos por chamada HTTPS, trata páginas de inicialização e evita repetir gravações automaticamente. O PostgreSQL Free no Supabase tem 500 MB de dados, pode pausar por inatividade e não inclui backups automáticos. Defina um processo de backup e restauração antes de depender desses dados. [Render Free](https://render.com/docs/free) · [Render — recursos por plano](https://render.com/docs/compute-plans) · [Supabase Free](https://supabase.com/pricing).

## 3. Validar antes de distribuir

1. Confirme que `GET https://<SERVICO>.onrender.com/health` retorna `200 {"status":"ok"}` e que `trago.api_migrations` registra `001` a `006`. Confira que o schema `public` não recebeu tabelas do Trago, que a Data API está desativada e que rotas protegidas rejeitam tokens de demonstração e requisições sem JWT.
2. Cadastre dois usuários fictícios. No primeiro, publique uma viagem. No segundo, selecione a viagem e envie uma solicitação. Verifique o isolamento das contas e dos pedidos, aceite com o viajante e confirme o saldo de capacidade. Repita o aceite e confirme que o peso é descontado uma vez. Faça logout e confirme a revogação do token. Teste o primeiro acesso após a suspensão do Render.
3. Após verificar a API HTTPS, configure a variável de repositório GitHub `TRAGO_API_BASE_URL` com a URL pública e execute o workflow manualmente. Baixe o artefato `trago-release-apk` no Actions, instale em Android e repita o passo 2. O workflow faz uma compilação integrada quando a URL HTTPS está presente e uma demonstração isolada quando está vazia. Somente pushes de tags `v*` publicam um GitHub Release. O APK ainda usa a assinatura de desenvolvimento. Planeje assinatura própria antes de distribuir a um público amplo.

## Testes locais e CI

```powershell
# A partir da raiz do repositório. O Podman Machine precisa estar ativo.
Set-Location backend
npm ci
$env:TRAGO_TEST_CONTAINER_ENGINE = 'podman'
npm run check
Set-Location ../mobile
flutter pub get
flutter analyze
flutter test
```

Com Docker, pode omitir `TRAGO_TEST_CONTAINER_ENGINE`. Cada execução cria e remove seu próprio PostgreSQL 17, com porta local aleatória, sem volume do Trago e com credenciais geradas na hora. A suíte usa certificado de teste próprio para verificar a conexão TLS de produção. O `DATABASE_URL` externo não é usado pelos testes.

### Resultados desta preparação

| Verificação | Resultado local |
| --- | --- |
| `npm run check` com Podman | TypeScript compilado e 17 testes aprovados com PostgreSQL 17, mesmo com uma `DATABASE_URL` externa fictícia no ambiente |
| Imagem backend | Build OCI aprovado. Em Node 22 e com limite de 512 MB, iniciou na porta 10000, aplicou as seis migrações com TLS, respondeu 200 em `/health` e rejeitou um token demo com 401 |
| Dependências de produção | `npm audit --omit=dev` reportou zero vulnerabilidades após a atualização do adaptador NestJS/Fastify e do lockfile |
| Flutter | 43 testes aprovados e `flutter analyze` sem problemas |
| APK Android | Build release local concluído com uma URL HTTPS fictícia. `apksigner verify` confirmou assinatura v2 de desenvolvimento. O Flutter emitiu avisos sobre versões futuras de Gradle, AGP e Kotlin |

A validação do APK nesta etapa foi de compilação e assinatura. A cadeia real de proxies no Render, os tempos de retomada e a execução do workflow no GitHub Actions ainda precisam ser verificados.

## T14 — Integração local com Supabase

Validação executada em 17/11/2026.

O projeto Free em São Paulo usa **Session pooler**, porta 5432, banco `postgres` e certificado `certs/prod-ca-2021.crt`. A Data API está desativada conforme a configuração informada pelo responsável pelo projeto. A conexão até o pooler negociou TLS 1.3 com cadeia e hostname verificados, antes da autenticação. A credencial administrativa é solicitada em um prompt local com entrada oculta. A configuração de execução contém somente a credencial do papel dedicado e o segredo JWT.

No Windows, a preparação local desta etapa usa `%LOCALAPPDATA%\TragoCloud`, um diretório restrito à conta Windows que configurou o Trago. O arquivo `runtime.env` fica nessa pasta e fora do Git. Se a configuração já existir, o script de provisionamento para antes de pedir senha ou alterar objetos do banco. O certificado é público. Para iniciar o backend local em uma sessão futura, execute `node "$env:LOCALAPPDATA\TragoCloud\start-backend.cjs"` no PowerShell. O serviço escuta somente em `127.0.0.1:3001`.

| Verificação | Resultado |
| --- | --- |
| DNS, TCP 5432 e TLS com a CA fornecida | Confirmados |
| Login administrativo, schema `trago` e papel `trago_app` | Confirmados. O backend conectou como `trago_app`. Os papéis `anon`, `authenticated` e `service_role` não têm `USAGE` no schema |
| Migrações e API | Seis arquivos, de `001` a `006`, registrados em `trago.api_migrations`. `public.api_migrations` ausente, nenhuma identidade demo no schema e `GET /health` retornando 200 |
| Fluxo com dois usuários fictícios | Cadastro, login, isolamento PF, publicação, busca de viagem, pedido e aceite aprovados. Tentativa de aceite pelo comprador retornou 404. Repetir o aceite manteve 1.300 g reservados e 6.700 g disponíveis de um total de 8.000 g |
| Persistência após reinício | Confirmada em um novo processo do backend, com o mesmo pedido aceito, a mesma capacidade, JWT anterior válido e novo login bem-sucedido |

A validação deixou os registros identificados como T14 para conferência e realizou apenas operações de criação, consulta e aceite. A suíte de testes destrutivos permaneceu restrita ao banco descartável. A validação desta etapa foi pela API.

## T15 — Preparação do Dashboard do Render

Use estes campos depois da aprovação e do envio da branch revisada. O botão **Create Web Service** dispara a primeira implantação mesmo com Auto Deploy desligado. [Criação de Web Services no Render](https://render.com/docs/web-services).

| Campo | Valor |
| --- | --- |
| Tipo | **New → Web Service** |
| Source | Repositório GitHub `TheHugoHypothesis/Trago` |
| Name | `trago-api`, se disponível |
| Branch | `feat/cloud-mvp` |
| Language / Runtime | Docker |
| Instance Type | Free |
| Region | Virginia (US East), região inicial recomendada. [Regiões do Render](https://render.com/docs/regions) |
| Root Directory | Deixe vazio, para usar a raiz |
| Dockerfile Path | `./containers/Containerfile.backend` |
| Docker Build Context Directory | `.` |
| Docker Command | Deixe vazio para usar o `CMD` da imagem |
| Health Check Path | `/health` |
| Auto Deploy | Off |
| Secret Files / Persistent Disk | Nenhum |

Para novas branches no Trago, use prefixos como `feat/`, `fix/`, `chore/` ou `docs/`.

Em **Environment Variables**, cadastre os valores abaixo. `RENDER=true` e `PORT` são automáticos. A API escuta em `0.0.0.0` na porta indicada pela plataforma. [Variáveis padrão do Render](https://render.com/docs/environment-variables).

| Chave | Valor |
| --- | --- |
| `NODE_ENV` | `production` |
| `TRAGO_DEMO_AUTH` | `false` |
| `DATABASE_URL` | Copie privadamente o valor da conexão com `trago_app` em `%LOCALAPPDATA%\TragoCloud\runtime.env`. Deve ter o formato `postgresql://trago_app.<PROJECT_REF>:<SENHA_CODIFICADA>@aws-0-sa-east-1.pooler.supabase.com:5432/postgres`, sem opções de URL |
| `DATABASE_SCHEMA` | `trago` |
| `DATABASE_TLS` | `true` |
| `DATABASE_TLS_CA_FILE` | `/app/certs/prod-ca-2021.crt` |
| `AUTH_JWT_SECRET` | Novo segredo exclusivo do Render, gerado com 48 bytes aleatórios e guardado no gerenciador de segredos |
| `AUTH_TOKEN_TTL_SECONDS` | `900` |
| `AUTH_MAX_CONCURRENT` | `2` |
| `TRUST_PROXY_HOPS` | `0` |

Deixe `DATABASE_TLS_CA` e `CORS_ORIGINS` ausentes. A CA raiz pública do Supabase vai na imagem e é legível pelo usuário `node`. O backend no Render exige uma CA explícita e confere, em cada conexão, se os papéis efetivo e de sessão são `trago_app` sem atributos elevados nem associação a outros papéis. Uma URL administrativa é recusada antes da conexão.

Com `TRUST_PROXY_HOPS=0`, a aplicação ignora cabeçalhos de encaminhamento fornecidos pelo cliente e aplica os limites de IP ao endereço do socket. Clientes que chegam pelo mesmo proxy podem compartilhar a cota e receber `429`. O limite por email e o limite de concorrência continuam ativos. A topologia real precisa ser verificada antes de aumentar o número de saltos ou liberar o MVP para mais usuários. Evite configurar um número com base apenas em exemplos da documentação, pois uma cadeia mais curta pode tornar um valor encaminhado pelo cliente indistinguível de um valor confiável. [IP do cliente no Render](https://render.com/articles/how-render-handles-ddos-attacks#reading-the-true-client-ip).

### Verificações antes do primeiro deploy

- O Gitleaks verificou o diff e o conteúdo completo dos arquivos preparados para o commit. O único arquivo de ambiente versionado é `.env.example`, com valores de exemplo. A imagem foi inspecionada sem rede para confirmar a ausência de arquivos de credenciais e a leitura da CA pública pelo usuário `node`.
- A suíte voltou a passar com 17 testes de backend em PostgreSQL 17 descartável e 43 testes Flutter. A análise estática Flutter também passou. A regressão de backend confirmou a rejeição de papel administrativo ou elevado e o comportamento do limite de IP com cabeçalhos não confiáveis.
- O build Docker foi validado localmente. O Supabase do MVP ficou fora da suíte da preparação.

### Validação do deploy da T15

Em 17/11/2026, o serviço informado no Render estava em `https://trago-qyfz.onrender.com`, com a branch `feat/cloud-mvp` e o commit `7fc0ba2`. O endpoint [`/health`](https://trago-qyfz.onrender.com/health) retornou HTTP 200 e `{"status":"ok"}` com a validação TLS ativa.

- Foram verificados via HTTPS cadastro e login de dois usuários fictícios, isolamento de contas PF, publicação e consulta de viagem, pedido e aceite. Uma tentativa de aceite pelo comprador retornou 404. Repetir o aceite manteve 1.300 g reservados e 6.700 g disponíveis.
- O logout revogou a sessão anterior. Um novo login recuperou o mesmo pedido aceito e a mesma capacidade pelo backend do Render. A persistência no Supabase foi observada pela API. A validação não reiniciou o serviço.
- Em um email fictício exclusivo, os dez primeiros logins inválidos retornaram 401 e o 11º retornou 429. O bloqueio por email persistiu com um valor de `X-Forwarded-For` diferente. Outro email retornou 401, mostrando que o bloqueio observado era específico do email. A separação das cotas por IP entre origens reais no Render ainda não foi medida.
- O responsável pelo deploy confirmou a substituição das credenciais e os ajustes no Supabase e no Render. As credenciais anteriores não foram reutilizadas para testar a rotação.

## T16 — APK Android conectado à nuvem

Para reproduzir a compilação, execute no diretório `mobile`:

```powershell
flutter build apk --release --dart-define=API_BASE_URL=https://trago-qyfz.onrender.com --dart-define=TRAGO_DEMO_MODE=false
```

O primeiro teste no emulador detectou que a variante release não tinha a permissão `android.permission.INTERNET`. A permissão foi adicionada ao manifesto principal do Android e confirmada no APK recompilado. O APK usa HTTPS e mantém a demonstração desativada.

O APK de teste `Trago-Cloud-MVP.apk` foi salvo localmente, com aproximadamente 52,9 MiB. O pacote é `com.trago.trago`, exige Android API 24 ou superior e inclui binários ARM de 32 e 64 bits e x86_64. O `apksigner verify` confirmou a assinatura v2, usando a chave de desenvolvimento configurada no projeto.

SHA-256 do APK: `366d329308d91f30d2b5fb0d2c85c27524aac63572a47f33f80b2f426e89d902`.

Em 18/11/2026, esse APK foi instalado e aberto no emulador Android 15 (API 35). A conta fictícia entrou pela API HTTPS, a sessão foi restaurada após encerrar e abrir o aplicativo, e uma viagem criada no Render apareceu em **Minhas viagens**, com 4 kg disponíveis.

## T17 — Validação manual em celular físico

Em 18/11/2026, Gustavo confirmou a instalação e a abertura do APK no celular físico. Também confirmou cadastro, login, consulta de viagens e consulta de pedidos. O modelo do aparelho e a versão do Android não foram informados nesta rodada.

Esta validação manual cobre apenas esses fluxos. Publicação, aceite e reserva estão registrados no teste pela API da T15. A restauração de sessão foi conferida no emulador na T16.

O APK pode ser compartilhado como arquivo para instalação manual em Android. Use o arquivo `Trago-Cloud-MVP.apk` conferido acima ou reproduza a compilação local com a URL pública. Se já houver uma instalação do mesmo pacote assinada com outra chave, o Android pode recusar a atualização. A chave atual é de desenvolvimento.

Na consolidação, passaram 17 testes de backend com PostgreSQL 17 descartável, 43 testes Flutter e a análise estática. O build da imagem backend foi conferido, e o `npm audit --omit=dev` reportou zero vulnerabilidades. A assinatura v2 e o SHA-256 do APK usado no teste foram conferidos novamente.

A CI fixa o Flutter em `3.47.8`, a versão usada no APK validado. A primeira execução com o canal `stable` sem versão fixa parou na análise por avisos de obsolescência dos imports Material.

A variável global `TRAGO_API_BASE_URL` permanece como estava. A configuração do GitHub Actions, o merge e a publicação de release dependem de aprovação. As melhorias de interface e distribuição estão no [backlog](CLOUD_MVP_BACKLOG.md).
