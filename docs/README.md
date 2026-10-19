# Trago — descoberta e proposta de arquitetura

Data: 18/10/2026 (America/Sao_Paulo). Estado: **arquitetura aprovada; fundação implementada em Podman; SaaS ainda não implementado**.

O usuário confirmou produto comercial PF/PJ, aprovou a arquitetura e autorizou codificação/orquestração com poucas perguntas. A orientação seguinte exige Podman para agentes/builds. Integrações reais continuam desabilitadas; agy não foi iniciado.

## Leitura recomendada

**U-07 — iniciar agora:** [comandos dos três agentes e continuação automática](engineering/START.md). O contrato mínimo foi congelado para liberar backend, frontend e Android simultaneamente.

1. [Guia de execução paralela](engineering/agent-orchestration.md) e [Podman/perfis](engineering/podman.md).
2. [Descoberta e evidências](product/discovery.md) e [visão](product/vision.md).
3. [Arquitetura proposta](architecture/overview.md).
4. [Pesquisa de integrações](architecture/integrations.md).
5. [Modelo de ameaças](architecture/threat-model.md).
6. [ADRs propostos](architecture/decisions/0001-stack-and-boundaries.md).
7. [Auditoria do ambiente](engineering/environment-audit.md) e [relatórios das fases](planning/phase-reports.md).
8. [Especificação da fundação](../specs/000-agent-orchestration/spec.md) e [primeira fatia local](../specs/001-request-draft/spec.md).

## Estado dos artefatos

- Originais de `InitialAssets/` preservados; ambientes Podman os montam somente leitura quando necessário.
- ADRs aceitos em U-05; controlador/task schema/DAG/policy e imagem local implementados por specs 000/001.
- `make verify-foundation` verifica o controlador no Podman. `make verify` falha explicitamente até existir pipeline completo do produto.
- Web/API/Android/contrato do produto ainda não implementados; provedores não contratados/conectados/homologados.
- Revisão independente nativa do Codex identificou problemas de concorrência/fingerprint/log, corrigidos com regressão. Não houve sessão agy nem inferência paga de worker.

## Convenção de rastreabilidade

`U-*`: instrução confirmada do usuário; `S-*`: fonte original; `E-*`: evidência externa; `R-*`: requisito candidato extraído; `A-*`: hipótese; `Q-*`: questão em aberto; `D-*`: decisão; `VS-*`: proposta de fluxo vertical. Os identificadores e suas origens estão na descoberta e no registro de decisões.
