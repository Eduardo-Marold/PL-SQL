CREATE OR REPLACE PACKAGE pkg_funcionarios AS
    /*
    Package de Gestão de Funcionários
    Autor: [Seu Nome]
    Data: [Data Atual]
    Descrição: Package responsável por todas as operações relacionadas a funcionários
    */
    
    -- Tipos
    TYPE t_funcionario_info IS RECORD (
        id_funcionario NUMBER,
        nome VARCHAR2(100),
        cargo VARCHAR2(100),
        departamento VARCHAR2(100),
        salario NUMBER,
        gestor VARCHAR2(100)
    );
    
    TYPE t_array_funcionarios IS TABLE OF t_funcionario_info;
    
    -- Funções e Procedures Públicas
    FUNCTION inserir_funcionario(
        p_nome IN VARCHAR2,
        p_cpf IN VARCHAR2,
        p_email IN VARCHAR2,
        p_id_cargo IN NUMBER,
        p_id_departamento IN NUMBER,
        p_salario IN NUMBER
    ) RETURN NUMBER;
    
    PROCEDURE atualizar_funcionario(
        p_id_funcionario IN NUMBER,
        p_nome IN VARCHAR2 DEFAULT NULL,
        p_email IN VARCHAR2 DEFAULT NULL,
        p_id_cargo IN NUMBER DEFAULT NULL,
        p_id_departamento IN NUMBER DEFAULT NULL,
        p_salario IN NUMBER DEFAULT NULL
    );
    
    PROCEDURE desligar_funcionario(
        p_id_funcionario IN NUMBER,
        p_data_demissao IN DATE DEFAULT SYSDATE,
        p_motivo IN VARCHAR2
    );
    
    FUNCTION buscar_funcionario(
        p_id_funcionario IN NUMBER
    ) RETURN t_funcionario_info;
    
    FUNCTION listar_funcionarios_departamento(
        p_id_departamento IN NUMBER
    ) RETURN t_array_funcionarios;
    
    FUNCTION calcular_folha_pagamento(
        p_id_departamento IN NUMBER DEFAULT NULL,
        p_mes IN NUMBER DEFAULT EXTRACT(MONTH FROM SYSDATE),
        p_ano IN NUMBER DEFAULT EXTRACT(YEAR FROM SYSDATE)
    ) RETURN NUMBER;
    
    PROCEDURE registrar_promocao(
        p_id_funcionario IN NUMBER,
        p_novo_cargo IN NUMBER,
        p_novo_salario IN NUMBER,
        p_data_promocao IN DATE DEFAULT SYSDATE,
        p_observacoes IN VARCHAR2 DEFAULT NULL
    );
    
    PROCEDURE adicionar_beneficio(
        p_id_funcionario IN NUMBER,
        p_id_beneficio IN NUMBER,
        p_valor_especifico IN NUMBER DEFAULT NULL
    );
    
    FUNCTION calcular_tempo_empresa(
        p_id_funcionario IN NUMBER
    ) RETURN NUMBER;
    
    FUNCTION obter_historico_cargos(
        p_id_funcionario IN NUMBER
    ) RETURN SYS_REFCURSOR;
    
    PROCEDURE registrar_avaliacao(
        p_id_funcionario IN NUMBER,
        p_avaliador_id IN NUMBER,
        p_nota IN NUMBER,
        p_pontos_fortes IN CLOB,
        p_pontos_melhoria IN CLOB,
        p_metas IN CLOB
    );
    
    FUNCTION calcular_media_avaliacao(
        p_id_funcionario IN NUMBER,
        p_ano IN NUMBER DEFAULT EXTRACT(YEAR FROM SYSDATE)
    ) RETURN NUMBER;
    
    -- Funções de Relatórios
    FUNCTION relatorio_headcount(
        p_data_referencia IN DATE DEFAULT SYSDATE
    ) RETURN SYS_REFCURSOR;
    
    FUNCTION relatorio_turnover(
        p_ano IN NUMBER DEFAULT EXTRACT(YEAR FROM SYSDATE)
    ) RETURN NUMBER;
    
    FUNCTION relatorio_custos_departamento(
        p_id_departamento IN NUMBER,
        p_mes IN NUMBER DEFAULT EXTRACT(MONTH FROM SYSDATE),
        p_ano IN NUMBER DEFAULT EXTRACT(YEAR FROM SYSDATE)
    ) RETURN SYS_REFCURSOR;
