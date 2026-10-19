# ADR-0003 — Preparar domínio para integrações sem ativá-las

Estado: **ACEITO em U-05**. Data: 18/10/2026. Restrição confirmada: U-03, sem integração externa real.

## Contexto

O produto comercial precisa avaliar PSP, identidade, comex, documentos e câmbio. Pesquisa documental não determina contratação, enquadramento jurídico ou compatibilidade operacional. O usuário pediu deixar integrações abertas, sem conectar agora.

## Decisão proposta

Descrever capacidades e contratos internos pequenos; manter identificadores de fornecedores em vínculos próprios. Implementar adaptador apenas quando existir caso de uso especificado e aprovado. Antes disso, usar fixtures/fakes exclusivamente em testes, sem resultados simulados apresentados como operação real.

Não adotar SDK, criar conta, chave, webhook, certificado, recurso cloud ou chamada autenticada nesta fase. Estado de capacidade ausente é explícito e bloqueia a ação correspondente. Domain layer não depende de payload de fornecedor.

## Alternativas e consequências

- Acoplamento direto ao PSP acelera primeiro protótipo, mas espalha estados e regras comerciais.
- Framework universal de integrações antecipa variações desconhecidas e encarece manutenção.
- Escolher um provedor só por ter split pode inviabilizar retenção, reembolso e disputas.

Quando aprovada a primeira integração assíncrona: idempotência, autenticação de eventos, inbox/outbox quando cabível, conciliação e limites de retentativa. Não construir esse mecanismo para um rascunho sem efeitos externos.

Critérios de escolha e fontes: [integrations.md](../integrations.md). A documentação fiscal e o regime aduaneiro seguem gates distintos do pagamento.
