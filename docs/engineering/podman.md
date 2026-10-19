# Podman para agentes e builds

Estado: implementado e testado em Podman 6.1.4 rootless, por U-06. Nenhuma sessão/inferência de produto ou agy foi iniciada.

Atualização U-07: [START.md](START.md) contém os launchers atuais. `start-backend` inicia PostgreSQL de desenvolvimento antes do worker; perfis conhecidos são importados seletivamente no início, sem sobrescrever existentes. O restante registra o bootstrap anterior; nenhum launcher de produto foi executado ainda. Autenticação agy permanece sem validação real, mesmo com seed dos arquivos locais conhecidos.

## Imagem e comandos

`containers/Containerfile` instala Node 22/npm, Python 3.11, Git, make e JDK 17. `images.lock.json` fixa digest da base e ID da imagem local; apt não usa snapshot temporal, portanto não há promessa de rebuild bit a bit idêntico.

```sh
make containers-build
make containers-doctor
make verify-foundation
```

Diagnóstico real no container: Node 22.23.3, npm 10.9.9, Python 3.11.2, JDK 17.0.20.1 e Git 2.39.5. Codex 0.163.0 e pi 1.3.0 responderam a comandos de versão dentro de containers, sem inferência. Pi exige Node >=22.19.0; a imagem satisfaz o requisito.

O host executa somente o controlador Python/Git/Podman. Compiladores, testes e CLIs de workers ficam no container. `verify-foundation-local` é o target interno da imagem; `make verify` ainda falha explicitamente porque não há pipeline de produto implementado.

## Fronteiras

- Worktree rw em seu caminho absoluto; diretório Git comum ro. Stage/commit ficam com o coordenador.
- Perfil próprio em `.agent-state/profiles/<engine>` montado em `/home/node`; a home pessoal não é montada.
- Rede e cache nomeados por projeto/tarefa. Não usar network host, socket Podman/Docker ou privileged.
- Apenas o binário selecionado é montado ro; pi recebe o código da versão instalada, sem histórico pessoal.
- SDK Android instalado montado ro; cache Gradle e build outputs graváveis. Imagem permite compilação com o SDK presente, mas nenhum build Android foi executado ainda.
- Root filesystem ro; tmpfs em `/tmp`/`/run`; keep-id, usuário não root, cap-drop ALL, no-new-privileges e limites de CPU/memória/processos.

`label=disable` evita relabelar instalações de CLIs/SDK na home do host. Isso desativa a separação SELinux do container; namespaces, UID rootless, seccomp padrão e mounts limitados permanecem. Não alegar isolamento SELinux completo. Codex usa `danger-full-access` somente no argv **interno ao Podman**, que é a fronteira de SO. Não há opção CLI do controlador para executar worker diretamente no host.

Referência: [Podman run](https://docs.podman.io/en/stable/markdown/podman-run.1.html). Rootless não remove a permissão exigida pelo sandbox externo desta sessão para acessar o estado do Podman; o acesso foi autorizado nesta sessão.

## Perfis de inferência e pi harness

Configurações globais foram preservadas. Importação opcional e explícita, sem imprimir valores nem incluir segredo em Git/imagem:

```sh
python3 scripts/podman_env.py import-profile codex
python3 scripts/podman_env.py import-profile pi
```

Codex seleciona `auth.json`; pi seleciona `auth.json`, `models.json` e `settings.json`. São dados privados em diretórios ignorados; o importador não sobrescreve perfil existente. **Nenhuma credencial foi importada nesta entrega.**

Pi básico desativa descoberta de extensões/MCP/skills/templates. `--pi-harness` preserva configuração no perfil isolado. Foram identificados `@monotykamary/pi-vcc` e `pi-web-access` no host; isso não comprova funcionamento no container. Pacotes, binários auxiliares, paths absolutos e MCPs locais precisam resolução no ambiente próprio. Localhost do container não é localhost do host. Não montar home/socket para contornar falhas.

`--model`/`--provider` encaminham identificadores escolhidos pelo usuário, sem inventar modelos. Autenticação do agy não teve seu formato verificado; usar seu fluxo de login no perfil próprio quando a execução real for autorizada. Não copiar pasta inteira com histórico.

## Builds e serviços

```sh
# Preview; não inicia container.
python3 scripts/podman_env.py run --task T02-api -- python3 --version

# Comando no ambiente isolado.
python3 scripts/podman_env.py run --task T02-api --execute -- npm --version
```

DATABASE_URL aponta para `db:5432` na rede de tarefa como configuração local proposta; o launcher **não inicia PostgreSQL automaticamente**. T00 define serviços e o coordenador os administra; worker não recebe socket. Uma variável de conexão não é evidência de banco operacional. Emulador Android/KVM também não foi habilitado nem validado; precisa perfil próprio de dispositivo/grupos/bibliotecas.

Timeout encerra o grupo de processos e solicita parada do container nomeado. Crash/SIGKILL do próprio coordenador exige auditar processo/container/estado antes de recuperar claim; não há daemon de leases ou reatribuição automática. Nunca apagar trabalho para liberar uma tarefa.
