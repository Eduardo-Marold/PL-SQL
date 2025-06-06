-- Package de Gestão do Acervo
-- Autor: Sistema de Gestão de Biblioteca
-- Data: 2024

CREATE OR REPLACE PACKAGE pkg_acervo AS
    -- Tipos
    TYPE t_livro_info IS RECORD (
        id_livro NUMBER,
        titulo VARCHAR2(200),
        isbn VARCHAR2(13),
        qtd_disponivel NUMBER,
        qtd_total NUMBER
    );
    
    TYPE t_array_livros IS TABLE OF t_livro_info;
    
    -- Funções e Procedures
    FUNCTION cadastrar_livro(
        p_isbn IN VARCHAR2,
        p_titulo IN VARCHAR2,
        p_subtitulo IN VARCHAR2,
        p_id_editora IN NUMBER,
        p_ano_publicacao IN NUMBER,
        p_edicao IN VARCHAR2,
        p_num_paginas IN NUMBER,
        p_id_categoria IN NUMBER,
        p_sinopse IN CLOB DEFAULT NULL,
        p_capa IN BLOB DEFAULT NULL
    ) RETURN NUMBER;
    
    PROCEDURE adicionar_autor_livro(
        p_id_livro IN NUMBER,
        p_id_autor IN NUMBER,
        p_tipo_autoria IN VARCHAR2 DEFAULT 'PRINCIPAL'
    );
    
    FUNCTION cadastrar_exemplar(
        p_id_livro IN NUMBER,
        p_codigo_barras IN VARCHAR2,
        p_preco_aquisicao IN NUMBER,
        p_localizacao IN VARCHAR2
    ) RETURN NUMBER;
    
    PROCEDURE atualizar_status_exemplar(
        p_id_exemplar IN NUMBER,
        p_novo_status IN VARCHAR2,
        p_estado_conservacao IN VARCHAR2 DEFAULT NULL
    );
    
    FUNCTION buscar_livros_por_titulo(
        p_titulo IN VARCHAR2
    ) RETURN t_array_livros PIPELINED;
    
    FUNCTION buscar_livros_por_autor(
        p_nome_autor IN VARCHAR2
    ) RETURN t_array_livros PIPELINED;
    
    FUNCTION verificar_disponibilidade(
        p_id_livro IN NUMBER
    ) RETURN NUMBER;
    
    FUNCTION obter_localizacao_exemplar(
        p_id_exemplar IN NUMBER
    ) RETURN VARCHAR2;
    
    PROCEDURE registrar_manutencao_exemplar(
        p_id_exemplar IN NUMBER,
        p_motivo IN VARCHAR2,
        p_previsao_retorno IN DATE
    );
    
    -- Exceptions
    isbn_ja_cadastrado EXCEPTION;
    livro_nao_encontrado EXCEPTION;
    exemplar_nao_encontrado EXCEPTION;
    status_invalido EXCEPTION;
    
    PRAGMA EXCEPTION_INIT(isbn_ja_cadastrado, -20001);
    PRAGMA EXCEPTION_INIT(livro_nao_encontrado, -20002);
    PRAGMA EXCEPTION_INIT(exemplar_nao_encontrado, -20003);
    PRAGMA EXCEPTION_INIT(status_invalido, -20004);
END pkg_acervo;
/

