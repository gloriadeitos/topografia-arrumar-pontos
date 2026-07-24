/*
Numerar somente o ponto MR43 do projeto 1332.

Resultado:
ordem = 1: base mais antiga, que deve permanecer
ordem > 1: bases que deverão virar ocupações
globalid_base_mantida: GlobalID da base mais antiga
*/

SELECT *
FROM (
    SELECT
        objectid,
        globalid,
        projeto,
        nome_ponto,
        local_ponto,
        tipo_ponto,
        cadastrador,
        created_date,
        created_user,
        COUNT(*) OVER () AS quantidade,
        ROW_NUMBER() OVER (
            ORDER BY created_date ASC NULLS LAST, objectid ASC
        ) AS ordem,
        FIRST_VALUE(globalid) OVER (
            ORDER BY created_date ASC NULLS LAST, objectid ASC
        ) AS globalid_base_mantida
    FROM hsu_9qqz5.service_19276d4d553c4a94bebf9facd_levantamentobases
    WHERE TRIM(projeto) = '1332'
      AND UPPER(TRIM(nome_ponto)) = 'MR43'
) AS bases_ordenadas
ORDER BY ordem;
