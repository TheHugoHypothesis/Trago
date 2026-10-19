# Iniciar codificação agora

Arquitetura mantida; contrato mínimo congelado em `contracts/http/openapi.json`. Três tarefas independentes, três worktrees, locks/dependências próprios de cada componente. O DAG sequencial anterior foi arquivado; U-07 autorizou essa rodada paralela para acelerar o MVP.

Na raiz do projeto, em três terminais:

```sh
# agy: frontend Next.js, mantendo InitialAssets/Design.png
make start-frontend
```

```sh
# Codex CLI: backend NestJS/Fastify/PostgreSQL
make start-backend
```

```sh
# pi: Android Kotlin/Compose, usando a harness/configuração instalada
make start-android
```

Ou iniciar os três processos juntos:

```sh
make start-all
```

Os launchers executam no Podman. O agy recebe `--dangerously-skip-permissions` dentro do container, pi recebe `--approve`, Codex usa permissões completas somente dentro do container. Não há socket, home inteira ou Git comum gravável. Perfis de inferência existentes são copiados seletivamente para perfis privados/ignorados, sem imprimir tokens ou sobrescrever arquivos existentes. Não há integração real do produto.

O agy recebe o protótipo somente leitura em `/opt/trago-assets/Design.png`; sua tarefa exige preservar navy/coral/off-white, hierarquia, marca e cards. Só escreve `apps/web/`. Backend só escreve `apps/api/`; Android só `apps/android/`. O contrato é montado somente leitura. Nenhum agente altera o código de outro componente.

Backend inicia com PostgreSQL local rootless em rede privada, sem porta publicada no host. Cada componente roda sua verificação essencial ao terminar. Sem merge/push/deploy automáticos.

## Para o Codex desta conversa assumir o backend

Em vez de iniciar outro Codex CLI, envie:

> Implemente MVP-backend na worktree já preparada. Use Podman para executar/buildar, siga o contrato congelado, priorize MVP funcional e testes essenciais, tome decisões reversíveis sem perguntas. Frontend e Android pertencem aos outros agentes. Não faça push/merge/deploy.

Não iniciar o CLI backend e esta conversa como escritores da mesma tarefa ao mesmo tempo.

## Continuação se acabar quota/contexto

Cada agente atualiza `.task/HANDOFF.md`; o coordenador registra `.task/RESUME.md`, histórico e logs. Se um processo falhar ou indicar quota/contexto esgotados, outro executor é iniciado **na mesma worktree**, após o anterior terminar. O progresso fica preservado. Há até três executores/duas transferências por tarefa; se todos estiverem indisponíveis, o estado fica salvo para retomar, sem prometer créditos ilimitados. Alteração fora do escopo bloqueia transferência automática.

Os agentes de pi usam o modelo/provedor padrão da configuração importada. Para escolher outro explicitamente:

```sh
python3 scripts/start_agent.py android --model 'provedor/modelo-que-voce-usa'
```

Configuração pode conter MCPs com paths/localhost exclusivos do host; esses serviços não são automaticamente acessíveis no container. O bootstrap reaproveita arquivos conhecidos de autenticação/configuração, mas login real de cada fornecedor não foi testado nesta entrega. Falhas ficam nos logs e acionam tentativa de outro executor.

## Ver progresso e abrir o MVP

```sh
make agents
make mvp-logs
```

Quando API e Web tiverem concluído o código e instalado suas dependências:

```sh
make mvp-up
```

Isso inicia serviços locais diretamente das duas worktrees, sem merge: Web em `http://localhost:3000`, API em `http://localhost:3001`. O APK Android fica no build da worktree Android. `make mvp-down` para somente os serviços de preview e preserva o banco. Esses serviços ainda não foram iniciados: a aplicação será escrita pelos três agentes.
