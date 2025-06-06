-- Script de Criação das Tabelas do Sistema de Biblioteca
-- Autor: Sistema de Gestão de Biblioteca
-- Data: 2024

-- Sequências
CREATE SEQUENCE seq_livro START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_usuario START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_emprestimo START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_reserva START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_autor START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_editora START WITH 1 INCREMENT BY 1;

-- Tabela de Autores
CREATE TABLE autores (
    id_autor NUMBER DEFAULT seq_autor.NEXTVAL PRIMARY KEY,
    nome VARCHAR2(100) NOT NULL,
    nacionalidade VARCHAR2(50),
    data_nascimento DATE,
    biografia CLOB,
    data_cadastro DATE DEFAULT SYSDATE,
    status VARCHAR2(20) DEFAULT 'ATIVO',
    CONSTRAINT chk_status_autor CHECK (status IN ('ATIVO', 'INATIVO'))
);

-- Tabela de Editoras
CREATE TABLE editoras (
    id_editora NUMBER DEFAULT seq_editora.NEXTVAL PRIMARY KEY,
    nome VARCHAR2(100) NOT NULL,
    cnpj VARCHAR2(14) UNIQUE,
    endereco VARCHAR2(200),
    telefone VARCHAR2(20),
    email VARCHAR2(100),
    contato_nome VARCHAR2(100),
    data_cadastro DATE DEFAULT SYSDATE,
    status VARCHAR2(20) DEFAULT 'ATIVO',
    CONSTRAINT chk_status_editora CHECK (status IN ('ATIVO', 'INATIVO'))
);

-- Tabela de Categorias
CREATE TABLE categorias (
    id_categoria NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome VARCHAR2(50) NOT NULL,
    descricao VARCHAR2(200),
    categoria_pai NUMBER,
    nivel NUMBER GENERATED ALWAYS AS (
        CONNECT_BY_LEVEL
        START WITH categoria_pai IS NULL
        CONNECT BY PRIOR id_categoria = categoria_pai
    ) VIRTUAL,
    CONSTRAINT fk_categoria_pai FOREIGN KEY (categoria_pai) 
        REFERENCES categorias(id_categoria)
);

-- Tabela de Livros
CREATE TABLE livros (
    id_livro NUMBER DEFAULT seq_livro.NEXTVAL PRIMARY KEY,
    isbn VARCHAR2(13) UNIQUE,
    titulo VARCHAR2(200) NOT NULL,
    subtitulo VARCHAR2(200),
    id_editora NUMBER,
    ano_publicacao NUMBER(4),
    edicao VARCHAR2(20),
    num_paginas NUMBER,
    id_categoria NUMBER,
    sinopse CLOB,
    capa BLOB,
    data_cadastro DATE DEFAULT SYSDATE,
    status VARCHAR2(20) DEFAULT 'DISPONIVEL',
    CONSTRAINT fk_livro_editora FOREIGN KEY (id_editora) 
        REFERENCES editoras(id_editora),
    CONSTRAINT fk_livro_categoria FOREIGN KEY (id_categoria) 
        REFERENCES categorias(id_categoria),
    CONSTRAINT chk_status_livro CHECK (status IN 
        ('DISPONIVEL', 'EMPRESTADO', 'EM_MANUTENCAO', 'EXTRAVIADO'))
) PARTITION BY RANGE (ano_publicacao) (
    PARTITION livros_antigos VALUES LESS THAN (2000),
    PARTITION livros_2000_2010 VALUES LESS THAN (2010),
    PARTITION livros_2010_2020 VALUES LESS THAN (2020),
    PARTITION livros_atuais VALUES LESS THAN (MAXVALUE)
);

