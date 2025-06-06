-- Triggers do Sistema de Biblioteca
-- Autor: Sistema de Gestão de Biblioteca
-- Data: 2024

-- Trigger para atualizar status do livro quando todos os exemplares estiverem emprestados
CREATE OR REPLACE TRIGGER trg_atualiza_status_livro
AFTER INSERT OR UPDATE OF status ON exemplares
FOR EACH ROW
DECLARE
    v_total_exemplares NUMBER;
    v_exemplares_emprestados NUMBER;
BEGIN
    -- Conta total de exemplares e exemplares emprestados
    SELECT COUNT(*),
           COUNT(CASE WHEN status = 'EMPRESTADO' THEN 1 END)
    INTO v_total_exemplares, v_exemplares_emprestados
    FROM exemplares
    WHERE id_livro = :NEW.id_livro;
    
    -- Atualiza status do livro
    IF v_total_exemplares = v_exemplares_emprestados THEN
        UPDATE livros
        SET status = 'EMPRESTADO'
        WHERE id_livro = :NEW.id_livro;
    ELSE
        UPDATE livros
        SET status = 'DISPONIVEL'
        WHERE id_livro = :NEW.id_livro;
    END IF;
END;
/

-- Trigger para verificar limite de empréstimos do usuário
CREATE OR REPLACE TRIGGER trg_verifica_limite_emprestimos
BEFORE INSERT ON emprestimos
FOR EACH ROW
DECLARE
    v_qtd_emprestimos NUMBER;
    v_limite NUMBER;
    v_status VARCHAR2(20);
BEGIN
    -- Verifica status do usuário
    SELECT status, limite_emprestimos
    INTO v_status, v_limite
    FROM usuarios
    WHERE id_usuario = :NEW.id_usuario;
    
    IF v_status != 'ATIVO' THEN
        RAISE_APPLICATION_ERROR(-20301, 'Usuário não está ativo para realizar empréstimos');
    END IF;
    
    -- Conta empréstimos ativos
    SELECT COUNT(*)
    INTO v_qtd_emprestimos
    FROM emprestimos
    WHERE id_usuario = :NEW.id_usuario
    AND status = 'ATIVO';
    
    IF v_qtd_emprestimos >= v_limite THEN
        RAISE_APPLICATION_ERROR(-20302, 'Usuário atingiu limite de empréstimos');
    END IF;
END;
/

-- Trigger para verificar multas pendentes antes de novo empréstimo
CREATE OR REPLACE TRIGGER trg_verifica_multas_pendentes
BEFORE INSERT ON emprestimos
FOR EACH ROW
DECLARE
    v_tem_multa NUMBER;
BEGIN
    SELECT COUNT(*)
    INTO v_tem_multa
    FROM historico_multas hm
    JOIN emprestimos e ON e.id_emprestimo = hm.id_emprestimo
    WHERE e.id_usuario = :NEW.id_usuario
    AND hm.status = 'PENDENTE';
    
    IF v_tem_multa > 0 THEN
        RAISE_APPLICATION_ERROR(-20303, 'Usuário possui multas pendentes');
    END IF;
END;
/

-- Trigger para atualizar data de devolução e calcular multa
CREATE OR REPLACE TRIGGER trg_atualiza_devolucao
BEFORE UPDATE OF status ON emprestimos
FOR EACH ROW
WHEN (NEW.status = 'DEVOLVIDO')
DECLARE
    v_dias_atraso NUMBER;
    v_valor_multa NUMBER;
BEGIN
    -- Atualiza data de devolução
    :NEW.data_devolucao := SYSDATE;
    
    -- Calcula dias de atraso
    v_dias_atraso := TRUNC(SYSDATE - :OLD.data_prevista_devolucao);
    
    -- Se houver atraso, calcula multa
    IF v_dias_atraso > 0 THEN
        v_valor_multa := v_dias_atraso * pkg_emprestimos.c_valor_multa_dia;
        :NEW.multa := v_valor_multa;
    END IF;
END;
/

-- Trigger para atualizar fila de reservas
CREATE OR REPLACE TRIGGER trg_atualiza_fila_reservas
AFTER UPDATE OF status ON emprestimos
FOR EACH ROW
WHEN (NEW.status = 'DEVOLVIDO')
DECLARE
    v_id_livro NUMBER;
    v_proxima_reserva NUMBER;
BEGIN
    -- Obtém ID do livro
    SELECT l.id_livro
    INTO v_id_livro
    FROM exemplares e
    JOIN livros l ON l.id_livro = e.id_livro
    WHERE e.id_exemplar = :NEW.id_exemplar;
    
    -- Verifica se há reservas pendentes
    SELECT MIN(id_reserva)
    INTO v_proxima_reserva
    FROM reservas
    WHERE id_livro = v_id_livro
    AND status = 'PENDENTE'
    ORDER BY data_reserva;
    
    -- Se houver reserva, atualiza status
    IF v_proxima_reserva IS NOT NULL THEN
        UPDATE reservas
        SET status = 'DISPONIVEL',
            data_limite = SYSDATE + 2 -- 2 dias para retirar o livro
        WHERE id_reserva = v_proxima_reserva;
    END IF;
