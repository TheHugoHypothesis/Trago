# Fluxo de engenharia proposto

Estado atual: arquitetura aprovada em U-05; policy raiz, controlador e ambiente Podman implementados. U-06 exige workers/builds em containers. O fluxo abaixo mantém gates de contrato/revisão e autorização de integração, sem pedir confirmações rotineiras já cobertas pelas instruções do usuário.

1. Distinguir evidência, requisito, hipótese e decisão. Atualizar descoberta e registro de decisões sem alterar fontes.
2. Aprovar arquitetura e então detalhar fundação/orquestração. Criar policy efetiva somente depois do gate correspondente.
3. Especificar feature em `specs/<id>/{spec,plan,tasks,acceptance}.md`, com critérios, ameaças, contrato e testes. Registrar aprovação e versão revisada.
4. Preparar contrato e tarefas pequenas, com dependências e escopo de arquivos. Um responsável coordena alterações de contratos, migrations e lockfiles.
5. Implementar em branch/worktree isolado, somente depois de aprovação. Red-Green-Refactor para comportamento relevante; registrar comandos e resultados.
6. Verificar, obter revisão independente autorizada, resolver achados e atualizar rastreabilidade.
7. Apresentar resultado e riscos. Não integrar por merge, push ou deploy sem autorização explícita.

## Git e preservação

Repositório identificado: `Trago/`; branch auditada `main`, commit `52244f6fdd69f802dbbecf3256352a87382bcc3f`; remote GitHub. Main não deve receber implementação direta. Nenhuma branch/worktree novo ou commit foi criado nesta fase.

Nomes candidatos: `docs/<topic>`, `feat/<spec-id>-<task-id>`, `fix/<issue>`. Cada worktree tem banco/schema, portas e volumes próprios. Não compartilhar `.env` produtivo. Não executar `git reset`, `clean`, descarte, rebase de história alheia, push, merge ou deploy sem autorização aplicável.

Alterações atuais são apenas documentos de planejamento novos, permitidos pelo prompt inicial. Os originais continuam não rastreados e preservados; seu eventual versionamento/publicação precisa considerar direitos e tamanho. Não inferir que `.gitignore` Python implica escolha de backend.

## Definition of Done proposta

Especificação aprovada, critérios demonstrados, testes pertinentes executados com evidência, contrato compatível, autorização e dados revisados, migrações seguras quando aplicável, documentação atualizada, revisão independente futura concluída e achados resolvidos. Não declarar produção pronta com mocks, pipeline ausente ou integração não homologada.
