# Estado da implementação — T00 a T09

Atualizado em **25/10/2026**, America/Sao_Paulo. Base Git: `5f47cc47981d961086d77b54ad3bf04eda322022`, branch `main`. O diff acumulado contém as etapas anteriores ainda sem commit. Esta rodada partiu da T08 aprovada provisoriamente e implementou exclusivamente a T09. Não houve commit, push ou publicação.

## Escopo e situação

| Item | Situação |
|---|---|
| T00–T03 | Implementados e cobertos pelas regressões atuais |
| T04 — cadastro, login, sessão e logout backend | Implementado com PostgreSQL e sessão revogável |
| T05 — login Flutter e estado de sessão | Implementado; aprovado provisoriamente pelo usuário |
| T06 — contas PF/PJ, titularidade e viajante | Implementado; garantias de autorização e concorrência revisadas |
| T07 — gestão real de viagens | Aprovado provisoriamente; regressão preservada |
| T08 — decisões do viajante | Aprovado provisoriamente; regressão preservada |
| T09 — reserva de capacidade e concorrência | **Implementado e verificado neste lote** |
| T10 e posteriores | Não implementados |
| Pagamento, custódia, rastreio e verificação documental | Não integrados; dados de demonstração continuam identificados |

## T06: decisões e implementação

### Modelo e migração

- A migração aditiva `003_account_ownership.sql` mantém `owner_id`, `memberships`, `traveler_id` e `actor_id` legados para não quebrar fixtures existentes. Identidades reais usam chaves estrangeiras UUID para `users` em colunas separadas.
- Cada cadastro insere usuário, conta `PERSONAL` e sessão na mesma transação. A conta usa `personal-<user UUID>` e há um índice único parcial por titular PF. Se a conta não puder ser criada, o cadastro inteiro é revertido.
- A migração provisiona uma PF para usuários T04 já presentes que ainda não possuam uma. O filtro e o índice impedem duplicação na aplicação da migração e nos cadastros seguintes.
- `account_memberships` registra acesso empresarial real com usuário, conta, estado ativo e papel `MEMBER`. O titular permanece em `accounts.owner_user_id`; somente ele pode associar outro usuário já cadastrado.
- Viagens e pedidos ganharam referências opcionais ao usuário real, com restrições que exigem exatamente uma identidade real ou de demonstração. A idempotência de pedidos reais fica em `user_idempotency`, separada da tabela legada.

### API e autorização

| Endpoint | Comportamento T06 |
|---|---|
| `GET /v1/me/accounts` | Retorna somente PF própria, PJ própria ou PJ com associação ativa |
| `POST /v1/me/accounts/organizations` | Cria PJ com o usuário da sessão como titular |
| `POST /v1/me/accounts/{accountId}/members` | Titular concede acesso a outro email já cadastrado; alheios recebem 404 |
| `POST /v1/trips` | Usuário real autenticado publica com seu UUID e nome cadastrado |
| Rotas de pedidos | Aceitam PF/PJ real somente após validar titularidade ou associação no PostgreSQL |

- `accountId`, nome do viajante e ator não são aceitos como prova de identidade. O controller obtém o usuário por JWT e sessão ativa; o service repete a autorização da conta antes de listar, criar ou ler pedidos.
- O mesmo usuário pode publicar viagem e criar pedido. A T07 completou edição, cancelamento, detalhes, listagem própria e disponibilidade no endpoint existente.
- Recursos privados alheios retornam 404 para não confirmar sua existência. Associação PJ inexistente ou tentada por não titular também retorna 404.
- O contrato OpenAPI da T06 passou à versão 0.3.0 com os dois endpoints PJ, schemas de entrada, `accessRole` e viagens reais com `isDemo: false`.
- A concessão empresarial deste MVP é direta pelo titular a um usuário cadastrado. Não há envio de email, aceite de convite, remoção de membro ou administração de papéis. CNPJ/CPF não são coletados.

### Flutter

