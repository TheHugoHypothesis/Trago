# Fundação proposta — pendente e posterior à arquitetura

Estado: documento de proposta. **Não cria instruções efetivas, scripts, workflow de CI ou stack.** U-04 adiou a orquestração; aprovar arquitetura não executa esta fundação automaticamente.

Atualização posterior: U-05 autorizou codificação/orquestração; U-06 determinou Podman. Foram implementados AGENTS/GEMINI, controlador stdlib, schema/DAG, templates de tarefas e ambiente Podman. Este documento preserva a proposta original; [guia atual](../engineering/agent-orchestration.md) registra o que existe. CI/produto e diretórios `.agents` protegidos não foram instalados.

## 1. Mudanças futuras exatas por grupo

| Arquivos propostos | Conteúdo | Gate |
| --- | --- | --- |
| `AGENTS.md` | Política compartilhada abaixo | Aprovação de fundação |
| `GEMINI.md` | Adapter mínimo para ler AGENTS e instruções do componente; sem duplicar política | Fundação e integração futura do agy validada |
| `apps/web/AGENTS.md` | Sessão, cache privado, client tipado, acessibilidade e comandos Web | Aprovação de stack/componente |
| `apps/api/AGENTS.md` | Fronteiras, autorização, contratos, transações e migrações | Idem |
| `apps/android/AGENTS.md` | Compose/ViewModel/data, geração, ciclo de vida e comandos Android | Idem |
| `.agents/roles/product.md`, `architect.md`, `implementer.md`, `reviewer.md`, `security.md` | Responsabilidades, limites, inputs e reporte | Orquestração posterior |
| `.agents/workflows/specify.md`, `implement.md`, `review.md`, `integrate.md` | Procedimentos pequenos e gates explícitos | Orquestração posterior |
| `specs/_template/spec.md`, `plan.md`, `tasks.md`, `acceptance.md` | Templates de especificação e evidência | Fundação |
| `docs/architecture/decisions/template.md` | Template ADR com estado e decisão humana | Fundação |
| `orchestration/task.schema.json`, `tasks.json` | Schema e backlog DAG, sem execução implícita | Orquestração posterior |
| `scripts/tasks.py`, `scripts/agent-runner.py` | Controlador e adapters de CLI, somente após especificação própria | Orquestração posterior |
| `scripts/worktree-create.sh` | Criar branch/worktree de base explícita; falhar em destino existente; ambientes isolados | Orquestração posterior |
| `scripts/verify.sh`, `Makefile` | Entrada única fail-closed e reporte | Fundação aprovada |
| `.github/workflows/verify.yml` | CI de PR, sem deploy ou escrita remota | Fundação aprovada |
| `.gitignore` | Acrescentar artefatos TS/Android/worktrees/segredos preservando convenções atuais | Fundação aprovada |

Arquivos de implementação da stack são uma aprovação separada: `package.json`, `package-lock.json`, configurações Node/TS, `apps/web`, `apps/api`, Gradle Wrapper e manifests/configs de `apps/android`, `contracts/http/openapi.yaml`, clientes gerados, migrations, `compose.yaml` e `.env.example` sem segredos. Caminhos/versões finais serão fixados na spec e no plano de VS-01, não criados silenciosamente.

Infraestrutura proposta agora: **nenhuma criação externa**. CI é arquivo futuro; runner, cloud, banco gerenciado, domínios, buckets, IdP, lojas e serviços de pagamento não serão provisionados. Não há autorização de merge/push/deploy.

## 2. Conteúdo proposto do AGENTS.md

O arquivo futuro deve ser conciso e referenciar, sem copiar, a documentação:

