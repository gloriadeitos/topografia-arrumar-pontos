/*
CORREÇÃO DE BASES DUPLICADAS
ESSE CÓDIGO PEGA VÁRIOS PONTOS E TRANSFORMA EM 1 PONTO COM OCUPAÇÕES

COMO EXECUTAR NO DBEAVER:

1. Desative o Auto-commit.
2. Nas opções de execução de script, deixe "Commit type" como "No commit".
3. Selecione TODO este código.
4. Clique no botão "Execute SQL Script".
5. Não execute linha por linha com Ctrl + Enter.
6. Não remova o BEGIN TRANSACTION.

O DBEAVER MOSTRARÁ:

1º resultado:
Situação antes da correção.

Mensagens:
Base mantida, bases convertidas e quantidades alteradas.

2º resultado:
Situação depois da correção.

Statistics:
Apenas informações do DBeaver sobre a execução.

ALTERE SOMENTE OS DOIS VALORES ABAIXO:
'1332' = número do projeto
'MR43' = nome do ponto

OBS:Para trocar de projeto e ponto, substitua todas as 3 ocorrências de '1332' e todas as 3 ocorrências de 'MR43'. Use Ctrl + H para substituir tudo.
*/

BEGIN TRANSACTION;


/*
INFORME AQUI O PROJETO E O PONTO.

Você só precisa alterar estas duas linhas.
*/
SET LOCAL correcao.projeto = '1332';
SET LOCAL correcao.ponto = 'MR43';


/*
ANTES DA CORREÇÃO

Mostra:

ordem 1:
Base mais antiga que será mantida.

ordem maior que 1:
Bases duplicadas que serão convertidas em ocupações
da base mais antiga.

A ocupação já existe. O código apenas altera seu
parentglobalid para o globalid da base mais antiga.
*/
WITH bases_ordenadas AS (
    SELECT
        b.objectid,
        b.globalid,
        b.projeto,
        b.nome_ponto,
        b.created_date,
        ROW_NUMBER() OVER (
            ORDER BY
                b.created_date ASC NULLS LAST,
                b.objectid ASC
        ) AS ordem,
        FIRST_VALUE(b.globalid) OVER (
            ORDER BY
                b.created_date ASC NULLS LAST,
                b.objectid ASC
        ) AS globalid_base_mantida
    FROM hsu_9qqz5.service_19276d4d553c4a94bebf9facd_levantamentobases AS b
    WHERE UPPER(TRIM(b.projeto)) =
          UPPER(TRIM(current_setting('correcao.projeto')))
      AND UPPER(TRIM(b.nome_ponto)) =
          UPPER(TRIM(current_setting('correcao.ponto')))
)
SELECT
    b.ordem,
    b.objectid AS base_objectid,
    b.globalid AS base_globalid,
    b.projeto,
    b.nome_ponto,
    b.globalid_base_mantida,
    o.objectid AS ocupacao_objectid,
    o.globalid AS ocupacao_globalid,
    o.parentglobalid AS parentglobalid_atual,
    CASE
        WHEN b.ordem = 1
            THEN 'MANTER ESTA BASE'

        WHEN o.objectid IS NULL
            THEN 'ERRO: BASE DUPLICADA SEM OCUPACAO'

        ELSE
            'CONVERTER ESTA BASE EM OCUPACAO DA BASE MAIS ANTIGA'
    END AS acao
FROM bases_ordenadas AS b
LEFT JOIN hsu_9qqz5.service_19276d4d553c4a94bebf9facdbebb5b6_ocupacoes AS o
    ON o.parentglobalid = b.globalid
ORDER BY
    b.ordem,
    o.objectid;


/*
FAZ A CORREÇÃO

1. Localiza a base mais antiga.
2. Confere se todas as bases duplicadas possuem ocupação.
3. Altera o parentglobalid das ocupações.
4. Liga todas as ocupações à base mais antiga.
5. Exclui somente os registros duplicados da tabela de bases.

As ocupações não são copiadas nem excluídas.

O globalid das ocupações continua igual.
Por isso, as fotos continuam ligadas corretamente.
*/
DO $correcao$
DECLARE
    v_projeto TEXT :=
        current_setting('correcao.projeto');

    v_ponto TEXT :=
        current_setting('correcao.ponto');

    v_base_mantida_objectid INTEGER;
    v_base_mantida_globalid TEXT;
    v_base_mantida_nome TEXT;
    v_base_mantida_projeto TEXT;

    v_quantidade_bases BIGINT;
    v_bases_sem_ocupacao BIGINT;
    v_ocupacoes_esperadas BIGINT;
    v_ocupacoes_movidas BIGINT;
    v_bases_excluidas BIGINT;

    v_lista_bases_convertidas TEXT;