- Após cadastro, login ou restauração, a sincronização carrega somente as contas devolvidas pela sessão. A PF aparece primeiro; PF/PJ podem ser selecionadas no perfil.
- A tela de perfil cria uma conta empresarial e, quando a conta selecionada tem `accessRole: OWNER`, permite autorizar um membro pelo email cadastrado.
- A seleção local rejeita IDs ausentes da lista. Toda operação subsequente envia o JWT e o backend valida novamente o `accountId`; a lista Flutter não é uma fronteira de segurança.
- O botão de viagem funciona para sessão real e demo. No modo real, o nome retornado pelo backend prevalece sobre texto digitado no cliente.
- Logout e respostas 401 continuam apagando token, usuário, contas, seleção, pedidos e chaves de idempotência em memória. Erros 403 preservam a sessão.
- O modo demonstração mantém suas contas e tokens `dev:*` em ramo explícito. Endpoints PJ reais rejeitam identidades demo; produção continua recusando a configuração demo.

## T07: gestão real de viagens

### Revisão herdada da T06

- A associação PJ continua restrita ao titular por consulta a `accounts.owner_user_id`; membros não conseguem convidar terceiros. O teste usa três usuários e confirma 404 para a tentativa por não titular.
- Criação, listagem e leitura de pedidos continuam chamando a autorização de `accountId` no backend. Uma conta alheia não pode ser selecionada como autorização por mero envio do ID.
- A PF é criada na mesma transação do usuário e protegida pelo índice único parcial `accounts_personal_owner_user`. O teste de cadastro concorrente agora também confirma exatamente uma PF no PostgreSQL.

### Persistência, estados e API

- A migração `004_trip_management.sql` adiciona estado persistido, datas de criação/atualização, índices para disponibilidade/titular e idempotência de publicação.
- `POST /v1/trips` exige `Idempotency-Key`. Repetição com o mesmo corpo retorna a mesma viagem; reutilização com conteúdo diferente retorna 409.
- `GET /v1/trips` retorna somente viagens `AVAILABLE` cuja data ainda não expirou no fuso informado. `GET /v1/me/trips` inclui as viagens do titular em qualquer estado.
- `GET /v1/trips/{id}` mostra uma viagem disponível a compradores e mantém viagens canceladas/expiradas visíveis somente ao titular.
- `PATCH /v1/trips/{id}` exige titularidade, dados válidos, estado disponível e ausência de pedidos associados. Usuários alheios recebem 404; viagem expirada, cancelada ou já referenciada recebe 409.
- `POST /v1/trips/{id}/cancel` é idempotente para viagens já canceladas. O cancelamento é lógico: preserva a viagem e seus pedidos, retira a oferta da busca pública e bloqueia novos pedidos.
- Criação de pedido lê a viagem com lock compartilhado e cancelamento usa lock exclusivo; assim, um pedido iniciado antes do cancelamento termina antes dele, enquanto pedidos posteriores observam o estado cancelado. A T09 acrescenta a reserva somente no aceite.
- Origem/destino são aparadas e precisam ser diferentes; data deve ser futura no fuso da viagem; peso é inteiro entre 1 g e 100 kg; tarifa deve ser positiva.

### Flutter

- Sessões reais começam sem `kFeaturedTravelerTrips`; fixtures são usadas apenas no modo demonstração explícito. A busca autenticada exibe somente o retorno da API.
- Publicação real envia JWT e chave de idempotência, preservada após falha para retry. O estado local só recebe a viagem após 201.
- A nova tela `MyTripsScreen` consulta as viagens do usuário, mostra `Disponível`, `Cancelada` ou `Expirada`, atualiza por pull-to-refresh e oferece edição/cancelamento quando permitido.
- Edição e cancelamento atualizam as listas locais somente após 200. Erros de rede ou autorização mantêm os dados anteriores e exibem mensagem.
- A abertura de detalhes consulta `GET /v1/trips/{id}` no modo real. O modo demonstração continua usando somente seus objetos locais identificados.

## T08: caixa de entrada e decisões do viajante

### Modelo, segurança e concorrência

