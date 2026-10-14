# Atlas do Mestre (TTS Mapas v2)

Troca de mapas no centro da mesa do Tabletop Simulator, com props e tokens salvos por mapa, pastas, grade e névoa. Inspirado no OneWorld.

## Instalação
1. Modding > Scripting > **Global**: cole `Global.lua` e clique em **Save & Play**.
2. Pronto. O botão **Atlas** aparece no canto superior direito (só para host/admins).
3. Painel na mesa (opcional): aba **Área** > **Criar painel na mesa**. Qualquer objeto com a tag `PainelMapas` também vira painel.

> Se você usava a v1 (`Controle.lua` num bloco), apague esse bloco. A v2 começa sem mapas.

## Abas
- **Mapas:** adicionar por link ou arquivo do PC (sobe para a Steam Cloud), pastas, lista com páginas, apagar (x, dois cliques), **Salvar estado / Restaurar** dos props e tokens.
- **Imagem:** *Na mesa* (imagem na parte customizável da mesa), *Caber* ou *Preencher* (tile assentado na superfície da mesa), zoom, giro e posição.
- **Grade:** linhas desenhadas por cima do mapa, encaixe (snap), tamanho, intensidade e alinhamento.
- **Névoa:** células de Hidden Zone rentes ao mapa. O mestre enxerga através; os jogadores veem um bloco opaco e não veem os tokens escondidos. Pincel de revelar/cobrir, raio e tamanho da célula.
  - Atalhos: Options > Game Keys > "Atlas: revelar névoa" / "Atlas: cobrir névoa". Segure e passe o mouse.
  - A névoa tem a cor do mestre que a ligou; sente-se no **Black** para névoa preta.
- **Área:** detecção automática pela mesa, calibração manual (mire nos cantos), mostrar área, fixar objetos (não trocam com o mapa).

## Ajustes
No topo de `Global.lua`:
- `OBJ_UI` — se o painel na mesa aparecer virado, deslocado ou afundado.
- `TABLE_FRACTION` — fração da mesa usada como área automática.
- `FOG_HEIGHT` — altura das células de névoa.