-- Tabela de Relacionamento Livros x Autores
CREATE TABLE livros_autores (
    id_livro NUMBER,
    id_autor NUMBER,
    tipo_autoria VARCHAR2(30) DEFAULT 'PRINCIPAL',
    CONSTRAINT pk_livro_autor PRIMARY KEY (id_livro, id_autor),
    CONSTRAINT fk_la_livro FOREIGN KEY (id_livro) 
        REFERENCES livros(id_livro),
    CONSTRAINT fk_la_autor FOREIGN KEY (id_autor) 
        REFERENCES autores(id_autor),
    CONSTRAINT chk_tipo_autoria CHECK (tipo_autoria IN 
        ('PRINCIPAL', 'COAUTOR', 'ORGANIZADOR', 'TRADUTOR'))
);

-- Tabela de Exemplares
CREATE TABLE exemplares (
    id_exemplar NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_livro NUMBER,
    codigo_barras VARCHAR2(20) UNIQUE,
    data_aquisicao DATE DEFAULT SYSDATE,
    preco_aquisicao NUMBER(10,2),
    estado_conservacao VARCHAR2(20) DEFAULT 'NOVO',
    localizacao VARCHAR2(50),
    status VARCHAR2(20) DEFAULT 'DISPONIVEL',
    notas CLOB,
    CONSTRAINT fk_exemplar_livro FOREIGN KEY (id_livro) 
        REFERENCES livros(id_livro),
    CONSTRAINT chk_estado_exemplar CHECK (estado_conservacao IN 
        ('NOVO', 'BOM', 'REGULAR', 'RUIM', 'PESSIMO')),
    CONSTRAINT chk_status_exemplar CHECK (status IN 
        ('DISPONIVEL', 'EMPRESTADO', 'EM_MANUTENCAO', 'EXTRAVIADO'))
);

-- Tabela de Usuários
CREATE TABLE usuarios (
    id_usuario NUMBER DEFAULT seq_usuario.NEXTVAL PRIMARY KEY,
    nome VARCHAR2(100) NOT NULL,
    cpf VARCHAR2(11) UNIQUE,
    email VARCHAR2(100) UNIQUE,
    telefone VARCHAR2(20),
    endereco VARCHAR2(200),
    data_nascimento DATE,
    tipo_usuario VARCHAR2(20) DEFAULT 'LEITOR',
    limite_emprestimos NUMBER(2) DEFAULT 3,
    data_cadastro DATE DEFAULT SYSDATE,
    senha VARCHAR2(64) NOT NULL,
    status VARCHAR2(20) DEFAULT 'ATIVO',
    foto BLOB,
    CONSTRAINT chk_tipo_usuario CHECK (tipo_usuario IN 
        ('LEITOR', 'BIBLIOTECARIO', 'ADMINISTRADOR')),
    CONSTRAINT chk_status_usuario CHECK (status IN 
        ('ATIVO', 'SUSPENSO', 'INATIVO'))
) PARTITION BY LIST (tipo_usuario) (
    PARTITION usuarios_leitores VALUES ('LEITOR'),
    PARTITION usuarios_funcionarios VALUES ('BIBLIOTECARIO', 'ADMINISTRADOR')
);

-- Tabela de Empréstimos
CREATE TABLE emprestimos (
    id_emprestimo NUMBER DEFAULT seq_emprestimo.NEXTVAL PRIMARY KEY,
    id_usuario NUMBER,
    id_exemplar NUMBER,
    data_emprestimo DATE DEFAULT SYSDATE,
    data_prevista_devolucao DATE,
    data_devolucao DATE,
    multa NUMBER(10,2) DEFAULT 0,
    status VARCHAR2(20) DEFAULT 'ATIVO',
    bibliotecario_emprestimo NUMBER,
    bibliotecario_devolucao NUMBER,
    CONSTRAINT fk_emp_usuario FOREIGN KEY (id_usuario) 
        REFERENCES usuarios(id_usuario),
    CONSTRAINT fk_emp_exemplar FOREIGN KEY (id_exemplar) 
        REFERENCES exemplares(id_exemplar),
    CONSTRAINT fk_emp_bib_emp FOREIGN KEY (bibliotecario_emprestimo) 
        REFERENCES usuarios(id_usuario),
    CONSTRAINT fk_emp_bib_dev FOREIGN KEY (bibliotecario_devolucao) 
        REFERENCES usuarios(id_usuario),
    CONSTRAINT chk_status_emprestimo CHECK (status IN 
        ('ATIVO', 'DEVOLVIDO', 'ATRASADO', 'PERDIDO'))
) PARTITION BY RANGE (data_emprestimo) (
    PARTITION emp_2023 VALUES LESS THAN (TO_DATE('2024-01-01', 'YYYY-MM-DD')),
    PARTITION emp_2024 VALUES LESS THAN (TO_DATE('2025-01-01', 'YYYY-MM-DD')),
    PARTITION emp_future VALUES LESS THAN (MAXVALUE)
);

