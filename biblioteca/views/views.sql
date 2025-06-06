-- Views do Sistema de Biblioteca
-- Autor: Sistema de Gestão de Biblioteca
-- Data: 2024

-- View de disponibilidade de livros
CREATE OR REPLACE VIEW vw_disponibilidade_livros AS
SELECT 
    l.id_livro,
    l.titulo,
    l.isbn,
    l.status as status_livro,
    COUNT(e.id_exemplar) as total_exemplares,
    COUNT(CASE WHEN e.status = 'DISPONIVEL' THEN 1 END) as exemplares_disponiveis,
    COUNT(CASE WHEN e.status = 'EMPRESTADO' THEN 1 END) as exemplares_emprestados,
    COUNT(CASE WHEN e.status = 'EM_MANUTENCAO' THEN 1 END) as exemplares_manutencao,
    COUNT(CASE WHEN r.status = 'PENDENTE' THEN 1 END) as reservas_pendentes,
    CASE 
        WHEN COUNT(CASE WHEN e.status = 'DISPONIVEL' THEN 1 END) > 0 THEN 'DISPONÍVEL'
        WHEN COUNT(CASE WHEN e.status = 'EMPRESTADO' THEN 1 END) > 0 THEN 'EMPRESTADO'
        ELSE 'INDISPONÍVEL'
    END as situacao_atual
FROM livros l
LEFT JOIN exemplares e ON e.id_livro = l.id_livro
LEFT JOIN reservas r ON r.id_livro = l.id_livro AND r.status = 'PENDENTE'
GROUP BY l.id_livro, l.titulo, l.isbn, l.status;

-- View de empréstimos ativos com detalhes
CREATE OR REPLACE VIEW vw_emprestimos_ativos AS
SELECT 
    e.id_emprestimo,
    u.nome as usuario,
    l.titulo as livro,
    ex.codigo_barras,
    e.data_emprestimo,
    e.data_prevista_devolucao,
    CASE 
        WHEN e.data_prevista_devolucao < SYSDATE THEN 'ATRASADO'
        ELSE 'EM_DIA'
    END as situacao,
    CASE 
        WHEN e.data_prevista_devolucao < SYSDATE 
        THEN TRUNC(SYSDATE - e.data_prevista_devolucao)
        ELSE 0
    END as dias_atraso,
    CASE 
        WHEN e.data_prevista_devolucao < SYSDATE 
        THEN TRUNC(SYSDATE - e.data_prevista_devolucao) * pkg_emprestimos.c_valor_multa_dia
        ELSE 0
    END as multa_prevista,
    ub.nome as bibliotecario_emprestimo
FROM emprestimos e
JOIN usuarios u ON u.id_usuario = e.id_usuario
JOIN exemplares ex ON ex.id_exemplar = e.id_exemplar
JOIN livros l ON l.id_livro = ex.id_livro
JOIN usuarios ub ON ub.id_usuario = e.bibliotecario_emprestimo
WHERE e.status = 'ATIVO';

-- View de histórico de empréstimos por usuário
CREATE OR REPLACE VIEW vw_historico_usuario AS
SELECT 
    u.id_usuario,
    u.nome as usuario,
    COUNT(e.id_emprestimo) as total_emprestimos,
    COUNT(CASE WHEN e.status = 'ATIVO' THEN 1 END) as emprestimos_ativos,
    COUNT(CASE WHEN e.status = 'DEVOLVIDO' THEN 1 END) as emprestimos_concluidos,
    COUNT(CASE WHEN e.status = 'ATRASADO' THEN 1 END) as emprestimos_atrasados,
    SUM(e.multa) as total_multas,
    COUNT(CASE WHEN hm.status = 'PENDENTE' THEN 1 END) as multas_pendentes,
    ROUND(AVG(CASE 
        WHEN e.data_devolucao IS NOT NULL 
        THEN e.data_devolucao - e.data_emprestimo 
    END)) as media_dias_devolucao
FROM usuarios u
LEFT JOIN emprestimos e ON e.id_usuario = u.id_usuario
LEFT JOIN historico_multas hm ON hm.id_emprestimo = e.id_emprestimo
GROUP BY u.id_usuario, u.nome;

-- View de ranking de livros mais emprestados
CREATE OR REPLACE VIEW vw_ranking_livros AS
SELECT 
    l.id_livro,
    l.titulo,
    l.isbn,
    COUNT(e.id_emprestimo) as total_emprestimos,
    COUNT(DISTINCT e.id_usuario) as usuarios_distintos,
    ROUND(AVG(CASE 
        WHEN e.data_devolucao IS NOT NULL 
        THEN e.data_devolucao - e.data_emprestimo 
    END)) as media_dias_emprestimo,
    COUNT(CASE WHEN e.status = 'ATRASADO' THEN 1 END) as total_atrasos,
    COUNT(CASE WHEN r.status = 'PENDENTE' THEN 1 END) as reservas_atuais
