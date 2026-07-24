/* Contar quantos pontos (no caso o MR43) existem no projeto (no caso o 1332): */

SELECT *
FROM hsu_9qqz5.service_19276d4d553c4a94bebf9facd_levantamentobases

SELECT COUNT(*) AS quantidade
FROM hsu_9qqz5.service_19276d4d553c4a94bebf9facd_levantamentobases
WHERE TRIM(projeto) = '1332'
  AND UPPER(TRIM(nome_ponto)) = 'MR43';
