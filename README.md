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
- **Névoa:** Fog of War nativo do TTS, uma zona só cobrindo a área do mapa. O mestre sentado no **Black** enxerga tudo; props bloqueiam a linha de visão.
  - **Criar revelador** cria uma peça (ficha dourada) que abre um círculo de visão em volta dela. **Marcar revelador** faz o mesmo com tokens/props selecionados.
  - **Alcance**, **Ângulo** (360° = círculo, menos = cone) e **Girar visão** ajustam os reveladores selecionados. Também dá para ajustar no clique direito no revelador > *Reveal Fog of War*.
  - **Modo sobrevivência:** clique esquerdo na névoa > **ReHide Objects** (o que sai da visão volta a ficar escondido).
  - **Resetar névoa** cobre o mapa todo de novo. Trocar de mapa também recomeça a névoa.
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
- **Fog:** TTS's native Fog of War, a single zone over the map area. The GM sitting as **Black** sees everything; props block line of sight.
  - **Create revealer** spawns a piece (gold chip) that opens a circle of vision around it. **Make revealer** does the same for selected tokens/props.
  - **Range**, **Angle** (360° = circle, less = cone) and **Turn view** adjust the selected revealers. You can also adjust them with right-click on the revealer > *Reveal Fog of War*.
  - **Survival mode:** left-click the fog > **ReHide Objects** (anything that leaves vision is hidden again).
  - **Reset fog** covers the whole map again. Switching maps also restarts the fog.
- **Area:** automatic detection from the table, manual calibration (point at the corners), show area, pin objects.
