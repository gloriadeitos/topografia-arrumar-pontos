/* Pesquisar ponto específico de um projeto específico: 

% permite encontrar qualquer texto antes ou depois do valor pesquisado
%NOME%

Essas linhas com o mesmo GlobalID não são bases duplicadas: são o histórico da mesma feição após várias alterações.
Quando gdb_to_date é 9999-12-31, aquela linha representa a versão atual; as linhas com outra data são versões antigas.

Então:
não delete usando ctid;
não use a tabela física para contar bases duplicadas;
use a view terminada em _evw, que apresenta a versão atual;
não use mais o código que removia “linhas físicas repetidas”.

*/

SELECT
    objectid,
    globalid,
    projeto,
    nome_ponto,
    created_date,
    created_user
FROM hsu_9qqz5.service_19276d4d553c4a94bebf9facd_levantamentobases_evw
WHERE TRIM(projeto) ILIKE '%1333%'
  AND TRIM(nome_ponto) ILIKE '%MR 15%'
ORDER BY
    created_date,
    objectid;
