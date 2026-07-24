/*
CORREÇÃO DE BASES DUPLICADAS - VARIOS PONTOS E VARIOS PROJETOS

Este código:

1. Encontra todas as bases cujos projetos estejam na lista informada.
2. Encontra todas as bases cujos nomes estejam na lista informada.
3. Mantém a base mais antiga.
4. Transforma as outras bases em ocupações da base mantida.
5. Remove registros físicos repetidos com o mesmo GlobalID.
6. Corrige o projeto e o nome da base mantida.
7. Mantém as fotos ligadas às ocupações.

FUNCIONA COM:

Um projeto:
'1333'

Vários projetos:
'1333,1333 2,133 Projeto tal'

Um ponto:
'MR 24'

Vários pontos:
'MR 24,MR24,MR-24'

Os valores são separados somente pela vírgula.
Os espaços dentro dos nomes são mantidos normalmente.

COMO EXECUTAR NO DBEAVER:

1. Selecione TODO o código.
2. Clique em "Execute SQL Script".
3. Não execute linha por linha.
4. Para testar, mantenha ROLLBACK no final.
5. Para salvar, troque somente ROLLBACK por COMMIT.
*/

BEGIN TRANSACTION;


/*
ALTERE SOMENTE ESTAS QUATRO LINHAS.

Inclua nas listas tanto os valores corretos quanto os errados.
*/

SET LOCAL correcao.projetos_origem = '1333,1333 2,133 Projeto tal';
SET LOCAL correcao.pontos_origem = 'MR 24,MR24,MR-24';

SET LOCAL correcao.projeto_correto = '1333';
SET LOCAL correcao.ponto_correto = 'MR 24';


/*
ANTES DA CORREÇÃO

Mostra todas as linhas encontradas.

A primeira linha será mantida.

Registros com outro GlobalID serão convertidos em ocupações.

Registros repetidos com o mesmo GlobalID serão removidos,
mantendo apenas uma linha física.
*/
WITH bases_encontradas AS (
    SELECT
        b.ctid,
        b.objectid,
        b.globalid,
        b.projeto,
        b.nome_ponto,
        b.created_date,

        FIRST_VALUE(b.ctid) OVER (
            ORDER BY
                b.created_date ASC NULLS LAST,
                b.objectid ASC,
                b.ctid::TEXT ASC
        ) AS ctid_base_mantida,

        FIRST_VALUE(b.globalid) OVER (
            ORDER BY
                b.created_date ASC NULLS LAST,
                b.objectid ASC,
                b.ctid::TEXT ASC
        ) AS globalid_base_mantida

    FROM hsu_9qqz5.service_19276d4d553c4a94bebf9facd_levantamentobases AS b

    WHERE EXISTS (
        SELECT 1
        FROM unnest(
            regexp_split_to_array(
                current_setting('correcao.projetos_origem'),
                '\s*,\s*'
            )
        ) AS p(valor)
        WHERE UPPER(TRIM(b.projeto)) = UPPER(TRIM(p.valor))
    )

    AND EXISTS (
        SELECT 1
        FROM unnest(
            regexp_split_to_array(
                current_setting('correcao.pontos_origem'),
                '\s*,\s*'
            )
        ) AS n(valor)
        WHERE UPPER(TRIM(b.nome_ponto)) = UPPER(TRIM(n.valor))
    )
)

SELECT
    b.ctid,
    b.objectid AS base_objectid,
    b.globalid AS base_globalid,
    b.projeto AS projeto_atual,
    b.nome_ponto AS ponto_atual,
    b.created_date,

    o.objectid AS ocupacao_objectid,
    o.globalid AS ocupacao_globalid,
    o.parentglobalid,

    CASE
        WHEN b.ctid = b.ctid_base_mantida
            THEN 'MANTER ESTA BASE'

        WHEN b.globalid = b.globalid_base_mantida
            THEN 'REMOVER REGISTRO FISICO REPETIDO'

        WHEN o.objectid IS NULL
            THEN 'ERRO: BASE SEM OCUPACAO'

        ELSE
            'CONVERTER EM OCUPACAO DA BASE MANTIDA'
    END AS acao

FROM bases_encontradas AS b

LEFT JOIN hsu_9qqz5.service_19276d4d553c4a94bebf9facdbebb5b6_ocupacoes AS o
    ON o.parentglobalid = b.globalid

