-- Exemplo de uso dos packages de RH
-- Autor: [Seu Nome]
-- Data: [Data Atual]

-- Configuração inicial
SET SERVEROUTPUT ON;
SET VERIFY OFF;

DECLARE
    -- Variáveis para teste
    v_id_departamento NUMBER;
    v_id_cargo NUMBER;
    v_id_funcionario NUMBER;
    v_id_vaga NUMBER;
    v_cursor SYS_REFCURSOR;
    v_record_dept pkg_analytics_rh.r_indicadores_departamento;
    v_array_indicadores pkg_analytics_rh.t_array_indicadores;
    
BEGIN
    -- 1. Criando um departamento
    INSERT INTO departamentos (nome, descricao, orcamento_anual, centro_custo)
    VALUES ('Tecnologia', 'Departamento de TI', 1000000, 'CC001')
    RETURNING id_departamento INTO v_id_departamento;
    
    -- 2. Criando um cargo
    INSERT INTO cargos (titulo, descricao, nivel, faixa_salarial_min, faixa_salarial_max)
    VALUES ('Desenvolvedor PL/SQL', 'Desenvolvedor PL/SQL Pleno', 'PLENO', 8000, 12000)
    RETURNING id_cargo INTO v_id_cargo;
    
    -- 3. Inserindo um funcionário
    v_id_funcionario := pkg_funcionarios.inserir_funcionario(
        p_nome => 'João Silva',
        p_cpf => '123.456.789-00',
        p_email => 'joao.silva@empresa.com',
        p_id_cargo => v_id_cargo,
        p_id_departamento => v_id_departamento,
        p_salario => 10000
    );
    
    -- 4. Abrindo uma vaga
    v_id_vaga := pkg_recrutamento.abrir_vaga(
        p_titulo => 'Desenvolvedor PL/SQL Pleno',
        p_id_departamento => v_id_departamento,
        p_id_cargo => v_id_cargo,
        p_descricao => 'Vaga para desenvolvedor PL/SQL com experiência em desenvolvimento de sistemas',
        p_requisitos => 'Oracle, PL/SQL, SQL, Desenvolvimento de Packages, Performance Tuning',
        p_faixa_salarial_min => 8000,
        p_faixa_salarial_max => 12000,
        p_responsavel_id => v_id_funcionario
    );
    
    -- 5. Registrando uma candidatura
    pkg_recrutamento.registrar_candidatura(
        p_id_vaga => v_id_vaga,
        p_nome_candidato => 'Maria Santos',
        p_email => 'maria.santos@email.com',
        p_telefone => '(11) 98765-4321',
        p_curriculo => 'Experiência com Oracle, PL/SQL, SQL, Desenvolvimento de Packages...',
        p_pretensao_salarial => 9500
    );
    
    -- 6. Avaliando aderência do candidato
    DBMS_OUTPUT.PUT_LINE('Score de aderência: ' || 
        pkg_recrutamento.avaliar_aderencia_candidato(
            p_id_vaga => v_id_vaga,
            p_email_candidato => 'maria.santos@email.com'
        )
    );
    
    -- 7. Atualizando status da candidatura
    pkg_recrutamento.atualizar_status_candidatura(
        p_id_vaga => v_id_vaga,
        p_email_candidato => 'maria.santos@email.com',
        p_novo_status => 'ENTREVISTA',
        p_observacoes => 'Candidata aprovada na triagem inicial'
    );
    
    -- 8. Registrando avaliação de desempenho do funcionário
    pkg_funcionarios.registrar_avaliacao(
        p_id_funcionario => v_id_funcionario,
        p_avaliador_id => v_id_funcionario, -- Auto-avaliação neste exemplo
        p_nota => 9.5,
        p_pontos_fortes => 'Excelente conhecimento técnico e proatividade',
        p_pontos_melhoria => 'Pode melhorar em documentação',
        p_metas => 'Implementar novo sistema de análise de dados'
    );
    
    -- 9. Obtendo relatório de headcount
    v_cursor := pkg_analytics_rh.relatorio_tempo_preenchimento(
        p_id_departamento => v_id_departamento
    );
    
    -- 10. Obtendo dashboard de indicadores
    v_array_indicadores := pkg_analytics_rh.dashboard_indicadores_rh(SYSDATE);
    
    -- 11. Calculando turnover
    DBMS_OUTPUT.PUT_LINE('Taxa de turnover: ' || 
        pkg_funcionarios.relatorio_turnover(EXTRACT(YEAR FROM SYSDATE))
    );
    
    -- 12. Registrando promoção
    pkg_funcionarios.registrar_promocao(
        p_id_funcionario => v_id_funcionario,
        p_novo_cargo => v_id_cargo,
        p_novo_salario => 11000,
        p_observacoes => 'Promoção por mérito'
    );
    
    -- 13. Analisando distribuição salarial
    v_cursor := pkg_analytics_rh.analisar_distribuicao_salarial(
        p_id_cargo => v_id_cargo
    );
    
    -- 14. Calculando ROI de treinamentos
    DBMS_OUTPUT.PUT_LINE('ROI de treinamentos: ' || 
        pkg_analytics_rh.calcular_roi_treinamentos(
            p_id_departamento => v_id_departamento
        )
    );
    
    COMMIT;
    
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
/ 