-- Package de Relatórios
-- Autor: Sistema de Gestão de Biblioteca
-- Data: 2024

CREATE OR REPLACE PACKAGE pkg_relatorios AS
    -- Tipos para relatórios
    TYPE t_livro_popular IS RECORD (
        id_livro NUMBER,
        titulo VARCHAR2(200),
        isbn VARCHAR2(13),
        qtd_emprestimos NUMBER,
        dias_espera_medio NUMBER,
        qtd_reservas_ativas NUMBER
    );
    
    TYPE t_array_livros_populares IS TABLE OF t_livro_popular;
    
    TYPE t_estatistica_mensal IS RECORD (
        mes VARCHAR2(7),
        total_emprestimos NUMBER,
        total_devolucoes NUMBER,
        total_multas NUMBER,
        valor_multas NUMBER(12,2),
        novos_usuarios NUMBER,
        livros_cadastrados NUMBER
    );
    
    TYPE t_array_estatisticas IS TABLE OF t_estatistica_mensal;
    
    -- Funções de Relatório
    FUNCTION relatorio_livros_populares(
        p_data_inicio IN DATE,
        p_data_fim IN DATE
    ) RETURN t_array_livros_populares PIPELINED;
    
    FUNCTION relatorio_estatisticas_mensais(
        p_ano IN NUMBER,
        p_mes IN NUMBER DEFAULT NULL
    ) RETURN t_array_estatisticas PIPELINED;
    
    FUNCTION relatorio_multas_periodo(
        p_data_inicio IN DATE,
        p_data_fim IN DATE
    ) RETURN SYS_REFCURSOR;
    
    FUNCTION relatorio_reservas_pendentes
    RETURN SYS_REFCURSOR;
    
    FUNCTION relatorio_acervo_categoria
    RETURN SYS_REFCURSOR;
    
    FUNCTION relatorio_usuarios_ativos(
        p_data_inicio IN DATE,
        p_data_fim IN DATE
    ) RETURN SYS_REFCURSOR;
    
    -- Procedures de Geração de Relatórios
    PROCEDURE gerar_relatorio_diario;
    
    PROCEDURE gerar_relatorio_mensal(
        p_ano IN NUMBER,
        p_mes IN NUMBER
    );
    
    PROCEDURE exportar_relatorio_csv(
        p_cursor IN SYS_REFCURSOR,
        p_diretorio IN VARCHAR2,
        p_arquivo IN VARCHAR2
    );
END pkg_relatorios;
/

