# Fase 0 — auditoria do ambiente

Auditoria: 18/10/2026, America/Sao_Paulo. Snapshot auditado do repositório antes dos documentos: `52244f6fdd69f802dbbecf3256352a87382bcc3f`.

## Repositório e arquivos

- Raiz confirmada por `git rev-parse --show-toplevel`: `/home/elliot/Desktop/God Ex Machina/40-49 Projects/41 BSI/41.06 6º Semestre/EI/Trago`.
- Branch `main`, acompanhando `origin/main` segundo refs locais; um commit, `52244f6 Initial commit`. Não houve fetch; sincronismo com o servidor não foi confirmado.
- Remote: `https://github.com/TheHugoHypothesis/Trago`, fetch/push configurados. Nenhum push, merge, alteração de branch, commit ou inicialização foi feito.
- Antes da pesquisa: apenas `LICENSE` e `.gitignore` rastreados. Licença MIT, copyright Hugo Cardoso, 2026. `.gitignore` é template Python, não evidência de implementação Python.
- Três arquivos em `InitialAssets/`, todos inicialmente não rastreados; inventário e hashes na [descoberta](../product/discovery.md).
- Não encontrados: código, package/build manifests, CI, AGENTS.md, GEMINI.md, instruções aninhadas ou instruções nos ancestrais inspecionados até `/`. Hooks presentes são somente samples; `core.hooksPath` não configurado na leitura realizada.
- Branch protections/rulesets no GitHub não foram consultados; não há evidência local de proteção. Nenhuma configuração remota foi alterada.

## Ferramentas verificadas

| Item | Resultado observado | Limite |
| --- | --- | --- |
| Linux | Host `interstellar`, kernel `7.2.10-300.fc45.x86_64`, x86_64; shell zsh | Não é validação de ambiente de produção |
| Node / npm | v22.14.0 / 10.9.2 | Compatibilidade/dependências não instaladas/testadas |
| Python | 3.15.0 | Utilizado para inventário/registro de planejamento; não é escolha do backend |
| Java default | OpenJDK 27-ea | Não fixar JDK experimental no build; JDKs 17/21 também encontrados |
| Android SDK | `~/Android/Sdk`; platforms 34, 35, 36, 37.0; build-tools 35.0.0, 36.0.0, 36.1.0; adb/emulator/sdkmanager encontrados | Build, emulator e matriz de compatibilidade não executados |
| make / gh | Make 4.4.1 / gh 2.97.0 | Autenticação GitHub e acesso à API não testados |
| pnpm / Gradle / kotlinc / Docker | Não encontrados no PATH | Nada instalado; futuro Gradle Wrapper é proposta |
| Podman | Binário encontrado; tentativa de `--version` falhou ao acessar estado runtime em diretório somente leitura | Containers não validados; sem afirmar disponibilidade de banco ou CI |
| Poppler | pdfinfo, pdftotext e pdftoppm disponíveis | Usados para ler PDFs/renderizar cópias em `/tmp`, sem modificar originais |
| Codex | `/home/elliot/.local/bin/codex`, `codex-cli 0.163.0` | Interface local inspecionada; segunda sessão não inicializou |
| agy | `/home/elliot/.local/bin/agy`; help inspecionado; `/usr/bin/antigravity` também existe | Não equivaler os dois binários; versão/sessão operacional do agy não comprovadas |

## CLIs: capacidade inspecionada e execução interrompida

`codex --version`, `codex --help` e `codex exec --help` responderam; help local confirmou execução não interativa, `read-only`, `--ephemeral`, saída em arquivo e controles de configuração. Houve avisos de diretório somente leitura. A documentação oficial foi consultada como apoio: [modo não interativo](https://learn.chatgpt.com/docs/non-interactive-mode). A interface da instalação foi a evidência para os argumentos tentados; nenhum modelo foi escolhido ou substituído.

`agy --help` respondeu, expondo `--mode plan`, `--sandbox`, `--print`, `--print-timeout` e opção de desativar expansão de comandos. Isso não comprova política somente leitura completa nem funcionamento da sessão.

Antes da correção U-04, foram tentadas revisões limitadas com resumo de evidências e hipóteses, sem pedido de código. Codex saiu **1** antes da revisão, ao inicializar app-server em filesystem restrito. agy saiu **1**, com logs locais bloqueados e socket de loopback não permitido. Arquivos temporários não contêm parecer concluído.

O pedido subsequente de permissões ampliadas foi interrompido pelo usuário. Não há execução ampliada concluída nem resultado de revisão. Após U-04, nenhum CLI de agente foi reiniciado; a inspeção do processo visível não mostrou a revisão em execução. Não alegar auditoria de processos fora do namespace do sandbox.

## Evidência e exit codes

[environment-commands.json](environment-commands.json) registra argv, saída e exit code de 17 comandos essenciais reexecutados em modo de leitura. Todos retornaram 0. Isso verifica inventário/metadados, não comportamento de uma aplicação.

Outras execuções observadas nesta sessão:

| Comando/ação | Exit/status observado | Interpretação |
| --- | --- | --- |
| `pdftotext -layout` nos dois PDFs | 0 | Relatório textual legível; slides não tinham texto útil |
| `pdftoppm` dos 8 slides e figura p. 2 | 0 | Cópias de visualização em `/tmp` |
| `codex --version`, `--help`, `exec --help`; `agy --help` | 0 na inspeção registrada | Help não equivale a sessão de agente funcional |
| `docker --version` | comando não encontrado | Docker indisponível no PATH |
| `podman --version` | falha com mensagem de filesystem restrito | Disponibilidade operacional desconhecida |
| `codex sandbox linux --help` | 1 | Falhou em validação de diretório de socket; nenhum isolamento adicional configurado |
| Codex review não interativa | 1 | Falha de inicialização, sem achados |
| agy review em plan/sandbox | 1 | Falha de inicialização, sem achados |
| Execução ampliada dos revisores | interrompida pelo usuário | Nenhuma revisão concluída; não repetir agora |
| Testes de aplicação, build, CI e `make verify` | não executados; inexistentes | Não declarar aprovação técnica operacional |

Comandos compostos iniciais podem terminar em 0 apesar de uma ferramenta anterior ter falhado; as falhas acima estão explícitas, e o JSON registra subprocessos individuais para as leituras essenciais. Verificações de integridade dos documentos/originais serão registradas no relatório final desta fase.
