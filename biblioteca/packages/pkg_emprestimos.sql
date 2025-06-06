-- Package de Gestão de Empréstimos
-- Autor: Sistema de Gestão de Biblioteca
-- Data: 2024

CREATE OR REPLACE PACKAGE pkg_emprestimos AS
    -- Tipos
    TYPE t_emprestimo_info IS RECORD (
        id_emprestimo NUMBER,
        titulo_livro VARCHAR2(200),
        nome_usuario VARCHAR2(100),
        data_emprestimo DATE,
        data_prevista_devolucao DATE,
        status VARCHAR2(20)
    );
    
    TYPE t_array_emprestimos IS TABLE OF t_emprestimo_info;
    
    -- Constantes
    c_dias_emprestimo CONSTANT NUMBER := 14; -- Prazo padrão de empréstimo
    c_valor_multa_dia CONSTANT NUMBER := 1.00; -- Valor da multa por dia de atraso
    
    -- Funções e Procedures
    FUNCTION realizar_emprestimo(
        p_id_usuario IN NUMBER,
        p_id_exemplar IN NUMBER,
        p_bibliotecario_id IN NUMBER
    ) RETURN NUMBER;
    
    PROCEDURE realizar_devolucao(
        p_id_emprestimo IN NUMBER,
        p_bibliotecario_id IN NUMBER,
        p_estado_conservacao IN VARCHAR2 DEFAULT NULL
    );
    
    FUNCTION calcular_multa(
        p_id_emprestimo IN NUMBER
    ) RETURN NUMBER;
    
    PROCEDURE registrar_pagamento_multa(
        p_id_emprestimo IN NUMBER,
        p_valor IN NUMBER,
        p_forma_pagamento IN VARCHAR2
    );
    
    FUNCTION verificar_disponibilidade_usuario(
        p_id_usuario IN NUMBER
    ) RETURN BOOLEAN;
    
    FUNCTION listar_emprestimos_ativos(
        p_id_usuario IN NUMBER
    ) RETURN t_array_emprestimos PIPELINED;
    
    FUNCTION listar_emprestimos_atrasados
    RETURN t_array_emprestimos PIPELINED;
    
    PROCEDURE renovar_emprestimo(
        p_id_emprestimo IN NUMBER
    );
    
    -- Exceptions
    usuario_bloqueado EXCEPTION;
    limite_excedido EXCEPTION;
    exemplar_indisponivel EXCEPTION;
    emprestimo_nao_encontrado EXCEPTION;
    renovacao_nao_permitida EXCEPTION;
    
    PRAGMA EXCEPTION_INIT(usuario_bloqueado, -20101);
    PRAGMA EXCEPTION_INIT(limite_excedido, -20102);
    PRAGMA EXCEPTION_INIT(exemplar_indisponivel, -20103);
    PRAGMA EXCEPTION_INIT(emprestimo_nao_encontrado, -20104);
    PRAGMA EXCEPTION_INIT(renovacao_nao_permitida, -20105);
END pkg_emprestimos;
/

