# Plano 001

Ver arquitetura aprovada em `docs/architecture/overview.md`. Contrato precede implementações. Toolchain central cria manifests/scripts/lockfile compartilhados antes da divisão de arquivos. Contrato estabiliza schemas, exemplos e clientes. Implementadores usam o mesmo commit integrado e não alteram contratos/manifests raiz por iniciativa própria.

Mudanças necessárias em arquivos compartilhados retornam ao coordenador como tarefa pequena; enquanto isso, continuar fontes/testes dentro do escopo. Não simular cobertura de recursos ainda não implementados. Cada task registra outputs e comandos em `orchestration/tasks.json`.