- A migração `005_request_decisions.sql` normaliza registros `DRAFT` legados para `PENDING`, adiciona a restrição `PENDING | ACCEPTED | REJECTED`, datas de atualização/decisão, índice por viagem/estado e a tabela auditável `purchase_request_events`.
- A máquina de estados é `PENDING → ACCEPTED | REJECTED`. A mesma decisão repetida retorna o recurso já confirmado sem criar outro evento. Uma decisão terminal oposta retorna `409 DECISION_CONFLICT`.
- Aceite e rejeição bloqueiam, na mesma transação PostgreSQL, as linhas do pedido e da viagem com `FOR UPDATE`. Cancelamento usa o mesmo lock da viagem. Assim, operações concorrentes são ordenadas e somente uma decisão terminal conflitante vence.
- O proprietário é obtido do JWT e comparado a `trips.traveler_user_id`; IDs enviados pelo cliente não concedem acesso. Recurso alheio retorna 404. O comprador consulta somente pedidos de PF/PJ cujo acesso é validado no banco.
- Viagem cancelada ou expirada bloqueia uma nova decisão com 409. Uma decisão já persistida continua idempotente mesmo se a viagem for cancelada depois.
- Na T08 o aceite registrava somente a decisão. A T09 passou a reservar capacidade, mantendo pagamento, custódia e confirmação de transporte fora do fluxo.

### API e Flutter

| Endpoint | Comportamento T08 |
|---|---|
| `GET /v1/me/incoming-requests` | Lista pedidos vinculados às viagens do usuário autenticado |
| `GET /v1/purchase-requests?accountId=...` | Mantém acompanhamento dos pedidos enviados por PF/PJ autorizada |
| `GET /v1/purchase-requests/{id}` | Autoriza comprador da conta ou proprietário da viagem |
| `POST /v1/purchase-requests/{id}/accept` | Aceita pedido pendente, de forma transacional e repetível |
| `POST /v1/purchase-requests/{id}/reject` | Rejeita pedido pendente, de forma transacional e repetível |

- O contrato OpenAPI da T08 passou à versão 0.5.0; a T09 o atualizou para 0.6.0 com capacidade total, reservada e disponível.
- `IncomingRequestsScreen` oferece caixa de entrada, detalhes expansíveis, aceite/rejeição, loading, vazio, retry e mensagens de erro. A tela de pedidos enviados mostra o estado confirmado pela API.
- `AppState` troca o item somente depois de resposta 200. Falhas de rede/API preservam o pedido e mostram erro, sem confirmação local falsa.
- Logout/401 continuam limpando pedidos enviados e recebidos. O modo demonstração continua em ramo explícito e usa apenas a identidade sintética do viajante quando configurado.

## T09: reserva de capacidade e concorrência

### Decisões de modelagem e migração

- A capacidade é persistida em `trips.total_capacity_grams` e `trips.reserved_capacity_grams`. A disponível é sempre derivada por `total - reserved`; todos os valores são inteiros em gramas.
- A persistência do agregado permite validar e incrementar a reserva sob o mesmo lock da viagem, sem somar toda a tabela de pedidos durante cada aceite. A restrição PostgreSQL impede reserva negativa ou superior à capacidade total.
- A migração `006_trip_capacity_reservations.sql` copia a capacidade total legada e soma o peso dos pedidos `ACCEPTED` existentes. Se registros legados já estiverem sobrecontratados ou inválidos, a migração falha em vez de aumentar capacidade ou descartar aceites silenciosamente.
- O cancelamento lógico preserva `reserved_capacity_grams` e os pedidos aceitos para manter o compromisso histórico. Como ainda não há transição de cancelamento de pedido, esta etapa não libera reservas.

### Ordem de locks e comportamento

- A ordem foi padronizada como **viagem → pedido** para decisões. Edição e cancelamento já começam pela viagem; criação usa lock compartilhado da viagem e não bloqueia um pedido existente. Não foi encontrada operação que adquira esses locks na ordem inversa.
- Aceite, atualização da capacidade, mudança do pedido e evento de auditoria ocorrem na mesma transação. Falha em qualquer gravação reverte todas as anteriores.
- Dois aceites simultâneos para a mesma viagem são serializados pelo lock da viagem. O segundo observa a capacidade atualizada e recebe `422 CAPACITY_EXCEEDED` quando não há saldo.
- Repetir um aceite já confirmado retorna o pedido e a capacidade atual sem novo desconto. Rejeição não altera capacidade. Viagem cancelada ou expirada continua bloqueando um novo aceite.
- Uma corrida entre aceite e cancelamento é ordenada pelo mesmo lock: se o aceite vencer, a reserva fica registrada e depois a viagem é cancelada; se o cancelamento vencer, o aceite recebe 409 e não reserva.

