# Atlas do Mestre (TTS Mapas v4)

Uma mesa de controle em 3D (moldura de nogueira, tampo de couro ardósia, detalhes em latão) que guarda seus mapas com miniaturas e troca a imagem da mesa do Tabletop Simulator, com props e tokens salvos por mapa e grade. Português e inglês.

## Instalação
1. Se você usou versões anteriores, apague o objeto antigo. A v4 limpa sozinha restos da névoa antiga.
2. **Objects > Components > Custom > Model**
   - Model/Mesh: `assets/atlas.obj`
   - Diffuse/Image: `assets/atlas.png`
   - Aceite subir os arquivos para a Steam Cloud e clique em Import.
3. Clique direito no objeto > **Scripting > Scripting Editor**, cole `Atlas.lua` e clique em **Save & Play**.

## Abas
- **Mapas**
  - **+ Arquivo do PC** (principal): escolha a imagem no menu Custom do TTS (sobe para a sua Cloud) e dê um nome. **Link** adiciona por endereço da web.
  - Miniaturas de cada mapa, 6 por página. Clique para selecionar; clique de novo (ou **Aplicar na mesa**) para colocar na mesa.
  - **Renomear**, **Mover** (para outra pasta) e **Apagar**, por caixas de diálogo do próprio TTS.
  - **Pasta:** escolhe qual pasta ver; **+ Pasta** cria uma.
  - **Salvar estado / Restaurar:** guarda e devolve a posição dos props e tokens do mapa ativo. Ao trocar de mapa, os objetos de cada um também são guardados.
- **Imagem:** **Encaixar na mesa** (principal) coloca a imagem na parte customizável da mesa. Em *Avançado*, **Caber** / **Preencher** põem a imagem sobre a área, com zoom, giro e posição.
- **Grade:** linhas por cima do mapa e encaixe (snap); tamanho, cor, espessura, intensidade, alinhamento e **Seguir relevo** (as linhas sobem por cima de props e terrenos 3D).
- **Área:** detectar, calibrar (mire nos cantos), mostrar área, fixar objetos; idioma; **Resetar tudo** (a mesa volta ao padrão e as configurações de imagem, grade e área são apagadas — os mapas continuam no Atlas).

## Ajustes
No topo de `Atlas.lua`: `DECAL_ROT` (se as miniaturas aparecerem de cabeça para baixo), `U` (tamanho dos botões), `TABLE_FRACTION` (área automática por tipo de mesa).
`tools/gerar_modelo.py` gera o modelo e a textura (precisa de `pillow` e `numpy`).

## Créditos e inspiração
Ideias adaptadas de mods da Workshop: *Map changer / Picture Book* (Marum) — miniaturas por decals e preservar as mãos ao trocar a imagem da mesa; *3D Gridlines* (stom) — cores, espessura e grade seguindo o relevo.

---

# Game Master's Atlas (English)

A 3D control desk (walnut frame, slate leather top, brass details) that stores your maps with thumbnails and swaps the Tabletop Simulator table image, keeping each map's props and tokens, plus a grid. Switch to English in the **Area** tab.

## Install
1. **Objects > Components > Custom > Model** — Model/Mesh: `assets/atlas.obj`, Diffuse/Image: `assets/atlas.png`. Accept the Steam Cloud upload, then Import.
2. Right-click the object > **Scripting > Scripting Editor**, paste `Atlas.lua`, click **Save & Play**.

## Tabs
- **Maps:** **+ File from PC** (main) or **Link**; thumbnails, 6 per page; click to select, click again (or **Apply to table**) to use it; **Rename**, **Move**, **Delete** via TTS dialogs; folders; **Save state / Restore**.
- **Image:** **Fit to table** (main). *Advanced:* **Fit** / **Fill** over the area with zoom, rotation and position.
- **Grid:** lines over the map, snap, size, color, thickness, strength, alignment and **Follow terrain**.
- **Area:** detect, calibrate, show area, pin objects; language; **Reset everything** (the table returns to default; the maps stay in the Atlas).
