# Estratégia de verificação proposta

Estado atual: **fundação implementada e testada; estratégia de produto ainda não implementada**. Há Makefile, testes do controlador e imagem Podman. `make verify-foundation` executa a suíte dentro do Podman; `make verify` falha explicitamente enquanto o SaaS não existir. Nenhum teste de produto foi executado. A tabela abaixo descreve gates futuros de produto; não confundir com a suíte operacional da fundação.

## TDD e evidência

Para cada comportamento de risco: escrever teste significativo; executar e confirmar falha pela regra ausente, não por ambiente quebrado; implementar mínimo; executar green; refatorar; executar regressão afetada. Não alterar expectativa para acomodar implementação incorreta. Documentos e mudanças triviais não exigem testes artificiais.

Cada tarefa registra comando exato, cwd, exit code, duração e evidência de resultado. Uma execução parcial deve listar verificações omitidas e motivo. Zero testes descobertos, SDK ausente, banco inacessível ou runner sem emulator não podem ser apresentados como sucesso completo.

## Entrada única futura

`make verify` será o gate completo e deve falhar se componente obrigatório estiver ausente. Targets auxiliares podem dar feedback mais rápido, mas não substituem o gate completo.

| Target proposto | Conteúdo | Estado atual |
| --- | --- | --- |
| `make verify-docs` | Links locais, schemas de tarefas e consistência das instruções | Não criado |
| `make verify-contracts` | Lint OpenAPI, exemplos, geração e mudanças incompatíveis | Não criado |
| `make verify-api` | Formatação, lint, tipos, testes de domínio, autorização e integração PostgreSQL | Não criado |
| `make verify-web` | Formatação, lint, tipos, testes de componentes, build e E2E | Não criado |
| `make verify-android` | Análise Kotlin/Android, testes JVM, build e instrumentação | Não criado |
| `make verify-security` | Segredos, dependências e configuração | Não criado |
| `make verify` | Agrega gates obrigatórios com ambiente reproduzível e relatório | Não criado |

Ferramentas candidatas: formatter/linter TS, runner de testes TS, Playwright, Android Lint/JUnit/Compose tests, linter OpenAPI, gerador TS/Kotlin, scanner de segredos e auditoria de dependências. Nomes e versões serão fixados na fundação; não há instalação aprovada.

## Casos prioritários ligados aos requisitos

| Requisito | Evidência automatizada proposta |
| --- | --- |
| R-01/R-03 | Busca por rota/data, datas em fusos diferentes, ordenação estável, viagem cancelada/expirada, capacidade incompatível |
| R-02 | Valores/peso/URL inválidos, limites de entrada, rascunho privado, reenvio idempotente e persistência após restart |
| R-09/R-12 | PF→outra PF; PF→PJ; PJ A→PJ B; membership revogada; troca de contexto; viajante sem acesso a rascunho; admin sem acesso global |
| R-09 | CNPJ numérico e alfanumérico, formatação e payload de fornecedor sem perda de letras; empresa existente não implica representação comprovada |
| R-04 | Moedas, arredondamento, validade e versão de cotação, câmbio defasado, regime ausente ou inelegível; totais reprodutíveis |
| R-03/R-05 | Reserva concorrente no último espaço e cancelamento idempotente; testes em PostgreSQL real |
| R-05/R-11 | Evento duplicado/fora de ordem, pagamento pendente/falha, retenção expirada, disputa antes/depois da entrega, refund parcial/total, chargeback após repasse |
| R-06 | UI de erro/vazio/loading, retomada Android, sessão expirada e troca de conta sem vazamento |
| R-09 documentos | Download/exports sem permissão, referência autorizada vs processamento pendente, cancelamento/correção |

Os casos monetários, de reserva e integração são gates para suas features futuras, não testes que deveriam existir num primeiro rascunho sem essas capacidades.

## Contrato e ponta a ponta

OpenAPI precede handlers; verificar resposta do servidor contra schema, geração reprodutível e compatibilidade com contrato anterior. Cliente gerado não prova autorização. E2E de VS-01 usa API e PostgreSQL reais com contas sintéticas PF/PJ; Android em emulator/dispositivo e Web em navegador. Asserções de estado/segurança, não snapshots que apenas copiam a UI.

Migração de base vazia e upgrade da versão anterior; dados de teste isolados por execução. Ao habilitar booking, acrescentar concorrência real. Para release, restore de backup, migração sem perda, carga representativa e observabilidade são evidências operacionais separadas de unit tests.

## CI futuro

Jobs propostos: docs/contratos, API+banco, Web+E2E, Android JVM/build e Android instrumentado, segurança. Pull requests executam verificações sem secrets produtivos; permissões mínimas; actions e imagens fixadas; artifacts com retenção e sem dados sensíveis. Release/deploy/merge continuam manuais e autorizados.

Emulator pode exigir runner com virtualização adequada. O host tem SDK Android, mas nenhuma combinação de JDK/Gradle/AGP foi testada. Container runtime também não está validado no sandbox atual. Esses pré-requisitos devem ser resolvidos antes de afirmar que `make verify` funciona.