END pkg_funcionarios;
/

CREATE OR REPLACE PACKAGE BODY pkg_funcionarios AS
    -- Variáveis Privadas
    v_erro_processo EXCEPTION;
    
    -- Funções e Procedures Privadas
    PROCEDURE log_operacao(
        p_operacao IN VARCHAR2,
        p_id_funcionario IN NUMBER,
        p_descricao IN VARCHAR2
    ) IS
    BEGIN
        INSERT INTO log_operacoes_rh (
            data_operacao,
            tipo_operacao,
            id_funcionario,
            descricao,
            usuario_operacao
        ) VALUES (
            SYSDATE,
            p_operacao,
            p_id_funcionario,
            p_descricao,
            USER
        );
    END;
    
    FUNCTION validar_cpf(p_cpf IN VARCHAR2) RETURN BOOLEAN IS
        v_soma NUMBER := 0;
        v_digito NUMBER;
        v_cpf_limpo VARCHAR2(11);
    BEGIN
        -- Remove caracteres especiais
        v_cpf_limpo := REGEXP_REPLACE(p_cpf, '[^0-9]', '');
        
        -- Verifica tamanho
        IF LENGTH(v_cpf_limpo) != 11 THEN
            RETURN FALSE;
        END IF;
        
        -- Validação do primeiro dígito
        FOR i IN 1..9 LOOP
            v_soma := v_soma + TO_NUMBER(SUBSTR(v_cpf_limpo, i, 1)) * (11 - i);
        END LOOP;
        
        v_digito := 11 - MOD(v_soma, 11);
        IF v_digito > 9 THEN
            v_digito := 0;
        END IF;
        
        IF v_digito != TO_NUMBER(SUBSTR(v_cpf_limpo, 10, 1)) THEN
            RETURN FALSE;
        END IF;
        
        -- Validação do segundo dígito
        v_soma := 0;
        FOR i IN 1..10 LOOP
            v_soma := v_soma + TO_NUMBER(SUBSTR(v_cpf_limpo, i, 1)) * (12 - i);
        END LOOP;
        
        v_digito := 11 - MOD(v_soma, 11);
        IF v_digito > 9 THEN
            v_digito := 0;
        END IF;
        
        RETURN v_digito = TO_NUMBER(SUBSTR(v_cpf_limpo, 11, 1));
    END;
    
    -- Implementação das Funções e Procedures Públicas
    FUNCTION inserir_funcionario(
        p_nome IN VARCHAR2,
        p_cpf IN VARCHAR2,
        p_email IN VARCHAR2,
        p_id_cargo IN NUMBER,
        p_id_departamento IN NUMBER,
        p_salario IN NUMBER
    ) RETURN NUMBER IS
        v_id_funcionario NUMBER;
    BEGIN
        -- Validações
        IF NOT validar_cpf(p_cpf) THEN
            RAISE_APPLICATION_ERROR(-20001, 'CPF inválido');
        END IF;
        
        -- Verifica cargo e departamento
        IF NOT EXISTS (SELECT 1 FROM cargos WHERE id_cargo = p_id_cargo) THEN
            RAISE_APPLICATION_ERROR(-20002, 'Cargo não encontrado');
        END IF;
        
        IF NOT EXISTS (SELECT 1 FROM departamentos WHERE id_departamento = p_id_departamento) THEN
            RAISE_APPLICATION_ERROR(-20003, 'Departamento não encontrado');
        END IF;
        
        -- Insere o funcionário
        INSERT INTO funcionarios (
            nome,
            cpf,
            email,
            id_cargo,
            id_departamento,
            salario_atual,
            data_admissao,
            status
        ) VALUES (
            p_nome,
            p_cpf,
            p_email,
            p_id_cargo,
            p_id_departamento,
            p_salario,
            SYSDATE,
            'ATIVO'
        ) RETURNING id_funcionario INTO v_id_funcionario;
        
        -- Registra no histórico salarial
        INSERT INTO historico_salarial (
            id_funcionario,
            data_alteracao,
            salario_anterior,
            salario_novo,
            motivo
        ) VALUES (
            v_id_funcionario,
            SYSDATE,
            0,
            p_salario,
            'ADMISSÃO'
        );
        
        -- Log da operação
        log_operacao(
            'INSERÇÃO',
            v_id_funcionario,
            'Novo funcionário cadastrado'
        );
        
        RETURN v_id_funcionario;
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            RAISE_APPLICATION_ERROR(-20004, 'CPF ou email já cadastrado');
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20000, 'Erro ao inserir funcionário: ' || SQLERRM);
    END;
    
    PROCEDURE atualizar_funcionario(
        p_id_funcionario IN NUMBER,
        p_nome IN VARCHAR2 DEFAULT NULL,
        p_email IN VARCHAR2 DEFAULT NULL,
        p_id_cargo IN NUMBER DEFAULT NULL,
        p_id_departamento IN NUMBER DEFAULT NULL,
        p_salario IN NUMBER DEFAULT NULL
    ) IS
        v_salario_atual NUMBER;
    BEGIN
        -- Verifica se funcionário existe
        SELECT salario_atual
        INTO v_salario_atual
        FROM funcionarios
        WHERE id_funcionario = p_id_funcionario;
        
        -- Atualiza dados do funcionário
        UPDATE funcionarios
        SET nome = COALESCE(p_nome, nome),
            email = COALESCE(p_email, email),
            id_cargo = COALESCE(p_id_cargo, id_cargo),
            id_departamento = COALESCE(p_id_departamento, id_departamento),
            salario_atual = COALESCE(p_salario, salario_atual)
        WHERE id_funcionario = p_id_funcionario;
        
        -- Se houve alteração salarial, registra no histórico
        IF p_salario IS NOT NULL AND p_salario != v_salario_atual THEN
            INSERT INTO historico_salarial (
                id_funcionario,
                data_alteracao,
                salario_anterior,
                salario_novo,
                motivo
            ) VALUES (
                p_id_funcionario,
                SYSDATE,
                v_salario_atual,
                p_salario,
                'ATUALIZAÇÃO'
            );
        END IF;
        
        -- Log da operação
        log_operacao(
            'ATUALIZAÇÃO',
            p_id_funcionario,
            'Dados do funcionário atualizados'
        );
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20005, 'Funcionário não encontrado');
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20000, 'Erro ao atualizar funcionário: ' || SQLERRM);
    END;
    
    PROCEDURE desligar_funcionario(
        p_id_funcionario IN NUMBER,
        p_data_demissao IN DATE DEFAULT SYSDATE,
        p_motivo IN VARCHAR2
    ) IS
    BEGIN
        -- Atualiza status do funcionário
        UPDATE funcionarios
        SET status = 'DESLIGADO',
            data_demissao = p_data_demissao
        WHERE id_funcionario = p_id_funcionario
        AND status = 'ATIVO';
        
        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20006, 'Funcionário não encontrado ou já desligado');
        END IF;
        
        -- Finaliza benefícios
        UPDATE funcionarios_beneficios
        SET data_fim = p_data_demissao
        WHERE id_funcionario = p_id_funcionario
        AND data_fim IS NULL;
        
        -- Log da operação
        log_operacao(
            'DESLIGAMENTO',
            p_id_funcionario,
            'Funcionário desligado. Motivo: ' || p_motivo
        );
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20000, 'Erro ao desligar funcionário: ' || SQLERRM);
    END;
    
    FUNCTION buscar_funcionario(
        p_id_funcionario IN NUMBER
    ) RETURN t_funcionario_info IS
        v_funcionario t_funcionario_info;
    BEGIN
        SELECT f.id_funcionario,
               f.nome,
               c.titulo,
               d.nome,
               f.salario_atual,
               g.nome
        INTO v_funcionario.id_funcionario,
             v_funcionario.nome,
             v_funcionario.cargo,
             v_funcionario.departamento,
             v_funcionario.salario,
             v_funcionario.gestor
        FROM funcionarios f
        JOIN cargos c ON f.id_cargo = c.id_cargo
        JOIN departamentos d ON f.id_departamento = d.id_departamento
        LEFT JOIN funcionarios g ON f.gestor_id = g.id_funcionario
        WHERE f.id_funcionario = p_id_funcionario;
        
        RETURN v_funcionario;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20005, 'Funcionário não encontrado');
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20000, 'Erro ao buscar funcionário: ' || SQLERRM);
    END;
    
    FUNCTION listar_funcionarios_departamento(
        p_id_departamento IN NUMBER
    ) RETURN t_array_funcionarios IS
        v_funcionarios t_array_funcionarios := t_array_funcionarios();
    BEGIN
        SELECT t_funcionario_info(
               f.id_funcionario,
               f.nome,
               c.titulo,
               d.nome,
               f.salario_atual,
               g.nome)
        BULK COLLECT INTO v_funcionarios
        FROM funcionarios f
        JOIN cargos c ON f.id_cargo = c.id_cargo
        JOIN departamentos d ON f.id_departamento = d.id_departamento
        LEFT JOIN funcionarios g ON f.gestor_id = g.id_funcionario
        WHERE f.id_departamento = p_id_departamento
        AND f.status = 'ATIVO'
        ORDER BY f.nome;
        
        RETURN v_funcionarios;
    END;
    
    FUNCTION calcular_folha_pagamento(
        p_id_departamento IN NUMBER DEFAULT NULL,
        p_mes IN NUMBER DEFAULT EXTRACT(MONTH FROM SYSDATE),
        p_ano IN NUMBER DEFAULT EXTRACT(YEAR FROM SYSDATE)
    ) RETURN NUMBER IS
        v_total_folha NUMBER := 0;
    BEGIN
        SELECT NVL(SUM(salario_atual), 0)
        INTO v_total_folha
        FROM funcionarios
        WHERE status = 'ATIVO'
        AND (p_id_departamento IS NULL OR id_departamento = p_id_departamento)
        AND EXTRACT(MONTH FROM data_admissao) <= p_mes
        AND EXTRACT(YEAR FROM data_admissao) <= p_ano
        AND (data_demissao IS NULL OR
             (EXTRACT(MONTH FROM data_demissao) >= p_mes AND
              EXTRACT(YEAR FROM data_demissao) >= p_ano));
              
        RETURN v_total_folha;
    END;
    
    PROCEDURE registrar_promocao(
        p_id_funcionario IN NUMBER,
        p_novo_cargo IN NUMBER,
        p_novo_salario IN NUMBER,
        p_data_promocao IN DATE DEFAULT SYSDATE,
        p_observacoes IN VARCHAR2 DEFAULT NULL
    ) IS
        v_salario_atual NUMBER;
        v_cargo_atual NUMBER;
    BEGIN
        -- Obtém dados atuais
        SELECT salario_atual, id_cargo
        INTO v_salario_atual, v_cargo_atual
        FROM funcionarios
        WHERE id_funcionario = p_id_funcionario;
        
        -- Atualiza cargo e salário
        UPDATE funcionarios
        SET id_cargo = p_novo_cargo,
            salario_atual = p_novo_salario
        WHERE id_funcionario = p_id_funcionario;
        
        -- Registra no histórico salarial
        INSERT INTO historico_salarial (
            id_funcionario,
            data_alteracao,
            salario_anterior,
            salario_novo,
            motivo
        ) VALUES (
            p_id_funcionario,
            p_data_promocao,
            v_salario_atual,
            p_novo_salario,
            'PROMOÇÃO'
        );
        
        -- Log da operação
        log_operacao(
            'PROMOÇÃO',
            p_id_funcionario,
            'Funcionário promovido. ' || p_observacoes
        );
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20005, 'Funcionário não encontrado');
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20000, 'Erro ao registrar promoção: ' || SQLERRM);
    END;
    
    PROCEDURE adicionar_beneficio(
        p_id_funcionario IN NUMBER,
        p_id_beneficio IN NUMBER,
        p_valor_especifico IN NUMBER DEFAULT NULL
    ) IS
        v_valor_padrao NUMBER;
    BEGIN
        -- Verifica se benefício existe
        SELECT valor
        INTO v_valor_padrao
        FROM beneficios
        WHERE id_beneficio = p_id_beneficio;
        
        -- Insere o benefício
        INSERT INTO funcionarios_beneficios (
            id_funcionario,
            id_beneficio,
            data_inicio,
            valor_especifico
        ) VALUES (
            p_id_funcionario,
            p_id_beneficio,
            SYSDATE,
            COALESCE(p_valor_especifico, v_valor_padrao)
        );
        
        -- Log da operação
        log_operacao(
            'BENEFÍCIO',
            p_id_funcionario,
            'Benefício adicionado: ' || p_id_beneficio
        );
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            RAISE_APPLICATION_ERROR(-20007, 'Benefício já cadastrado para este funcionário');
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20008, 'Benefício não encontrado');
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20000, 'Erro ao adicionar benefício: ' || SQLERRM);
    END;
    
    FUNCTION calcular_tempo_empresa(
        p_id_funcionario IN NUMBER
    ) RETURN NUMBER IS
        v_tempo NUMBER;
    BEGIN
        SELECT MONTHS_BETWEEN(
            COALESCE(data_demissao, SYSDATE),
            data_admissao
        ) / 12
        INTO v_tempo
        FROM funcionarios
        WHERE id_funcionario = p_id_funcionario;
        
        RETURN ROUND(v_tempo, 2);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20005, 'Funcionário não encontrado');
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20000, 'Erro ao calcular tempo de empresa: ' || SQLERRM);
    END;
    
    FUNCTION obter_historico_cargos(
        p_id_funcionario IN NUMBER
    ) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT c.titulo,
                   h.data_alteracao,
                   h.salario_anterior,
                   h.salario_novo,
                   h.motivo
            FROM historico_salarial h
            JOIN funcionarios f ON h.id_funcionario = f.id_funcionario
            JOIN cargos c ON f.id_cargo = c.id_cargo
            WHERE h.id_funcionario = p_id_funcionario
            ORDER BY h.data_alteracao DESC;
            
        RETURN v_cursor;
    END;
    
    PROCEDURE registrar_avaliacao(
        p_id_funcionario IN NUMBER,
        p_avaliador_id IN NUMBER,
        p_nota IN NUMBER,
        p_pontos_fortes IN CLOB,
        p_pontos_melhoria IN CLOB,
        p_metas IN CLOB
    ) IS
    BEGIN
        INSERT INTO avaliacoes_desempenho (
            id_funcionario,
            avaliador_id,
            data_avaliacao,
            nota_geral,
            pontos_fortes,
            pontos_melhoria,
            metas_proximas,
            status
        ) VALUES (
            p_id_funcionario,
            p_avaliador_id,
            SYSDATE,
            p_nota,
            p_pontos_fortes,
            p_pontos_melhoria,
            p_metas,
            'CONCLUÍDA'
        );
        
        -- Log da operação
        log_operacao(
            'AVALIAÇÃO',
            p_id_funcionario,
            'Avaliação de desempenho registrada'
        );
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20000, 'Erro ao registrar avaliação: ' || SQLERRM);
    END;
    
    FUNCTION calcular_media_avaliacao(
        p_id_funcionario IN NUMBER,
        p_ano IN NUMBER DEFAULT EXTRACT(YEAR FROM SYSDATE)
    ) RETURN NUMBER IS
        v_media NUMBER;
    BEGIN
        SELECT AVG(nota_geral)
        INTO v_media
        FROM avaliacoes_desempenho
        WHERE id_funcionario = p_id_funcionario
        AND EXTRACT(YEAR FROM data_avaliacao) = p_ano;
        
        RETURN ROUND(NVL(v_media, 0), 2);
    END;
    
    FUNCTION relatorio_headcount(
        p_data_referencia IN DATE DEFAULT SYSDATE
    ) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT d.nome as departamento,
                   COUNT(*) as total_funcionarios,
                   AVG(f.salario_atual) as media_salarial,
                   MIN(f.data_admissao) as funcionario_mais_antigo,
                   MAX(f.data_admissao) as funcionario_mais_recente
            FROM funcionarios f
            JOIN departamentos d ON f.id_departamento = d.id_departamento
            WHERE f.status = 'ATIVO'
            AND f.data_admissao <= p_data_referencia
            AND (f.data_demissao IS NULL OR f.data_demissao > p_data_referencia)
            GROUP BY d.nome
            ORDER BY d.nome;
            
        RETURN v_cursor;
    END;
    
    FUNCTION relatorio_turnover(
        p_ano IN NUMBER DEFAULT EXTRACT(YEAR FROM SYSDATE)
    ) RETURN NUMBER IS
        v_media_funcionarios NUMBER;
        v_desligamentos NUMBER;
        v_turnover NUMBER;
    BEGIN
        -- Calcula média de funcionários no ano
        SELECT AVG(total)
        INTO v_media_funcionarios
        FROM (
            SELECT COUNT(*) as total
            FROM funcionarios
            WHERE EXTRACT(YEAR FROM data_admissao) <= p_ano
            AND (data_demissao IS NULL OR EXTRACT(YEAR FROM data_demissao) >= p_ano)
            GROUP BY EXTRACT(MONTH FROM data_admissao)
        );
        
        -- Calcula número de desligamentos
        SELECT COUNT(*)
        INTO v_desligamentos
        FROM funcionarios
        WHERE EXTRACT(YEAR FROM data_demissao) = p_ano;
        
        -- Calcula turnover
        IF v_media_funcionarios > 0 THEN
            v_turnover := (v_desligamentos / v_media_funcionarios) * 100;
        ELSE
            v_turnover := 0;
        END IF;
        
        RETURN ROUND(v_turnover, 2);
    END;
    
    FUNCTION relatorio_custos_departamento(
        p_id_departamento IN NUMBER,
        p_mes IN NUMBER DEFAULT EXTRACT(MONTH FROM SYSDATE),
        p_ano IN NUMBER DEFAULT EXTRACT(YEAR FROM SYSDATE)
    ) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT 
                d.nome as departamento,
                COUNT(*) as total_funcionarios,
                SUM(f.salario_atual) as custo_salarios,
                SUM(
                    SELECT NVL(SUM(COALESCE(fb.valor_especifico, b.valor)), 0)
                    FROM funcionarios_beneficios fb
                    JOIN beneficios b ON fb.id_beneficio = b.id_beneficio
                    WHERE fb.id_funcionario = f.id_funcionario
                    AND fb.data_inicio <= LAST_DAY(TO_DATE(p_mes || '/' || p_ano, 'MM/YYYY'))
                    AND (fb.data_fim IS NULL OR 
                         fb.data_fim >= LAST_DAY(TO_DATE(p_mes || '/' || p_ano, 'MM/YYYY')))
                ) as custo_beneficios,
                d.orcamento_anual/12 as orcamento_mensal
            FROM funcionarios f
            JOIN departamentos d ON f.id_departamento = d.id_departamento
            WHERE f.id_departamento = p_id_departamento
            AND f.status = 'ATIVO'
            AND EXTRACT(MONTH FROM f.data_admissao) <= p_mes
            AND EXTRACT(YEAR FROM f.data_admissao) <= p_ano
            GROUP BY d.nome, d.orcamento_anual;
            
        RETURN v_cursor;
    END;
    
END pkg_funcionarios;
/ 