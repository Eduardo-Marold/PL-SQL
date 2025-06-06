-- Script de Criação de Índices e Otimizações Adicionais
-- Autor: Sistema de Gestão de Biblioteca
-- Data: 2024

-- Índices Bitmap para campos de status
CREATE BITMAP INDEX idx_bmp_livro_status ON livros(status);
CREATE BITMAP INDEX idx_bmp_exemplar_status ON exemplares(status);
CREATE BITMAP INDEX idx_bmp_usuario_status ON usuarios(status);
CREATE BITMAP INDEX idx_bmp_emprestimo_status ON emprestimos(status);

-- Índices para busca por texto
CREATE INDEX idx_autor_nome ON autores(UPPER(nome));
CREATE INDEX idx_editora_nome ON editoras(UPPER(nome));
CREATE INDEX idx_livro_isbn ON livros(isbn);
CREATE INDEX idx_exemplar_codbarras ON exemplares(codigo_barras);
CREATE INDEX idx_usuario_cpf ON usuarios(cpf);
CREATE INDEX idx_usuario_email ON usuarios(LOWER(email));

-- Índices para Foreign Keys
CREATE INDEX idx_fk_livro_editora ON livros(id_editora);
CREATE INDEX idx_fk_livro_categoria ON livros(id_categoria);
CREATE INDEX idx_fk_exemplar_livro ON exemplares(id_livro);
CREATE INDEX idx_fk_emprestimo_usuario ON emprestimos(id_usuario);
CREATE INDEX idx_fk_emprestimo_exemplar ON emprestimos(id_exemplar);
CREATE INDEX idx_fk_reserva_usuario ON reservas(id_usuario);
CREATE INDEX idx_fk_reserva_livro ON reservas(id_livro);

-- Índices para campos de data
CREATE INDEX idx_emp_data_prevista ON emprestimos(data_prevista_devolucao);
CREATE INDEX idx_emp_data_devolucao ON emprestimos(data_devolucao);
CREATE INDEX idx_reserva_data ON reservas(data_reserva);
CREATE INDEX idx_reserva_limite ON reservas(data_limite);

-- Materialized Views para relatórios comuns
CREATE MATERIALIZED VIEW mv_livros_disponiveis
REFRESH ON COMMIT AS
SELECT l.id_livro, l.titulo, l.isbn, 
       COUNT(e.id_exemplar) as qtd_disponivel
FROM livros l
JOIN exemplares e ON e.id_livro = l.id_livro
WHERE e.status = 'DISPONIVEL'
GROUP BY l.id_livro, l.titulo, l.isbn;

CREATE MATERIALIZED VIEW mv_emprestimos_ativos
REFRESH ON COMMIT AS
SELECT u.id_usuario, u.nome, l.titulo, 
       e.data_emprestimo, e.data_prevista_devolucao,
       CASE 
           WHEN e.data_prevista_devolucao < SYSDATE THEN 'ATRASADO'
           ELSE 'EM_DIA'
       END as situacao
FROM emprestimos e
JOIN usuarios u ON u.id_usuario = e.id_usuario
JOIN exemplares ex ON ex.id_exemplar = e.id_exemplar
JOIN livros l ON l.id_livro = ex.id_livro
WHERE e.status = 'ATIVO';

CREATE MATERIALIZED VIEW mv_estatisticas_mensais
REFRESH ON DEMAND AS
SELECT TO_CHAR(data_emprestimo, 'YYYY-MM') as mes,
       COUNT(*) as total_emprestimos,
       COUNT(DISTINCT id_usuario) as usuarios_ativos,
       COUNT(DISTINCT id_exemplar) as livros_emprestados,
       SUM(CASE WHEN status = 'ATRASADO' THEN 1 ELSE 0 END) as total_atrasos,
       SUM(multa) as total_multas
FROM emprestimos
GROUP BY TO_CHAR(data_emprestimo, 'YYYY-MM');

-- Índices para as Materialized Views
CREATE INDEX idx_mv_livros_disp_titulo ON mv_livros_disponiveis(UPPER(titulo));
CREATE INDEX idx_mv_emp_ativos_nome ON mv_emprestimos_ativos(UPPER(nome));
CREATE INDEX idx_mv_emp_ativos_data ON mv_emprestimos_ativos(data_prevista_devolucao);

-- Estatísticas
EXEC DBMS_STATS.GATHER_TABLE_STATS('biblioteca', 'livros');
EXEC DBMS_STATS.GATHER_TABLE_STATS('biblioteca', 'exemplares');
EXEC DBMS_STATS.GATHER_TABLE_STATS('biblioteca', 'usuarios');
EXEC DBMS_STATS.GATHER_TABLE_STATS('biblioteca', 'emprestimos');
EXEC DBMS_STATS.GATHER_TABLE_STATS('biblioteca', 'reservas'); 