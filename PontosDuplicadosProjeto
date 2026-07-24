/* Encontrar todos os pontos duplicados dentro do mesmo projeto (isso serve pra ver onde existem erros na tabela como um todo) */

SELECT *
FROM hsu_9qqz5.service_19276d4d553c4a94bebf9facd_levantamentobases

SELECT
    TRIM(projeto) AS projeto,
    UPPER(TRIM(nome_ponto)) AS nome_ponto,
    COUNT(*) AS quantidade
FROM hsu_9qqz5.service_19276d4d553c4a94bebf9facd_levantamentobases
WHERE projeto IS NOT NULL
  AND nome_ponto IS NOT NULL
GROUP BY
    TRIM(projeto),
    UPPER(TRIM(nome_ponto))
HAVING COUNT(*) > 1
ORDER BY quantidade DESC, projeto, nome_ponto;
