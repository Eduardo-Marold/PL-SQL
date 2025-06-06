-- Package de Gestão de Usuários
-- Autor: Sistema de Gestão de Biblioteca
-- Data: 2024

CREATE OR REPLACE PACKAGE pkg_usuarios AS
    -- Tipos
    TYPE t_usuario_info IS RECORD (
        id_usuario NUMBER,
        nome VARCHAR2(100),
        email VARCHAR2(100),
        tipo_usuario VARCHAR2(20),
        status VARCHAR2(20),
        qtd_emprestimos_ativos NUMBER,
        tem_multas_pendentes BOOLEAN
    );
    
    TYPE t_array_usuarios IS TABLE OF t_usuario_info;
    
    -- Funções e Procedures
    FUNCTION cadastrar_usuario(
        p_nome IN VARCHAR2,
        p_cpf IN VARCHAR2,
        p_email IN VARCHAR2,
        p_telefone IN VARCHAR2,
        p_endereco IN VARCHAR2,
        p_data_nascimento IN DATE,
        p_tipo_usuario IN VARCHAR2,
        p_senha IN VARCHAR2,
        p_foto IN BLOB DEFAULT NULL
    ) RETURN NUMBER;
    
    PROCEDURE alterar_senha(
        p_id_usuario IN NUMBER,
        p_senha_atual IN VARCHAR2,
        p_nova_senha IN VARCHAR2
    );
    
    PROCEDURE atualizar_status(
        p_id_usuario IN NUMBER,
        p_novo_status IN VARCHAR2,
        p_motivo IN VARCHAR2
    );
    
    FUNCTION autenticar_usuario(
        p_email IN VARCHAR2,
        p_senha IN VARCHAR2
    ) RETURN NUMBER;
    
    FUNCTION buscar_usuario(
        p_id_usuario IN NUMBER
    ) RETURN t_usuario_info;
    
    FUNCTION listar_usuarios_ativos
    RETURN t_array_usuarios PIPELINED;
    
    FUNCTION listar_usuarios_bloqueados
    RETURN t_array_usuarios PIPELINED;
    
    FUNCTION verificar_multas_pendentes(
        p_id_usuario IN NUMBER
    ) RETURN BOOLEAN;
    
    -- Exceptions
    usuario_ja_existe EXCEPTION;
    usuario_nao_encontrado EXCEPTION;
    senha_invalida EXCEPTION;
    status_invalido EXCEPTION;
    
    PRAGMA EXCEPTION_INIT(usuario_ja_existe, -20201);
    PRAGMA EXCEPTION_INIT(usuario_nao_encontrado, -20202);
    PRAGMA EXCEPTION_INIT(senha_invalida, -20203);
    PRAGMA EXCEPTION_INIT(status_invalido, -20204);
END pkg_usuarios;
/