-- Tabela de Reservas
CREATE TABLE reservas (
    id_reserva NUMBER DEFAULT seq_reserva.NEXTVAL PRIMARY KEY,
    id_usuario NUMBER,
    id_livro NUMBER,
    data_reserva DATE DEFAULT SYSDATE,
    data_limite DATE,
    status VARCHAR2(20) DEFAULT 'PENDENTE',
    posicao_fila NUMBER GENERATED ALWAYS AS (
        ROW_NUMBER() OVER (
            PARTITION BY id_livro, status 
            ORDER BY data_reserva
        )
    ) VIRTUAL,
    CONSTRAINT fk_res_usuario FOREIGN KEY (id_usuario) 
        REFERENCES usuarios(id_usuario),
    CONSTRAINT fk_res_livro FOREIGN KEY (id_livro) 
        REFERENCES livros(id_livro),
    CONSTRAINT chk_status_reserva CHECK (status IN 
        ('PENDENTE', 'ATENDIDA', 'CANCELADA', 'EXPIRADA'))
);

-- Tabela de Histórico de Multas
CREATE TABLE historico_multas (
    id_multa NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_emprestimo NUMBER,
    valor NUMBER(10,2) NOT NULL,
    data_geracao DATE DEFAULT SYSDATE,
    data_pagamento DATE,
    forma_pagamento VARCHAR2(30),
    status VARCHAR2(20) DEFAULT 'PENDENTE',
    CONSTRAINT fk_multa_emprestimo FOREIGN KEY (id_emprestimo) 
        REFERENCES emprestimos(id_emprestimo),
    CONSTRAINT chk_status_multa CHECK (status IN 
        ('PENDENTE', 'PAGO', 'CANCELADO')),
    CONSTRAINT chk_forma_pagamento CHECK (forma_pagamento IN 
        ('DINHEIRO', 'CARTAO', 'PIX', 'ISENCAO'))
);

-- Índices
CREATE INDEX idx_livro_titulo ON livros(UPPER(titulo));
CREATE INDEX idx_usuario_nome ON usuarios(UPPER(nome));
CREATE INDEX idx_emp_data ON emprestimos(data_emprestimo);
CREATE INDEX idx_emp_status ON emprestimos(status);
CREATE INDEX idx_reserva_status ON reservas(status);
CREATE INDEX idx_exemplar_status ON exemplares(status);

-- Comentários nas Tabelas
COMMENT ON TABLE livros IS 'Cadastro do acervo de livros';
COMMENT ON TABLE autores IS 'Cadastro de autores das obras';
COMMENT ON TABLE editoras IS 'Cadastro de editoras';
COMMENT ON TABLE exemplares IS 'Registro físico dos livros';
COMMENT ON TABLE usuarios IS 'Cadastro de usuários do sistema';
COMMENT ON TABLE emprestimos IS 'Controle de empréstimos';
COMMENT ON TABLE reservas IS 'Gestão de reservas de livros';
COMMENT ON TABLE historico_multas IS 'Histórico de multas por atraso'; 