BEGIN

    /*
    Conta quantas bases existem para o projeto e ponto.
    */
    SELECT COUNT(*)
    INTO v_quantidade_bases
    FROM hsu_9qqz5.service_19276d4d553c4a94bebf9facd_levantamentobases AS b
    WHERE UPPER(TRIM(b.projeto)) = UPPER(TRIM(v_projeto))
      AND UPPER(TRIM(b.nome_ponto)) = UPPER(TRIM(v_ponto));


    /*
    Para se houver apenas uma base ou nenhuma.
    */
    IF v_quantidade_bases < 2 THEN
        RAISE EXCEPTION
            'Não existem bases duplicadas para o projeto % e ponto %.',
            v_projeto,
            v_ponto;
    END IF;


    /*
    Localiza a base mais antiga.

    Se as datas forem iguais, mantém a que possuir
    o menor ObjectID.
    */
    SELECT
        b.objectid,
        b.globalid,
        b.nome_ponto,
        b.projeto
    INTO
        v_base_mantida_objectid,
        v_base_mantida_globalid,
        v_base_mantida_nome,
        v_base_mantida_projeto
    FROM hsu_9qqz5.service_19276d4d553c4a94bebf9facd_levantamentobases AS b
    WHERE UPPER(TRIM(b.projeto)) = UPPER(TRIM(v_projeto))
      AND UPPER(TRIM(b.nome_ponto)) = UPPER(TRIM(v_ponto))
    ORDER BY
        b.created_date ASC NULLS LAST,
        b.objectid ASC
    LIMIT 1;


    /*
    Impede a correção caso a base mantida não tenha GlobalID.
    */
    IF v_base_mantida_globalid IS NULL THEN
        RAISE EXCEPTION
            'A base mais antiga não possui GlobalID. Nada foi alterado.';
    END IF;


    /*
    Confere se alguma base duplicada está sem ocupação.

    Se existir, o código para antes de alterar qualquer dado.
    */
    SELECT COUNT(*)
    INTO v_bases_sem_ocupacao
    FROM hsu_9qqz5.service_19276d4d553c4a94bebf9facd_levantamentobases AS b
    WHERE UPPER(TRIM(b.projeto)) = UPPER(TRIM(v_projeto))
      AND UPPER(TRIM(b.nome_ponto)) = UPPER(TRIM(v_ponto))
      AND b.objectid <> v_base_mantida_objectid
      AND NOT EXISTS (
          SELECT 1
          FROM hsu_9qqz5.service_19276d4d553c4a94bebf9facdbebb5b6_ocupacoes AS o
          WHERE o.parentglobalid = b.globalid
      );


    IF v_bases_sem_ocupacao > 0 THEN
        RAISE EXCEPTION
            'Existem % bases duplicadas sem ocupação. Nada foi alterado.',
            v_bases_sem_ocupacao;
    END IF;


    /*
    Conta quantas ocupações deverão ser vinculadas
    à base mais antiga.
    */
    SELECT COUNT(*)
    INTO v_ocupacoes_esperadas
    FROM hsu_9qqz5.service_19276d4d553c4a94bebf9facdbebb5b6_ocupacoes AS o
    INNER JOIN hsu_9qqz5.service_19276d4d553c4a94bebf9facd_levantamentobases AS b
        ON o.parentglobalid = b.globalid
    WHERE UPPER(TRIM(b.projeto)) = UPPER(TRIM(v_projeto))
      AND UPPER(TRIM(b.nome_ponto)) = UPPER(TRIM(v_ponto))
      AND b.objectid <> v_base_mantida_objectid;


    /*
    Monta a lista das bases duplicadas.

    Essa lista será mostrada nas mensagens do DBeaver.
    */
    SELECT STRING_AGG(
        FORMAT(
            'Nome: %s | Projeto: %s | ObjectID: %s | GlobalID: %s',
            b.nome_ponto,
            b.projeto,
            b.objectid,
            b.globalid
        ),
        E'\n'
        ORDER BY
            b.created_date ASC NULLS LAST,
            b.objectid ASC
    )
    INTO v_lista_bases_convertidas
    FROM hsu_9qqz5.service_19276d4d553c4a94bebf9facd_levantamentobases AS b
    WHERE UPPER(TRIM(b.projeto)) = UPPER(TRIM(v_projeto))
      AND UPPER(TRIM(b.nome_ponto)) = UPPER(TRIM(v_ponto))
      AND b.objectid <> v_base_mantida_objectid;


    /*
    Converte as bases duplicadas em ocupações da base mantida.

    Isso é feito alterando o parentglobalid das ocupações
    para o globalid da base mais antiga.
    */
    UPDATE hsu_9qqz5.service_19276d4d553c4a94bebf9facdbebb5b6_ocupacoes AS o
    SET parentglobalid = v_base_mantida_globalid
    WHERE o.parentglobalid IN (
        SELECT b.globalid
        FROM hsu_9qqz5.service_19276d4d553c4a94bebf9facd_levantamentobases AS b
        WHERE UPPER(TRIM(b.projeto)) = UPPER(TRIM(v_projeto))
          AND UPPER(TRIM(b.nome_ponto)) = UPPER(TRIM(v_ponto))
          AND b.objectid <> v_base_mantida_objectid
    );

    GET DIAGNOSTICS v_ocupacoes_movidas = ROW_COUNT;


    /*
    Confere se todas as ocupações esperadas foram alteradas.
    */
    IF v_ocupacoes_movidas <> v_ocupacoes_esperadas THEN
        RAISE EXCEPTION
            'Era esperado mover % ocupações, mas foram movidas %. Nada será salvo.',
            v_ocupacoes_esperadas,
            v_ocupacoes_movidas;
    END IF;


    /*
    Exclui somente os registros duplicados da tabela de bases.

    As ocupações dessas bases já foram ligadas
    à base mais antiga.
    */
    DELETE
    FROM hsu_9qqz5.service_19276d4d553c4a94bebf9facd_levantamentobases AS b
    WHERE UPPER(TRIM(b.projeto)) = UPPER(TRIM(v_projeto))
      AND UPPER(TRIM(b.nome_ponto)) = UPPER(TRIM(v_ponto))
      AND b.objectid <> v_base_mantida_objectid;

    GET DIAGNOSTICS v_bases_excluidas = ROW_COUNT;


    /*
    Confere se todas as bases duplicadas foram excluídas.
    */
    IF v_bases_excluidas <> v_quantidade_bases - 1 THEN
        RAISE EXCEPTION
            'Era esperado excluir % bases duplicadas, mas foram excluídas %. Nada será salvo.',
            v_quantidade_bases - 1,
            v_bases_excluidas;
    END IF;


    /*
    Mensagem mostrada no painel de saída do DBeaver.
    */
    RAISE NOTICE E'
