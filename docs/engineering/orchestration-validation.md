# Validação da fundação

Escopo: controlador, worktrees, handoff e ambiente Podman; não é validação do produto SaaS.

## Executado

- Imagem construída no Podman 6.1.4 rootless, exit 0. Base por digest e imagem por ID em `containers/images.lock.json`.
- Diagnóstico no container, exit 0: Node 22.23.3, npm 10.9.9, Python 3.11.2, JDK 17.0.20.1, Git 2.39.5.
- Codex `--version` no container, exit 0: 0.163.0. Pi `--offline --version`, exit 0: 1.3.0. Sem inferência.
- Conferência runtime, exit 0: UID não root; filesystem raiz, Git e assets ro; perfil/cache graváveis; hashes originais preservados.
- Suíte final da fundação no Podman: 32 testes passaram, exit 0, incluindo os dois cenários de handoff; não houve chamada real a modelos nos testes.
- Validação semântica final de tarefas: 3 tarefas paralelas válidas, exit 0, por U-07, com contrato congelado e caminhos disjuntos. DAG original de 6 arquivado.

## Revisão e TDD

Revisor nativo Codex somente leitura reproduziu corrida de verify, output ignorado fora do fingerprint e log ausente prendendo estado. Regressões específicas falharam antes das correções e passaram depois. Também corrigidos metadata force-added fora de escopo, stdin do Codex para Podman e normalização de ID da imagem retornado pelo Podman.

Os testes usam Git temporário e executores falsos. Cobrem claim concorrente, paths, dependências, worktree real, rename/untracked, symlink, fingerprints, revisão independente declarada, ancestralidade de integração, timeout de descendentes e handoff sem perder progresso. As validações Podman testam plano de mounts e houve conferência real de mounts no container.

## Limites reais

Nenhum agy/Codex/pi de produto foi iniciado nem login de fornecedor validado. PostgreSQL/serviços/API/Web/Android de produto serão iniciados pelos launchers quando executados; nenhum build do aplicativo passou hoje. Não houve merge, push ou deploy. A suíte de fundação não é pipeline completo de produto; `make verify` continua falhando explicitamente até integração do MVP.
