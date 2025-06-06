# Sistema de Gestão de RH em PL/SQL

## Descrição
Sistema avançado de gestão de recursos humanos desenvolvido em PL/SQL, incluindo análise de dados, relatórios gerenciais e automação de processos de RH.

## Funcionalidades Principais

### 1. Gestão de Funcionários
- Cadastro completo de funcionários com histórico profissional
- Gestão de cargos e salários
- Controle de promoções e transferências
- Histórico de avaliações de desempenho

### 2. Folha de Pagamento
- Cálculo automático de salários
- Processamento de benefícios
- Gestão de horas extras
- Controle de férias e 13º salário
- Integração com sistema fiscal

### 3. Análise de Dados e BI
- Dashboard de indicadores de RH
- Análise de turnover
- Relatórios de custos por departamento
- Previsões de crescimento da folha
- KPIs de performance

### 4. Recrutamento e Seleção
- Gestão de vagas
- Tracking de candidatos
- Análise de perfil vs. requisitos
- Workflow de aprovações

### 5. Treinamento e Desenvolvimento
- Gestão de programas de treinamento
- Controle de certificações
- Planos de desenvolvimento individual
- ROI de treinamentos

## Tecnologias Utilizadas
- Oracle Database 19c
- PL/SQL
- Oracle Analytics
- Packages
- Procedures
- Functions
- Triggers
- Views Materializadas
- Particionamento de Tabelas
- Jobs Automatizados

## Estrutura do Projeto

```
/src
  /tables         # Definições das tabelas
  /packages       # Packages principais
  /procedures     # Stored procedures
  /functions      # Functions
  /triggers       # Triggers do sistema
  /views         # Views e views materializadas
  /jobs          # Jobs automatizados
  /reports       # Queries para relatórios
  /analytics     # Procedures de análise de dados
  /tests         # Testes unitários
```

## Destaques Técnicos
- Implementação de ACID
- Controle de concorrência
- Otimização de queries
- Particionamento para melhor performance
- Backup e recovery procedures
- Segurança e auditoria
- Logging e monitoramento

## Como Instalar e Configurar

1. Clone este repositório
2. Execute os scripts de criação de schema
3. Execute os scripts de criação de objetos na ordem:
   - Tables
   - Sequences
   - Packages
   - Procedures
   - Functions
   - Triggers
   - Views
   - Jobs
4. Execute os scripts de dados iniciais
5. Configure os jobs automáticos

## Boas Práticas Implementadas
- Nomenclatura padronizada
- Documentação completa
- Tratamento de exceções
- Logging de operações
- Versionamento de objetos
- Testes unitários
- Performance tuning 