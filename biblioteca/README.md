# Sistema de Gestão de Biblioteca

Este é um sistema completo de gestão de biblioteca desenvolvido em PL/SQL, projetado para gerenciar todas as operações de uma biblioteca moderna.

## Funcionalidades Principais

- Gestão de Acervo
  - Cadastro e controle de livros, periódicos e materiais digitais
  - Controle de múltiplas cópias e edições
  - Categorização e classificação por gênero, autor e editora

- Gestão de Usuários
  - Cadastro de leitores e funcionários
  - Controle de permissões e níveis de acesso
  - Histórico de empréstimos e devoluções

- Empréstimos e Reservas
  - Sistema automatizado de empréstimos
  - Gestão de reservas e fila de espera
  - Controle de multas e penalidades
  - Renovações online

- Relatórios e Estatísticas
  - Relatórios de circulação
  - Estatísticas de uso
  - Análise de acervo mais requisitado
  - Controle de multas e pagamentos

## Estrutura do Projeto

```
biblioteca/
├── tables/
│   ├── 01_create_tables.sql       # Criação das tabelas principais
│   └── 02_create_indexes.sql      # Índices e otimizações
├── packages/
│   ├── pkg_acervo.sql            # Package de gestão do acervo
│   ├── pkg_usuarios.sql          # Package de gestão de usuários
│   ├── pkg_emprestimos.sql       # Package de empréstimos e devoluções
│   └── pkg_relatorios.sql        # Package de relatórios
├── procedures/
│   └── procedures.sql            # Procedures auxiliares
├── triggers/
│   └── triggers.sql              # Triggers do sistema
└── views/
    └── views.sql                 # Views para relatórios
```

## Tecnologias Utilizadas

- Oracle Database 19c ou superior
- PL/SQL
- Particionamento de tabelas
- Índices bitmap e B-tree
- Materialized Views
- Jobs automatizados

## Como Instalar

1. Certifique-se de ter um banco Oracle instalado (19c ou superior)
2. Execute os scripts na seguinte ordem:
   - tables/01_create_tables.sql
   - tables/02_create_indexes.sql
   - packages/*.sql
   - procedures/procedures.sql
   - triggers/triggers.sql
   - views/views.sql

## Recursos Avançados

- Particionamento de tabelas para melhor performance
- Sistema de backup automático
- Auditoria completa de operações
- Cache de consultas frequentes
- Integração com sistema de pagamentos 