### Contrato e Flutter

- Todas as respostas de viagem incluem `totalWeightGrams`, `reservedWeightGrams` e `availableWeightGrams`. Busca de viagens não retorna ofertas sem saldo disponível.
- A resposta da decisão inclui `tripCapacity`, permitindo atualizar a viagem local com valores confirmados na mesma operação.
- `Trip` e as telas exibem total, reservado e disponível. `AppState` só altera pedido e capacidade depois do 200; falha de rede ou 422 mantém os valores anteriores.
- A caixa de entrada apresenta a capacidade confirmada e explica que aceite reserva espaço, mas não confirma pagamento, custódia ou transporte. O modo demonstração continua separado.

## Arquivos alterados em T06–T09

| Arquivo | Mudança |
|---|---|
| `backend/migrations/003_account_ownership.sql` | Titular real, PF única, associação PJ, referências de viajante/comprador e idempotência real |
| `backend/migrations/004_trip_management.sql` | Estados, índices e idempotência das viagens |
| `backend/migrations/005_request_decisions.sql` | Estados de pedido, datas, índice e eventos auditáveis |
| `backend/migrations/006_trip_capacity_reservations.sql` | Capacidade total/reservada, backfill e restrições de integridade |
| `backend/src/auth.ts` | Criação transacional da PF no cadastro |
| `backend/src/database.ts` | Inserts demo com colunas explícitas, compatíveis com a migração aditiva |
| `backend/src/main.ts` | Endpoints PJ, viagens e decisões de solicitações |
| `backend/src/service.ts` | Autorização PF/PJ, ciclo de viagens e máquina transacional de pedidos |
| `backend/test/auth.test.cjs`, `api.test.cjs`, `capacity_migration.test.cjs` | Regressão T04–T08, concorrência, rollback e migração T09 |
| `contracts/http/openapi.json` | Contrato 0.6.0 com capacidade e resultado confirmado da decisão |
| `mobile/lib/models/account.dart` | Papel de acesso `OWNER`/`MEMBER` |
| `mobile/lib/models/trip.dart`, `purchase_request.dart` | Total, reserva, saldo e capacidade retornada pela decisão |
| `mobile/lib/api/trago_api_client.dart` | Chamadas JWT de contas, viagens, caixa de entrada, detalhe e decisão |
| `mobile/lib/state/app_state.dart` | Sessão, PF/PJ, viagens e atualização confirmada de decisões |
| `mobile/lib/screens/profile_screen.dart`, `search_screen.dart`, `publish_screen.dart` | Acesso às viagens próprias, detalhes e formulário de criação/edição |
| `mobile/lib/screens/my_trips_screen.dart` | Nova tela de gestão de viagens do titular |
| `mobile/lib/screens/incoming_requests_screen.dart`, `orders_screen.dart` | Caixa recebida e acompanhamento enviado |
| `mobile/test/auth_state_test.dart` | Alternância autorizada e limpeza de contas no logout |
| `mobile/test/api_client_test.dart`, `app_state_test.dart` | Capacidade confirmada, erro 422 e preservação de estado |
| `README.md`, `backend/README.md`, este relatório | Execução, contrato, decisões e limites atuais |

Os demais arquivos modificados no `git status` pertencem aos lotes anteriores aprovados provisoriamente. Nenhuma funcionalidade da T10 foi adicionada.

## Ambiente e resultados efetivos

- Windows/PowerShell, Node **24.11.1**, npm **11.6.2**.
- PostgreSQL **17.9** em cluster dedicado fora do repositório, `127.0.0.1:55432`. As migrações 001–006 foram aplicadas. Um schema isolado também executou 001–005, recebeu um aceite legado e validou o backfill da 006.
- Flutter **3.47.8 stable**, Dart **3.13.7**, instalado em `%LOCALAPPDATA%\TragoTools\flutter`.

| Verificação executada | Resultado final |
|---|---|
| `npm run check` com PostgreSQL real | Build TypeScript e **14 testes passaram**, 0 falhas, 0 ignorados |
| `flutter analyze --no-pub` | **Passou: No issues found** |
| `flutter test --no-pub` | **41 testes passaram** |
| `flutter build apk --release --dart-define=TRAGO_DEMO_MODE=true` | **Passou**, APK universal de 52,6 MiB com assinatura Android válida |
| `git diff --check` | Passou, sem erros de whitespace |

