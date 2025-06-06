CREATE OR REPLACE PACKAGE pkg_recrutamento AS
    /*
    Package de Recrutamento e Seleção
    Autor: [Seu Nome]
    Data: [Data Atual]
    Descrição: Package responsável por gerenciar o processo de recrutamento e seleção
    */
    
    -- Tipos
    TYPE r_vaga_info IS RECORD (
        id_vaga NUMBER,
        titulo VARCHAR2(100),
        departamento VARCHAR2(100),
        cargo VARCHAR2(100),
        status VARCHAR2(20),
        data_abertura DATE,
        responsavel VARCHAR2(100)
    );
    
    TYPE t_array_vagas IS TABLE OF r_vaga_info;
    
    -- Funções e Procedures Públicas
    FUNCTION abrir_vaga(
        p_titulo IN VARCHAR2,
        p_id_departamento IN NUMBER,
        p_id_cargo IN NUMBER,
        p_descricao IN CLOB,
        p_requisitos IN CLOB,
        p_faixa_salarial_min IN NUMBER,
        p_faixa_salarial_max IN NUMBER,
        p_responsavel_id IN NUMBER
    ) RETURN NUMBER;
    
    PROCEDURE atualizar_vaga(
        p_id_vaga IN NUMBER,
        p_titulo IN VARCHAR2 DEFAULT NULL,
        p_descricao IN CLOB DEFAULT NULL,
        p_requisitos IN CLOB DEFAULT NULL,
        p_faixa_salarial_min IN NUMBER DEFAULT NULL,
        p_faixa_salarial_max IN NUMBER DEFAULT NULL,
        p_status IN VARCHAR2 DEFAULT NULL
    );
    
    PROCEDURE fechar_vaga(
        p_id_vaga IN NUMBER,
        p_motivo IN VARCHAR2,
        p_id_funcionario_contratado IN NUMBER DEFAULT NULL
    );
    
    FUNCTION buscar_vaga(
        p_id_vaga IN NUMBER
    ) RETURN r_vaga_info;
    
    FUNCTION listar_vagas_abertas(
        p_id_departamento IN NUMBER DEFAULT NULL
    ) RETURN t_array_vagas;
    
    FUNCTION buscar_vagas_por_criterio(
        p_titulo IN VARCHAR2 DEFAULT NULL,
        p_id_departamento IN NUMBER DEFAULT NULL,
        p_faixa_salarial_min IN NUMBER DEFAULT NULL,
        p_faixa_salarial_max IN NUMBER DEFAULT NULL,
        p_status IN VARCHAR2 DEFAULT 'ABERTA'
    ) RETURN SYS_REFCURSOR;
    
    PROCEDURE registrar_candidatura(
        p_id_vaga IN NUMBER,
        p_nome_candidato IN VARCHAR2,
        p_email IN VARCHAR2,
        p_telefone IN VARCHAR2,
        p_curriculo IN CLOB,
        p_pretensao_salarial IN NUMBER
    );
    
    PROCEDURE atualizar_status_candidatura(
        p_id_vaga IN NUMBER,
        p_email_candidato IN VARCHAR2,
        p_novo_status IN VARCHAR2,
        p_observacoes IN VARCHAR2 DEFAULT NULL
    );
    
    FUNCTION listar_candidatos_vaga(
        p_id_vaga IN NUMBER
    ) RETURN SYS_REFCURSOR;
    
    FUNCTION avaliar_aderencia_candidato(
        p_id_vaga IN NUMBER,
        p_email_candidato IN VARCHAR2
    ) RETURN NUMBER;
    
    -- Relatórios
    FUNCTION relatorio_tempo_preenchimento(
        p_id_departamento IN NUMBER DEFAULT NULL,
        p_ano IN NUMBER DEFAULT EXTRACT(YEAR FROM SYSDATE)
    ) RETURN SYS_REFCURSOR;
    
    FUNCTION relatorio_fonte_candidatos(
        p_id_departamento IN NUMBER DEFAULT NULL,
        p_ano IN NUMBER DEFAULT EXTRACT(YEAR FROM SYSDATE)
    ) RETURN SYS_REFCURSOR;
    
    FUNCTION relatorio_eficiencia_processo(
        p_id_departamento IN NUMBER DEFAULT NULL,
        p_ano IN NUMBER DEFAULT EXTRACT(YEAR FROM SYSDATE)
    ) RETURN SYS_REFCURSOR;