CREATE OR REPLACE PACKAGE BODY pkg_emprestimos AS
    -- Funções e procedures privadas
    FUNCTION usuario_pode_emprestar(
        p_id_usuario IN NUMBER
    ) RETURN BOOLEAN IS
        v_status VARCHAR2(20);
        v_qtd_atual NUMBER;
        v_limite NUMBER;
    BEGIN
        -- Verifica status do usuário
        SELECT status, limite_emprestimos
        INTO v_status, v_limite
        FROM usuarios
        WHERE id_usuario = p_id_usuario;
        
        IF v_status != 'ATIVO' THEN
            RETURN FALSE;
        END IF;
        
        -- Verifica quantidade atual de empréstimos
        SELECT COUNT(*)
        INTO v_qtd_atual
        FROM emprestimos
        WHERE id_usuario = p_id_usuario
        AND status = 'ATIVO';
        
        RETURN v_qtd_atual < v_limite;
    END usuario_pode_emprestar;
    
    -- Implementação das funções e procedures públicas
    FUNCTION realizar_emprestimo(
        p_id_usuario IN NUMBER,
        p_id_exemplar IN NUMBER,
        p_bibliotecario_id IN NUMBER
    ) RETURN NUMBER IS
        v_id_emprestimo NUMBER;
        v_status_exemplar VARCHAR2(20);
        v_pode_emprestar BOOLEAN;
    BEGIN
        -- Verifica se usuário pode realizar empréstimo
        v_pode_emprestar := usuario_pode_emprestar(p_id_usuario);
        IF NOT v_pode_emprestar THEN
            RAISE limite_excedido;
        END IF;
        
        -- Verifica disponibilidade do exemplar
        SELECT status
        INTO v_status_exemplar
        FROM exemplares
        WHERE id_exemplar = p_id_exemplar;
        
        IF v_status_exemplar != 'DISPONIVEL' THEN
            RAISE exemplar_indisponivel;
        END IF;
        
        -- Realiza o empréstimo
        INSERT INTO emprestimos (
            id_usuario,
            id_exemplar,
            data_emprestimo,
            data_prevista_devolucao,
            status,
            bibliotecario_emprestimo
        ) VALUES (
            p_id_usuario,
            p_id_exemplar,
            SYSDATE,
            SYSDATE + c_dias_emprestimo,
            'ATIVO',
            p_bibliotecario_id
        ) RETURNING id_emprestimo INTO v_id_emprestimo;
        
        -- Atualiza status do exemplar
        UPDATE exemplares
        SET status = 'EMPRESTADO'
        WHERE id_exemplar = p_id_exemplar;
        
        RETURN v_id_emprestimo;
    EXCEPTION
        WHEN limite_excedido THEN
            RAISE_APPLICATION_ERROR(-20102, 'Usuário atingiu limite de empréstimos');
        WHEN exemplar_indisponivel THEN
            RAISE_APPLICATION_ERROR(-20103, 'Exemplar não está disponível para empréstimo');
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20100, 'Erro ao realizar empréstimo: ' || SQLERRM);
    END realizar_emprestimo;
    
    PROCEDURE realizar_devolucao(
        p_id_emprestimo IN NUMBER,
        p_bibliotecario_id IN NUMBER,
        p_estado_conservacao IN VARCHAR2 DEFAULT NULL
    ) IS
        v_id_exemplar NUMBER;
        v_multa NUMBER;
    BEGIN
        -- Verifica se empréstimo existe e está ativo
        SELECT id_exemplar
        INTO v_id_exemplar
        FROM emprestimos
        WHERE id_emprestimo = p_id_emprestimo
        AND status = 'ATIVO';
        
        -- Calcula multa, se houver
        v_multa := calcular_multa(p_id_emprestimo);
        
        -- Atualiza empréstimo
        UPDATE emprestimos SET
            status = 'DEVOLVIDO',
            data_devolucao = SYSDATE,
            multa = v_multa,
            bibliotecario_devolucao = p_bibliotecario_id
        WHERE id_emprestimo = p_id_emprestimo;
        
        -- Atualiza exemplar
        UPDATE exemplares SET
            status = 'DISPONIVEL',
            estado_conservacao = NVL(p_estado_conservacao, estado_conservacao)
        WHERE id_exemplar = v_id_exemplar;
        
        -- Se houver multa, registra no histórico
        IF v_multa > 0 THEN
            INSERT INTO historico_multas (
                id_emprestimo,
                valor,
                status
            ) VALUES (
                p_id_emprestimo,
                v_multa,
                'PENDENTE'
            );
        END IF;
        
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20104, 'Empréstimo não encontrado ou já finalizado');
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20100, 'Erro ao realizar devolução: ' || SQLERRM);
    END realizar_devolucao;
    
    FUNCTION calcular_multa(
        p_id_emprestimo IN NUMBER
    ) RETURN NUMBER IS
        v_data_prevista DATE;
        v_dias_atraso NUMBER;
    BEGIN
        SELECT data_prevista_devolucao
        INTO v_data_prevista
        FROM emprestimos
        WHERE id_emprestimo = p_id_emprestimo;
        
        v_dias_atraso := TRUNC(SYSDATE - v_data_prevista);
        
        IF v_dias_atraso > 0 THEN
            RETURN v_dias_atraso * c_valor_multa_dia;
        ELSE
            RETURN 0;
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE emprestimo_nao_encontrado;
    END calcular_multa;
    
    PROCEDURE registrar_pagamento_multa(
        p_id_emprestimo IN NUMBER,
        p_valor IN NUMBER,
        p_forma_pagamento IN VARCHAR2
    ) IS
    BEGIN
        UPDATE historico_multas SET
            status = 'PAGO',
            data_pagamento = SYSDATE,
            forma_pagamento = p_forma_pagamento
        WHERE id_emprestimo = p_id_emprestimo
        AND status = 'PENDENTE';
        
        IF SQL%NOTFOUND THEN
            RAISE emprestimo_nao_encontrado;
        END IF;
    EXCEPTION
        WHEN emprestimo_nao_encontrado THEN
            RAISE_APPLICATION_ERROR(-20104, 'Multa não encontrada ou já paga');
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20100, 'Erro ao registrar pagamento: ' || SQLERRM);
    END registrar_pagamento_multa;
    
    FUNCTION verificar_disponibilidade_usuario(
        p_id_usuario IN NUMBER
    ) RETURN BOOLEAN IS
    BEGIN
        RETURN usuario_pode_emprestar(p_id_usuario);
    END verificar_disponibilidade_usuario;
    
    FUNCTION listar_emprestimos_ativos(
        p_id_usuario IN NUMBER
    ) RETURN t_array_emprestimos PIPELINED IS
        v_emprestimo t_emprestimo_info;
    BEGIN
        FOR r IN (
            SELECT e.id_emprestimo, l.titulo, u.nome,
                   e.data_emprestimo, e.data_prevista_devolucao,
                   e.status
            FROM emprestimos e
            JOIN usuarios u ON u.id_usuario = e.id_usuario
            JOIN exemplares ex ON ex.id_exemplar = e.id_exemplar
            JOIN livros l ON l.id_livro = ex.id_livro
            WHERE e.id_usuario = p_id_usuario
            AND e.status = 'ATIVO'
            ORDER BY e.data_emprestimo DESC
        ) LOOP
            v_emprestimo.id_emprestimo := r.id_emprestimo;
            v_emprestimo.titulo_livro := r.titulo;
            v_emprestimo.nome_usuario := r.nome;
            v_emprestimo.data_emprestimo := r.data_emprestimo;
            v_emprestimo.data_prevista_devolucao := r.data_prevista_devolucao;
            v_emprestimo.status := r.status;
            PIPE ROW(v_emprestimo);
        END LOOP;
        RETURN;
    END listar_emprestimos_ativos;
    
    FUNCTION listar_emprestimos_atrasados
    RETURN t_array_emprestimos PIPELINED IS
        v_emprestimo t_emprestimo_info;
    BEGIN
        FOR r IN (
            SELECT e.id_emprestimo, l.titulo, u.nome,
                   e.data_emprestimo, e.data_prevista_devolucao,
                   e.status
            FROM emprestimos e
            JOIN usuarios u ON u.id_usuario = e.id_usuario
            JOIN exemplares ex ON ex.id_exemplar = e.id_exemplar
            JOIN livros l ON l.id_livro = ex.id_livro
            WHERE e.status = 'ATIVO'
            AND e.data_prevista_devolucao < SYSDATE
            ORDER BY e.data_prevista_devolucao ASC
        ) LOOP
            v_emprestimo.id_emprestimo := r.id_emprestimo;
            v_emprestimo.titulo_livro := r.titulo;
            v_emprestimo.nome_usuario := r.nome;
            v_emprestimo.data_emprestimo := r.data_emprestimo;
            v_emprestimo.data_prevista_devolucao := r.data_prevista_devolucao;
            v_emprestimo.status := r.status;
            PIPE ROW(v_emprestimo);
        END LOOP;
        RETURN;
    END listar_emprestimos_atrasados;
    
    PROCEDURE renovar_emprestimo(
        p_id_emprestimo IN NUMBER
    ) IS
        v_status VARCHAR2(20);
        v_data_prevista DATE;
        v_id_livro NUMBER;
        v_tem_reserva NUMBER;
    BEGIN
        -- Verifica se empréstimo existe e está ativo
        SELECT status, data_prevista_devolucao, l.id_livro
        INTO v_status, v_data_prevista, v_id_livro
        FROM emprestimos e
        JOIN exemplares ex ON ex.id_exemplar = e.id_exemplar
        JOIN livros l ON l.id_livro = ex.id_livro
        WHERE e.id_emprestimo = p_id_emprestimo;
        
        IF v_status != 'ATIVO' THEN
            RAISE emprestimo_nao_encontrado;
        END IF;
        
        -- Verifica se há reservas para o livro
        SELECT COUNT(*)
        INTO v_tem_reserva
        FROM reservas
        WHERE id_livro = v_id_livro
        AND status = 'PENDENTE';
        
        IF v_tem_reserva > 0 THEN
            RAISE renovacao_nao_permitida;
        END IF;
        
        -- Renova o empréstimo
        UPDATE emprestimos SET
            data_prevista_devolucao = SYSDATE + c_dias_emprestimo
        WHERE id_emprestimo = p_id_emprestimo;
        
    EXCEPTION
        WHEN emprestimo_nao_encontrado THEN
            RAISE_APPLICATION_ERROR(-20104, 'Empréstimo não encontrado ou já finalizado');
        WHEN renovacao_nao_permitida THEN
            RAISE_APPLICATION_ERROR(-20105, 'Renovação não permitida - há reservas pendentes');
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20100, 'Erro ao renovar empréstimo: ' || SQLERRM);
    END renovar_emprestimo;
    
END pkg_emprestimos;
/ 