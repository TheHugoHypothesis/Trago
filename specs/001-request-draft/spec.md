# 001 — Primeira fatia local PF/PJ

Estado: implementação local autorizada pela aprovação da arquitetura e instrução de foco em codificação (U-05, 18/10/2026). Escopo técnico VS-01; sem operação comercial, dinheiro, transporte ou integração externa reais. Modelo aduaneiro segue pendente e não será simulado como conformidade.

U-07: priorizar MVP funcionando e entrega rápida; frontend deve preservar identidade de InitialAssets/Design.png. O coordenador congelou `contracts/http/openapi.json` e fixtures antes da rodada. As três tarefas MVP-backend/frontend/android agora são independentes e alteram somente seu componente, inclusive package/lockfile local. Não instalar workspace/lockfile raiz em paralelo. O DAG sequencial anterior foi arquivado em `orchestration/backlog.initial.json`. Usar verificações essenciais de build, autorização e smoke; não ampliar escopo para testes intensivos nesta rodada.

Para a demo local, usar os Bearer `dev:buyer`, `dev:traveler`, `dev:outsider`, `dev:revoked` somente com modo demo explícito; produção rejeita esse mecanismo. É uma simplificação autorizada para a fatia local, não autenticação produtiva. O contrato congelado define formas exatas de payload/erro; fixtures são exemplos sintéticos, não cadastros reais.

## Problema e histórias

Validar que Web e Android usam a mesma API e persistência, com isolamento pessoal/empresarial. Viajante de teste publica viagem fictícia. Comprador PF ou representante ativo de PJ busca por rota/data, escolhe contexto, cria solicitação privada e a consulta em outro cliente.

## Requisitos

- Contextos User/Account(PERSONAL|ORGANIZATION), Organization e Membership; dono/membro ativo autoriza cada operação. Rascunho não é visível ao viajante.
- Fixtures sintéticas para duas PF, duas PJ e representante revogado; CNPJ numérico e alfanumérico como texto. A mesma pessoa pode representar várias contas.
- Emissor de identidade de teste apenas local; produção rejeita configuração de teste. Sem login público, custom IdP produtivo ou integração OIDC externa neste incremento.
- Viagem: origem/destino, datas/timezone, capacidade inteira em gramas e tarifa de referência. Viajar não comprova autorização aduaneira. Publicação é visível como oferta fictícia.
- Solicitação: Account proprietária, descrição/link de produto, moeda, valor inteiro como string e peso em gramas; estado DRAFT. Não reservar capacidade, cobrar ou enviar solicitação ao viajante.
- Busca paginada com ordenação estável, filtros validados e respostas de vazio/erro. Não buscar conteúdo de URLs no servidor.
- Persistir em PostgreSQL por migração versionada; reinício da API preserva dados. Sem SQLite substituindo integração PostgreSQL.
- Idempotência na criação por ator/conta/operação/chave/payload; conflito para payload diferente. Limites e validade definidos no OpenAPI antes de handlers.
- API /v1: accounts do ator, publicar/buscar viagem, criar/ler purchase-request. YAML canônico com schemas e erros; clientes TS/Kotlin gerados reproduzivelmente.
- Interfaces em português, acessíveis; Web responsivo e Compose com ViewModel/data. Loading, vazio, sessão expirada, offline/retomada e troca de contexto não vazam dados nem duplicam criação.

## Aceitação

AC-01: viajante publica viagem; busca por rota/data retorna somente viagens compatíveis e fictícias.
AC-02: criar rascunho PF e PJ persiste e permite leitura Web→API→Android com mesma identidade/contexto.
AC-03: outra PF, outra PJ, membro revogado e viajante não conseguem ler rascunho privado; erros não enumeram sua existência.
AC-04: reenvio idêntico retorna mesma solicitação; payload diferente com mesma chave é conflito.
AC-05: peso/valor/data/URL inválidos são rejeitados; CNPJ alfanumérico preservado em contrato/fixtures.
AC-06: reiniciar backend não perde rascunho; troca de conta limpa estado privado; falha de rede não resulta em sucesso fictício.
AC-07: generated clients/contrato/API são consistentes; CI executa verificações reais; ausência de banco/SDK falha explicitamente.
AC-08: nenhuma chamada a PSP/KYC/comex/fiscal/câmbio ocorre. Interface não promete importação legal, entrega real ou escrow operacional.

## Contrato, segurança e dependências

Backend é autoritativo. Todos os campos derivados de identidade/contexto precisam validação server-side. Dados sintéticos somente; logs sem tokens/documentos completos. Manter separação PF/PJ em exports/caches futuros.

Ordem: T00 toolchain/manifests comuns → T01 contrato/fixtures/clientes → T02 API, T03 Web e T04 Android em paralelo → T05 E2E/CI. Somente liberar dependentes quando contrato estiver revisado e integrado numa base comum. Integração Git exige autorização vigente; controlador não integra sozinho.

## Testes e DoD

Unit/integration para autorização, filtros, idempotência, validação e persistência; Web E2E real; testes Compose/JVM e instrumentação; contract checks e builds. Implementação mínima de mocks só para testes isolados, identificada como tal. Resultado inclui red/green, comando/cwd/exit e revisão independente. Não chamar essa fatia de MVP comercial pronto.