END pkg_recrutamento;
/

CREATE OR REPLACE PACKAGE BODY pkg_recrutamento AS
    -- Variáveis Privadas
    v_erro_processo EXCEPTION;
    
    -- Funções e Procedures Privadas
    PROCEDURE log_recrutamento(
        p_id_vaga IN NUMBER,
        p_operacao IN VARCHAR2,
        p_descricao IN VARCHAR2
    ) IS
    BEGIN
        INSERT INTO log_recrutamento (
            data_operacao,
            id_vaga,
            tipo_operacao,
            descricao,
            usuario_operacao
        ) VALUES (
            SYSDATE,
            p_id_vaga,
            p_operacao,
            p_descricao,
            USER
        );
    END;
    
    -- Implementação das Funções e Procedures Públicas
    FUNCTION abrir_vaga(
        p_titulo IN VARCHAR2,
        p_id_departamento IN NUMBER,
        p_id_cargo IN NUMBER,
        p_descricao IN CLOB,
        p_requisitos IN CLOB,
        p_faixa_salarial_min IN NUMBER,
        p_faixa_salarial_max IN NUMBER,
        p_responsavel_id IN NUMBER
    ) RETURN NUMBER IS
        v_id_vaga NUMBER;
    BEGIN
        -- Validações
        IF p_faixa_salarial_min > p_faixa_salarial_max THEN
            RAISE_APPLICATION_ERROR(-20001, 'Faixa salarial mínima não pode ser maior que a máxima');
        END IF;
        
        -- Verifica departamento e cargo
        IF NOT EXISTS (SELECT 1 FROM departamentos WHERE id_departamento = p_id_departamento) THEN
            RAISE_APPLICATION_ERROR(-20002, 'Departamento não encontrado');
        END IF;
        
        IF NOT EXISTS (SELECT 1 FROM cargos WHERE id_cargo = p_id_cargo) THEN
            RAISE_APPLICATION_ERROR(-20003, 'Cargo não encontrado');
        END IF;
        
        -- Insere a vaga
        INSERT INTO vagas (
            titulo,
            id_departamento,
            id_cargo,
            descricao,
            requisitos,
            faixa_salarial_min,
            faixa_salarial_max,
            status,
            data_abertura,
            responsavel_id
        ) VALUES (
            p_titulo,
            p_id_departamento,
            p_id_cargo,
            p_descricao,
            p_requisitos,
            p_faixa_salarial_min,
            p_faixa_salarial_max,
            'ABERTA',
            SYSDATE,
            p_responsavel_id
        ) RETURNING id_vaga INTO v_id_vaga;
        
        -- Log da operação
        log_recrutamento(
            v_id_vaga,
            'ABERTURA',
            'Nova vaga aberta: ' || p_titulo
        );
        
        RETURN v_id_vaga;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20000, 'Erro ao abrir vaga: ' || SQLERRM);
    END;
    
    PROCEDURE atualizar_vaga(
        p_id_vaga IN NUMBER,
        p_titulo IN VARCHAR2 DEFAULT NULL,
        p_descricao IN CLOB DEFAULT NULL,
        p_requisitos IN CLOB DEFAULT NULL,
        p_faixa_salarial_min IN NUMBER DEFAULT NULL,
        p_faixa_salarial_max IN NUMBER DEFAULT NULL,
        p_status IN VARCHAR2 DEFAULT NULL
    ) IS
    BEGIN
        -- Validações
        IF p_faixa_salarial_min IS NOT NULL AND p_faixa_salarial_max IS NOT NULL AND
           p_faixa_salarial_min > p_faixa_salarial_max THEN
            RAISE_APPLICATION_ERROR(-20001, 'Faixa salarial mínima não pode ser maior que a máxima');
        END IF;
        
        -- Atualiza a vaga
        UPDATE vagas
        SET titulo = COALESCE(p_titulo, titulo),
            descricao = COALESCE(p_descricao, descricao),
            requisitos = COALESCE(p_requisitos, requisitos),
            faixa_salarial_min = COALESCE(p_faixa_salarial_min, faixa_salarial_min),
            faixa_salarial_max = COALESCE(p_faixa_salarial_max, faixa_salarial_max),
            status = COALESCE(p_status, status)
        WHERE id_vaga = p_id_vaga;
        
        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20004, 'Vaga não encontrada');
        END IF;
        
        -- Log da operação
        log_recrutamento(
            p_id_vaga,
            'ATUALIZAÇÃO',
            'Vaga atualizada'
        );
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20000, 'Erro ao atualizar vaga: ' || SQLERRM);
    END;
    
    PROCEDURE fechar_vaga(
        p_id_vaga IN NUMBER,
        p_motivo IN VARCHAR2,
        p_id_funcionario_contratado IN NUMBER DEFAULT NULL
    ) IS
    BEGIN
        -- Atualiza status da vaga
        UPDATE vagas
        SET status = 'FECHADA',
            data_fechamento = SYSDATE
        WHERE id_vaga = p_id_vaga
        AND status IN ('ABERTA', 'EM_PROCESSO');
        
        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20005, 'Vaga não encontrada ou já fechada');
        END IF;
        
        -- Se houve contratação, registra
        IF p_id_funcionario_contratado IS NOT NULL THEN
            UPDATE vagas
            SET funcionario_contratado_id = p_id_funcionario_contratado
            WHERE id_vaga = p_id_vaga;
        END IF;
        
        -- Log da operação
        log_recrutamento(
            p_id_vaga,
            'FECHAMENTO',
            'Vaga fechada. Motivo: ' || p_motivo ||
            CASE WHEN p_id_funcionario_contratado IS NOT NULL 
                 THEN ' - Funcionário contratado: ' || p_id_funcionario_contratado
                 ELSE ''
            END
        );
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20000, 'Erro ao fechar vaga: ' || SQLERRM);
    END;
    
    FUNCTION buscar_vaga(
        p_id_vaga IN NUMBER
    ) RETURN r_vaga_info IS
        v_vaga r_vaga_info;
    BEGIN
        SELECT v.id_vaga,
               v.titulo,
               d.nome,
               c.titulo,
               v.status,
               v.data_abertura,
               f.nome
        INTO v_vaga.id_vaga,
             v_vaga.titulo,
             v_vaga.departamento,
             v_vaga.cargo,
             v_vaga.status,
             v_vaga.data_abertura,
             v_vaga.responsavel
        FROM vagas v
        JOIN departamentos d ON v.id_departamento = d.id_departamento
        JOIN cargos c ON v.id_cargo = c.id_cargo
        JOIN funcionarios f ON v.responsavel_id = f.id_funcionario
        WHERE v.id_vaga = p_id_vaga;
        
        RETURN v_vaga;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20004, 'Vaga não encontrada');
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20000, 'Erro ao buscar vaga: ' || SQLERRM);
    END;
    
    FUNCTION listar_vagas_abertas(
        p_id_departamento IN NUMBER DEFAULT NULL
    ) RETURN t_array_vagas IS
        v_vagas t_array_vagas := t_array_vagas();
    BEGIN
        SELECT r_vaga_info(
               v.id_vaga,
               v.titulo,
               d.nome,
               c.titulo,
               v.status,
               v.data_abertura,
               f.nome)
        BULK COLLECT INTO v_vagas
        FROM vagas v
        JOIN departamentos d ON v.id_departamento = d.id_departamento
        JOIN cargos c ON v.id_cargo = c.id_cargo
        JOIN funcionarios f ON v.responsavel_id = f.id_funcionario
        WHERE v.status = 'ABERTA'
        AND (p_id_departamento IS NULL OR v.id_departamento = p_id_departamento)
        ORDER BY v.data_abertura;
        
        RETURN v_vagas;
    END;
    
    FUNCTION buscar_vagas_por_criterio(
        p_titulo IN VARCHAR2 DEFAULT NULL,
        p_id_departamento IN NUMBER DEFAULT NULL,
        p_faixa_salarial_min IN NUMBER DEFAULT NULL,
        p_faixa_salarial_max IN NUMBER DEFAULT NULL,
        p_status IN VARCHAR2 DEFAULT 'ABERTA'
    ) RETURN SYS_REFCURSOR IS
        v_result SYS_REFCURSOR;
    BEGIN
        OPEN v_result FOR
            SELECT v.id_vaga,
                   v.titulo,
                   d.nome as departamento,
                   c.titulo as cargo,
                   v.descricao,
                   v.requisitos,
                   v.faixa_salarial_min,
                   v.faixa_salarial_max,
                   v.status,
                   v.data_abertura,
                   f.nome as responsavel
            FROM vagas v
            JOIN departamentos d ON v.id_departamento = d.id_departamento
            JOIN cargos c ON v.id_cargo = c.id_cargo
            JOIN funcionarios f ON v.responsavel_id = f.id_funcionario
            WHERE (p_titulo IS NULL OR UPPER(v.titulo) LIKE '%' || UPPER(p_titulo) || '%')
            AND (p_id_departamento IS NULL OR v.id_departamento = p_id_departamento)
            AND (p_faixa_salarial_min IS NULL OR v.faixa_salarial_max >= p_faixa_salarial_min)
            AND (p_faixa_salarial_max IS NULL OR v.faixa_salarial_min <= p_faixa_salarial_max)
            AND (p_status IS NULL OR v.status = p_status)
            ORDER BY v.data_abertura DESC;
            
        RETURN v_result;
    END;
    
    PROCEDURE registrar_candidatura(
        p_id_vaga IN NUMBER,
        p_nome_candidato IN VARCHAR2,
        p_email IN VARCHAR2,
        p_telefone IN VARCHAR2,
        p_curriculo IN CLOB,
        p_pretensao_salarial IN NUMBER
    ) IS
    BEGIN
        -- Verifica se a vaga está aberta
        IF NOT EXISTS (
            SELECT 1 FROM vagas 
            WHERE id_vaga = p_id_vaga 
            AND status IN ('ABERTA', 'EM_PROCESSO')
        ) THEN
            RAISE_APPLICATION_ERROR(-20006, 'Vaga não está disponível para candidaturas');
        END IF;
        
        -- Insere a candidatura
        INSERT INTO candidaturas (
            id_vaga,
            nome_candidato,
            email,
            telefone,
            curriculo,
            pretensao_salarial,
            data_candidatura,
            status
        ) VALUES (
            p_id_vaga,
            p_nome_candidato,
            p_email,
            p_telefone,
            p_curriculo,
            p_pretensao_salarial,
            SYSDATE,
            'RECEBIDA'
        );
        
        -- Log da operação
        log_recrutamento(
            p_id_vaga,
            'CANDIDATURA',
            'Nova candidatura recebida: ' || p_nome_candidato
        );
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            RAISE_APPLICATION_ERROR(-20007, 'Candidato já registrado para esta vaga');
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20000, 'Erro ao registrar candidatura: ' || SQLERRM);
    END;
    
    PROCEDURE atualizar_status_candidatura(
        p_id_vaga IN NUMBER,
        p_email_candidato IN VARCHAR2,
        p_novo_status IN VARCHAR2,
        p_observacoes IN VARCHAR2 DEFAULT NULL
    ) IS
    BEGIN
        UPDATE candidaturas
        SET status = p_novo_status,
            ultima_atualizacao = SYSDATE,
            observacoes = p_observacoes
        WHERE id_vaga = p_id_vaga
        AND email = p_email_candidato;
        
        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20008, 'Candidatura não encontrada');
        END IF;
        
        -- Log da operação
        log_recrutamento(
            p_id_vaga,
            'ATUALIZAÇÃO_CANDIDATURA',
            'Status atualizado para ' || p_novo_status || ': ' || p_email_candidato
        );
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20000, 'Erro ao atualizar status da candidatura: ' || SQLERRM);
    END;
    
    FUNCTION listar_candidatos_vaga(
        p_id_vaga IN NUMBER
    ) RETURN SYS_REFCURSOR IS
        v_result SYS_REFCURSOR;
    BEGIN
        OPEN v_result FOR
            SELECT c.*,
                   v.titulo as vaga_titulo,
                   d.nome as departamento
            FROM candidaturas c
            JOIN vagas v ON c.id_vaga = v.id_vaga
            JOIN departamentos d ON v.id_departamento = d.id_departamento
            WHERE c.id_vaga = p_id_vaga
            ORDER BY c.data_candidatura DESC;
            
        RETURN v_result;
    END;
    
    FUNCTION avaliar_aderencia_candidato(
        p_id_vaga IN NUMBER,
        p_email_candidato IN VARCHAR2
    ) RETURN NUMBER IS
        v_score NUMBER := 0;
        v_requisitos CLOB;
        v_curriculo CLOB;
        v_faixa_min NUMBER;
        v_faixa_max NUMBER;
        v_pretensao NUMBER;
    BEGIN
        -- Obtém dados da vaga e candidatura
        SELECT v.requisitos, v.faixa_salarial_min, v.faixa_salarial_max, c.curriculo, c.pretensao_salarial
        INTO v_requisitos, v_faixa_min, v_faixa_max, v_curriculo, v_pretensao
        FROM vagas v
        JOIN candidaturas c ON v.id_vaga = c.id_vaga
        WHERE v.id_vaga = p_id_vaga
        AND c.email = p_email_candidato;
        
        -- Avalia aderência salarial (30% do score)
        IF v_pretensao BETWEEN v_faixa_min AND v_faixa_max THEN
            v_score := v_score + 30;
        ELSIF v_pretensao < v_faixa_min THEN
            v_score := v_score + 20;
        ELSE
            v_score := v_score + 10;
        END IF;
        
        -- Avalia palavras-chave dos requisitos no currículo (70% do score)
        -- Simplificado para exemplo, em produção usar análise mais sofisticada
        FOR palavra IN (
            SELECT REGEXP_SUBSTR(v_requisitos, '[^,]+', 1, LEVEL) as req
            FROM DUAL
            CONNECT BY REGEXP_SUBSTR(v_requisitos, '[^,]+', 1, LEVEL) IS NOT NULL
        ) LOOP
            IF INSTR(UPPER(v_curriculo), UPPER(TRIM(palavra.req))) > 0 THEN
                v_score := v_score + (70/10); -- Assume até 10 palavras-chave
            END IF;
        END LOOP;
        
        RETURN ROUND(LEAST(v_score, 100), 2);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20009, 'Vaga ou candidatura não encontrada');
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20000, 'Erro ao avaliar aderência: ' || SQLERRM);
    END;
    
    FUNCTION relatorio_tempo_preenchimento(
        p_id_departamento IN NUMBER DEFAULT NULL,
        p_ano IN NUMBER DEFAULT EXTRACT(YEAR FROM SYSDATE)
    ) RETURN SYS_REFCURSOR IS
        v_result SYS_REFCURSOR;
    BEGIN
        OPEN v_result FOR
            SELECT 
                d.nome as departamento,
                COUNT(*) as total_vagas,
                ROUND(AVG(v.data_fechamento - v.data_abertura), 2) as media_dias_preenchimento,
                MIN(v.data_fechamento - v.data_abertura) as menor_tempo,
                MAX(v.data_fechamento - v.data_abertura) as maior_tempo
            FROM vagas v
            JOIN departamentos d ON v.id_departamento = d.id_departamento
            WHERE v.status = 'FECHADA'
            AND v.funcionario_contratado_id IS NOT NULL
            AND EXTRACT(YEAR FROM v.data_abertura) = p_ano
            AND (p_id_departamento IS NULL OR v.id_departamento = p_id_departamento)
            GROUP BY d.nome
            ORDER BY media_dias_preenchimento;
            
        RETURN v_result;
    END;
    
    FUNCTION relatorio_fonte_candidatos(
        p_id_departamento IN NUMBER DEFAULT NULL,
        p_ano IN NUMBER DEFAULT EXTRACT(YEAR FROM SYSDATE)
    ) RETURN SYS_REFCURSOR IS
        v_result SYS_REFCURSOR;
    BEGIN
        OPEN v_result FOR
            SELECT 
                d.nome as departamento,
                c.fonte_origem,
                COUNT(*) as total_candidatos,
                COUNT(CASE WHEN c.status = 'CONTRATADO' THEN 1 END) as contratados,
                ROUND(COUNT(CASE WHEN c.status = 'CONTRATADO' THEN 1 END) / 
                      NULLIF(COUNT(*), 0) * 100, 2) as taxa_conversao
            FROM candidaturas c
            JOIN vagas v ON c.id_vaga = v.id_vaga
            JOIN departamentos d ON v.id_departamento = d.id_departamento
            WHERE EXTRACT(YEAR FROM c.data_candidatura) = p_ano
            AND (p_id_departamento IS NULL OR v.id_departamento = p_id_departamento)
            GROUP BY d.nome, c.fonte_origem
            ORDER BY d.nome, total_candidatos DESC;
            
        RETURN v_result;
    END;
    
    FUNCTION relatorio_eficiencia_processo(
        p_id_departamento IN NUMBER DEFAULT NULL,
        p_ano IN NUMBER DEFAULT EXTRACT(YEAR FROM SYSDATE)
    ) RETURN SYS_REFCURSOR IS
        v_result SYS_REFCURSOR;
    BEGIN
        OPEN v_result FOR
            WITH etapas AS (
                SELECT 
                    d.nome as departamento,
                    v.id_vaga,
                    COUNT(*) as total_candidatos,
                    COUNT(CASE WHEN c.status IN ('TRIAGEM', 'ENTREVISTA', 'TESTE', 'CONTRATADO') THEN 1 END) as passou_triagem,
                    COUNT(CASE WHEN c.status IN ('ENTREVISTA', 'TESTE', 'CONTRATADO') THEN 1 END) as passou_entrevista,
                    COUNT(CASE WHEN c.status IN ('TESTE', 'CONTRATADO') THEN 1 END) as passou_teste,
                    COUNT(CASE WHEN c.status = 'CONTRATADO' THEN 1 END) as contratados
                FROM candidaturas c
                JOIN vagas v ON c.id_vaga = v.id_vaga
                JOIN departamentos d ON v.id_departamento = d.id_departamento
                WHERE EXTRACT(YEAR FROM c.data_candidatura) = p_ano
                AND (p_id_departamento IS NULL OR v.id_departamento = p_id_departamento)
                GROUP BY d.nome, v.id_vaga
            )
            SELECT 
                departamento,
                COUNT(DISTINCT id_vaga) as total_vagas,
                ROUND(AVG(total_candidatos), 2) as media_candidatos_vaga,
                ROUND(AVG(passou_triagem/NULLIF(total_candidatos, 0) * 100), 2) as perc_passaram_triagem,
                ROUND(AVG(passou_entrevista/NULLIF(passou_triagem, 0) * 100), 2) as perc_passaram_entrevista,
                ROUND(AVG(passou_teste/NULLIF(passou_entrevista, 0) * 100), 2) as perc_passaram_teste,
                ROUND(AVG(contratados/NULLIF(total_candidatos, 0) * 100), 2) as taxa_conversao_total
            FROM etapas
            GROUP BY departamento
            ORDER BY taxa_conversao_total DESC;
            
        RETURN v_result;
    END;
    
END pkg_recrutamento;
/ 