END;
/

-- Trigger para log de alterações em livros
CREATE OR REPLACE TRIGGER trg_log_alteracoes_livros
AFTER INSERT OR UPDATE OR DELETE ON livros
FOR EACH ROW
DECLARE
    v_operacao VARCHAR2(20);
    v_usuario VARCHAR2(100);
BEGIN
    -- Identifica tipo de operação
    v_operacao := CASE
        WHEN INSERTING THEN 'INSERT'
        WHEN UPDATING THEN 'UPDATE'
        WHEN DELETING THEN 'DELETE'
    END;
    
    -- Obtém usuário do banco
    SELECT USER INTO v_usuario FROM dual;
    
    -- Registra log (implementar tabela de log)
    NULL;
    /*
    INSERT INTO log_alteracoes (
        data_alteracao,
        usuario,
        operacao,
        tabela,
        id_registro,
        valor_antigo,
        valor_novo
    ) VALUES (
        SYSDATE,
        v_usuario,
        v_operacao,
        'LIVROS',
        CASE
            WHEN INSERTING THEN :NEW.id_livro
            WHEN UPDATING THEN :OLD.id_livro
            WHEN DELETING THEN :OLD.id_livro
        END,
        CASE
            WHEN UPDATING OR DELETING THEN
                JSON_OBJECT(
                    'titulo' VALUE :OLD.titulo,
                    'status' VALUE :OLD.status
                )
            ELSE NULL
        END,
        CASE
            WHEN INSERTING OR UPDATING THEN
                JSON_OBJECT(
                    'titulo' VALUE :NEW.titulo,
                    'status' VALUE :NEW.status
                )
            ELSE NULL
        END
    );
    */
END;
/

-- Trigger para validar CPF antes de inserir/atualizar usuário
CREATE OR REPLACE TRIGGER trg_valida_cpf
BEFORE INSERT OR UPDATE OF cpf ON usuarios
FOR EACH ROW
DECLARE
    v_soma NUMBER;
    v_digito1 NUMBER;
    v_digito2 NUMBER;
    v_cpf VARCHAR2(11);
    
    -- Função local para validar dígito
    FUNCTION calcular_digito(p_cpf IN VARCHAR2, p_pos IN NUMBER) RETURN NUMBER IS
        v_soma NUMBER := 0;
    BEGIN
        FOR i IN 1..p_pos LOOP
            v_soma := v_soma + TO_NUMBER(SUBSTR(p_cpf, i, 1)) * (p_pos + 1 - i);
        END LOOP;
        v_soma := MOD(v_soma * 10, 11);
        RETURN CASE WHEN v_soma = 10 THEN 0 ELSE v_soma END;
    END;
BEGIN
    -- Remove caracteres não numéricos
    v_cpf := REGEXP_REPLACE(:NEW.cpf, '[^0-9]', '');
    
    -- Verifica tamanho
    IF LENGTH(v_cpf) != 11 THEN
        RAISE_APPLICATION_ERROR(-20304, 'CPF deve conter 11 dígitos');
    END IF;
    
    -- Verifica se todos os dígitos são iguais
    IF REGEXP_LIKE(v_cpf, '^(\d)\1{10}$') THEN
        RAISE_APPLICATION_ERROR(-20305, 'CPF inválido');
    END IF;
    
    -- Calcula primeiro dígito verificador
    v_digito1 := calcular_digito(v_cpf, 9);
    
    -- Verifica primeiro dígito
    IF v_digito1 != TO_NUMBER(SUBSTR(v_cpf, 10, 1)) THEN
        RAISE_APPLICATION_ERROR(-20305, 'CPF inválido');
    END IF;
    
    -- Calcula segundo dígito verificador
    v_digito2 := calcular_digito(v_cpf, 10);
    
    -- Verifica segundo dígito
    IF v_digito2 != TO_NUMBER(SUBSTR(v_cpf, 11, 1)) THEN
        RAISE_APPLICATION_ERROR(-20305, 'CPF inválido');
    END IF;
    
    -- Formata CPF
    :NEW.cpf := v_cpf;
END;
/

-- Trigger para atualizar estatísticas de empréstimo
CREATE OR REPLACE TRIGGER trg_atualiza_estatisticas
AFTER INSERT OR UPDATE OF status ON emprestimos
FOR EACH ROW
BEGIN
    -- Atualiza materialized view de estatísticas
    DBMS_MVIEW.REFRESH('mv_estatisticas_mensais', 'F');
END;
/ 