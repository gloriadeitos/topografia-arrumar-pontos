/* Pesquisar ponto específico de um projeto específico: */

SELECT
    objectid,
    globalid,
    projeto,
    nome_ponto,
    created_date,
    created_user
FROM hsu_9qqz5.service_19276d4d553c4a94bebf9facd_levantamentobases
WHERE TRIM(projeto) ILIKE '%1332%'
  AND TRIM(nome_ponto) ILIKE '%MR43%'
ORDER BY created_date, objectid;
