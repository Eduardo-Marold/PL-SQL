CREATE OR REPLACE PACKAGE pkg_analytics_rh AS
    /*
    Package de Analytics de RH
    Autor: [Seu Nome]
    Data: [Data Atual]
    Descrição: Package responsável por análises avançadas e relatórios de RH
    */
    
    -- Tipos
    TYPE r_indicadores_departamento IS RECORD (
        nome_departamento VARCHAR2(100),
        total_funcionarios NUMBER,
        media_salarial NUMBER,
        turnover_rate NUMBER,
        custo_total NUMBER,
        orcamento_utilizado NUMBER
    );
    
    TYPE t_array_indicadores IS TABLE OF r_indicadores_departamento;
    
    -- Funções e Procedures Públicas
    FUNCTION analisar_turnover_detalhado(
        p_ano IN NUMBER DEFAULT EXTRACT(YEAR FROM SYSDATE)
    ) RETURN SYS_REFCURSOR;
    
    FUNCTION analisar_custos_beneficios(
        p_ano IN NUMBER DEFAULT EXTRACT(YEAR FROM SYSDATE)
    ) RETURN SYS_REFCURSOR;
    
    FUNCTION calcular_crescimento_folha(
        p_mes_inicio IN DATE,
        p_mes_fim IN DATE
    ) RETURN NUMBER;
    
    FUNCTION analisar_distribuicao_salarial(
        p_id_cargo IN NUMBER DEFAULT NULL
    ) RETURN SYS_REFCURSOR;
    
    FUNCTION calcular_gap_salarial(
        p_id_cargo IN NUMBER,
        p_id_departamento IN NUMBER DEFAULT NULL
    ) RETURN NUMBER;
    
    FUNCTION analisar_tempo_servico(
    ) RETURN SYS_REFCURSOR;
    
    FUNCTION avaliar_desempenho_departamento(
        p_id_departamento IN NUMBER,
        p_ano IN NUMBER DEFAULT EXTRACT(YEAR FROM SYSDATE)
    ) RETURN SYS_REFCURSOR;
    
    FUNCTION projetar_custos_folha(
        p_meses_projecao IN NUMBER DEFAULT 12
    ) RETURN SYS_REFCURSOR;
    
    FUNCTION analisar_eficiencia_recrutamento(
        p_ano IN NUMBER DEFAULT EXTRACT(YEAR FROM SYSDATE)
    ) RETURN SYS_REFCURSOR;
    
    FUNCTION calcular_roi_treinamentos(
        p_id_departamento IN NUMBER DEFAULT NULL,
        p_ano IN NUMBER DEFAULT EXTRACT(YEAR FROM SYSDATE)
    ) RETURN NUMBER;
    
    -- Relatórios Estratégicos
    FUNCTION dashboard_indicadores_rh(
        p_data_referencia IN DATE DEFAULT SYSDATE
    ) RETURN t_array_indicadores;
    
    FUNCTION analise_comparativa_mercado(
        p_id_cargo IN NUMBER
    ) RETURN SYS_REFCURSOR;
    
    FUNCTION projecao_headcount(
        p_meses_projecao IN NUMBER DEFAULT 12
    ) RETURN SYS_REFCURSOR;
END pkg_analytics_rh;
/

