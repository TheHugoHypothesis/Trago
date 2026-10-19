# ADR-0001 — Monólito modular e clientes separados

Estado: **ACEITO em U-05**. Data: 18/10/2026. Decisor: usuário. Implementação local autorizada; serviços externos continuam desabilitados. U-06 determina Podman para workers e builds.

## Contexto

U-01 exige Web e Android; U-02 inclui PF/PJ. Há busca, pedidos, tributos, pagamentos e documentos previstos, mas não há código ou volume operacional comprovado. Complexidade dominante é consistência do domínio e operação, não escala distribuída.

## Decisão proposta

Next.js/TypeScript no Web; Kotlin/Compose no Android; NestJS com Fastify no backend; PostgreSQL; contrato OpenAPI versionado; npm workspaces e Gradle Wrapper. Começar com um processo de API e fronteiras internas por domínio. Redis, microsserviços, Kubernetes e ML ficam fora até necessidade demonstrada.

## Alternativas

- React/Vite é menor se não houver páginas públicas/SEO ou sessão no servidor. Tradeoff: sessão e composição pública exigem solução adicional.
- Fastify direto reduz framework; aumenta a responsabilidade da equipe por convenções consistentes.
- Spring Boot/Kotlin ou Java é apropriado para transações e segurança e pode vencer se a equipe dominar JVM. Não escolher TS por suposta superioridade financeira.
- React Native compartilha linguagem com Web; Flutter oferece outra estratégia de UI. Ambos exigem validar dependências nativas e manutenção; conhecimento da equipe ainda não foi informado.

## Consequências e aprovação pendente

Dois ecossistemas de build; nenhuma regra fiscal ou monetária duplicada nos clientes. ORM, versões exatas e bibliotecas serão decididos com compatibilidade e testes. A proposta não fixa cloud, estimativa de custo nem fornecedor. Reavaliar com experiência da equipe, orçamento e critérios de VS-01.

Detalhes e fontes: [overview.md](../overview.md). Aceitar este ADR exige confirmação explícita e registro no [decision-log](../../engineering/decision-log.md).
