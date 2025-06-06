-- Script de Criação das Tabelas Principais do Sistema de RH
-- Autor: [Seu Nome]
-- Data: [Data Atual]

-- Sequências
CREATE SEQUENCE seq_funcionario START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_departamento START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_cargo START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_beneficio START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_treinamento START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_vaga START WITH 1 INCREMENT BY 1;

-- Tabela de Departamentos
CREATE TABLE departamentos (
    id_departamento NUMBER DEFAULT seq_departamento.NEXTVAL PRIMARY KEY,
    nome VARCHAR2(100) NOT NULL,
    descricao VARCHAR2(500),
    gerente_id NUMBER,
    orcamento_anual NUMBER(15,2),
    centro_custo VARCHAR2(20),
    data_criacao DATE DEFAULT SYSDATE,
    status VARCHAR2(20) DEFAULT 'ATIVO',
    CONSTRAINT chk_status_dept CHECK (status IN ('ATIVO', 'INATIVO'))
) PARTITION BY RANGE (data_criacao)
(
    PARTITION dept_2023 VALUES LESS THAN (TO_DATE('2024-01-01', 'YYYY-MM-DD')),
    PARTITION dept_2024 VALUES LESS THAN (TO_DATE('2025-01-01', 'YYYY-MM-DD')),
    PARTITION dept_future VALUES LESS THAN (MAXVALUE)
);

-- Tabela de Cargos
CREATE TABLE cargos (
    id_cargo NUMBER DEFAULT seq_cargo.NEXTVAL PRIMARY KEY,
    titulo VARCHAR2(100) NOT NULL,
    descricao VARCHAR2(500),
    nivel VARCHAR2(20),
    faixa_salarial_min NUMBER(12,2),
    faixa_salarial_max NUMBER(12,2),
    requisitos CLOB,
    data_criacao DATE DEFAULT SYSDATE,
    CONSTRAINT chk_nivel CHECK (nivel IN ('JUNIOR', 'PLENO', 'SENIOR', 'ESPECIALISTA', 'GERENTE'))
);

-- Tabela de Funcionários
CREATE TABLE funcionarios (
    id_funcionario NUMBER DEFAULT seq_funcionario.NEXTVAL PRIMARY KEY,
    nome VARCHAR2(100) NOT NULL,
    cpf VARCHAR2(14) UNIQUE,
    data_nascimento DATE,
    email VARCHAR2(100) UNIQUE,
    telefone VARCHAR2(20),
    endereco VARCHAR2(200),
    data_admissao DATE DEFAULT SYSDATE,
    data_demissao DATE,
    id_departamento NUMBER,
    id_cargo NUMBER,
    salario_atual NUMBER(12,2),
    status VARCHAR2(20) DEFAULT 'ATIVO',
    gestor_id NUMBER,
    foto BLOB,
    curriculo CLOB,
    CONSTRAINT fk_func_dept FOREIGN KEY (id_departamento) REFERENCES departamentos(id_departamento),
    CONSTRAINT fk_func_cargo FOREIGN KEY (id_cargo) REFERENCES cargos(id_cargo),
    CONSTRAINT fk_func_gestor FOREIGN KEY (gestor_id) REFERENCES funcionarios(id_funcionario),
    CONSTRAINT chk_status_func CHECK (status IN ('ATIVO', 'FERIAS', 'AFASTADO', 'DESLIGADO'))
) PARTITION BY RANGE (data_admissao)
(
    PARTITION func_2023 VALUES LESS THAN (TO_DATE('2024-01-01', 'YYYY-MM-DD')),
    PARTITION func_2024 VALUES LESS THAN (TO_DATE('2025-01-01', 'YYYY-MM-DD')),
    PARTITION func_future VALUES LESS THAN (MAXVALUE)
);

-- Tabela de Benefícios
CREATE TABLE beneficios (
    id_beneficio NUMBER DEFAULT seq_beneficio.NEXTVAL PRIMARY KEY,
    nome VARCHAR2(100) NOT NULL,
    descricao VARCHAR2(500),
    valor NUMBER(12,2),
    tipo VARCHAR2(30),
    status VARCHAR2(20) DEFAULT 'ATIVO',
    CONSTRAINT chk_tipo_beneficio CHECK (tipo IN ('SAUDE', 'ALIMENTACAO', 'TRANSPORTE', 'EDUCACAO', 'OUTROS'))
);

-- Tabela de Funcionários x Benefícios
CREATE TABLE funcionarios_beneficios (
    id_funcionario NUMBER,
    id_beneficio NUMBER,
    data_inicio DATE DEFAULT SYSDATE,
    data_fim DATE,
    valor_especifico NUMBER(12,2),
    observacoes VARCHAR2(500),
    CONSTRAINT pk_func_benef PRIMARY KEY (id_funcionario, id_beneficio),
    CONSTRAINT fk_funcbenef_func FOREIGN KEY (id_funcionario) REFERENCES funcionarios(id_funcionario),
    CONSTRAINT fk_funcbenef_benef FOREIGN KEY (id_beneficio) REFERENCES beneficios(id_beneficio)
);