CREATE OR REPLACE PACKAGE BODY pkg_analytics_rh AS
    -- Funções Privadas
    FUNCTION calcular_media_movel(
        p_valores IN SYS_REFCURSOR,
        p_periodo IN NUMBER
    ) RETURN NUMBER IS
        v_soma NUMBER := 0;
        v_count NUMBER := 0;
        v_valor NUMBER;
    BEGIN
        LOOP
            FETCH p_valores INTO v_valor;
            EXIT WHEN p_valores%NOTFOUND;
            
            v_soma := v_soma + v_valor;
            v_count := v_count + 1;
            
            IF v_count > p_periodo THEN
                EXIT;
            END IF;
        END LOOP;
        
        RETURN CASE WHEN v_count > 0 THEN v_soma / v_count ELSE 0 END;
    END;
    
    -- Implementação das Funções Públicas
    FUNCTION analisar_turnover_detalhado(
        p_ano IN NUMBER DEFAULT EXTRACT(YEAR FROM SYSDATE)
    ) RETURN SYS_REFCURSOR IS
        v_result SYS_REFCURSOR;
    BEGIN
        OPEN v_result FOR
            WITH desligamentos AS (
                SELECT 
                    d.nome as departamento,
                    c.titulo as cargo,
                    COUNT(*) as total_desligamentos,
                    AVG(f.salario_atual) as media_salario_desligados,
                    AVG(MONTHS_BETWEEN(f.data_demissao, f.data_admissao)/12) as tempo_medio_empresa
                FROM funcionarios f
                JOIN departamentos d ON f.id_departamento = d.id_departamento
                JOIN cargos c ON f.id_cargo = c.id_cargo
                WHERE EXTRACT(YEAR FROM f.data_demissao) = p_ano
                GROUP BY d.nome, c.titulo
            ),
            ativos AS (
                SELECT 
                    d.nome as departamento,
                    c.titulo as cargo,
                    COUNT(*) as total_ativos
                FROM funcionarios f
                JOIN departamentos d ON f.id_departamento = d.id_departamento
                JOIN cargos c ON f.id_cargo = c.id_cargo
                WHERE f.status = 'ATIVO'
                AND EXTRACT(YEAR FROM f.data_admissao) <= p_ano
                GROUP BY d.nome, c.titulo
            )
            SELECT 
                a.departamento,
                a.cargo,
                a.total_ativos,
                NVL(d.total_desligamentos, 0) as desligamentos,
                ROUND(NVL(d.total_desligamentos, 0) / NULLIF(a.total_ativos, 0) * 100, 2) as taxa_turnover,
                d.media_salario_desligados,
                d.tempo_medio_empresa
            FROM ativos a
            LEFT JOIN desligamentos d ON a.departamento = d.departamento 
                                    AND a.cargo = d.cargo
            ORDER BY taxa_turnover DESC;
        
        RETURN v_result;
    END;
    
    FUNCTION analisar_custos_beneficios(
        p_ano IN NUMBER DEFAULT EXTRACT(YEAR FROM SYSDATE)
    ) RETURN SYS_REFCURSOR IS
        v_result SYS_REFCURSOR;
    BEGIN
        OPEN v_result FOR
            WITH custos_mensais AS (
                SELECT 
                    d.nome as departamento,
                    b.tipo as tipo_beneficio,
                    EXTRACT(MONTH FROM fb.data_inicio) as mes,
                    SUM(COALESCE(fb.valor_especifico, b.valor)) as valor_total
                FROM funcionarios_beneficios fb
                JOIN beneficios b ON fb.id_beneficio = b.id_beneficio
                JOIN funcionarios f ON fb.id_funcionario = f.id_funcionario
                JOIN departamentos d ON f.id_departamento = d.id_departamento
                WHERE EXTRACT(YEAR FROM fb.data_inicio) = p_ano
                AND (fb.data_fim IS NULL OR EXTRACT(YEAR FROM fb.data_fim) >= p_ano)
                GROUP BY d.nome, b.tipo, EXTRACT(MONTH FROM fb.data_inicio)
            )
            SELECT 
                departamento,
                tipo_beneficio,
                SUM(valor_total) as custo_total_ano,
                AVG(valor_total) as media_mensal,
                MIN(valor_total) as menor_mes,
                MAX(valor_total) as maior_mes,
                STDDEV(valor_total) as desvio_padrao
            FROM custos_mensais
            GROUP BY departamento, tipo_beneficio
            ORDER BY departamento, custo_total_ano DESC;
        
        RETURN v_result;
    END;
    
    FUNCTION calcular_crescimento_folha(
        p_mes_inicio IN DATE,
        p_mes_fim IN DATE
    ) RETURN NUMBER IS
        v_valor_inicial NUMBER;
        v_valor_final NUMBER;
    BEGIN
        -- Calcula valor da folha no início do período
        SELECT SUM(salario_atual)
        INTO v_valor_inicial
        FROM funcionarios
        WHERE data_admissao <= p_mes_inicio
        AND (data_demissao IS NULL OR data_demissao > p_mes_inicio);
        
        -- Calcula valor da folha no fim do período
        SELECT SUM(salario_atual)
        INTO v_valor_final
        FROM funcionarios
        WHERE data_admissao <= p_mes_fim
        AND (data_demissao IS NULL OR data_demissao > p_mes_fim);
        
        -- Calcula crescimento percentual
        RETURN CASE 
            WHEN v_valor_inicial > 0 
            THEN ROUND(((v_valor_final - v_valor_inicial) / v_valor_inicial) * 100, 2)
            ELSE 0
        END;
    END;
    
    FUNCTION analisar_distribuicao_salarial(
        p_id_cargo IN NUMBER DEFAULT NULL
    ) RETURN SYS_REFCURSOR IS
        v_result SYS_REFCURSOR;
    BEGIN
        OPEN v_result FOR
            WITH estatisticas AS (
                SELECT 
                    c.titulo,
                    MIN(f.salario_atual) as min_salario,
                    MAX(f.salario_atual) as max_salario,
                    AVG(f.salario_atual) as media_salario,
                    MEDIAN(f.salario_atual) as mediana_salario,
                    STDDEV(f.salario_atual) as desvio_padrao,
                    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY f.salario_atual) as quartil_1,
                    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY f.salario_atual) as quartil_3
                FROM funcionarios f
                JOIN cargos c ON f.id_cargo = c.id_cargo
                WHERE f.status = 'ATIVO'
                AND (p_id_cargo IS NULL OR f.id_cargo = p_id_cargo)
                GROUP BY c.titulo
            )
            SELECT 
                titulo,
                min_salario,
                max_salario,
                media_salario,
                mediana_salario,
                desvio_padrao,
                quartil_1,
                quartil_3,
                quartil_3 - quartil_1 as amplitude_interquartil
            FROM estatisticas
            ORDER BY media_salario DESC;
        
        RETURN v_result;
    END;
    
    FUNCTION calcular_gap_salarial(
        p_id_cargo IN NUMBER,
        p_id_departamento IN NUMBER DEFAULT NULL
    ) RETURN NUMBER IS
        v_gap NUMBER;
    BEGIN
        WITH salarios_genero AS (
            SELECT 
                CASE WHEN LENGTH(cpf) % 2 = 0 THEN 'F' ELSE 'M' END as genero,
                AVG(salario_atual) as media_salario
            FROM funcionarios
            WHERE id_cargo = p_id_cargo
            AND status = 'ATIVO'
            AND (p_id_departamento IS NULL OR id_departamento = p_id_departamento)
            GROUP BY CASE WHEN LENGTH(cpf) % 2 = 0 THEN 'F' ELSE 'M' END
        )
        SELECT 
            ROUND(
                (MAX(CASE WHEN genero = 'M' THEN media_salario END) -
                 MAX(CASE WHEN genero = 'F' THEN media_salario END)) /
                NULLIF(MAX(CASE WHEN genero = 'M' THEN media_salario END), 0) * 100,
                2
            )
        INTO v_gap
        FROM salarios_genero;
        
        RETURN NVL(v_gap, 0);
    END;
    
    FUNCTION analisar_tempo_servico(
    ) RETURN SYS_REFCURSOR IS
        v_result SYS_REFCURSOR;
    BEGIN
        OPEN v_result FOR
            WITH tempo_servico AS (
                SELECT 
                    d.nome as departamento,
                    c.titulo as cargo,
                    ROUND(AVG(MONTHS_BETWEEN(COALESCE(f.data_demissao, SYSDATE), f.data_admissao)/12), 2) as tempo_medio,
                    COUNT(*) as total_funcionarios,
                    SUM(CASE WHEN MONTHS_BETWEEN(COALESCE(f.data_demissao, SYSDATE), f.data_admissao) > 60 THEN 1 ELSE 0 END) as senior_5anos
                FROM funcionarios f
                JOIN departamentos d ON f.id_departamento = d.id_departamento
                JOIN cargos c ON f.id_cargo = c.id_cargo
                WHERE f.status = 'ATIVO'
                GROUP BY d.nome, c.titulo
            )
            SELECT 
                departamento,
                cargo,
                tempo_medio,
                total_funcionarios,
                senior_5anos,
                ROUND(senior_5anos/NULLIF(total_funcionarios, 0) * 100, 2) as perc_senior
            FROM tempo_servico
            ORDER BY tempo_medio DESC;
        
        RETURN v_result;
    END;
    
    FUNCTION avaliar_desempenho_departamento(
        p_id_departamento IN NUMBER,
        p_ano IN NUMBER DEFAULT EXTRACT(YEAR FROM SYSDATE)
    ) RETURN SYS_REFCURSOR IS
        v_result SYS_REFCURSOR;
    BEGIN
        OPEN v_result FOR
            WITH avaliacoes_dept AS (
                SELECT 
                    f.id_funcionario,
                    f.nome,
                    c.titulo as cargo,
                    AVG(ad.nota_geral) as media_nota,
                    COUNT(*) as total_avaliacoes,
                    MIN(ad.nota_geral) as menor_nota,
                    MAX(ad.nota_geral) as maior_nota
                FROM funcionarios f
                JOIN cargos c ON f.id_cargo = c.id_cargo
                LEFT JOIN avaliacoes_desempenho ad ON f.id_funcionario = ad.id_funcionario
                WHERE f.id_departamento = p_id_departamento
                AND f.status = 'ATIVO'
                AND EXTRACT(YEAR FROM ad.data_avaliacao) = p_ano
                GROUP BY f.id_funcionario, f.nome, c.titulo
            )
            SELECT 
                nome,
                cargo,
                media_nota,
                total_avaliacoes,
                menor_nota,
                maior_nota,
                CASE 
                    WHEN media_nota >= 9 THEN 'EXCELENTE'
                    WHEN media_nota >= 7 THEN 'BOM'
                    WHEN media_nota >= 5 THEN 'REGULAR'
                    ELSE 'NECESSITA MELHORIAS'
                END as classificacao
            FROM avaliacoes_dept
            ORDER BY media_nota DESC;
        
        RETURN v_result;
    END;
    
    FUNCTION projetar_custos_folha(
        p_meses_projecao IN NUMBER DEFAULT 12
    ) RETURN SYS_REFCURSOR IS
        v_result SYS_REFCURSOR;
    BEGIN
        OPEN v_result FOR
            WITH historico_custos AS (
                SELECT 
                    TRUNC(data_alteracao, 'MM') as mes,
                    SUM(salario_novo - salario_anterior) as variacao_mes
                FROM historico_salarial
                WHERE data_alteracao >= ADD_MONTHS(SYSDATE, -12)
                GROUP BY TRUNC(data_alteracao, 'MM')
            ),
            media_crescimento AS (
                SELECT AVG(variacao_mes) as media_variacao
                FROM historico_custos
            ),
            base_atual AS (
                SELECT SUM(salario_atual) as custo_atual
                FROM funcionarios
                WHERE status = 'ATIVO'
            )
            SELECT 
                ADD_MONTHS(TRUNC(SYSDATE, 'MM'), nivel) as mes_referencia,
                ROUND(custo_atual + (nivel * media_variacao), 2) as custo_projetado
            FROM base_atual
            CROSS JOIN media_crescimento
            CROSS JOIN (
                SELECT LEVEL-1 as nivel
                FROM DUAL
                CONNECT BY LEVEL <= p_meses_projecao
            )
            ORDER BY mes_referencia;
        
        RETURN v_result;
    END;
    
    FUNCTION analisar_eficiencia_recrutamento(
        p_ano IN NUMBER DEFAULT EXTRACT(YEAR FROM SYSDATE)
    ) RETURN SYS_REFCURSOR IS
        v_result SYS_REFCURSOR;
    BEGIN
        OPEN v_result FOR
            SELECT 
                d.nome as departamento,
                COUNT(DISTINCT v.id_vaga) as total_vagas,
                AVG(CASE WHEN v.status = 'FECHADA' 
                    THEN TRUNC(v.data_fechamento) - TRUNC(v.data_abertura)
                    ELSE NULL END) as tempo_medio_preenchimento,
                COUNT(CASE WHEN v.status = 'FECHADA' THEN 1 END) as vagas_preenchidas,
                COUNT(CASE WHEN v.status = 'CANCELADA' THEN 1 END) as vagas_canceladas,
                ROUND(COUNT(CASE WHEN v.status = 'FECHADA' THEN 1 END) / 
                      NULLIF(COUNT(DISTINCT v.id_vaga), 0) * 100, 2) as taxa_sucesso
            FROM vagas v
            JOIN departamentos d ON v.id_departamento = d.id_departamento
            WHERE EXTRACT(YEAR FROM v.data_abertura) = p_ano
            GROUP BY d.nome
            ORDER BY taxa_sucesso DESC;
        
        RETURN v_result;
    END;
    
    FUNCTION calcular_roi_treinamentos(
        p_id_departamento IN NUMBER DEFAULT NULL,
        p_ano IN NUMBER DEFAULT EXTRACT(YEAR FROM SYSDATE)
    ) RETURN NUMBER IS
        v_custo_total NUMBER := 0;
        v_beneficio_estimado NUMBER := 0;
        v_roi NUMBER;
    BEGIN
        -- Calcula custo total dos treinamentos
        SELECT NVL(SUM(t.custo), 0)
        INTO v_custo_total
        FROM funcionarios_treinamentos ft
        JOIN treinamentos t ON ft.id_treinamento = t.id_treinamento
        JOIN funcionarios f ON ft.id_funcionario = f.id_funcionario
        WHERE EXTRACT(YEAR FROM ft.data_inicio) = p_ano
        AND (p_id_departamento IS NULL OR f.id_departamento = p_id_departamento);
        
        -- Estima benefício baseado em aumento de produtividade (nota das avaliações)
        SELECT NVL(SUM(
            CASE 
                WHEN ad2.nota_geral > ad1.nota_geral 
                THEN (ad2.nota_geral - ad1.nota_geral) * f.salario_atual * 0.1
                ELSE 0 
            END), 0)
        INTO v_beneficio_estimado
        FROM funcionarios_treinamentos ft
        JOIN funcionarios f ON ft.id_funcionario = f.id_funcionario
        JOIN avaliacoes_desempenho ad1 ON f.id_funcionario = ad1.id_funcionario
        JOIN avaliacoes_desempenho ad2 ON f.id_funcionario = ad2.id_funcionario
        WHERE EXTRACT(YEAR FROM ft.data_inicio) = p_ano
        AND (p_id_departamento IS NULL OR f.id_departamento = p_id_departamento)
        AND ad1.data_avaliacao < ft.data_inicio
        AND ad2.data_avaliacao > ft.data_fim
        AND ad1.data_avaliacao = (
            SELECT MAX(data_avaliacao)
            FROM avaliacoes_desempenho ad3
            WHERE ad3.id_funcionario = f.id_funcionario
            AND ad3.data_avaliacao < ft.data_inicio
        )
        AND ad2.data_avaliacao = (
            SELECT MIN(data_avaliacao)
            FROM avaliacoes_desempenho ad4
            WHERE ad4.id_funcionario = f.id_funcionario
            AND ad4.data_avaliacao > ft.data_fim
        );
        
        -- Calcula ROI
        IF v_custo_total > 0 THEN
            v_roi := ((v_beneficio_estimado - v_custo_total) / v_custo_total) * 100;
        ELSE
            v_roi := 0;
        END IF;
        
        RETURN ROUND(v_roi, 2);
    END;
    
    FUNCTION dashboard_indicadores_rh(
        p_data_referencia IN DATE DEFAULT SYSDATE
    ) RETURN t_array_indicadores IS
        v_indicadores t_array_indicadores := t_array_indicadores();
    BEGIN
        SELECT r_indicadores_departamento(
            d.nome,
            COUNT(DISTINCT f.id_funcionario),
            AVG(f.salario_atual),
            (SELECT pkg_funcionarios.relatorio_turnover(EXTRACT(YEAR FROM p_data_referencia)) FROM DUAL),
            SUM(f.salario_atual) + NVL((
                SELECT SUM(COALESCE(fb.valor_especifico, b.valor))
                FROM funcionarios_beneficios fb
                JOIN beneficios b ON fb.id_beneficio = b.id_beneficio
                WHERE fb.id_funcionario = f.id_funcionario
                AND fb.data_inicio <= p_data_referencia
                AND (fb.data_fim IS NULL OR fb.data_fim > p_data_referencia)
            ), 0),
            ROUND(
                (SUM(f.salario_atual) / NULLIF(d.orcamento_anual/12, 0)) * 100,
                2
            )
        )
        BULK COLLECT INTO v_indicadores
        FROM departamentos d
        LEFT JOIN funcionarios f ON d.id_departamento = f.id_departamento
        WHERE f.status = 'ATIVO'
        AND f.data_admissao <= p_data_referencia
        AND (f.data_demissao IS NULL OR f.data_demissao > p_data_referencia)
        GROUP BY d.nome, d.orcamento_anual;
        
        RETURN v_indicadores;
    END;
    
    FUNCTION analise_comparativa_mercado(
        p_id_cargo IN NUMBER
    ) RETURN SYS_REFCURSOR IS
        v_result SYS_REFCURSOR;
    BEGIN
        OPEN v_result FOR
            WITH estatisticas_cargo AS (
                SELECT 
                    c.titulo,
                    c.nivel,
                    AVG(f.salario_atual) as media_interna,
                    STDDEV(f.salario_atual) as desvio_padrao,
                    MIN(f.salario_atual) as min_salario,
                    MAX(f.salario_atual) as max_salario,
                    c.faixa_salarial_min as mercado_min,
                    c.faixa_salarial_max as mercado_max
                FROM cargos c
                LEFT JOIN funcionarios f ON c.id_cargo = f.id_cargo
                WHERE c.id_cargo = p_id_cargo
                AND f.status = 'ATIVO'
                GROUP BY c.titulo, c.nivel, c.faixa_salarial_min, c.faixa_salarial_max
            )
            SELECT 
                titulo,
                nivel,
                media_interna,
                desvio_padrao,
                min_salario,
                max_salario,
                mercado_min,
                mercado_max,
                ROUND(
                    (media_interna - mercado_min) / NULLIF(mercado_min, 0) * 100,
                    2
                ) as diff_mercado_min_perc,
                ROUND(
                    (media_interna - mercado_max) / NULLIF(mercado_max, 0) * 100,
                    2
                ) as diff_mercado_max_perc
            FROM estatisticas_cargo;
        
        RETURN v_result;
    END;
    
    FUNCTION projecao_headcount(
        p_meses_projecao IN NUMBER DEFAULT 12
    ) RETURN SYS_REFCURSOR IS
        v_result SYS_REFCURSOR;
    BEGIN
        OPEN v_result FOR
            WITH historico_headcount AS (
                SELECT 
                    d.nome as departamento,
                    TRUNC(f.data_admissao, 'MM') as mes,
                    COUNT(*) as admissoes,
                    SUM(CASE WHEN f.data_demissao IS NOT NULL THEN 1 ELSE 0 END) as demissoes
                FROM funcionarios f
                JOIN departamentos d ON f.id_departamento = d.id_departamento
                WHERE f.data_admissao >= ADD_MONTHS(SYSDATE, -12)
                GROUP BY d.nome, TRUNC(f.data_admissao, 'MM')
            ),
            media_variacao AS (
                SELECT 
                    departamento,
                    AVG(admissoes - demissoes) as media_crescimento_mensal
                FROM historico_headcount
                GROUP BY departamento
            ),
            headcount_atual AS (
                SELECT 
                    d.nome as departamento,
                    COUNT(*) as total_atual
                FROM funcionarios f
                JOIN departamentos d ON f.id_departamento = d.id_departamento
                WHERE f.status = 'ATIVO'
                GROUP BY d.nome
            )
            SELECT 
                h.departamento,
                ADD_MONTHS(TRUNC(SYSDATE, 'MM'), nivel) as mes_referencia,
                ROUND(h.total_atual + (nivel * m.media_crescimento_mensal)) as headcount_projetado
            FROM headcount_atual h
            JOIN media_variacao m ON h.departamento = m.departamento
            CROSS JOIN (
                SELECT LEVEL-1 as nivel
                FROM DUAL
                CONNECT BY LEVEL <= p_meses_projecao
            )
            ORDER BY h.departamento, mes_referencia;
        
        RETURN v_result;
    END;
    
END pkg_analytics_rh;
/ 