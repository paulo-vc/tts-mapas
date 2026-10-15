# Atlas do Mestre (TTS Mapas v3)

Uma mesa de controle em 3D (moldura de madeira, tampo de pergaminho, mapa enrolado com ponteiras de latão) que troca os mapas no centro da mesa do Tabletop Simulator, com props e tokens salvos por mapa, pastas, grade e névoa. Inspirado no OneWorld.

## Instalação
1. Se você usou versões anteriores: apague o script Global da v2 (Modding > Scripting > Global) e qualquer bloco antigo.
2. **Objects > Components > Custom > Model**
   - Model/Mesh: `assets/atlas.obj`
   - Diffuse/Image: `assets/atlas.png`
   - Aceite subir os arquivos para a Steam Cloud. Clique em Import.
3. Clique direito no objeto > **Scripting > Scripting Editor**, cole `Atlas.lua` e clique em **Save & Play**.
4. O lado com o mapa enrolado é o topo do painel. Se os botões ficarem de cabeça para baixo, gire o objeto 180°.

Sem o modelo também funciona: cole `Atlas.lua` num bloco (Objects > Blocks > Square).

## Abas
- **Mapas:** adicionar por link ou arquivo do PC (sobe para a Cloud), pastas, lista com páginas, apagar (x, dois cliques), **Salvar estado / Restaurar** dos props e tokens.
- **Imagem:** *Na mesa* (imagem na parte customizável da mesa), *Caber* ou *Preencher* (tile assentado na superfície da mesa), zoom, giro e posição.
- **Grade:** linhas desenhadas por cima do mapa, encaixe (snap), tamanho, intensidade e alinhamento.
- **Névoa:** células de Hidden Zone rentes ao mapa. O mestre enxerga através; os jogadores veem um bloco opaco e não veem os tokens escondidos. Pincel de revelar/cobrir, raio e tamanho da célula.
  - Atalhos: Options > Game Keys > "Atlas: revelar névoa" / "Atlas: cobrir névoa". Segure e passe o mouse.
  - A névoa tem a cor do mestre que a ligou; sente-se no **Black** para névoa preta.
  - **Revelador:** selecione um token/prop e clique em *Revelador*; ele limpa a névoa por onde passa (permanente). Evita que alguém limpe a névoa sem querer com o mouse.
  - **Modo sobrevivência:** marque tokens com *Visão em cone* e ligue *Sobrevivência*. Eles só enxergam um cone à frente (mais um círculo pequeno em volta); a névoa volta quando o cone sai. *Alcance*, *Ângulo* e *Girar cone* ajustam os tokens selecionados.
  - A visão aberta vale para todos os jogadores (Hidden Zones não mudam por jogador).
- **Área:** detecção automática pela mesa, calibração manual (mire nos cantos), mostrar área, fixar objetos.

## Modelo
`tools/gerar_modelo.py` gera `assets/atlas.obj` e `assets/atlas.png` (precisa de `pillow` e `numpy`). Se mudar o tamanho do tampo, ajuste `INNER` em `Atlas.lua`.

## Idioma / Language
Aba **Área** > **Português / English**. A escolha fica salva no objeto.

---

# Game Master's Atlas (English)

A 3D control desk (wooden frame, parchment top, rolled map with brass caps) that swaps maps in the middle of the Tabletop Simulator table, keeping each map's props and tokens, with folders, grid and fog of war. Switch the board to English in the **Area** tab > **English**.

## Install
1. **Objects > Components > Custom > Model** — Model/Mesh: `assets/atlas.obj`, Diffuse/Image: `assets/atlas.png`. Accept the Steam Cloud upload, then Import.
2. Right-click the object > **Scripting > Scripting Editor**, paste `Atlas.lua`, click **Save & Play**.
3. The rolled-map side is the top of the board. If the buttons are upside down, rotate the object 180°.

## Tabs
- **Maps:** add by link or from your PC (uploaded to the Cloud), folders, paged list, delete (x, two clicks), **Save state / Restore** for props and tokens.
- **Image:** *On table* (the table's custom surface), *Fit* or *Fill* (a tile resting on the table), zoom, rotation, position.
- **Grid:** lines drawn over the map, snap, size, line strength and alignment.
- **Fog:** Hidden Zones right on the map. The GM sees through; players see solid fog and not the hidden tokens. Reveal/cover brush (or hotkeys: Options > Game Keys > "Atlas: reveal fog" / "Atlas: cover fog").
  - **Revealer:** a selected token clears the fog wherever it goes (permanent).
  - **Survival mode:** *Cone vision* tokens only see a cone ahead; the fog comes back behind them. Range, angle and direction per token.
  - Opened vision is shared by all players (Hidden Zones can't differ per player). Sit as **Black** for black fog.
- **Area:** automatic detection from the table, manual calibration (point at the corners), show area, pin objects.
