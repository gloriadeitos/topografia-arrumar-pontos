/*
Numerar os pontos duplicados para identificar o mais antigo.

Resultado:
- ordem = 1: base que deve permanecer
- ordem > 1: registros que deverão virar ocupações
- globalid_base_mantida: GlobalID que deverá ser gravado
  no parentglobalid das novas ocupações
*/

SELECT *
FROM hsu_9qqz5.service_19276d4d553c4a94bebf9facd_levantamentobases;

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
        COUNT(*) OVER (
            PARTITION BY TRIM(projeto), UPPER(TRIM(nome_ponto))
        ) AS quantidade,
        ROW_NUMBER() OVER (
            PARTITION BY TRIM(projeto), UPPER(TRIM(nome_ponto))
            ORDER BY created_date ASC NULLS LAST, objectid ASC
        ) AS ordem,
        FIRST_VALUE(globalid) OVER (
            PARTITION BY TRIM(projeto), UPPER(TRIM(nome_ponto))
            ORDER BY created_date ASC NULLS LAST, objectid ASC
        ) AS globalid_base_mantida
    FROM hsu_9qqz5.service_19276d4d553c4a94bebf9facd_levantamentobases
) AS bases_ordenadas
WHERE quantidade > 1
ORDER BY projeto, nome_ponto, ordem;
