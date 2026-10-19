# Tarefas 001

Fonte executável: `orchestration/tasks.json`; não manter dois quadros independentes.

```text
T00-toolchain → T01-contract ┬→ T02-api     ┐
                           ├→ T03-web     ├→ T05-e2e
                           └→ T04-android ┘
```

Atribuições de harness são sugestões; `run --agent` permite trocar executor sem mudar a tarefa. Review é papel separado da implementação, com evidência e conteúdo verificado.
