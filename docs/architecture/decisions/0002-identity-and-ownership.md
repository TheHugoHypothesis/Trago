# ADR-0002 — Identidade pessoal e contexto comercial PF/PJ

Estado: **ACEITO em U-05**. Data: 18/10/2026. Identidade externa real permanece sem integração.

## Contexto

PF/PJ desde o início é requisito confirmado, não hipótese. Usuário pode comprar para si, representar empresas e viajar. Visibilidade entre comprador e viajante não equivale a acesso ao tenant empresarial inteiro.

## Decisão proposta

Separar User, Account pessoal/empresarial, Organization e Membership ativa. Solicitação pertence a uma Account; Order posterior declara participantes. Verificação de existência da empresa, autoridade do representante e autenticação são controles distintos. Autorização por recurso no backend é obrigatória.

OIDC Code/PKCE; cookie opaco com tokens no servidor Web; navegador externo e armazenamento protegido no Android. IdP não selecionado nem conectado. Apenas emissor local isolado para testes enquanto integração externa estiver adiada.

## Alternativas e consequências

- Uma conta = uma pessoa = uma empresa impede múltiplas representações e mistura dados.
- Tenant por usuário com compartilhamento improvisado cria duplicação e falhas de autorização.
- Banco por empresa aumenta operação sem requisito que o justifique hoje.
- RLS como defesa adicional requer avaliação dos participantes e do pool; não substitui autorização da aplicação e não está aprovado como mecanismo único.

Revogar membership invalida futuras operações no backend; token antigo não mantém poderes empresariais. Política de documentos distingue comprador, representante, viajante e suporte. Casos de isolamento são critérios de aceitação de VS-01.