ORDER BY
    b.created_date ASC NULLS LAST,
    b.objectid,
    b.ctid::TEXT,
    o.objectid;


/*
FAZ A CORREÇÃO
*/
DO $correcao$
DECLARE
    v_projetos_origem TEXT[] :=
        regexp_split_to_array(
            current_setting('correcao.projetos_origem'),
            '\s*,\s*'
        );

    v_pontos_origem TEXT[] :=
        regexp_split_to_array(
            current_setting('correcao.pontos_origem'),
            '\s*,\s*'
        );

    v_projeto_correto TEXT :=
        current_setting('correcao.projeto_correto');

    v_ponto_correto TEXT :=
        current_setting('correcao.ponto_correto');

    v_base_mantida_ctid TID;
    v_base_mantida_objectid INTEGER;
    v_base_mantida_globalid TEXT;

    v_quantidade_linhas BIGINT;
    v_quantidade_globalids BIGINT;
    v_bases_sem_globalid BIGINT;
    v_bases_sem_ocupacao BIGINT;

    v_ocupacoes_esperadas BIGINT;
    v_ocupacoes_movidas BIGINT;

    v_linhas_excluir_esperadas BIGINT;
    v_linhas_excluidas BIGINT;

    v_lista_bases_convertidas TEXT;
BEGIN

    /*
    Conta as linhas físicas e os GlobalIDs diferentes.
    */
    SELECT
        COUNT(*),
        COUNT(DISTINCT b.globalid),
        COUNT(*) FILTER (WHERE b.globalid IS NULL)

    INTO
        v_quantidade_linhas,
        v_quantidade_globalids,
        v_bases_sem_globalid

    FROM hsu_9qqz5.service_19276d4d553c4a94bebf9facd_levantamentobases AS b

    WHERE EXISTS (
        SELECT 1
        FROM unnest(v_projetos_origem) AS p(valor)
        WHERE UPPER(TRIM(b.projeto)) = UPPER(TRIM(p.valor))
    )

    AND EXISTS (
        SELECT 1
        FROM unnest(v_pontos_origem) AS n(valor)
        WHERE UPPER(TRIM(b.nome_ponto)) = UPPER(TRIM(n.valor))
    );


    IF v_quantidade_linhas = 0 THEN
        RAISE EXCEPTION
            'Nenhuma base foi encontrada. Nada foi alterado.';
    END IF;


    IF v_bases_sem_globalid > 0 THEN
        RAISE EXCEPTION
            'Existem % bases sem GlobalID. Nada foi alterado.',
            v_bases_sem_globalid;
    END IF;


    /*
    Mantém a linha física mais antiga.

    Se as datas forem iguais:
    1. mantém o menor ObjectID;
    2. depois utiliza o ctid apenas para desempate.
    */
    SELECT
        b.ctid,
        b.objectid,
        b.globalid

    INTO
        v_base_mantida_ctid,
        v_base_mantida_objectid,
        v_base_mantida_globalid

    FROM hsu_9qqz5.service_19276d4d553c4a94bebf9facd_levantamentobases AS b

    WHERE EXISTS (
        SELECT 1
        FROM unnest(v_projetos_origem) AS p(valor)
        WHERE UPPER(TRIM(b.projeto)) = UPPER(TRIM(p.valor))
    )

    AND EXISTS (
        SELECT 1
        FROM unnest(v_pontos_origem) AS n(valor)
        WHERE UPPER(TRIM(b.nome_ponto)) = UPPER(TRIM(n.valor))
    )

    ORDER BY
        b.created_date ASC NULLS LAST,
        b.objectid ASC,
        b.ctid::TEXT ASC

    LIMIT 1;


    /*
    Verifica se algum GlobalID que será convertido
    não possui ocupação.

    Cada GlobalID é contado somente uma vez.
    */
    SELECT COUNT(*)
    INTO v_bases_sem_ocupacao

    FROM (
        SELECT DISTINCT
            b.globalid

        FROM hsu_9qqz5.service_19276d4d553c4a94bebf9facd_levantamentobases AS b

        WHERE EXISTS (
            SELECT 1
            FROM unnest(v_projetos_origem) AS p(valor)
            WHERE UPPER(TRIM(b.projeto)) = UPPER(TRIM(p.valor))
        )

        AND EXISTS (
            SELECT 1
            FROM unnest(v_pontos_origem) AS n(valor)
            WHERE UPPER(TRIM(b.nome_ponto)) = UPPER(TRIM(n.valor))
        )

        AND b.globalid <> v_base_mantida_globalid
    ) AS bases_converter

    WHERE NOT EXISTS (
        SELECT 1

        FROM hsu_9qqz5.service_19276d4d553c4a94bebf9facdbebb5b6_ocupacoes AS o

        WHERE o.parentglobalid = bases_converter.globalid
    );


    IF v_bases_sem_ocupacao > 0 THEN
        RAISE EXCEPTION
            'Existem % bases sem ocupação. Nada foi alterado.',
            v_bases_sem_ocupacao;
    END IF;


    /*
    Conta as ocupações reais que serão vinculadas.

    A consulta usa os GlobalIDs distintos.
    Portanto, registros físicos repetidos não aumentam a contagem.
    */
    SELECT COUNT(*)
    INTO v_ocupacoes_esperadas

    FROM hsu_9qqz5.service_19276d4d553c4a94bebf9facdbebb5b6_ocupacoes AS o

    WHERE o.parentglobalid IN (
        SELECT DISTINCT
            b.globalid

        FROM hsu_9qqz5.service_19276d4d553c4a94bebf9facd_levantamentobases AS b

        WHERE EXISTS (
            SELECT 1
            FROM unnest(v_projetos_origem) AS p(valor)
            WHERE UPPER(TRIM(b.projeto)) = UPPER(TRIM(p.valor))
        )

        AND EXISTS (
            SELECT 1
            FROM unnest(v_pontos_origem) AS n(valor)
            WHERE UPPER(TRIM(b.nome_ponto)) = UPPER(TRIM(n.valor))
        )

        AND b.globalid <> v_base_mantida_globalid
    );


    /*
    Monta a lista mostrada na mensagem final.

    Cada GlobalID aparece somente uma vez.
    */
    SELECT STRING_AGG(
        FORMAT(
            'ObjectID: %s
GlobalID: %s',
            bases.objectid,
            bases.globalid
        ),
        E'\n\n'
        ORDER BY
            bases.created_date ASC NULLS LAST,
            bases.objectid ASC
    )

    INTO v_lista_bases_convertidas

    FROM (
        SELECT DISTINCT ON (b.globalid)
            b.objectid,
            b.globalid,
            b.created_date

        FROM hsu_9qqz5.service_19276d4d553c4a94bebf9facd_levantamentobases AS b

        WHERE EXISTS (
            SELECT 1
            FROM unnest(v_projetos_origem) AS p(valor)
            WHERE UPPER(TRIM(b.projeto)) = UPPER(TRIM(p.valor))
        )

        AND EXISTS (
            SELECT 1
            FROM unnest(v_pontos_origem) AS n(valor)
            WHERE UPPER(TRIM(b.nome_ponto)) = UPPER(TRIM(n.valor))
        )

        AND b.globalid <> v_base_mantida_globalid

        ORDER BY
            b.globalid,
            b.created_date ASC NULLS LAST,
            b.objectid ASC
    ) AS bases;


    /*
    Liga as ocupações das outras bases
    ao GlobalID da base mantida.
    */
    UPDATE hsu_9qqz5.service_19276d4d553c4a94bebf9facdbebb5b6_ocupacoes AS o

    SET parentglobalid = v_base_mantida_globalid

    WHERE o.parentglobalid IN (
        SELECT DISTINCT
            b.globalid

        FROM hsu_9qqz5.service_19276d4d553c4a94bebf9facd_levantamentobases AS b

        WHERE EXISTS (
            SELECT 1
            FROM unnest(v_projetos_origem) AS p(valor)
            WHERE UPPER(TRIM(b.projeto)) = UPPER(TRIM(p.valor))
        )

        AND EXISTS (
            SELECT 1
            FROM unnest(v_pontos_origem) AS n(valor)
            WHERE UPPER(TRIM(b.nome_ponto)) = UPPER(TRIM(n.valor))
        )

        AND b.globalid <> v_base_mantida_globalid
    );


    GET DIAGNOSTICS v_ocupacoes_movidas = ROW_COUNT;


    IF v_ocupacoes_movidas <> v_ocupacoes_esperadas THEN
        RAISE EXCEPTION
            'Era esperado mover % ocupações, mas foram movidas %. Nada será salvo.',
            v_ocupacoes_esperadas,
            v_ocupacoes_movidas;
    END IF;


    /*
    Conta quantas linhas físicas serão removidas.

    Remove:

    1. Todas as linhas das bases convertidas.
    2. Todas as cópias físicas da base mantida,
       deixando apenas o ctid escolhido.
    */
    SELECT COUNT(*)
    INTO v_linhas_excluir_esperadas

    FROM hsu_9qqz5.service_19276d4d553c4a94bebf9facd_levantamentobases AS b

    WHERE (
        b.globalid = v_base_mantida_globalid
        AND b.ctid <> v_base_mantida_ctid
    )

    OR b.globalid IN (
        SELECT DISTINCT
            origem.globalid

        FROM hsu_9qqz5.service_19276d4d553c4a94bebf9facd_levantamentobases AS origem

        WHERE EXISTS (
            SELECT 1
            FROM unnest(v_projetos_origem) AS p(valor)
            WHERE UPPER(TRIM(origem.projeto)) = UPPER(TRIM(p.valor))
        )

        AND EXISTS (
            SELECT 1
            FROM unnest(v_pontos_origem) AS n(valor)
            WHERE UPPER(TRIM(origem.nome_ponto)) = UPPER(TRIM(n.valor))
        )

        AND origem.globalid <> v_base_mantida_globalid
    );


    /*
    Remove as bases convertidas e as cópias físicas repetidas.
    */
    DELETE
    FROM hsu_9qqz5.service_19276d4d553c4a94bebf9facd_levantamentobases AS b

    WHERE (
        b.globalid = v_base_mantida_globalid
        AND b.ctid <> v_base_mantida_ctid
    )

    OR b.globalid IN (
        SELECT DISTINCT
            origem.globalid

        FROM hsu_9qqz5.service_19276d4d553c4a94bebf9facd_levantamentobases AS origem

        WHERE EXISTS (
            SELECT 1
            FROM unnest(v_projetos_origem) AS p(valor)
            WHERE UPPER(TRIM(origem.projeto)) = UPPER(TRIM(p.valor))
        )

        AND EXISTS (
            SELECT 1
            FROM unnest(v_pontos_origem) AS n(valor)
            WHERE UPPER(TRIM(origem.nome_ponto)) = UPPER(TRIM(n.valor))
        )

        AND origem.globalid <> v_base_mantida_globalid
    );


    GET DIAGNOSTICS v_linhas_excluidas = ROW_COUNT;


    IF v_linhas_excluidas <> v_linhas_excluir_esperadas THEN
        RAISE EXCEPTION
            'Era esperado remover % linhas de bases, mas foram removidas %. Nada será salvo.',
            v_linhas_excluir_esperadas,
            v_linhas_excluidas;
    END IF;


    /*
    Corrige o projeto e o nome da linha mantida.
    */
    UPDATE hsu_9qqz5.service_19276d4d553c4a94bebf9facd_levantamentobases

    SET
        projeto = v_projeto_correto,
        nome_ponto = v_ponto_correto

    WHERE ctid = v_base_mantida_ctid;


    /*
    Mensagem final.
    */
    RAISE NOTICE E'
Correção concluída.

Base mantida:
Nome: %
Projeto: %
ObjectID: %
GlobalID: %

Bases duplicadas convertidas em ocupações da base mantida:

%

Total de novas ocupações vinculadas à base mantida: %.
',
        v_ponto_correto,
        v_projeto_correto,
        v_base_mantida_objectid,
        v_base_mantida_globalid,
        COALESCE(
            v_lista_bases_convertidas,
            'Nenhuma outra base precisou ser convertida.'
        ),
        v_ocupacoes_movidas;

END
$correcao$;


/*
DEPOIS DA CORREÇÃO

Mostra:

1. A única base mantida.
2. O projeto e o nome corrigidos.
3. Todas as ocupações.
4. A quantidade de fotos.
*/
SELECT
    b.ctid,
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
      UPPER(TRIM(current_setting('correcao.projeto_correto')))

AND UPPER(TRIM(b.nome_ponto)) =
    UPPER(TRIM(current_setting('correcao.ponto_correto')))

ORDER BY
    b.created_date,
    b.objectid,
    o.created_date,
    o.objectid;


/*
PARA TESTAR E DESFAZER:
deixe ROLLBACK.

PARA SALVAR:
troque somente ROLLBACK por COMMIT.
*/

ROLLBACK;
