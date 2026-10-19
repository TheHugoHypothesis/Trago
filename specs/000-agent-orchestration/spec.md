# 000 — Orquestração local de tarefas e worktrees

Estado: autorizado para implementação local pela instrução do usuário de 18/10/2026: aprovação da arquitetura, foco em codificação e preparação de trabalho paralelo com Codex, agy e pi. Não autoriza iniciar agy nesta sessão nem serviços externos do produto.

## Problema

Agentes independentes precisam trabalhar simultaneamente sem escrever na mesma checkout, perder contexto ou declarar trabalho integrado sem verificação. A configuração pessoal dos CLIs deve permanecer intacta.

## Histórias e escopo

- Coordenador lista tarefas prontas, prepara uma worktree por tarefa e entrega um prompt explícito a qualquer CLI suportado.
- Implementador recebe spec, dependências, arquivos permitidos, outputs e comandos; trabalha apenas na sua branch.
- Coordenador executa verificações e recebe revisão independente antes de aprovar. Integração Git é humana/explicitamente autorizada.
- Pi pode usar modelo/provedor informado pelo usuário e, opcionalmente, extensões/MCP já configurados. Não descobrir ou imprimir credenciais nem presumir modelos disponíveis.

## Critérios de aceitação

1. JSON de tarefas rejeita IDs duplicados, dependências inexistentes/cíclicas, campos inválidos e caminhos absolutos/escapes/reservados.
2. Só preparar tarefa autorizada cujas dependências estejam MERGED e cujos contextos estejam em commit base. Nunca copiar silenciosamente arquivos não commitados à worktree.
3. Claims concorrentes são serializados por flock e state é persistido atomicamente. Tarefas ativas com caminhos sobrepostos não são preparadas.
4. Worktree usa branch própria e destino novo, sem reset, clean, overwrite, merge, push ou deploy. Falha mantém evidência recuperável.
5. Prompt inclui tarefa e instruções compartilhadas; não envia assets ou repositório inteiro ao provedor.
6. `run` só mostra argv por padrão. `--execute` é obrigatório para iniciar processo. Por U-06 todos os workers e builds usam Podman rootless com workspace rw, Git comum ro, perfil dedicado e cache por tarefa. Não montar home inteira, socket ou usar privileged. Codex opera livremente dentro desse limite de container, sem depender de sandbox aninhado; não há execução host pela CLI do controlador. Allowlist e diff são validação adicional.
7. Processos usam argv sem shell, timeout com terminação do grupo, logs e exit codes. Sem retries automáticos de inferência/efeitos externos.
8. Mudanças staged/unstaged, commits locais e arquivos untracked são comparados com a base; rename não permite escapar do escopo; symlinks de outputs são rejeitados.
9. Verificação executa comandos declarados, detecta output ausente e falha real. Revisão/aprovação ficam inválidas quando conteúdo muda. Exit 0 do agente não é aprovação.
10. MERGED só é registrado após commit da worktree limpo e comprovadamente ancestral de HEAD do coordenador; controlador nunca integra código automaticamente.
11. Testes usam repositórios temporários e processos fictícios, sem inferência paga, agy, pi ou alteração da Git principal.

## Não funcionais e segurança

Linux, Python >=3.11 e Git, biblioteca padrão apenas. Paths com espaços e Unicode. Estado local ignorado; definições versionadas. Não suporta agentes hostis com mesmo UID nem autenticação criptográfica de reviewer. Worktree não isola rede, bases, portas ou credenciais; fornecer ambientes próprios e nunca credencial produtiva. Comandos de verificação são código confiável revisado, não executar manifests não confiáveis.

U-06 (orientação posterior nesta sessão): configurar agentes e builds no Podman instalado. O controlador no host apenas administra Git, estado e processos Podman; compiladores, testes e CLIs de workers ficam dentro da imagem. Imagem-base por digest e imagem local por ID; dependências apt da imagem são registradas pelo build, sem alegar reprodução bit a bit entre rebuilds.

## Estados

BACKLOG → READY (calculado por dependências) → CLAIMED → RUNNING → VERIFYING → REVIEWING → APPROVED → MERGED. FAILED e ESCALATED são explícitos. Timeout não reatribui tarefa automaticamente. `prepare` só permite nova tentativa após estado FAILED e respeita max_retries; não apaga a worktree anterior.

## Contrato e dados

`orchestration/tasks.json` validado por schema documental e validação semântica stdlib; estado separado em `.agent-state/state.json`, protegido por flock. Cada claim registra definição, base, dono, paths, workspace e tentativas. Fingerprint de alterações vincula verificação/revisão a conteúdo. Estado não é serviço distribuído.

## Estratégia de teste e DoD

Testar DAG e traversal, conflito de claim, Git worktree em caminho Unicode, prompt dos três CLIs, preview sem efeito externo, processo com falha/timeout, escopo de rename/untracked, invalidade de verificação antiga e comprovação de integração. `make verify-foundation` executa testes e valida manifesto real. Produto SaaS continua com especificação própria; pipeline de produto não será declarado operacional por esses testes.