FROM livros l
LEFT JOIN exemplares ex ON ex.id_livro = l.id_livro
LEFT JOIN emprestimos e ON e.id_exemplar = ex.id_exemplar
LEFT JOIN reservas r ON r.id_livro = l.id_livro AND r.status = 'PENDENTE'
GROUP BY l.id_livro, l.titulo, l.isbn
ORDER BY COUNT(e.id_emprestimo) DESC;

-- View de multas pendentes
CREATE OR REPLACE VIEW vw_multas_pendentes AS
SELECT 
    u.nome as usuario,
    l.titulo as livro,
    e.data_emprestimo,
    e.data_prevista_devolucao,
    e.data_devolucao,
    e.multa as valor_multa,
    hm.data_geracao,
    TRUNC(SYSDATE - hm.data_geracao) as dias_pendente
FROM historico_multas hm
JOIN emprestimos e ON e.id_emprestimo = hm.id_emprestimo
JOIN usuarios u ON u.id_usuario = e.id_usuario
JOIN exemplares ex ON ex.id_exemplar = e.id_exemplar
JOIN livros l ON l.id_livro = ex.id_livro
WHERE hm.status = 'PENDENTE'
ORDER BY hm.data_geracao;

-- View de reservas ativas com fila
CREATE OR REPLACE VIEW vw_fila_reservas AS
SELECT 
    l.titulo,
    COUNT(CASE WHEN ex.status = 'DISPONIVEL' THEN 1 END) as exemplares_disponiveis,
    COUNT(CASE WHEN ex.status = 'EMPRESTADO' THEN 1 END) as exemplares_emprestados,
    r.id_reserva,
    u.nome as usuario,
    r.data_reserva,
    r.posicao_fila,
    CASE 
        WHEN COUNT(CASE WHEN ex.status = 'DISPONIVEL' THEN 1 END) > 0 
        THEN 'DISPONÍVEL PARA RETIRADA'
        ELSE 'EM FILA DE ESPERA'
    END as situacao
FROM reservas r
JOIN livros l ON l.id_livro = r.id_livro
JOIN usuarios u ON u.id_usuario = r.id_usuario
LEFT JOIN exemplares ex ON ex.id_livro = l.id_livro
WHERE r.status = 'PENDENTE'
GROUP BY l.titulo, r.id_reserva, u.nome, r.data_reserva, r.posicao_fila
ORDER BY l.titulo, r.posicao_fila;

-- View de estatísticas gerais
CREATE OR REPLACE VIEW vw_estatisticas_gerais AS
WITH stats AS (
    SELECT
        COUNT(DISTINCT l.id_livro) as total_livros,
        COUNT(DISTINCT ex.id_exemplar) as total_exemplares,
        COUNT(DISTINCT CASE WHEN u.tipo_usuario = 'LEITOR' THEN u.id_usuario END) as total_leitores,
        COUNT(DISTINCT e.id_emprestimo) as total_emprestimos,
        COUNT(DISTINCT CASE WHEN e.status = 'ATIVO' THEN e.id_emprestimo END) as emprestimos_ativos,
        COUNT(DISTINCT CASE WHEN e.status = 'ATRASADO' THEN e.id_emprestimo END) as emprestimos_atrasados,
        SUM(e.multa) as total_multas,
        COUNT(DISTINCT CASE WHEN hm.status = 'PENDENTE' THEN hm.id_multa END) as multas_pendentes,
        COUNT(DISTINCT r.id_reserva) as total_reservas
    FROM livros l
    LEFT JOIN exemplares ex ON ex.id_livro = l.id_livro
    LEFT JOIN emprestimos e ON e.id_exemplar = ex.id_exemplar
    LEFT JOIN usuarios u ON u.id_usuario = e.id_usuario
    LEFT JOIN historico_multas hm ON hm.id_emprestimo = e.id_emprestimo
    LEFT JOIN reservas r ON r.id_livro = l.id_livro
)
SELECT
    total_livros,
    total_exemplares,
    total_leitores,
    total_emprestimos,
    emprestimos_ativos,
    emprestimos_atrasados,
    total_multas,
    multas_pendentes,
    total_reservas,
    ROUND(total_emprestimos / NULLIF(total_leitores, 0), 2) as media_emprestimos_por_leitor,
    ROUND(total_multas / NULLIF(total_emprestimos, 0), 2) as valor_medio_multa,
    ROUND(emprestimos_atrasados / NULLIF(total_emprestimos, 0) * 100, 2) as percentual_atrasos
FROM stats; 