CREATE OR REPLACE PACKAGE BODY pkg_acervo AS
    -- Implementação das funções e procedures
    
    FUNCTION cadastrar_livro(
        p_isbn IN VARCHAR2,
        p_titulo IN VARCHAR2,
        p_subtitulo IN VARCHAR2,
        p_id_editora IN NUMBER,
        p_ano_publicacao IN NUMBER,
        p_edicao IN VARCHAR2,
        p_num_paginas IN NUMBER,
        p_id_categoria IN NUMBER,
        p_sinopse IN CLOB DEFAULT NULL,
        p_capa IN BLOB DEFAULT NULL
    ) RETURN NUMBER IS
        v_id_livro NUMBER;
        v_existe NUMBER;
    BEGIN
        -- Verifica se ISBN já existe
        SELECT COUNT(*) INTO v_existe
        FROM livros WHERE isbn = p_isbn;
        
        IF v_existe > 0 THEN
            RAISE isbn_ja_cadastrado;
        END IF;
        
        -- Insere o novo livro
        INSERT INTO livros (
            isbn, titulo, subtitulo, id_editora,
            ano_publicacao, edicao, num_paginas,
            id_categoria, sinopse, capa
        ) VALUES (
            p_isbn, p_titulo, p_subtitulo, p_id_editora,
            p_ano_publicacao, p_edicao, p_num_paginas,
            p_id_categoria, p_sinopse, p_capa
        ) RETURNING id_livro INTO v_id_livro;
        
        RETURN v_id_livro;
    EXCEPTION
        WHEN isbn_ja_cadastrado THEN
            RAISE_APPLICATION_ERROR(-20001, 'ISBN já cadastrado no sistema');
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20000, 'Erro ao cadastrar livro: ' || SQLERRM);
    END cadastrar_livro;
    
    PROCEDURE adicionar_autor_livro(
        p_id_livro IN NUMBER,
        p_id_autor IN NUMBER,
        p_tipo_autoria IN VARCHAR2 DEFAULT 'PRINCIPAL'
    ) IS
        v_existe NUMBER;
    BEGIN
        -- Verifica se o livro existe
        SELECT COUNT(*) INTO v_existe
        FROM livros WHERE id_livro = p_id_livro;
        
        IF v_existe = 0 THEN
            RAISE livro_nao_encontrado;
        END IF;
        
        -- Insere a relação livro-autor
        INSERT INTO livros_autores (
            id_livro, id_autor, tipo_autoria
        ) VALUES (
            p_id_livro, p_id_autor, p_tipo_autoria
        );
    EXCEPTION
        WHEN livro_nao_encontrado THEN
            RAISE_APPLICATION_ERROR(-20002, 'Livro não encontrado');
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20000, 'Erro ao adicionar autor: ' || SQLERRM);
    END adicionar_autor_livro;
    
    FUNCTION cadastrar_exemplar(
        p_id_livro IN NUMBER,
        p_codigo_barras IN VARCHAR2,
        p_preco_aquisicao IN NUMBER,
        p_localizacao IN VARCHAR2
    ) RETURN NUMBER IS
        v_id_exemplar NUMBER;
        v_existe NUMBER;
    BEGIN
        -- Verifica se o livro existe
        SELECT COUNT(*) INTO v_existe
        FROM livros WHERE id_livro = p_id_livro;
        
        IF v_existe = 0 THEN
            RAISE livro_nao_encontrado;
        END IF;
        
        -- Insere o novo exemplar
        INSERT INTO exemplares (
            id_livro, codigo_barras,
            preco_aquisicao, localizacao
        ) VALUES (
            p_id_livro, p_codigo_barras,
            p_preco_aquisicao, p_localizacao
        ) RETURNING id_exemplar INTO v_id_exemplar;
        
        RETURN v_id_exemplar;
    EXCEPTION
        WHEN livro_nao_encontrado THEN
            RAISE_APPLICATION_ERROR(-20002, 'Livro não encontrado');
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20000, 'Erro ao cadastrar exemplar: ' || SQLERRM);
    END cadastrar_exemplar;
    
    PROCEDURE atualizar_status_exemplar(
        p_id_exemplar IN NUMBER,
        p_novo_status IN VARCHAR2,
        p_estado_conservacao IN VARCHAR2 DEFAULT NULL
    ) IS
        v_existe NUMBER;
    BEGIN
        -- Verifica se o exemplar existe
        SELECT COUNT(*) INTO v_existe
        FROM exemplares WHERE id_exemplar = p_id_exemplar;
        
        IF v_existe = 0 THEN
            RAISE exemplar_nao_encontrado;
        END IF;
        
        -- Atualiza o status do exemplar
        UPDATE exemplares SET
            status = p_novo_status,
            estado_conservacao = NVL(p_estado_conservacao, estado_conservacao)
        WHERE id_exemplar = p_id_exemplar;
        
    EXCEPTION
        WHEN exemplar_nao_encontrado THEN
            RAISE_APPLICATION_ERROR(-20003, 'Exemplar não encontrado');
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20000, 'Erro ao atualizar status: ' || SQLERRM);
    END atualizar_status_exemplar;
    
    FUNCTION buscar_livros_por_titulo(
        p_titulo IN VARCHAR2
    ) RETURN t_array_livros PIPELINED IS
        v_livro t_livro_info;
    BEGIN
        FOR r IN (
            SELECT l.id_livro, l.titulo, l.isbn,
                   COUNT(CASE WHEN e.status = 'DISPONIVEL' THEN 1 END) as qtd_disponivel,
                   COUNT(e.id_exemplar) as qtd_total
            FROM livros l
            LEFT JOIN exemplares e ON e.id_livro = l.id_livro
            WHERE UPPER(l.titulo) LIKE '%' || UPPER(p_titulo) || '%'
            GROUP BY l.id_livro, l.titulo, l.isbn
        ) LOOP
            v_livro.id_livro := r.id_livro;
            v_livro.titulo := r.titulo;
            v_livro.isbn := r.isbn;
            v_livro.qtd_disponivel := r.qtd_disponivel;
            v_livro.qtd_total := r.qtd_total;
            PIPE ROW(v_livro);
        END LOOP;
        RETURN;
    END buscar_livros_por_titulo;
    
    FUNCTION buscar_livros_por_autor(
        p_nome_autor IN VARCHAR2
    ) RETURN t_array_livros PIPELINED IS
        v_livro t_livro_info;
    BEGIN
        FOR r IN (
            SELECT l.id_livro, l.titulo, l.isbn,
                   COUNT(CASE WHEN e.status = 'DISPONIVEL' THEN 1 END) as qtd_disponivel,
                   COUNT(e.id_exemplar) as qtd_total
            FROM livros l
            JOIN livros_autores la ON la.id_livro = l.id_livro
            JOIN autores a ON a.id_autor = la.id_autor
            LEFT JOIN exemplares e ON e.id_livro = l.id_livro
            WHERE UPPER(a.nome) LIKE '%' || UPPER(p_nome_autor) || '%'
            GROUP BY l.id_livro, l.titulo, l.isbn
        ) LOOP
            v_livro.id_livro := r.id_livro;
            v_livro.titulo := r.titulo;
            v_livro.isbn := r.isbn;
            v_livro.qtd_disponivel := r.qtd_disponivel;
            v_livro.qtd_total := r.qtd_total;
            PIPE ROW(v_livro);
        END LOOP;
        RETURN;
    END buscar_livros_por_autor;
    
    FUNCTION verificar_disponibilidade(
        p_id_livro IN NUMBER
    ) RETURN NUMBER IS
        v_qtd_disponivel NUMBER;
    BEGIN
        SELECT COUNT(*)
        INTO v_qtd_disponivel
        FROM exemplares
        WHERE id_livro = p_id_livro
        AND status = 'DISPONIVEL';
        
        RETURN v_qtd_disponivel;
    END verificar_disponibilidade;
    
    FUNCTION obter_localizacao_exemplar(
        p_id_exemplar IN NUMBER
    ) RETURN VARCHAR2 IS
        v_localizacao VARCHAR2(50);
    BEGIN
        SELECT localizacao
        INTO v_localizacao
        FROM exemplares
        WHERE id_exemplar = p_id_exemplar;
        
        RETURN v_localizacao;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE exemplar_nao_encontrado;
    END obter_localizacao_exemplar;
    
    PROCEDURE registrar_manutencao_exemplar(
        p_id_exemplar IN NUMBER,
        p_motivo IN VARCHAR2,
        p_previsao_retorno IN DATE
    ) IS
    BEGIN
        UPDATE exemplares SET
            status = 'EM_MANUTENCAO',
            notas = notas || CHR(10) || 
                    'Manutenção em ' || TO_CHAR(SYSDATE, 'DD/MM/YYYY') || 
                    ' - Motivo: ' || p_motivo || 
                    ' - Previsão de retorno: ' || TO_CHAR(p_previsao_retorno, 'DD/MM/YYYY')
        WHERE id_exemplar = p_id_exemplar;
        
        IF SQL%NOTFOUND THEN
            RAISE exemplar_nao_encontrado;
        END IF;
    EXCEPTION
        WHEN exemplar_nao_encontrado THEN
            RAISE_APPLICATION_ERROR(-20003, 'Exemplar não encontrado');
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20000, 'Erro ao registrar manutenção: ' || SQLERRM);
    END registrar_manutencao_exemplar;
    
END pkg_acervo;
/ 