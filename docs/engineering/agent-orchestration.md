# Orquestração prática — Codex, agy e pi

Estado: controlador implementado, 6 tarefas, execução padrão em Podman. U-05 autorizou codificação/orquestração; U-06 determinou containers. Nenhum worker de produto ou agy foi iniciado. [Ambiente e perfis](podman.md).

**Atualização U-07:** o quadro atual tem 3 tarefas independentes, contrato mínimo congelado e launchers com handoff. Use [START.md](START.md). A sequência T00–T05 abaixo documenta o plano anterior, arquivado em `orchestration/backlog.initial.json`; não é pré-requisito para iniciar a rodada atual.

## Divisão do trabalho

O Codex desta conversa coordena quadro, worktrees, processos autorizados, logs e verificação. Codex CLI, agy e pi são executores intercambiáveis. Cada tarefa tem um dono e uma worktree; não precisam conversar diretamente ou compartilhar a mesma harness.

| Ordem | Tarefa | Executor sugerido | Escopo |
| --- | --- | --- | --- |
| 1 | T00-toolchain | Codex/coordenador | Manifests, lockfile e ferramentas comuns |
| 2 | T01-contract | Codex | OpenAPI, fixtures e clientes gerados |
| 3, paralelo | T02-api | Codex | Fontes/testes API |
| 3, paralelo | T03-web | agy | Fontes/testes Web |
| 3, paralelo | T04-android | pi/modelo escolhido | Android |
| 4 | T05-e2e | Codex + revisor | Integração/CI |

Contrato precisa estar revisado e integrado antes de liberar os três clientes. Manifests/lockfiles comuns têm um dono; pedidos de mudança viram tarefa do coordenador. Agentes adicionais pi/VCC podem revisar somente leitura ou receber subescopo explícito; não iniciar escritores independentes na mesma checkout.

## Comandos

```sh
make agents
python3 scripts/agents.py validate
python3 scripts/agents.py prepare T00-toolchain --owner codex-toolchain
python3 scripts/agents.py prompt T00-toolchain
python3 scripts/agents.py run T00-toolchain
```

`run` mostra preview. Somente `--execute` inicia o CLI dentro do Podman. `prepare` exige instruções/spec/manifesto commitados, pois worktrees não recebem untracked automaticamente. Branch `task/<id>-<n>`, pasta `.worktrees/<id>-<n>`, prompt `.task/TASK.md`. O controlador nunca cria commit automaticamente.

Depois de T01 integrado, preparar três tarefas:

```sh
python3 scripts/agents.py prepare T02-api --owner codex-api
python3 scripts/agents.py prepare T03-web --owner agy-web
python3 scripts/agents.py prepare T04-android --owner pi-android
```

Em três terminais/processos independentes, com execução autorizada e perfis configurados:

```sh
python3 scripts/agents.py run T02-api --agent codex --execute
python3 scripts/agents.py run T03-web --agent agy --execute
python3 scripts/agents.py run T04-android --agent pi --pi-harness --model 'provedor/modelo-que-voce-usa' --execute
```

O modelo acima é placeholder explícito. `--provider` opcional exige `--model`. Sem `--pi-harness`, pi usa ferramentas básicas e desativa descoberta de extensões/MCP. Com `--pi-harness`, carrega o perfil isolado configurado; disponibilidade dos serviços não foi testada. O exemplo agy é para autorização futura, não execução já realizada.

## Prompt simples

Para um agente na worktree:

> Leia AGENTS.md e .task/TASK.md. Implemente apenas esta tarefa nos arquivos permitidos. Siga TDD, rode os comandos indicados e grave critérios, arquivos, comandos/exit codes e pendências em .task/RESULT.md. Resolva detalhes reversíveis sem perguntas. Não altere contrato/lockfile fora do escopo nem faça push, merge ou deploy.

Para coordenar aqui numa próxima rodada:

> Coordene tarefas READY em Podman, máximo três simultâneas e uma worktree por tarefa. Use Codex para API, agy para Web e pi com meu modelo configurado para Android. Verifique resultados, obtenha revisão independente e pare antes de integrar. Não faça push/deploy.

O segundo prompt daria autorização futura aos executores nomeados; não foi aplicado automaticamente nesta entrega. Para continuar sem agy, omiti-lo e usar `--agent codex` ou `--agent pi` na tarefa.

## Verificação e revisão

```sh
python3 scripts/agents.py verify T02-api
python3 scripts/agents.py review T02-api --reviewer pi-reviewer --verdict pass --evidence 'Relatório em .task/REVIEW.md; critérios e testes conferidos'
python3 scripts/agents.py approve T02-api
```

`review` registra parecer que realmente ocorreu; não inicia modelo nem fabrica consenso. Identidade é declarada localmente, não autenticada criptograficamente. O coordenador confere a evidência. Alterar conteúdo após verificar invalida aprovação.

Após autorização de integração e commit do conteúdo verificado na worktree, o coordenador realiza Git e registra:

```sh
python3 scripts/agents.py merged T02-api --commit 'SHA_COMPLETO_DO_COMMIT_DA_WORKTREE'
```

O controlador exige worktree limpa, SHA do HEAD da tarefa e commit já ancestral do HEAD do coordenador. Nunca executa merge/cherry-pick/push. Cherry-pick com SHA diferente não é suportado por esse registro inicial.

## Falhas e limites

Definições versionadas em `orchestration/tasks.json`; estado local em `.agent-state/state.json`, com flock/replace. Status: BACKLOG/READY → CLAIMED → RUNNING → VERIFYING → REVIEWING → APPROVED → MERGED; FAILED/ESCALATED explícitos. Alterar definição ativa ou sobrepor caminhos bloqueia operação.

Logs em `.task/agent.log` e `.task/verify-*.log`. Timeout retorna 124, encerra grupo e para container nomeado. Sem retry automático de inferência. Nova tentativa exige FAILED e respeita limite, preservando tentativa anterior. `fail <id> --reason ...` não libera execução ativa. Crash do próprio coordenador exige auditoria manual de processo/container/estado; não há daemon de leases.

Worktree não é sandbox; [Podman](podman.md) é a fronteira de execução. Escopo/diff trata conflitos acidentais, não agentes hostis com mesmo UID. Implementação em `scripts/agents.py`, `scripts/podman_env.py`, schema/DAG em `orchestration/`, testes em `tests/`. Spec em `specs/000-agent-orchestration/`. Produto SaaS ainda não implementado.
