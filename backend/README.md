# API local Trago

NestJS/Fastify e PostgreSQL para a demonstração sintética PF/PJ. O contrato de entrada e os formatos de resposta são os de `../contracts/http/openapi.json`, consumido em runtime pela validação AJV e nos testes. Nenhum contrato ou fixture original foi alterado.

## Execução

Requer Node 22+, npm e `DATABASE_URL` fornecida para PostgreSQL. Não há fallback em memória/SQLite; falha de conexão impede inicialização e testes. Instalação e execução:

```sh
cd backend
npm install
npm run check
NODE_ENV=development TRAGO_DEMO_AUTH=true npm run dev
```

`dev` compila e escuta em `0.0.0.0:3001`. Na inicialização aplica `migrations/*.sql` em ordem, atomicamente, com registro em `api_migrations` e lock PostgreSQL para inicializações concorrentes. Em modo demo também faz seed idempotente sem sobrescrever registros existentes. As migrações não removem tabelas/dados. A persistência fica no banco fornecido, não no processo. SIGINT/SIGTERM fecha o pool.

`TRAGO_DEMO_AUTH=true` é a única opção de ambiente que habilita Bearer `dev:buyer`, `dev:traveler`, `dev:outsider`, `dev:revoked`. Com `NODE_ENV=production` e essa opção ativa o servidor recusa iniciar. Com demo desativada, todos esses tokens recebem 401; autenticação produtiva não foi implementada. `/health` é público e consulta o banco. CORS permite explicitamente `http://localhost:3000` e `http://127.0.0.1:3000`, sem wildcard, incluindo Authorization e Idempotency-Key.

## Dados e operações

- `GET /v1/me/accounts`: somente PF própria e PJs com membership ativo. Buyer acessa `personal-buyer`, `company-demo` e `company-numeric`; outsider acessa `personal-outsider`; revoked não acessa a PJ; traveler não acessa rascunhos do comprador.
- `GET /v1/trips`: ofertas fictícias, filtros opcionais `origin`, `destination` (igualdade sem distinguir maiúsculas), `departureDate` (data exata) e `cursor`. Página fixa de 20, ordenada por data/id; cursor opaco inclui os filtros e não é autorização. Filtros de texto têm limite de 500 caracteres; cursor tem limite separado de 32768 caracteres e validação base64url/JSON, data e vínculo aos filtros. Fim/vazio retorna `nextCursor: null`.
- `POST /v1/trips`: somente identidade demo traveler. Valida campos do contrato, data de calendário, timezone IANA e peso inteiro seguro; nenhuma capacidade é reservada.
- `POST /v1/purchase-requests`: `Idempotency-Key` de 8–128 caracteres, conta autorizada e viagem existente. Produz somente `DRAFT`, privado da conta. Transação e lock por ator/conta/operação/chave garantem a mesma resposta para reenvios concorrentes equivalentes; outro payload retorna 409. Igualdade usa JSONB, independente da ordem das propriedades. Como o contrato não define expiração, chaves ficam persistidas sem TTL.
- `GET /v1/purchase-requests?accountId=...`: verifica acesso e lista os rascunhos da conta por id. O contrato não oferece cursor nessa operação; retorna todos os itens e `nextCursor: null`.
- `GET /v1/purchase-requests/:id`: leitura privada com autorização a cada chamada. Ausência e acesso negado retornam o mesmo 404 seguro.

O seed preserva as fixtures canônicas e acrescenta `company-numeric`, segunda PJ sintética representada pelo buyer, para demonstrar múltiplos contextos e CNPJ numérico/alfanumérico como texto. Não valida autenticidade fiscal desses identificadores. Valores monetários são strings inteiras sem conversão para ponto flutuante. URLs HTTP(S) são apenas armazenadas: o servidor nunca busca o produto.

Erros têm apenas `code`, `message`, `correlationId`; exceções de banco e tokens não são expostos. Payload limitado a 64 KiB. Os testes usam o PostgreSQL informado: criam recursos próprios e limpam apenas seus IDs ao terminar; não usar banco produtivo.

## Verificação e limites

`check` compila TypeScript e executa quatro testes essenciais com Fastify inject e PostgreSQL real: publicação/busca, isolamento PF/PJ (incluindo revoked/traveler/outsider), idempotência concorrente/conflito, entradas inválidas, formatos de resposta do contrato, CORS das duas origens locais e rejeição externa, paginação com 21 viagens e filtros longos, persistência após fechar/recriar API e bloqueio demo em produção. O smoke HTTP de desenvolvimento foi executado separadamente; detalhes em `.task/RESULT.md` na raiz da worktree.

Identidades, contas, empresas, viagens e produtos são demonstração sintética. Não há mocks de banco nos testes. Pagamento, escrow, KYC, câmbio, fiscal, transporte/importação reais e autenticação produtiva estão ausentes/desabilitados. A API não comprova conformidade aduaneira ou fiscal e não representa MVP comercial pronto. Revisão independente e integração Web/Android pertencem ao coordenador.
