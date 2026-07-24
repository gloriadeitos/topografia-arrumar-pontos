# topografia-arrumar-pontos

Scripts Dbeaver para arrumar pontos q cadastram errado

Todas as tabelas são ligadas pelos campos de identificação "globalid". Quando um ponto é criado na tabela "levantamentobases", também é criada uma ocupação na tabela "ocupacoes". O campo "parentglobalid" da ocupação guarda o "globalid" da base à qual ela pertence.

As tabelas de fotos funcionam da mesma forma, o "parentglobalid" de cada foto guarda o "globalid" da ocupação correspondente. Por fim, o arquivo da imagem fica na tabela "__attach", ligado ao "globalid" do registro da foto pelo campo "rel_globalid".

A solução é manter o ponto mais antigo, copiar para ele o vínculo das ocupações (alterando o "parentglobalid" dessas ocupações para o "globalid" do ponto mais antigo) e, só depois de confirmar que todas ficaram ligadas corretamente, excluir apenas os pontos duplicados. As ocupações e as fotos não serão copiadas nem apagadas, apenas passarão a ficar vinculadas ao ponto mais antigo.