CREATE OR REPLACE PACKAGE BODY pkg_usuarios AS
    -- Funções privadas
    FUNCTION hash_senha(p_senha IN VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        -- Em produção, usar função de hash segura
        RETURN DBMS_CRYPTO.HASH(
            UTL_RAW.CAST_TO_RAW(p_senha),
            DBMS_CRYPTO.HASH_SH256
        );
    END hash_senha;
    
    -- Implementação das funções e procedures públicas
    FUNCTION cadastrar_usuario(
        p_nome IN VARCHAR2,
        p_cpf IN VARCHAR2,
        p_email IN VARCHAR2,
        p_telefone IN VARCHAR2,
        p_endereco IN VARCHAR2,
        p_data_nascimento IN DATE,
        p_tipo_usuario IN VARCHAR2,
        p_senha IN VARCHAR2,
        p_foto IN BLOB DEFAULT NULL
    ) RETURN NUMBER IS
        v_id_usuario NUMBER;
        v_existe NUMBER;
    BEGIN
        -- Verifica se CPF ou email já existem
        SELECT COUNT(*)
        INTO v_existe
        FROM usuarios
        WHERE cpf = p_cpf OR email = p_email;
        
        IF v_existe > 0 THEN
            RAISE usuario_ja_existe;
        END IF;
        
        -- Insere novo usuário
        INSERT INTO usuarios (
            nome, cpf, email, telefone,
            endereco, data_nascimento, tipo_usuario,
            senha, foto
        ) VALUES (
            p_nome, p_cpf, p_email, p_telefone,
            p_endereco, p_data_nascimento, p_tipo_usuario,
            hash_senha(p_senha), p_foto
        ) RETURNING id_usuario INTO v_id_usuario;
        
        RETURN v_id_usuario;
    EXCEPTION
        WHEN usuario_ja_existe THEN
            RAISE_APPLICATION_ERROR(-20201, 'CPF ou email já cadastrado');
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20200, 'Erro ao cadastrar usuário: ' || SQLERRM);
    END cadastrar_usuario;
    
    PROCEDURE alterar_senha(
        p_id_usuario IN NUMBER,
        p_senha_atual IN VARCHAR2,
        p_nova_senha IN VARCHAR2
    ) IS
        v_senha_atual VARCHAR2(64);
    BEGIN
        -- Verifica senha atual
        SELECT senha
        INTO v_senha_atual
        FROM usuarios
        WHERE id_usuario = p_id_usuario;
        
        IF v_senha_atual != hash_senha(p_senha_atual) THEN
            RAISE senha_invalida;
        END IF;
        
        -- Atualiza senha
        UPDATE usuarios SET
            senha = hash_senha(p_nova_senha)
        WHERE id_usuario = p_id_usuario;
        
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20202, 'Usuário não encontrado');
        WHEN senha_invalida THEN
            RAISE_APPLICATION_ERROR(-20203, 'Senha atual incorreta');
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20200, 'Erro ao alterar senha: ' || SQLERRM);
    END alterar_senha;
    
    PROCEDURE atualizar_status(
        p_id_usuario IN NUMBER,
        p_novo_status IN VARCHAR2,
        p_motivo IN VARCHAR2
    ) IS
    BEGIN
        UPDATE usuarios SET
            status = p_novo_status
        WHERE id_usuario = p_id_usuario;
        
        IF SQL%NOTFOUND THEN
            RAISE usuario_nao_encontrado;
        END IF;
        
        -- Registra alteração de status (poderia ser em uma tabela de auditoria)
        NULL;
        
    EXCEPTION
        WHEN usuario_nao_encontrado THEN
            RAISE_APPLICATION_ERROR(-20202, 'Usuário não encontrado');
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20200, 'Erro ao atualizar status: ' || SQLERRM);
    END atualizar_status;
    
    FUNCTION autenticar_usuario(
        p_email IN VARCHAR2,
        p_senha IN VARCHAR2
    ) RETURN NUMBER IS
        v_id_usuario NUMBER;
        v_senha_hash VARCHAR2(64);
        v_status VARCHAR2(20);
    BEGIN
        SELECT id_usuario, senha, status
        INTO v_id_usuario, v_senha_hash, v_status
        FROM usuarios
        WHERE email = p_email;
        
        IF v_senha_hash != hash_senha(p_senha) THEN
            RAISE senha_invalida;
        END IF;
        
        IF v_status != 'ATIVO' THEN
            RAISE status_invalido;
        END IF;
        
        RETURN v_id_usuario;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20202, 'Usuário não encontrado');
        WHEN senha_invalida THEN
            RAISE_APPLICATION_ERROR(-20203, 'Senha incorreta');
        WHEN status_invalido THEN
            RAISE_APPLICATION_ERROR(-20204, 'Usuário bloqueado ou inativo');
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20200, 'Erro na autenticação: ' || SQLERRM);
    END autenticar_usuario;
    
    FUNCTION buscar_usuario(
        p_id_usuario IN NUMBER
    ) RETURN t_usuario_info IS
        v_usuario t_usuario_info;
    BEGIN
        SELECT u.id_usuario, u.nome, u.email,
               u.tipo_usuario, u.status,
               COUNT(CASE WHEN e.status = 'ATIVO' THEN 1 END) as qtd_emprestimos,
               CASE WHEN EXISTS (
                   SELECT 1 FROM historico_multas hm
                   JOIN emprestimos emp ON emp.id_emprestimo = hm.id_emprestimo
                   WHERE emp.id_usuario = u.id_usuario
                   AND hm.status = 'PENDENTE'
               ) THEN TRUE ELSE FALSE END as tem_multas
        INTO v_usuario.id_usuario, v_usuario.nome, v_usuario.email,
             v_usuario.tipo_usuario, v_usuario.status,
             v_usuario.qtd_emprestimos_ativos, v_usuario.tem_multas_pendentes
        FROM usuarios u
        LEFT JOIN emprestimos e ON e.id_usuario = u.id_usuario
        WHERE u.id_usuario = p_id_usuario
        GROUP BY u.id_usuario, u.nome, u.email, u.tipo_usuario, u.status;
        
        RETURN v_usuario;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE usuario_nao_encontrado;
    END buscar_usuario;
    
    FUNCTION listar_usuarios_ativos
    RETURN t_array_usuarios PIPELINED IS
        v_usuario t_usuario_info;
    BEGIN
        FOR r IN (
            SELECT u.id_usuario, u.nome, u.email,
                   u.tipo_usuario, u.status,
                   COUNT(CASE WHEN e.status = 'ATIVO' THEN 1 END) as qtd_emprestimos,
                   CASE WHEN EXISTS (
                       SELECT 1 FROM historico_multas hm
                       JOIN emprestimos emp ON emp.id_emprestimo = hm.id_emprestimo
                       WHERE emp.id_usuario = u.id_usuario
                       AND hm.status = 'PENDENTE'
                   ) THEN TRUE ELSE FALSE END as tem_multas
            FROM usuarios u
            LEFT JOIN emprestimos e ON e.id_usuario = u.id_usuario
            WHERE u.status = 'ATIVO'
            GROUP BY u.id_usuario, u.nome, u.email, u.tipo_usuario, u.status
            ORDER BY u.nome
        ) LOOP
            v_usuario.id_usuario := r.id_usuario;
            v_usuario.nome := r.nome;
            v_usuario.email := r.email;
            v_usuario.tipo_usuario := r.tipo_usuario;
            v_usuario.status := r.status;
            v_usuario.qtd_emprestimos_ativos := r.qtd_emprestimos;
            v_usuario.tem_multas_pendentes := r.tem_multas;
            PIPE ROW(v_usuario);
        END LOOP;
        RETURN;
    END listar_usuarios_ativos;
    
    FUNCTION listar_usuarios_bloqueados
    RETURN t_array_usuarios PIPELINED IS
        v_usuario t_usuario_info;
    BEGIN
        FOR r IN (
            SELECT u.id_usuario, u.nome, u.email,
                   u.tipo_usuario, u.status,
                   COUNT(CASE WHEN e.status = 'ATIVO' THEN 1 END) as qtd_emprestimos,
                   CASE WHEN EXISTS (
                       SELECT 1 FROM historico_multas hm
                       JOIN emprestimos emp ON emp.id_emprestimo = hm.id_emprestimo
                       WHERE emp.id_usuario = u.id_usuario
                       AND hm.status = 'PENDENTE'
                   ) THEN TRUE ELSE FALSE END as tem_multas
            FROM usuarios u
            LEFT JOIN emprestimos e ON e.id_usuario = u.id_usuario
            WHERE u.status = 'SUSPENSO'
            GROUP BY u.id_usuario, u.nome, u.email, u.tipo_usuario, u.status
            ORDER BY u.nome
        ) LOOP
            v_usuario.id_usuario := r.id_usuario;
            v_usuario.nome := r.nome;
            v_usuario.email := r.email;
            v_usuario.tipo_usuario := r.tipo_usuario;
            v_usuario.status := r.status;
            v_usuario.qtd_emprestimos_ativos := r.qtd_emprestimos;
            v_usuario.tem_multas_pendentes := r.tem_multas;
            PIPE ROW(v_usuario);
        END LOOP;
        RETURN;
    END listar_usuarios_bloqueados;
    
    FUNCTION verificar_multas_pendentes(
        p_id_usuario IN NUMBER
    ) RETURN BOOLEAN IS
        v_tem_multas BOOLEAN;
    BEGIN
        SELECT CASE WHEN EXISTS (
            SELECT 1
            FROM historico_multas hm
            JOIN emprestimos e ON e.id_emprestimo = hm.id_emprestimo
            WHERE e.id_usuario = p_id_usuario
            AND hm.status = 'PENDENTE'
        ) THEN TRUE ELSE FALSE END
        INTO v_tem_multas
        FROM dual;
        
        RETURN v_tem_multas;
    END verificar_multas_pendentes;
    
END pkg_usuarios;
/ 