# Plano 000

Implementar `scripts/agents.py` com CLI stdlib e estado flock/replace; `orchestration/tasks.json` e schema; AGENTS/GEMINI; testes em Git temporário e guia prático. Sequência: testes red, controlador green, cenários de regressão, revisão independente local quando disponível.

Não criar framework distribuído, daemon, integração com APIs privadas de harness ou conversa direta entre agentes. Processo por tarefa em worktree. Modelos/provedores são parâmetros opcionais e não substituídos automaticamente.

CLI: validate, list, prepare, prompt, run (preview padrão), verify, review, approve, merged, fail. Operações com Git protegida dependem de permissão do ambiente; testes não precisam escrever em `.git` principal.
