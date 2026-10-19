# Registro de decisões

Data de abertura: 18/10/2026. Sem dependência exclusiva do histórico de conversa; este arquivo registra a direção atual e seu estado.

| ID | Estado | Decisão / origem | Consequência |
| --- | --- | --- | --- |
| D-01 | CONFIRMADA | Preservar originais e não implementar antes da aprovação (U-01) | Somente pesquisa e documentos novos nesta fase |
| D-02 | CONFIRMADA | Produto comercial PF e PJ desde o início (U-02) | PJ permanece no MVP e na primeira fatia técnica |
| D-03 | CONFIRMADA | Pesquisar integrações sem ativar (U-03) | Sem contas, SDKs, credenciais, callbacks ou recursos externos |
| D-04 | CONFIRMADA | Priorizar arquitetura; orquestração depois; não executar `agy` agora (U-04) | Revisão externa adiada; sem runner/agente adicional |
| D-05 | VERIFICADA | Raiz Git é `Trago`, commit inicial, main/origin; assets não rastreados | Não inicializar outro Git nem presumir branch protegida |
| D-06 | PROPOSTA | Monólito modular + Next/TS + Nest/Fastify + PostgreSQL + Kotlin/Compose | ADR-0001 depende de aprovação e capacidade da equipe |
| D-07 | PROPOSTA | User separado de Account PF/PJ, Organization e Membership | ADR-0002; autorização por participante/recurso |
| D-08 | PROPOSTA | Portas de integração pequenas, sem adaptadores atuais | ADR-0003; não criar framework genérico |
| D-09 | PROPOSTA | VS-01 de viagem/solicitação privada com PF/PJ e persistência | Não é lançamento comercial nem transação financeira |
| D-10 | PENDENTE | Regime aduaneiro, importador e papel do viajante | Q-01 bloqueia operação comercial e regra fiscal vinculante |
| D-11 | PENDENTE | PSP/retention, preço/câmbio, documentos e representação | Q-02 a Q-08; fornecedores sem seleção |
| D-12 | CONFIRMADA | U-05 aprovou arquitetura e autorizou codificação/orquestração local sem confirmações rotineiras | D-06/D-07/D-08 aceitas; fundação 000 implementada e spec 001 detalhada |
| D-13 | CONFIRMADA | U-06 exige Podman para agentes/builds | Worker sempre no container rootless; controlador Git/estado no host |
| D-14 | IMPLEMENTADA | Imagem local, mounts mínimos, perfis separados, rede/cache por projeto/tarefa | Sem privileged/socket/home inteira; Git e assets ro |
| D-15 | CONFIRMADA | U-07 prioriza MVP e três implementadores paralelos | agy em Web, Codex em API, pi em Android; contrato congelado e verificações essenciais |
| D-16 | IMPLEMENTADA | Launchers com handoff sequencial limitado e checkpoints na mesma worktree | Preserva progresso quando houver falha/quota; não cria créditos nem executores concorrentes na mesma tarefa |

D-04 registra orientação histórica: a prioridade de adiar orquestração foi superada por U-05. A restrição de não iniciar agy nesta sessão foi mantida. D-06/D-07/D-08, originalmente propostas na tabela, foram aceitas em U-05, conforme ADRs atualizados.

## Aprovação

Quando ocorrer, registrar: decisão/ADR ou spec, revisão exata, responsável, data e escopo autorizado. Aprovação de arquitetura não equivale a aprovação de fundação, código, integração real, merge, push ou deploy. Divergências posteriores atualizam a decisão e artefatos afetados; não transformar proposta em confirmação por mera passagem de tempo.

## Revisão independente

Na primeira entrega, nenhuma concluída e tentativas de CLIs falharam antes da análise. Na implementação da fundação, um revisor nativo Codex, somente leitura, encontrou corrida de verify, output ignorado fora do fingerprint e falha de log prendendo estado. Achados reproduzidos e corrigidos; regressão no Podman. Não houve execução/inferência do agy ou segunda instância do Codex CLI. Ver relatório de validação da orquestração.