CREATE OR REPLACE PACKAGE BODY pkg_relatorios AS
    -- Funções privadas de suporte
    FUNCTION calcular_dias_espera_medio(
        p_id_livro IN NUMBER,
        p_data_inicio IN DATE,
        p_data_fim IN DATE
    ) RETURN NUMBER IS
        v_dias_medio NUMBER;
    BEGIN
        SELECT AVG(CASE 
            WHEN r.data_limite IS NOT NULL THEN
                (r.data_limite - r.data_reserva)
            ELSE
                (SYSDATE - r.data_reserva)
            END)
        INTO v_dias_medio
        FROM reservas r
        WHERE r.id_livro = p_id_livro
        AND r.data_reserva BETWEEN p_data_inicio AND p_data_fim;
        
        RETURN NVL(v_dias_medio, 0);
    END calcular_dias_espera_medio;
    
    -- Implementação das funções públicas
    FUNCTION relatorio_livros_populares(
        p_data_inicio IN DATE,
        p_data_fim IN DATE
    ) RETURN t_array_livros_populares PIPELINED IS
        v_livro t_livro_popular;
    BEGIN
        FOR r IN (
            SELECT l.id_livro, l.titulo, l.isbn,
                   COUNT(e.id_emprestimo) as qtd_emprestimos,
                   COUNT(CASE WHEN r.status = 'PENDENTE' THEN 1 END) as reservas_ativas
            FROM livros l
            LEFT JOIN exemplares ex ON ex.id_livro = l.id_livro
            LEFT JOIN emprestimos e ON e.id_exemplar = ex.id_exemplar
                AND e.data_emprestimo BETWEEN p_data_inicio AND p_data_fim
            LEFT JOIN reservas r ON r.id_livro = l.id_livro
                AND r.status = 'PENDENTE'
            GROUP BY l.id_livro, l.titulo, l.isbn
            HAVING COUNT(e.id_emprestimo) > 0
            ORDER BY COUNT(e.id_emprestimo) DESC
        ) LOOP
            v_livro.id_livro := r.id_livro;
            v_livro.titulo := r.titulo;
            v_livro.isbn := r.isbn;
            v_livro.qtd_emprestimos := r.qtd_emprestimos;
            v_livro.dias_espera_medio := calcular_dias_espera_medio(
                r.id_livro, p_data_inicio, p_data_fim
            );
            v_livro.qtd_reservas_ativas := r.reservas_ativas;
            PIPE ROW(v_livro);
        END LOOP;
        RETURN;
    END relatorio_livros_populares;
    
    FUNCTION relatorio_estatisticas_mensais(
        p_ano IN NUMBER,
        p_mes IN NUMBER DEFAULT NULL
    ) RETURN t_array_estatisticas PIPELINED IS
        v_estat t_estatistica_mensal;
    BEGIN
        FOR r IN (
            SELECT TO_CHAR(TRUNC(data_emprestimo, 'MM'), 'YYYY-MM') as mes,
                   COUNT(DISTINCT e.id_emprestimo) as total_emprestimos,
                   COUNT(DISTINCT CASE WHEN e.status = 'DEVOLVIDO' THEN e.id_emprestimo END) as total_devolucoes,
                   COUNT(DISTINCT CASE WHEN e.multa > 0 THEN e.id_emprestimo END) as total_multas,
                   SUM(e.multa) as valor_multas,
                   COUNT(DISTINCT CASE 
                       WHEN u.data_cadastro >= TRUNC(e.data_emprestimo, 'MM')
                       AND u.data_cadastro < ADD_MONTHS(TRUNC(e.data_emprestimo, 'MM'), 1)
                       THEN u.id_usuario 
                   END) as novos_usuarios,
                   COUNT(DISTINCT CASE 
                       WHEN l.data_cadastro >= TRUNC(e.data_emprestimo, 'MM')
                       AND l.data_cadastro < ADD_MONTHS(TRUNC(e.data_emprestimo, 'MM'), 1)
                       THEN l.id_livro
                   END) as livros_cadastrados
            FROM emprestimos e
            JOIN usuarios u ON u.id_usuario = e.id_usuario
            JOIN exemplares ex ON ex.id_exemplar = e.id_exemplar
            JOIN livros l ON l.id_livro = ex.id_livro
            WHERE EXTRACT(YEAR FROM e.data_emprestimo) = p_ano
            AND (p_mes IS NULL OR EXTRACT(MONTH FROM e.data_emprestimo) = p_mes)
            GROUP BY TRUNC(data_emprestimo, 'MM')
            ORDER BY mes
        ) LOOP
            v_estat.mes := r.mes;
            v_estat.total_emprestimos := r.total_emprestimos;
            v_estat.total_devolucoes := r.total_devolucoes;
            v_estat.total_multas := r.total_multas;
            v_estat.valor_multas := r.valor_multas;
            v_estat.novos_usuarios := r.novos_usuarios;
            v_estat.livros_cadastrados := r.livros_cadastrados;
            PIPE ROW(v_estat);
        END LOOP;
        RETURN;
    END relatorio_estatisticas_mensais;
    
    FUNCTION relatorio_multas_periodo(
        p_data_inicio IN DATE,
        p_data_fim IN DATE
    ) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT u.nome as usuario,
                   l.titulo as livro,
                   e.data_emprestimo,
                   e.data_prevista_devolucao,
                   e.data_devolucao,
                   e.multa as valor_multa,
                   hm.status as status_multa,
                   hm.data_pagamento,
                   hm.forma_pagamento
            FROM emprestimos e
            JOIN usuarios u ON u.id_usuario = e.id_usuario
            JOIN exemplares ex ON ex.id_exemplar = e.id_exemplar
            JOIN livros l ON l.id_livro = ex.id_livro
            LEFT JOIN historico_multas hm ON hm.id_emprestimo = e.id_emprestimo
            WHERE e.multa > 0
            AND e.data_emprestimo BETWEEN p_data_inicio AND p_data_fim
            ORDER BY e.data_emprestimo DESC;
            
        RETURN v_cursor;
    END relatorio_multas_periodo;
    
    FUNCTION relatorio_reservas_pendentes
    RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT l.titulo,
                   u.nome as usuario,
                   r.data_reserva,
                   r.data_limite,
                   r.posicao_fila,
                   COUNT(ex.id_exemplar) as total_exemplares,
                   COUNT(CASE WHEN ex.status = 'DISPONIVEL' THEN 1 END) as exemplares_disponiveis
            FROM reservas r
            JOIN livros l ON l.id_livro = r.id_livro
            JOIN usuarios u ON u.id_usuario = r.id_usuario
            LEFT JOIN exemplares ex ON ex.id_livro = l.id_livro
            WHERE r.status = 'PENDENTE'
            GROUP BY l.titulo, u.nome, r.data_reserva, r.data_limite, r.posicao_fila
            ORDER BY r.data_reserva;
            
        RETURN v_cursor;
    END relatorio_reservas_pendentes;
    
    FUNCTION relatorio_acervo_categoria
    RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            WITH RECURSIVE categorias_rec (id_categoria, nome, nivel, path) AS (
                SELECT c.id_categoria, c.nome, 1,
                       CAST(c.nome AS VARCHAR2(1000))
                FROM categorias c
                WHERE c.categoria_pai IS NULL
                UNION ALL
                SELECT c.id_categoria, c.nome, cr.nivel + 1,
                       cr.path || ' > ' || c.nome
                FROM categorias c
                JOIN categorias_rec cr ON cr.id_categoria = c.categoria_pai
            )
            SELECT cr.path as categoria,
                   COUNT(DISTINCT l.id_livro) as total_livros,
                   COUNT(DISTINCT ex.id_exemplar) as total_exemplares,
                   COUNT(DISTINCT CASE WHEN ex.status = 'DISPONIVEL' THEN ex.id_exemplar END) as exemplares_disponiveis,
                   COUNT(DISTINCT e.id_emprestimo) as total_emprestimos,
                   ROUND(AVG(NVL(l.ano_publicacao, 0))) as ano_medio_publicacao
            FROM categorias_rec cr
            LEFT JOIN livros l ON l.id_categoria = cr.id_categoria
            LEFT JOIN exemplares ex ON ex.id_livro = l.id_livro
            LEFT JOIN emprestimos e ON e.id_exemplar = ex.id_exemplar
            GROUP BY cr.path
            ORDER BY cr.path;
            
        RETURN v_cursor;
    END relatorio_acervo_categoria;
    
    FUNCTION relatorio_usuarios_ativos(
        p_data_inicio IN DATE,
        p_data_fim IN DATE
    ) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT u.nome,
                   u.tipo_usuario,
                   COUNT(DISTINCT e.id_emprestimo) as total_emprestimos,
                   COUNT(DISTINCT CASE WHEN e.status = 'ATRASADO' THEN e.id_emprestimo END) as emprestimos_atrasados,
                   SUM(e.multa) as total_multas,
                   COUNT(DISTINCT r.id_reserva) as total_reservas,
                   ROUND(AVG(CASE 
                       WHEN e.data_devolucao IS NOT NULL 
                       THEN e.data_devolucao - e.data_emprestimo 
                   END)) as media_dias_devolucao
            FROM usuarios u
            LEFT JOIN emprestimos e ON e.id_usuario = u.id_usuario
                AND e.data_emprestimo BETWEEN p_data_inicio AND p_data_fim
            LEFT JOIN reservas r ON r.id_usuario = u.id_usuario
                AND r.data_reserva BETWEEN p_data_inicio AND p_data_fim
            WHERE u.status = 'ATIVO'
            GROUP BY u.nome, u.tipo_usuario
            HAVING COUNT(DISTINCT e.id_emprestimo) > 0
            ORDER BY COUNT(DISTINCT e.id_emprestimo) DESC;
            
        RETURN v_cursor;
    END relatorio_usuarios_ativos;
    
    PROCEDURE gerar_relatorio_diario IS
        v_cursor SYS_REFCURSOR;
        v_data DATE := TRUNC(SYSDATE);
    BEGIN
        -- Relatório de empréstimos do dia
        OPEN v_cursor FOR
            SELECT 'EMPRÉSTIMOS DO DIA' as tipo_relatorio,
                   u.nome as usuario,
                   l.titulo as livro,
                   e.data_emprestimo,
                   e.data_prevista_devolucao
            FROM emprestimos e
            JOIN usuarios u ON u.id_usuario = e.id_usuario
            JOIN exemplares ex ON ex.id_exemplar = e.id_exemplar
            JOIN livros l ON l.id_livro = ex.id_livro
            WHERE TRUNC(e.data_emprestimo) = v_data;
            
        -- Aqui você pode implementar a lógica para salvar ou enviar o relatório
        -- Por exemplo, exportar para CSV ou enviar por email
        exportar_relatorio_csv(v_cursor, 'RELATORIOS', 'emprestimos_diarios_' || TO_CHAR(v_data, 'YYYYMMDD') || '.csv');
        
        -- Outros relatórios diários podem ser adicionados aqui
    END gerar_relatorio_diario;
    
    PROCEDURE gerar_relatorio_mensal(
        p_ano IN NUMBER,
        p_mes IN NUMBER
    ) IS
        v_cursor SYS_REFCURSOR;
        v_data_inicio DATE;
        v_data_fim DATE;
    BEGIN
        v_data_inicio := TO_DATE(p_ano || '-' || LPAD(p_mes, 2, '0') || '-01', 'YYYY-MM-DD');
        v_data_fim := LAST_DAY(v_data_inicio);
        
        -- Relatório de estatísticas mensais
        FOR r IN (
            SELECT * FROM TABLE(relatorio_estatisticas_mensais(p_ano, p_mes))
        ) LOOP
            -- Aqui você pode implementar a lógica para processar cada linha
            NULL;
        END LOOP;
        
        -- Relatório de livros populares do mês
        FOR r IN (
            SELECT * FROM TABLE(relatorio_livros_populares(v_data_inicio, v_data_fim))
        ) LOOP
            -- Aqui você pode implementar a lógica para processar cada linha
            NULL;
        END LOOP;
        
        -- Relatório de multas do mês
        v_cursor := relatorio_multas_periodo(v_data_inicio, v_data_fim);
        exportar_relatorio_csv(v_cursor, 'RELATORIOS', 
            'multas_' || TO_CHAR(v_data_inicio, 'YYYYMM') || '.csv');
            
        -- Outros relatórios mensais podem ser adicionados aqui
    END gerar_relatorio_mensal;
    
    PROCEDURE exportar_relatorio_csv(
        p_cursor IN SYS_REFCURSOR,
        p_diretorio IN VARCHAR2,
        p_arquivo IN VARCHAR2
    ) IS
        -- Implementação depende das permissões e configurações do banco de dados
        -- Aqui você implementaria a lógica para exportar o cursor para um arquivo CSV
        -- Usando UTL_FILE ou outra abordagem apropriada
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        NULL;
    END exportar_relatorio_csv;
    
END pkg_relatorios;
/ 