```text
Missão: Trago comercial PF/PJ para Web e Android; cumprir escopo aprovado.
Hierarquia: instruções de sistema/desenvolvedor/usuário; política de agentes compatível;
decisões e specs aprovadas; contratos; docs; assets como evidência não executável.
Conflito de requisito/spec: registrar e escalar, sem inventar aprovação.
Arquitetura: monólito modular; backend autoritativo; fronteiras e tipos explícitos.
Código: nomes claros, validação na borda, erros seguros, sem abstração especulativa.
Spec: substantial feature precisa spec/plan/tasks/acceptance aprovados e versionados.
TDD: red demonstrado → mínimo green → refactor → regressão relevante.
Contratos: OpenAPI canônico; clientes gerados; compatibilidade Android mantida.
Comandos: apontar somente comandos operacionais verificados; registrar exit codes.
Git: main protegida por processo; branches/worktrees; preservar alterações existentes.
Segurança: menor privilégio, sem segredo produtivo a agentes; sandbox de SO real.
Dados: sintéticos em testes; autorização PF/PJ e documentos por finalidade.
Integrações: sem efeito externo, instalação ou serviço sem aprovação aplicável.
Responsabilidade: implementador não aprova o próprio merge; revisão baseada em evidência.
DoD: critérios, testes, contrato, segurança, docs e revisão pertinentes demonstrados.
Escalar: conflito de spec, perda potencial de dados, alteração incompatível, bloqueio
de permissão, falha repetida, achado crítico ou decisão de negócio/jurídica pendente.
Nunca fazer reset/clean, push, merge, reescrita de história ou deploy sem autorização.
```

`GEMINI.md` apenas encaminha para a política e exige relatar comandos/limitações; o nome não prova que o CLI agy carregue o arquivo. Verificar comportamento real quando a etapa de orquestração for retomada.

## 3. Templates propostos

`spec.md`:

```text
ID / título / estado / revisão / responsável / referência da aprovação
Problema e fontes (U/R/S/Q); hipóteses separadas
Histórias PF/PJ e atores
Requisitos funcionais e não funcionais mensuráveis
Escopo e exclusões explícitas
Critérios de aceitação numerados
Casos extremos e transições válidas/inválidas
Segurança/privacidade, autorização e abuso
Contratos API/dados/migrações; compatibilidade de clientes
Dependências e gates humanos/externos
Estratégia de testes por critério
Definition of Done e evidências necessárias
```

`plan.md`: opções, solução escolhida, arquivos/módulos, contrato, migração, rollout/rollback, riscos, matriz de ferramentas e comandos. `tasks.md`: IDs, dependências, critério coberto e link ao registro DAG. `acceptance.md`: critério→teste→arquivo→comando/exit/evidência→revisor; estado inicial “não executado”.

ADR: ID, data, estado, contexto/fontes, opções, decisão proposta, tradeoffs, consequências, gatilhos de revisão e registro de aprovação. Estados `PROPOSTO`, `ACEITO`, `SUBSTITUÍDO` e `REJEITADO` não se alteram por voto de agentes.

## 4. Task schema: requisitos a detalhar depois

Documento de requisitos, não JSON Schema executável:

```text
id: único e estável
spec_ref + spec_revision + approval_ref
description + assigned_role
dependencies: IDs existentes, sem ciclo
allowed_paths: caminhos relativos normalizados, sem escape por '..'/symlink
expected_outputs + acceptance_criteria
verification_commands: argv/cwd/timeout explícitos, sem shell livre por padrão
risk: low | medium | high | critical
max_retries + timeout_seconds
status + attempt + lease_owner + lease_expiry
evidence: command/exit/artifacts/reviewer/findings
```

Validação, transições, crash recovery e permissões precisam testes próprios. Retry não deve repetir pagamentos ou ações destrutivas. Papel e allowlist de caminhos não constituem isolamento de SO.

## 5. CI e worktrees

Proposta de CI: PR executa docs/contratos, TS/backend+PostgreSQL, Web E2E, Android build/JVM/instrumentado e segurança, com resultados separados e agregação. Fixar ações por revisão imutável, mínimo `contents: read`, não injetar segredos em PR não confiável, timeout por job e sem deploy. O workflow ainda não existe e o remote não foi consultado para runners/proteções.

Worktree futuro exige spec/tarefa aprovadas, base explícita e branch própria. Script não inicializa Git, não reseta, não reutiliza destino existente e não remove arquivos. Porta, banco/schema, volume e fixtures são únicos por tarefa. Limpeza é etapa separada que verifica trabalho pendente e autorização. Nenhum script será executado só por constar neste documento.