CORREÇÃO EXECUTADA NESTA TRANSAÇÃO

BASE MANTIDA, PARA ONDE AS OCUPAÇÕES FORAM VINCULADAS:

Nome: %
Projeto: %
ObjectID: %
GlobalID: %

BASES DUPLICADAS CONVERTIDAS EM OCUPAÇÕES DA BASE MANTIDA:

%

Total de ocupações vinculadas à base mantida: %
Total de bases duplicadas convertidas: %
',
        v_base_mantida_nome,
        v_base_mantida_projeto,
        v_base_mantida_objectid,
        v_base_mantida_globalid,
        v_lista_bases_convertidas,
        v_ocupacoes_movidas,
        v_bases_excluidas;

END
$correcao$;


/*
DEPOIS DA CORREÇÃO

Deve mostrar:

1. Somente uma base.
2. Todas as ocupações ligadas ao GlobalID dessa base.
3. As fotos ainda ligadas às respectivas ocupações.
*/
SELECT
    b.objectid AS base_objectid,
    b.globalid AS base_globalid,
    b.projeto,
    b.nome_ponto,

    o.objectid AS ocupacao_objectid,
    o.globalid AS ocupacao_globalid,
    o.parentglobalid,

    (
        SELECT COUNT(*)
        FROM hsu_9qqz5.service_19276d4d553c4a94bebf9facdbebb5b_r_foto_pano AS f
        WHERE f.parentglobalid = o.globalid
    ) AS fotos_pano,

    (
        SELECT COUNT(*)
        FROM hsu_9qqz5.service_19276d4d553c4a94bebf9facdbebb5_r_foto_bolha AS f
        WHERE f.parentglobalid = o.globalid
    ) AS fotos_bolha,

    (
        SELECT COUNT(*)
        FROM hsu_9qqz5.service_19276d4d553c4a94bebf9facdbebb_r_foto_altura AS f
        WHERE f.parentglobalid = o.globalid
    ) AS fotos_altura,

    (
        SELECT COUNT(*)
        FROM hsu_9qqz5.service_19276d4d553c4a94bebf9facdbebb_r_foto_croqui AS f
        WHERE f.parentglobalid = o.globalid
    ) AS fotos_croqui

FROM hsu_9qqz5.service_19276d4d553c4a94bebf9facd_levantamentobases AS b

LEFT JOIN hsu_9qqz5.service_19276d4d553c4a94bebf9facdbebb5b6_ocupacoes AS o
    ON o.parentglobalid = b.globalid

WHERE UPPER(TRIM(b.projeto)) =
      UPPER(TRIM(current_setting('correcao.projeto')))

  AND UPPER(TRIM(b.nome_ponto)) =
      UPPER(TRIM(current_setting('correcao.ponto')))

ORDER BY
    b.created_date,
    b.objectid,
    o.created_date,
    o.objectid;


/*
NÃO REMOVA O BEGIN TRANSACTION DO INÍCIO.

Quer apenas testar e desfazer tudo?
Deixe ROLLBACK abaixo.

Quer alterar o banco de verdade?
Troque somente a palavra ROLLBACK logo abaixo, por COMMIT.
*/

ROLLBACK;