A suíte backend preserva os quatro cenários legados e os testes T04–T08. O cenário T09 verifica reserva válida, insuficiência sequencial, dois aceites simultâneos, repetição sem duplo desconto, rejeição, cancelamento/expiração, corrida com cancelamento, rollback forçado, consistência entre aceites e agregado, e migração de aceites legados. A suíte Flutter verifica a capacidade retornada, atualização somente após confirmação e erro 422 sem reserva local.

Os testes Flutter usam clientes HTTP controlados e não são uma execução ponta a ponta Flutter → API. A integração real foi exercitada no nível HTTP do backend contra PostgreSQL.

### Reexecução neste computador

```powershell
$taskPgBin = 'C:\Program Files\PostgreSQL\17\bin'
$taskDb = Get-Content -Raw "$env:LOCALAPPDATA\TragoTools\postgres-test.json" | ConvertFrom-Json
$taskPgOptions = '-p 55432 -h 127.0.0.1'
& "$taskPgBin\pg_ctl.exe" -D $taskDb.data -l "$env:LOCALAPPDATA\TragoTools\postgres-test.log" -o $taskPgOptions -w start
$env:DATABASE_URL = 'postgresql://trago_test:' + [Uri]::EscapeDataString($taskDb.password) + '@127.0.0.1:55432/trago_test'

Set-Location C:\Users\gustavo\Documents\Trago\backend
npm run check

Set-Location C:\Users\gustavo\Documents\Trago\mobile
& "$env:LOCALAPPDATA\TragoTools\flutter\bin\flutter.bat" analyze --no-pub
& "$env:LOCALAPPDATA\TragoTools\flutter\bin\flutter.bat" test --no-pub

& "$taskPgBin\pg_ctl.exe" -D $taskDb.data -m fast -w stop
```

Use sempre banco dedicado: os testes inserem fixtures de demonstração e usuários sintéticos. A senha aleatória do cluster está fora do repositório.

## Limitações e pendências

- O build APK release foi executado localmente e o workflow voltou a publicar o artefato no GitHub Releases após os testes. A instalação e o fluxo Flutter em aparelho/emulador ainda não foram confirmados de ponta a ponta.
- O release Android continua assinado com a chave de depuração herdada do projeto. Ela permite testes e distribuição interna pelo GitHub, mas deve ser substituída por uma chave de produção protegida antes de publicar em loja.
- Sem a variável de repositório `TRAGO_API_BASE_URL`, o CI gera um release demonstrativo isolado. A integração real distribuída exige uma URL pública HTTPS para o backend e a configuração dessa variável no GitHub.
- Build Windows e GitHub Actions ainda não foram executados neste computador; o resultado definitivo do workflow será o primeiro run da branch/PR.
- O armazenamento seguro foi testado por abstração em memória; Keystore, Keychain, Credential Locker, libsecret e WebCrypto ainda precisam de validação em plataforma real.
- A concessão PJ não possui aceite/revogação, múltiplos papéis, auditoria administrativa ou recuperação de convite. Essas extensões não são necessárias para o aceite atual e exigem contrato próprio.
- Cancelamento não remove a viagem nem libera reservas aceitas. Não há reativação ou cancelamento de pedido; eventual liberação exige uma transição de domínio e contrato próprios.
- O histórico de decisões é persistido no PostgreSQL para auditoria, mas a API/UI expõe nesta etapa apenas o estado atual. Uma visualização cronológica exigirá contrato próprio.
- A reserva cobre somente o peso declarado e aceito. Não há pagamento, custódia, reembolso, expiração automática da reserva ou alteração/cancelamento do pedido. Semântica de dinheiro aguarda T10.
- Viagens públicas de fixture permanecem no catálogo e são rotuladas como demonstração. O banco de produção deve ser separado do banco demo.
- Os alertas de dependências registrados na T05 e as limitações de proxy/HTTPS, expurgo de sessões e recuperação de senha continuam pendentes.

**Próximo passo: revisão da T09 pelo usuário. Não avançar para T10 sem nova autorização.**
