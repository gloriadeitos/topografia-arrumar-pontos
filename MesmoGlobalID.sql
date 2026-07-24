/* Quando tem o mesmo GlobalID, use esse SQL pra conferir onde foi registrado

"ctid" é um identificador interno do PostgreSQL que mostra onde aquela linha está fisicamente armazenada na tabela.
*/

SELECT
    ctid,
    objectid,
    globalid,
    projeto,
    nome_ponto,
    created_date,
    created_user
FROM hsu_9qqz5.service_19276d4d553c4a94bebf9facd_levantamentobases
WHERE objectid = 2613;