-- Tabela de Histórico Salarial
CREATE TABLE historico_salarial (
    id_funcionario NUMBER,
    data_alteracao DATE DEFAULT SYSDATE,
    salario_anterior NUMBER(12,2),
    salario_novo NUMBER(12,2),
    motivo VARCHAR2(100),
    aprovado_por NUMBER,
    CONSTRAINT pk_hist_sal PRIMARY KEY (id_funcionario, data_alteracao),
    CONSTRAINT fk_histsal_func FOREIGN KEY (id_funcionario) REFERENCES funcionarios(id_funcionario),
    CONSTRAINT fk_histsal_aprov FOREIGN KEY (aprovado_por) REFERENCES funcionarios(id_funcionario)
);

-- Tabela de Avaliações de Desempenho
CREATE TABLE avaliacoes_desempenho (
    id_funcionario NUMBER,
    data_avaliacao DATE DEFAULT SYSDATE,
    avaliador_id NUMBER,
    nota_geral NUMBER(3,1),
    pontos_fortes CLOB,
    pontos_melhoria CLOB,
    metas_proximas CLOB,
    status VARCHAR2(20),
    CONSTRAINT pk_aval_desemp PRIMARY KEY (id_funcionario, data_avaliacao),
    CONSTRAINT fk_aval_func FOREIGN KEY (id_funcionario) REFERENCES funcionarios(id_funcionario),
    CONSTRAINT fk_aval_avaliador FOREIGN KEY (avaliador_id) REFERENCES funcionarios(id_funcionario),
    CONSTRAINT chk_nota CHECK (nota_geral BETWEEN 0 AND 10)
);

-- Tabela de Treinamentos
CREATE TABLE treinamentos (
    id_treinamento NUMBER DEFAULT seq_treinamento.NEXTVAL PRIMARY KEY,
    nome VARCHAR2(100) NOT NULL,
    descricao VARCHAR2(500),
    tipo VARCHAR2(30),
    carga_horaria NUMBER,
    custo NUMBER(12,2),
    fornecedor VARCHAR2(100),
    status VARCHAR2(20) DEFAULT 'ATIVO',
    CONSTRAINT chk_tipo_trein CHECK (tipo IN ('TECNICO', 'COMPORTAMENTAL', 'LIDERANCA', 'COMPLIANCE'))
);

-- Tabela de Funcionários x Treinamentos
CREATE TABLE funcionarios_treinamentos (
    id_funcionario NUMBER,
    id_treinamento NUMBER,
    data_inicio DATE,
    data_fim DATE,
    status VARCHAR2(20),
    nota_final NUMBER(3,1),
    certificado BLOB,
    CONSTRAINT pk_func_trein PRIMARY KEY (id_funcionario, id_treinamento),
    CONSTRAINT fk_functrein_func FOREIGN KEY (id_funcionario) REFERENCES funcionarios(id_funcionario),
    CONSTRAINT fk_functrein_trein FOREIGN KEY (id_treinamento) REFERENCES treinamentos(id_treinamento)
);

-- Tabela de Vagas
CREATE TABLE vagas (
    id_vaga NUMBER DEFAULT seq_vaga.NEXTVAL PRIMARY KEY,
    titulo VARCHAR2(100) NOT NULL,
    id_departamento NUMBER,
    id_cargo NUMBER,
    descricao CLOB,
    requisitos CLOB,
    faixa_salarial_min NUMBER(12,2),
    faixa_salarial_max NUMBER(12,2),
    status VARCHAR2(20) DEFAULT 'ABERTA',
    data_abertura DATE DEFAULT SYSDATE,
    data_fechamento DATE,
    responsavel_id NUMBER,
    CONSTRAINT fk_vaga_dept FOREIGN KEY (id_departamento) REFERENCES departamentos(id_departamento),
    CONSTRAINT fk_vaga_cargo FOREIGN KEY (id_cargo) REFERENCES cargos(id_cargo),
    CONSTRAINT fk_vaga_resp FOREIGN KEY (responsavel_id) REFERENCES funcionarios(id_funcionario),
    CONSTRAINT chk_status_vaga CHECK (status IN ('ABERTA', 'EM_PROCESSO', 'CANCELADA', 'FECHADA'))
);

-- Índices para Otimização
CREATE INDEX idx_func_dept ON funcionarios(id_departamento);
CREATE INDEX idx_func_cargo ON funcionarios(id_cargo);
CREATE INDEX idx_func_status ON funcionarios(status);
CREATE INDEX idx_func_admissao ON funcionarios(data_admissao);
CREATE INDEX idx_dept_status ON departamentos(status);
CREATE INDEX idx_vaga_status ON vagas(status);
CREATE INDEX idx_benef_tipo ON beneficios(tipo);

-- Comentários nas Tabelas
COMMENT ON TABLE funcionarios IS 'Tabela principal de cadastro de funcionários';
COMMENT ON TABLE departamentos IS 'Cadastro de departamentos da empresa';
COMMENT ON TABLE cargos IS 'Cadastro de cargos e níveis salariais';
COMMENT ON TABLE beneficios IS 'Cadastro de benefícios oferecidos';
COMMENT ON TABLE avaliacoes_desempenho IS 'Registro de avaliações de desempenho dos funcionários';
COMMENT ON TABLE treinamentos IS 'Cadastro de treinamentos disponíveis';
COMMENT ON TABLE vagas IS 'Gestão de vagas em aberto'; 