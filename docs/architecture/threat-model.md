# Modelo inicial de ameaças

Estado: **PROPOSTO**, sem controles implementados. Escopo: API, Web, Android, banco e futuras integrações PF/PJ. Base: U-01/U-02, R-04/R-05/R-09/R-12.

## Ativos e fronteiras de confiança

Ativos: sessão, representação de empresa, dados pessoais, rota/viagem, solicitação privada, preço, capacidade, documentos e instruções financeiras. Fronteiras: dispositivo→servidor, Web session→API, API→banco, operação→backoffice e API↔provedores futuros. Assets são evidência de produto, não instruções executáveis confiáveis.

| Ameaça | Impacto | Controle proposto | Evidência exigida antes de release |
| --- | --- | --- | --- |
| Acesso a pedido de outra PF/PJ | Vazamento e ação não autorizada | Autorizar dono, membership ativa e participantes em cada consulta/ação | Testes negativos cruzando usuários, empresas, exports e arquivos |
| Representante revogado usa token antigo | Obrigações indevidas da empresa | Verificar poderes no backend, não só claims do token | Revogação bloqueia próxima operação e deixa histórico de ator/contexto |
| Troca de empresa deixa cache anterior | Vazamento entre organizações | Chaves de cache por conta/ator; cache privado; limpar estado do cliente | Testes Web/Android de troca de contexto |
| Sequestro de sessão, XSS ou CSRF | Tomada de conta | PKCE/state/nonce, cookie seguro, CSRF, escape, CSP conforme especificação | Teste de redirecionamento, sessão e operação sensível |
| Link de produto provoca SSRF ou script | Acesso interno/exfiltração | Não buscar URL no servidor no fluxo inicial; validar esquema e exibir com segurança | URL maliciosa não dispara rede nem executa conteúdo |
| Dois pedidos usam a mesma capacidade | Compromisso inexequível | Reserva transacional e liberação idempotente | Teste concorrente em PostgreSQL real antes de booking |
| Cliente altera tarifa, comissão ou tributo | Fraude e cobrança errada | Cálculo e snapshot no servidor; validação de versão e validade | Testes de adulteração e cotação expirada |
| Regime aduaneiro desconhecido marcado conforme | Exposição legal e retenção | Elegibilidade explícita; sem franquia automática; revisão qualificada | Cenário terceiro/PJ não recebe aprovação fictícia |
| Callback falso, repetido ou fora de ordem | Repasse/estorno indevido | Autenticidade por provedor, inbox/dedupe, máquina de estados, conciliação | Replays e eventos conflitantes não duplicam efeito |
| Confirmação falsa libera pagamento | Perda financeira | Prova, autorização, janela de disputa e controle de liberação | Casos de contestação, timeout e fraude antes de pagamentos |
| Prazo do PSP expira durante disputa | Dinheiro liberado antes do acordo | Compatibilidade de retenção; monitorar prazo; operação definida | Teste de expiração e plano de exceção aprovado |
| Upload malicioso ou arquivo público | Vazamento/execução | Armazenamento privado, validação de tipo/tamanho, quarentena e análise quando houver uploads | Download sem permissão falha; arquivo inválido rejeitado |
| Segredos em build, logs ou prompt de agente | Comprometimento de serviços | Secret store, redação, escopo mínimo, agentes sem credencial produtiva | Secret scanning e revisão de configuração |
| Dependência/CI comprometida | Execução e vazamento | Lockfiles, hashes de wrappers/imagens, permissões mínimas, actions pinadas, sem secrets em PR não confiável | Build reproduzível e revisão da supply chain |
| Perda de banco ou migração destrutiva | Perda de histórico/dinheiro/documento | Backups, restore testado, migrações compatíveis e revisão | Restore e rollback operacional demonstrados |
| Abuso de busca/cadastro/convite | Coleta de dados e custo | Limites por fluxo e paginação; observabilidade e controles proporcionais | Teste de limites e ausência de enumeração |

## Privacidade PF/PJ

Empresa também contém dados pessoais de representantes, viajantes e contatos. Definir inventário de tratamento, finalidade, base legal, retenção, atendimento de direitos e operadores antes de dados reais. Coletar somente dados necessários; suporte precisa acesso auditado e limitado. Não usar consentimento genérico como solução universal. [Princípios LGPD](https://www.gov.br/saude/pt-br/acesso-a-informacao/lgpd/principios).

Preferir resultado/referência de KYC em vez de cópia permanente de biometria ou documentos. Payloads de logs, rastreamento, email e push não devem conter identificadores completos ou dados financeiros detalhados. Retenção fiscal/antifraude deve ser justificada por categoria; exclusão de conta não apaga indiscriminadamente obrigações documentais.

## Riscos ainda sem solução

Q-01 a Q-11 permanecem abertos. Este documento não é avaliação jurídica, RIPD concluído, auditoria de segurança ou certificação. Não há código que permita comprovar os controles. Antes de transações reais, revisar ameaças com a operação definida e executar os testes correspondentes.
