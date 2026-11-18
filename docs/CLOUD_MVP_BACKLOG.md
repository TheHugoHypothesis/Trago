# Backlog de consolidação do Trago Cloud MVP

Atualizado em 18/11/2026. O [guia de implantação](CLOUD_DEPLOYMENT.md) registra as evidências de T14 a T17. Os itens abaixo continuam pendentes e precisam de aprovação antes de implementação.

| Etapa | Pendência | Evidência de conclusão proposta |
| --- | --- | --- |
| T10 | Definir a semântica monetária para preço, moedas, conversão e arredondamento. Distinguir estimativa de valor final na API e no aplicativo. | Contrato de dinheiro documentado e testes de precisão, arredondamento e consistência entre backend e Flutter. |
| T11 | Proposta de escopo para pagamentos, repasse e eventual custódia. Decidir o fluxo e o provedor antes de integrar. | Fluxo aprovado, com autorização, idempotência e conciliação verificadas em ambiente de teste. Operações financeiras reais exigem autorização própria. |
| T12 | Proposta de escopo para rastreio, acompanhamento após o aceite e verificação documental. Definir os dados mínimos por fluxo e quem pode acessá-los. | Estados definidos, histórico verificável e testes de autorização. Qualquer tratamento de documentos depende de definição de acesso e retenção. |
| T18 | Proposta de consolidação após a avaliação do grupo. Priorizar melhorias de interface, experiência e funcionalidades. Decidir distribuição e assinatura Android, configurar o build cloud no GitHub e confirmar as cotas por IP por origens distintas no Render. | Feedback triado, regressões prioritárias verificadas e decisões de distribuição registradas. Alterar variáveis globais, fazer merge ou publicar release exige aprovação. |

O relatório anterior identifica a semântica monetária na T10 e lista pagamentos, rastreio e verificação documental como pendências. O backlog original detalhado de T11 e T12 não está versionado nesta base. A divisão sugerida acima não confirma a numeração original. [Estado da implementação T00–T09](IMPLEMENTATION_STATUS.md).
