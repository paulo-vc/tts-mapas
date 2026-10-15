--[[
  Atlas do Mestre v3 — script do objeto.

  Instalação:
    1. Objects > Components > Custom > Model
         Model/Mesh: assets/atlas.obj    Diffuse/Image: assets/atlas.png    (aceite subir para a Cloud)
         Type: Generic, Material: Wood. Import.
    2. Clique direito no objeto > Scripting > Scripting Editor, cole este arquivo, Save & Play.
  Funciona também num bloco comum (Objects > Blocks > Square), sem o visual de madeira/pergaminho.
]]

--------------------------------------------------------------------------
-- Estado (vai para o save do objeto)
--------------------------------------------------------------------------
D = {
  area = { x = 0, y = 1, z = 0, w = 30, d = 20, manual = false },
  maps = {},
  folders = {},
  current = nil,
  openFolder = nil,
}

-- Estado só da sessão
S = {
  tab = "mapas", page = 1, newName = "", newUrl = "",
  pending = nil, calib = nil, showingArea = false,
}

local ROWS = 8
local MOVE_STEP = 0.5
local ZOOM_STEP = 1.1
local GRID_STEP = 0.25
local FOG_HEIGHT = 4
local U = 450                 -- unidades de botão por unidade do mundo
local INNER = { w = 9, d = 11.8 } -- tampo de pergaminho do modelo (tools/gerar_modelo.py)
local MODEL_TOP = 0.30          -- altura do tampo no modelo

local TABLE_FRACTION = {
  Table_RPG = { 0.80, 0.69 },
  Table_Custom = { 0.95, 0.95 },
  Table_Custom_Square = { 0.95, 0.95 },
}

--------------------------------------------------------------------------
-- Idioma: D.lang = "pt" ou "en". tr() troca o texto em português pelo inglês.
--------------------------------------------------------------------------
local EN = {
  ["Atlas do Mestre"] = "Game Master's Atlas",
  ["Atlas: revelar névoa (segure)"] = "Atlas: reveal fog (hold)",
  ["Atlas: cobrir névoa (segure)"] = "Atlas: cover fog (hold)",
  ["Só o mestre (host/admin) pode usar o Atlas."] = "Only the game master (host/admin) can use the Atlas.",
  ["Mapa: "] = "Map: ",
  ["Mapa "] = "Map ",
  ["Selecione um token ou prop primeiro (clique nele, ou arraste uma caixa)."] = "Select a token or prop first (click it, or drag a box).",
  ["Ligue a névoa primeiro (aba Névoa)."] = "Turn the fog on first (Fog tab).",
  ["Cole o link da imagem (.jpg ou .png)."] = "Paste the image link (.jpg or .png).",
  ["Novo mapa: clique direito > Custom"] = "New map: right-click > Custom",
  ["Clique com o botão direito no tile no meio da mesa > Custom > escolha a imagem > Import. Aceite subir para a Cloud."] = "Right-click the tile in the middle of the table > Custom > pick the image > Import. Accept the Cloud upload.",
  ["Mapa adicionado!"] = "Map added!",
  ["Tempo esgotado esperando a imagem. Tente de novo."] = "Timed out waiting for the image. Try again.",
  ["Digite o nome da pasta no campo Nome."] = "Type the folder name in the Name field.",
  ["Já existe uma pasta com esse nome."] = "A folder with that name already exists.",
  ["Nenhum mapa ativo."] = "No active map.",
  ["Estado de \""] = "State of \"",
  ["\" salvo ("] = "\" saved (",
  [" objetos)."] = " objects).",
  ["Este mapa ainda não tem estado salvo."] = "This map has no saved state yet.",
  ["Ajustes funcionam nos modos Caber e Preencher."] = "Adjustments work in Fit and Fill modes.",
  ["Ligue a névoa primeiro."] = "Turn the fog on first.",
  [": não é mais "] = ": no longer ",
  ["revelador"] = "a revealer",
  ["visão em cone"] = "cone vision",
  ["Selecione objetos primeiro (arraste uma caixa ou Ctrl+clique)."] = "Select objects first (drag a box or Ctrl+click).",
  [": fixo"] = ": pinned",
  [": não é mais fixo"] = ": no longer pinned",
  ["Mire o mouse no canto "] = "Point the mouse at corner ",
  [" da área... (3s)"] = " of the area... (3s)",
  ["Carregue um mapa na aba Mapas."] = "Load a map in the Maps tab.",
  ["Mapa ativo: "] = "Active map: ",
  ["Nenhum mapa ativo"] = "No active map",
  ["Mapas"] = "Maps",
  ["Imagem"] = "Image",
  ["Grade"] = "Grid",
  ["Névoa"] = "Fog",
  ["Área"] = "Area",
  ["Nome do mapa ou da pasta"] = "Map or folder name",
  ["Link da imagem (.jpg / .png)"] = "Image link (.jpg / .png)",
  ["+ Link"] = "+ Link",
  ["Adiciona o mapa do link"] = "Adds the map from the link",
  ["+ Arquivo do PC"] = "+ File from PC",
  ["Escolher uma imagem do computador"] = "Pick an image from your computer",
  ["+ Pasta"] = "+ Folder",
  ["Cria uma pasta com o nome digitado"] = "Creates a folder with the typed name",
  ["Mover mapa p/ cá"] = "Move map here",
  ["Move o mapa ativo para a pasta aberta"] = "Moves the active map into the open folder",
  ["Pasta: "] = "Folder: ",
  ["Seus mapas"] = "Your maps",
  ["< Voltar"] = "< Back",
  ["Clique para abrir"] = "Click to open",
  ["Clique de novo para apagar a pasta"] = "Click again to delete the folder",
  ["Apagar pasta"] = "Delete folder",
  ["Clique para carregar   |   * = tem estado salvo"] = "Click to load   |   * = has saved state",
  ["Clique de novo para apagar"] = "Click again to delete",
  ["Apagar mapa"] = "Delete map",
  ["Nenhum mapa ainda. Adicione um acima."] = "No maps yet. Add one above.",
  ["Salvar estado"] = "Save state",
  ["Guarda a posição dos props e tokens neste mapa"] = "Saves where the props and tokens are on this map",
  ["Restaurar"] = "Restore",
  ["Confirmar?"] = "Confirm?",
  ["Volta ao último estado salvo"] = "Goes back to the last saved state",
  ["Como exibir"] = "How to display",
  ["Na mesa"] = "On table",
  ["Imagem direto na parte customizável da mesa"] = "Image straight on the table's custom surface",
  ["Caber"] = "Fit",
  ["Imagem inteira, mantendo a proporção"] = "Whole image, keeping proportions",
  ["Preencher"] = "Fill",
  ["Cobre a área toda"] = "Covers the whole area",
  ["Ajuste fino (Caber / Preencher)"] = "Fine tuning (Fit / Fill)",
  ["Zoom -"] = "Zoom -",
  ["Zoom +"] = "Zoom +",
  ["Girar 90"] = "Rotate 90",
  ["Resetar ajuste"] = "Reset adjustment",
  ["Grade: ligada"] = "Grid: on",
  ["Grade: desligada"] = "Grid: off",
  ["Encaixe: ligado"] = "Snap: on",
  ["Encaixe: desligado"] = "Snap: off",
  ["Peças encaixam no centro dos quadrados"] = "Pieces snap to the center of the squares",
  ["Tamanho do quadrado"] = "Square size",
  ["Intensidade das linhas"] = "Line strength",
  ["Mais clara"] = "Lighter",
  ["Mais escura"] = "Darker",
  ["Alinhar com o desenho do mapa"] = "Align with the map's drawing",
  ["Névoa: ligada"] = "Fog: on",
  ["Névoa: desligada"] = "Fog: off",
  ["Você ("] = "You (",
  [") enxerga através; os jogadores não."] = ") see through it; players don't.",
  ["Cobrir tudo"] = "Cover all",
  ["Revelar tudo"] = "Reveal all",
  ["Pincel"] = "Brush",
  ["Revelar"] = "Reveal",
  ["Revelando..."] = "Revealing...",
  ["Liga/desliga: revela por onde o mouse passa"] = "On/off: reveals wherever the mouse goes",
  ["Cobrir"] = "Cover",
  ["Cobrindo..."] = "Covering...",
  ["Liga/desliga: cobre por onde o mouse passa"] = "On/off: covers wherever the mouse goes",
  ["Raio -"] = "Radius -",
  ["Raio "] = "Radius ",
  ["Raio +"] = "Radius +",
  ["Célula -"] = "Cell -",
  ["Célula "] = "Cell ",
  ["Célula +"] = "Cell +",
  ["Atalhos: Options > Game Keys > Atlas"] = "Hotkeys: Options > Game Keys > Atlas",
  ["Tokens (selecione e clique)"] = "Tokens (select, then click)",
  ["Revelador"] = "Revealer",
  ["Limpa a névoa por onde o token passa (permanente)"] = "Clears the fog wherever the token goes (permanent)",
  ["Visão em cone"] = "Cone vision",
  ["Modo sobrevivência: só enxerga à frente do token"] = "Survival mode: only sees in front of the token",
  ["Desmarcar"] = "Unmark",
  ["Tira o token da névoa"] = "Removes the token from the fog",
  ["Alcance -"] = "Range -",
  ["Raio do revelador / alcance do cone"] = "Revealer radius / cone range",
  ["Raio %.1f  Cone %d"] = "Radius %.1f  Cone %d",
  ["Alcance +"] = "Range +",
  ["Ângulo -"] = "Angle -",
  ["Ângulo "] = "Angle ",
  ["Ângulo +"] = "Angle +",
  ["Sobrevivência: ligada"] = "Survival: on",
  ["Sobrevivência: desligada"] = "Survival: off",
  ["Tokens com visão em cone só enxergam à frente; a névoa volta atrás deles"] = "Cone-vision tokens only see ahead; the fog returns behind them",
  ["Girar cone 90"] = "Turn cone 90",
  ["Se o cone aponta para o lado errado do token"] = "If the cone points the wrong way for this token",
  [" revelador(es)   "] = " revealer(s)   ",
  [" com visão"] = " with vision",
  ["Área do mapa na mesa"] = "Map area on the table",
  ["calibrada"] = "calibrated",
  ["automática"] = "automatic",
  ["Detectar"] = "Detect",
  ["Detecta a área customizável pela própria mesa"] = "Detects the custom area from the table itself",
  ["Calibrar"] = "Calibrate",
  ["Canto 2..."] = "Corner 2...",
  ["Clique e mire o mouse no canto da área em 3s"] = "Click, then point the mouse at the area's corner within 3s",
  ["Mostrar área"] = "Show area",
  ["Fixar selecionados"] = "Pin selected",
  ["Objetos fixos não trocam com o mapa"] = "Pinned objects don't change with the map",
  ["Idioma"] = "Language",
  ["Resetar névoa"] = "Reset fog",
  ["Cobre o mapa todo de novo"] = "Covers the whole map again",
  ["Sente no Black para ver tudo (mestre)."] = "Sit as Black to see everything (GM).",
  ["Reveladores (selecione e clique)"] = "Revealers (select, then click)",
  ["Criar revelador"] = "Create revealer",
  ["Cria uma peça que revela a névoa em volta dela"] = "Creates a piece that reveals the fog around it",
  ["Marcar revelador"] = "Make revealer",
  ["Os objetos selecionados passam a revelar a névoa"] = "Selected objects start revealing the fog",
  ["Tira a revelação dos objetos selecionados"] = "Stops the selected objects from revealing",
  ["Alcance "] = "Range ",
  ["360° = círculo; menos = cone de visão"] = "360° = circle; less = vision cone",
  ["Girar visão 90"] = "Turn view 90",
  ["Dicas"] = "Tips",
  ["Clique direito no revelador > Reveal Fog of War: alcance e cor."] = "Right-click a revealer > Reveal Fog of War: range and color.",
  ["Modo sobrevivência: clique na névoa > ReHide Objects."] = "Survival mode: click the fog > ReHide Objects.",
  ["Revelador criado no centro do mapa. Arraste para onde quiser."] = "Revealer created in the middle of the map. Drag it anywhere.",
}

function tr(s)
  if D.lang == "en" then return EN[s] or s end
  return s
end

--------------------------------------------------------------------------
-- Ciclo de vida
--------------------------------------------------------------------------
function onLoad(saved)
  if saved and saved ~= "" then
    local ok, t = pcall(JSON.decode, saved)
    if ok and type(t) == "table" and t.area then D = t end
  end
  D.maps = D.maps or {}
  D.folders = D.folders or {}
  self.setName(tr("Atlas do Mestre"))
  self.addTag("Fixo")
  self.addTag("AtlasMesa")

  if isModel() then
    self.setScale({ 1, 1, 1 })
  else
    self.setScale({ INNER.w + 0.8, 0.3, INNER.d + 0.8 })
    self.setColorTint({ 0.36, 0.23, 0.12 })
  end


  Wait.frames(function()
    if not D.area.manual then autoArea() end
    applyGrid()
    buildFog()
    build()
  end, 10)
end

function onSave()
  return JSON.encode(D)
end

--------------------------------------------------------------------------
-- Utilitários
--------------------------------------------------------------------------
function isModel()
  local co = self.getCustomObject()
  return co ~= nil and co.mesh ~= nil and co.mesh ~= ""
end

function say(color, text)
  if color and Player[color] and Player[color].seated then
    printToColor(text, color, { 0.95, 0.85, 0.6 })
  else
    broadcastToAll(text, { 0.95, 0.85, 0.6 })
  end
end

function isGM(color)
  local p = Player[color]
  if p and (p.host or p.admin) then return true end
  say(color, tr("Só o mestre (host/admin) pode usar o Atlas."))
  return false
end

function current()
  return D.current and D.maps[D.current] or nil
end

function trim(s)
  s = s or ""
  local i, j = 1, #s
  while i <= j and s:sub(i, i):find("%s") do i = i + 1 end
  while j >= i and s:sub(j, j):find("%s") do j = j - 1 end
  return s:sub(i, j)
end

function inArea(p)
  local a = D.area
  return math.abs(p.x - a.x) <= a.w / 2 and math.abs(p.z - a.z) <= a.d / 2
end

function isOurs(o)
  return o == self or o.hasTag("MapaTile") or o.hasTag("Fog") or o.hasTag("AtlasNevoa") or o.hasTag("Fixo") or o.hasTag("AtlasMesa")
end

--------------------------------------------------------------------------
-- Área do mapa e superfície da mesa
--------------------------------------------------------------------------
-- Altura real do pano da mesa, lançando um raio de cima para baixo.
function surfaceY(x, z)
  local tableObj = Tables.getTableObject()
  local hits = Physics.cast({
    origin = { x = x, y = 60, z = z },
    direction = { x = 0, y = -1, z = 0 },
    type = 1,
    max_distance = 120,
  })
  for _, h in ipairs(hits) do
    if h.hit_object == tableObj then return h.point.y end
  end
  for _, h in ipairs(hits) do
    if not isOurs(h.hit_object) then return h.point.y end
  end
  return D.area.y
end

function autoArea()
  local t = Tables.getTableObject()
  if not t then return end
  local b = t.getBounds()
  local f = TABLE_FRACTION[Tables.getTable()] or { 0.85, 0.85 }
  D.area = { x = b.center.x, z = b.center.z, w = b.size.x * f[1], d = b.size.z * f[2], manual = false }
  D.area.y = surfaceY(D.area.x, D.area.z)
end

function afterAreaChange()
  showArea()
  local m = current()
  if m and m.fit ~= "mesa" then showMap(m) else applyGrid() end
  buildFog(true)
end

--------------------------------------------------------------------------
-- Imagem do mapa
--------------------------------------------------------------------------
function getTile() return getObjectsWithTag("MapaTile")[1] end

function removeTile()
  for _, o in ipairs(getObjectsWithTag("MapaTile")) do o.destruct() end
end

function mapTopY()
  local t = getTile()
  if t then
    local b = t.getBounds()
    return b.center.y + b.size.y / 2
  end
  return D.area.y
end

-- Caber/Preencher mantendo a proporção, com a base do tile encostada na superfície.
function fitTile(o, m)
  local a = D.area
  local s0 = o.getScale().x
  local b = o.getBoundsNormalized().size
  local bw, bd = b.x / s0, b.z / s0
  if bw <= 0 or bd <= 0 then return end
  local base = (m.fit == "preencher") and math.max(a.w / bw, a.d / bd) or math.min(a.w / bw, a.d / bd)
  local s = base * (m.zoom or 1)
  o.setScale({ s, 1, s })
  o.setRotation({ 0, m.rot or 0, 0 })
  Wait.frames(function()
    local bb = o.getBounds()
    local bottom = bb.center.y - bb.size.y / 2
    local p = o.getPosition()
    o.setPosition({ a.x + (m.ox or 0), p.y + (a.y + 0.005 - bottom), a.z + (m.oz or 0) })
    Wait.frames(applyGrid, 2)
  end, 2)
end

function spawnTile(m)
  removeTile()
  local a = D.area
  local o = spawnObject({
    type = "Custom_Tile",
    position = { a.x, a.y + 1, a.z },
    rotation = { 0, m.rot or 0, 0 },
    sound = false,
    callback_function = function(obj)
      obj.addTag("MapaTile")
      obj.setLock(true)
      obj.setName(tr("Mapa: ") .. m.name)
      obj.interactable = false
      Wait.frames(function() fitTile(obj, m) end, 5)
    end,
  })
  o.setCustomObject({ image = m.url, type = 0, thickness = 0.05, stretch = false })
end

function showMap(m)
  if m.fit == "mesa" then
    removeTile()
    Tables.setCustomURL(m.url)
    applyGrid()
  else
    spawnTile(m)
  end
end

--------------------------------------------------------------------------
-- Props e tokens
--------------------------------------------------------------------------
function storeObjects(keep)
  local a, list = D.area, {}
  for _, o in ipairs(getObjects()) do
    if not isOurs(o) and o.type ~= "Fog" and o.type ~= "Scripting" and o.type ~= "Hand" then
      local p = o.getPosition()
      if inArea(p) then
        table.insert(list, { json = o.getJSON(), dx = p.x - a.x, y = p.y - a.y, dz = p.z - a.z })
        if not keep then o.destruct() end
      end
    end
  end
  return list
end

function spawnStored(list)
  local a = D.area
  for _, e in ipairs(list or {}) do
    spawnObjectJSON({ json = e.json, position = { a.x + e.dx, a.y + e.y, a.z + e.dz } })
  end
end

--------------------------------------------------------------------------
-- Troca de mapa, pastas
--------------------------------------------------------------------------
function switchTo(i)
  local old = current()
  if old then old.objects = storeObjects() end
  D.current = i
  local m = D.maps[i]
  showMap(m)
  buildFog(true)
  Wait.frames(function()
    spawnStored(m.objects)
    m.objects = {}
  end, 15)
  S.pending = nil
  build()
end

function addMap(name, url)
  name = trim(name)
  if name == "" then name = tr("Mapa ") .. (#D.maps + 1) end
  table.insert(D.maps, {
    name = name, url = url, fit = "mesa", zoom = 1, ox = 0, oz = 0, rot = 0,
    objects = {}, folder = D.openFolder,
  })
  S.newName, S.newUrl = "", ""
  S.page = math.ceil(#getEntries() / ROWS)
  switchTo(#D.maps)
end

function getEntries()
  local e = {}
  if D.openFolder then
    table.insert(e, { kind = "back" })
    for i, m in ipairs(D.maps) do
      if m.folder == D.openFolder then table.insert(e, { kind = "map", i = i }) end
    end
  else
    for fi, f in ipairs(D.folders) do
      local n = 0
      for _, m in ipairs(D.maps) do if m.folder == f then n = n + 1 end end
      table.insert(e, { kind = "folder", name = f, fi = fi, count = n })
    end
    for i, m in ipairs(D.maps) do
      if not m.folder then table.insert(e, { kind = "map", i = i }) end
    end
  end
  return e
end

--------------------------------------------------------------------------
-- Grade: linhas por cima do mapa + encaixe nativo do TTS
--------------------------------------------------------------------------
function applyGrid()
  local m = current()
  local g = m and m.grid
  local a = D.area
  if g and g.on then
    Grid.type = 1
    Grid.show_lines = false
    Grid.sizeX, Grid.sizeY = g.size, g.size
    Grid.offsetX = a.x - a.w / 2 + (g.ox or 0)
    Grid.offsetY = a.z - a.d / 2 + (g.oz or 0)
    Grid.snapping = (g.snap ~= false) and 3 or 1
  else
    Grid.snapping = 1
  end
  drawLines()
end

function drawLines()
  local lines = {}
  local a = D.area
  local x0, x1 = a.x - a.w / 2, a.x + a.w / 2
  local z0, z1 = a.z - a.d / 2, a.z + a.d / 2
  local m = current()
  local g = m and m.grid
  if g and g.on then
    local y = mapTopY() + 0.02
    local col = { 0.1, 0.07, 0.04, g.alpha or 0.6 }
    local x = x0 + (g.ox or 0)
    while x <= x1 + 0.001 do
      table.insert(lines, { points = { { x, y, z0 }, { x, y, z1 } }, color = col, thickness = 0.03 })
      x = x + g.size
    end
    local z = z0 + (g.oz or 0)
    while z <= z1 + 0.001 do
      table.insert(lines, { points = { { x0, y, z }, { x1, y, z } }, color = col, thickness = 0.03 })
      z = z + g.size
    end
  end
  if S.showingArea then
    local y = mapTopY() + 0.05
    table.insert(lines, {
      points = { { x0, y, z0 }, { x1, y, z0 }, { x1, y, z1 }, { x0, y, z1 }, { x0, y, z0 } },
      color = { 1, 0.45, 0.1 }, thickness = 0.12,
    })
  end
  Global.setVectorLines(lines)
end

function showArea()
  S.showingArea = true
  drawLines()
  Wait.time(function() S.showingArea = false; drawLines() end, 6)
end

--------------------------------------------------------------------------
-- Névoa: Fog of War nativo do TTS — uma zona cobrindo a área do mapa.
-- Reveladores abrem círculos lisos (o motor do TTS cuida disso, sem travar);
-- o mestre sentado no Black enxerga tudo; props bloqueiam a linha de visão.
-- Ajustes da zona (ReHide Objects, Fog Height, Reset) ficam no clique esquerdo na névoa;
-- os de cada revelador (alcance, cor) no clique direito > Reveal Fog of War.
--------------------------------------------------------------------------
local TAG_ZONE, TAG_REVEAL = "AtlasNevoa", "AtlasRevelador"
local FOG_ZONE_HEIGHT = 6
local DEFAULT_VISION = { range = 5, angle = 360, rot = 0 }

function fogOf(m)
  m = m or current()
  if not m then return nil end
  m.fog = m.fog or { on = false }
  return m.fog
end

function fogZone() return getObjectsWithTag(TAG_ZONE)[1] end

function clearFog()
  for _, o in ipairs(getObjectsWithTag(TAG_ZONE)) do o.destruct() end
  -- zonas da versão antiga (Hidden Zones em células)
  for _, o in ipairs(getObjectsWithTag("Fog")) do o.destruct() end
end

-- Garante a zona de névoa do mapa ativo. reset = true recria do zero (cobre tudo de novo).
-- Sem reset, uma zona que já existe é mantida, com o que já foi revelado.
function buildFog(reset)
  local f = current() and current().fog
  if not (f and f.on) then return clearFog() end
  if fogZone() and not reset then return end
  clearFog()
  local a = D.area
  spawnObject({
    type = "FogOfWar",   -- nome interno da zona de Fog of War (o "Fog" da lista é só o nome exibido)
    position = { a.x, a.y + FOG_ZONE_HEIGHT / 2 - 0.1, a.z },
    scale = { a.w, FOG_ZONE_HEIGHT, a.d },
    sound = false,
    callback_function = function(o)
      o.addTag(TAG_ZONE)
      o.setName(tr("Névoa"))
    end,
  })
end

-- Configuração do revelador guardada no próprio objeto (memo), para mostrar no painel.
function visionOf(o)
  local ok, v = pcall(JSON.decode, o.memo or "")
  v = (ok and type(v) == "table") and v or {}
  for k, d in pairs(DEFAULT_VISION) do if v[k] == nil then v[k] = d end end
  return v
end

-- Liga a revelação nativa. fov/fov_offset fazem o cone de visão nas versões do TTS que os aceitam;
-- nas outras são ignorados e o revelador abre um círculo.
function applyReveal(o, v)
  o.memo = JSON.encode(v)
  o.addTag(TAG_REVEAL)
  o.setFogOfWarReveal({ reveal = true, color = "Black", range = v.range, fov = v.angle, fov_offset = v.rot })
end

function removeReveal(o)
  o.removeTag(TAG_REVEAL)
  o.setFogOfWarReveal({ reveal = false })
end

-- Aplica uma mudança em todos os objetos selecionados (exceto o próprio Atlas).
function eachSelected(c, fn)
  local sel = Player[c].getSelectedObjects()
  local n = 0
  for _, o in ipairs(sel) do
    if o ~= self and not o.hasTag("Fog") and not o.hasTag("AtlasNevoa") and not o.hasTag("MapaTile") then
      fn(o)
      n = n + 1
    end
  end
  if n == 0 then say(c, tr("Selecione um token ou prop primeiro (clique nele, ou arraste uma caixa).")) end
  return n
end




--------------------------------------------------------------------------
-- Ações dos botões — cada botão chama uma função com nome fixo: (obj, cor, clique_direito)
--------------------------------------------------------------------------
function noop() end

-- Abas
function setTab(t) S.tab = t; S.pending = nil; build() end
function t_mapas() setTab("mapas") end
function t_imagem() setTab("imagem") end
function t_grade() setTab("grade") end
function t_nevoa() setTab("nevoa") end
function t_area() setTab("area") end

-- Campos de texto: (obj, cor, valor, editando)
function in_name(_, _, value) S.newName = value end
function in_url(_, _, value) S.newUrl = value end

-- Mapas
function a_addLink(_, c)
  if not isGM(c) then return end
  local url = trim(S.newUrl)
  if url == "" then return say(c, tr("Cole o link da imagem (.jpg ou .png).")) end
  addMap(S.newName, url)
end

-- Arquivo do PC: o mestre escolhe a imagem no menu Custom do TTS (que sobe para a Cloud).
function a_addFile(_, c)
  if not isGM(c) then return end
  local name, a = S.newName, D.area
  local tile = spawnObject({ type = "Custom_Tile", position = { a.x, a.y + 3, a.z }, scale = { 3, 1, 3 } })
  tile.setName(tr("Novo mapa: clique direito > Custom"))
  local guid = tile.getGUID()
  say(c, tr("Clique com o botão direito no tile no meio da mesa > Custom > escolha a imagem > Import. Aceite subir para a Cloud."))
  Wait.condition(function()
    local t = getObjectFromGUID(guid)
    local url = t.getCustomObject().image
    t.destruct()
    addMap(name, url)
    say(c, tr("Mapa adicionado!"))
  end, function()
    local t = getObjectFromGUID(guid)
    if not t or t.spawning then return false end
    local co = t.getCustomObject()
    return co and co.image and co.image ~= ""
  end, 600, function() say(c, tr("Tempo esgotado esperando a imagem. Tente de novo.")) end)
end

function a_newFolder(_, c)
  if not isGM(c) then return end
  local name = trim(S.newName)
  if name == "" then return say(c, tr("Digite o nome da pasta no campo Nome.")) end
  for _, f in ipairs(D.folders) do
    if f == name then return say(c, tr("Já existe uma pasta com esse nome.")) end
  end
  table.insert(D.folders, name)
  S.newName = ""
  build()
end

function a_moveHere(_, c)
  if not isGM(c) then return end
  local m = current()
  if not m then return say(c, tr("Nenhum mapa ativo.")) end
  m.folder = D.openFolder
  build()
end

function a_prev() if S.page > 1 then S.page = S.page - 1; build() end end
function a_next()
  if S.page < math.ceil(#getEntries() / ROWS) then S.page = S.page + 1; build() end
end

function a_save(_, c)
  if not isGM(c) then return end
  local m = current()
  if not m then return say(c, tr("Nenhum mapa ativo.")) end
  m.saved = storeObjects(true)
  say(c, tr("Estado de \"") .. m.name .. tr("\" salvo (") .. #m.saved .. tr(" objetos)."))
  build()
end

function a_restore(_, c)
  if not isGM(c) then return end
  local m = current()
  if not (m and m.saved) then return say(c, tr("Este mapa ainda não tem estado salvo.")) end
  if S.pending ~= "restore" then
    S.pending = "restore"
    return build()
  end
  S.pending = nil
  storeObjects()
  Wait.frames(function() spawnStored(m.saved) end, 5)
  build()
end

-- Linhas da lista: r = abrir/carregar, x = apagar (dois cliques)
function row(n, c, del)
  if not isGM(c) then return end
  local e = getEntries()[(S.page - 1) * ROWS + n]
  if not e then return end
  if e.kind == "back" then
    D.openFolder, S.page = nil, 1
  elseif e.kind == "folder" and not del then
    D.openFolder, S.page = e.name, 1
  elseif e.kind == "map" and not del then
    if e.i ~= D.current then return switchTo(e.i) end
  else
    local key = e.kind .. ":" .. (e.i or e.fi)
    if S.pending ~= key then
      S.pending = key
      return build()
    end
    S.pending = nil
    if e.kind == "folder" then
      for _, m in ipairs(D.maps) do if m.folder == e.name then m.folder = nil end end
      table.remove(D.folders, e.fi)
    else
      if e.i == D.current then
        storeObjects()
        removeTile()
        clearFog()
        D.current = nil
        applyGrid()
      elseif D.current and e.i < D.current then
        D.current = D.current - 1
      end
      table.remove(D.maps, e.i)
    end
  end
  build()
end
function r1(_, c) row(1, c) end function x1(_, c) row(1, c, true) end
function r2(_, c) row(2, c) end function x2(_, c) row(2, c, true) end
function r3(_, c) row(3, c) end function x3(_, c) row(3, c, true) end
function r4(_, c) row(4, c) end function x4(_, c) row(4, c, true) end
function r5(_, c) row(5, c) end function x5(_, c) row(5, c, true) end
function r6(_, c) row(6, c) end function x6(_, c) row(6, c, true) end
function r7(_, c) row(7, c) end function x7(_, c) row(7, c, true) end
function r8(_, c) row(8, c) end function x8(_, c) row(8, c, true) end

-- Imagem
function setFit(c, fit)
  if not isGM(c) then return end
  local m = current()
  if not m then return end
  m.fit = fit
  showMap(m)
  build()
end
function f_mesa(_, c) setFit(c, "mesa") end
function f_caber(_, c) setFit(c, "caber") end
function f_preencher(_, c) setFit(c, "preencher") end

function adjust(c, k)
  if not isGM(c) then return end
  local m = current()
  if not m then return end
  if m.fit == "mesa" then return say(c, tr("Ajustes funcionam nos modos Caber e Preencher.")) end
  if k == "zin" then m.zoom = (m.zoom or 1) * ZOOM_STEP
  elseif k == "zout" then m.zoom = (m.zoom or 1) / ZOOM_STEP
  elseif k == "rot" then m.rot = ((m.rot or 0) + 90) % 360
  elseif k == "up" then m.oz = (m.oz or 0) + MOVE_STEP
  elseif k == "down" then m.oz = (m.oz or 0) - MOVE_STEP
  elseif k == "left" then m.ox = (m.ox or 0) - MOVE_STEP
  elseif k == "right" then m.ox = (m.ox or 0) + MOVE_STEP
  elseif k == "reset" then m.zoom, m.ox, m.oz, m.rot = 1, 0, 0, 0
  end
  local t = getTile()
  if t then fitTile(t, m) else showMap(m) end
end
function j_zin(_, c) adjust(c, "zin") end
function j_zout(_, c) adjust(c, "zout") end
function j_rot(_, c) adjust(c, "rot") end
function j_reset(_, c) adjust(c, "reset") end
function j_left(_, c) adjust(c, "left") end
function j_up(_, c) adjust(c, "up") end
function j_down(_, c) adjust(c, "down") end
function j_right(_, c) adjust(c, "right") end

-- Grade
function grid(c, k)
  if not isGM(c) then return end
  local m = current()
  if not m then return say(c, tr("Nenhum mapa ativo.")) end
  m.grid = m.grid or { on = false, size = 1, snap = true, ox = 0, oz = 0, alpha = 0.6 }
  local g = m.grid
  if k == "on" then g.on = not g.on
  elseif k == "snap" then g.snap = not (g.snap ~= false)
  elseif k == "less" then g.size = math.max(GRID_STEP, g.size - GRID_STEP)
  elseif k == "more" then g.size = g.size + GRID_STEP
  elseif k == "light" then g.alpha = math.max(0.15, (g.alpha or 0.6) - 0.15)
  elseif k == "dark" then g.alpha = math.min(1, (g.alpha or 0.6) + 0.15)
  else
    local dx = (k == "left" and -1) or (k == "right" and 1) or 0
    local dz = (k == "up" and 1) or (k == "down" and -1) or 0
    g.ox = ((g.ox or 0) + dx * g.size / 4) % g.size
    g.oz = ((g.oz or 0) + dz * g.size / 4) % g.size
  end
  applyGrid()
  build()
end
function g_on(_, c) grid(c, "on") end
function g_snap(_, c) grid(c, "snap") end
function g_less(_, c) grid(c, "less") end
function g_more(_, c) grid(c, "more") end
function g_light(_, c) grid(c, "light") end
function g_dark(_, c) grid(c, "dark") end
function g_left(_, c) grid(c, "left") end
function g_up(_, c) grid(c, "up") end
function g_down(_, c) grid(c, "down") end
function g_right(_, c) grid(c, "right") end

-- Névoa
function fog(c, k)
  if not isGM(c) then return end
  local f = fogOf()
  if not f then return say(c, tr("Nenhum mapa ativo.")) end
  if k == "on" then f.on = not f.on end
  buildFog(true)
  build()
end
function n_on(_, c) fog(c, "on") end
function n_reset(_, c) fog(c, "reset") end

-- Reveladores
function v_spawn(_, c)
  if not isGM(c) then return end
  local a = D.area
  spawnObject({
    type = "Chip_10",
    position = { a.x, a.y + 2, a.z },
    callback_function = function(o)
      o.setName(tr("Revelador"))
      o.setColorTint({ 0.85, 0.65, 0.2 })
      applyReveal(o, visionOf(o))
      build()
    end,
  })
  say(c, tr("Revelador criado no centro do mapa. Arraste para onde quiser."))
end

function v_reveal(_, c)
  if not isGM(c) then return end
  eachSelected(c, function(o) applyReveal(o, visionOf(o)) end)
  build()
end

function v_clear(_, c)
  if not isGM(c) then return end
  eachSelected(c, removeReveal)
  build()
end

-- Ajustes valem para os objetos selecionados que já são reveladores.
function tune(c, fn)
  if not isGM(c) then return end
  eachSelected(c, function(o)
    if o.hasTag(TAG_REVEAL) then
      local v = visionOf(o)
      fn(v)
      applyReveal(o, v)
      S.lastVision = v
    end
  end)
  build()
end
function v_rless(_, c) tune(c, function(v) v.range = math.max(1, v.range - 1) end) end
function v_rmore(_, c) tune(c, function(v) v.range = v.range + 1 end) end
function v_aless(_, c) tune(c, function(v) v.angle = math.max(30, v.angle - 30) end) end
function v_amore(_, c) tune(c, function(v) v.angle = math.min(360, v.angle + 30) end) end
function v_rot(_, c) tune(c, function(v) v.rot = ((v.rot or 0) + 90) % 360 end) end

-- Área
function z_auto(_, c)
  if not isGM(c) then return end
  autoArea()
  afterAreaChange()
  build()
end
function z_show() showArea() end

-- Idioma (os atalhos de teclado mudam de nome no próximo carregamento)
function l_pt(_, c) if isGM(c) then D.lang = "pt"; build() end end
function l_en(_, c) if isGM(c) then D.lang = "en"; build() end end
function z_fix(_, c)
  if not isGM(c) then return end
  local sel = Player[c].getSelectedObjects()
  if #sel == 0 then return say(c, tr("Selecione objetos primeiro (arraste uma caixa ou Ctrl+clique).")) end
  for _, o in ipairs(sel) do
    if o ~= self then
      if o.hasTag("Fixo") then o.removeTag("Fixo") else o.addTag("Fixo") end
      say(c, (o.getName() ~= "" and o.getName() or o.type) .. (o.hasTag("Fixo") and tr(": fixo") or tr(": não é mais fixo")))
    end
  end
end
function z_calib(_, c)
  if not isGM(c) then return end
  local step = S.calib and 2 or 1
  say(c, tr("Mire o mouse no canto ") .. step .. tr(" da área... (3s)"))
  Wait.time(function()
    local p = Player[c].getPointerPosition()
    if step == 1 then
      S.calib = p
    else
      local c1 = S.calib
      D.area = {
        x = (c1.x + p.x) / 2, z = (c1.z + p.z) / 2,
        w = math.abs(p.x - c1.x), d = math.abs(p.z - c1.z), manual = true,
      }
      D.area.y = surfaceY(D.area.x, D.area.z)
      S.calib = nil
      afterAreaChange()
    end
    build()
  end, 3)
end

--------------------------------------------------------------------------
-- Desenho dos botões sobre o tampo de pergaminho
--------------------------------------------------------------------------
-- Paleta (pergaminho, couro, vinho, musgo, latão) — cores chapadas, sem brilho
local INK = { 0.23, 0.15, 0.08 }
local MUTED = { 0.45, 0.34, 0.21 }
local WINE_TXT = { 0.48, 0.17, 0.14 }
local PARCH_TXT = { 0.97, 0.92, 0.79 }
local LEATHER = { 0.36, 0.22, 0.12 }
local LEATHER_SOFT = { 0.55, 0.40, 0.22 }
local WINE = { 0.48, 0.18, 0.15 }
local MOSS = { 0.31, 0.36, 0.18 }
local BRICK = { 0.55, 0.24, 0.14 }
local CLEAR = { 0, 0, 0, 0 }

-- Coordenadas em unidades do mundo a partir do centro do tampo; z positivo = topo do painel.
-- No TTS o "para cima" do texto dos botões aponta para o -z local, então o z é invertido aqui
-- (e o mapa enrolado do modelo fica no -z).
function place(x, z)
  local s = self.getScale()
  local top = isModel() and (MODEL_TOP + 0.02) / s.y or (0.5 + 0.02 / s.y)
  return { x / s.x, top, -z / s.z }, { 1 / s.x, 1 / s.y, 1 / s.z }
end

function B(label, fn, x, z, w, h, color, textColor, tip)
  local pos, sc = place(x, z)
  self.createButton({
    label = label, click_function = fn, function_owner = self,
    position = pos, scale = sc,
    width = w * U, height = h * U, font_size = math.floor(h * U * 0.42),
    color = color or LEATHER, font_color = textColor or PARCH_TXT,
    hover_color = { 0.62, 0.44, 0.22 }, press_color = { 0.74, 0.56, 0.28 },
    tooltip = tip or "",
  })
end

function T(label, x, z, h, color)
  local pos, sc = place(x, z)
  self.createButton({
    label = label, click_function = "noop", function_owner = self,
    position = pos, scale = sc, width = 0, height = math.floor(h * U),
    font_size = math.floor(h * U * 0.62), font_color = color or INK, color = CLEAR,
  })
end

function I(fn, placeholder, value, x, z, w, h)
  local pos, sc = place(x, z)
  self.createInput({
    input_function = fn, function_owner = self, label = placeholder, value = value,
    position = pos, scale = sc, alignment = 2,
    width = w * U, height = h * U, font_size = math.floor(h * U * 0.40),
    color = { 0.98, 0.95, 0.86 }, font_color = INK,
  })
end

function build()
  self.clearButtons()
  self.clearInputs()
  local m = current()
  local W = INNER.w - 0.7
  local half = W / 2 - 0.06
  local third = W / 3 - 0.08
  local quarter = W / 4 - 0.08
  local x2 = { -W / 4, W / 4 }
  local x3 = { -W / 3, 0, W / 3 }
  local x4 = { -W * 3 / 8, -W / 8, W / 8, W * 3 / 8 }

  local z = INNER.d / 2 - 0.3
  local function line(h)
    local c = z - h / 2
    z = z - h - 0.12
    return c
  end
  local function gap(h) z = z - h end
  local function heading(text) T(text, -W / 2 + 0.05 + #text * 0.066, line(0.36), 0.36, WINE_TXT) end
  local function on(flag) return flag and WINE or LEATHER end
  local function needMap()
    if m then return true end
    T(tr("Carregue um mapa na aba Mapas."), 0, line(0.4), 0.32, MUTED)
    return false
  end

  -- Cabeçalho
  T(tr("Atlas do Mestre"), 0, line(0.6), 0.6, WINE_TXT)
  T(m and (tr("Mapa ativo: ") .. m.name) or tr("Nenhum mapa ativo"), 0, line(0.36), 0.36, MUTED)
  gap(0.05)

  -- Abas
  local c = line(0.55)
  local tabs = { { "mapas", tr("Mapas") }, { "imagem", tr("Imagem") }, { "grade", tr("Grade") }, { "nevoa", tr("Névoa") }, { "area", tr("Área") } }
  local tw = W / #tabs
  for k, t in ipairs(tabs) do
    local sel = S.tab == t[1]
    B(t[2], "t_" .. t[1], -W / 2 + tw * (k - 0.5), c, tw - 0.08, 0.55, sel and WINE or LEATHER_SOFT, PARCH_TXT)
  end
  gap(0.2)

  if S.tab == "mapas" then
    I("in_name", tr("Nome do mapa ou da pasta"), S.newName, 0, line(0.5), W, 0.5)
    I("in_url", tr("Link da imagem (.jpg / .png)"), S.newUrl, 0, line(0.5), W, 0.5)
    c = line(0.5)
    B(tr("+ Link"), "a_addLink", x2[1], c, half, 0.5, MOSS, PARCH_TXT, tr("Adiciona o mapa do link"))
    B(tr("+ Arquivo do PC"), "a_addFile", x2[2], c, half, 0.5, MOSS, PARCH_TXT, tr("Escolher uma imagem do computador"))
    c = line(0.5)
    B(tr("+ Pasta"), "a_newFolder", x2[1], c, half, 0.5, LEATHER, PARCH_TXT, tr("Cria uma pasta com o nome digitado"))
    B(tr("Mover mapa p/ cá"), "a_moveHere", x2[2], c, half, 0.5, LEATHER, PARCH_TXT, tr("Move o mapa ativo para a pasta aberta"))
    gap(0.05)
    heading(D.openFolder and (tr("Pasta: ") .. D.openFolder) or tr("Seus mapas"))

    local entries = getEntries()
    local pages = math.max(1, math.ceil(#entries / ROWS))
    if S.page > pages then S.page = pages end
    local nameW = W - 0.62
    for n = 1, ROWS do
      local e = entries[(S.page - 1) * ROWS + n]
      local rc = line(0.46)
      if e then
        local nx = -W / 2 + nameW / 2
        if e.kind == "back" then
          B(tr("< Voltar"), "r" .. n, 0, rc, W, 0.46, LEATHER_SOFT)
        elseif e.kind == "folder" then
          local confirm = S.pending == ("folder:" .. e.fi)
          B(tr("Pasta: ") .. e.name .. "   (" .. e.count .. ")", "r" .. n, nx, rc, nameW, 0.46, LEATHER_SOFT, PARCH_TXT,
            tr("Clique para abrir"))
          B(confirm and "?" or "x", "x" .. n, W / 2 - 0.27, rc, 0.54, 0.46, BRICK, PARCH_TXT,
            confirm and tr("Clique de novo para apagar a pasta") or tr("Apagar pasta"))
        else
          local mp = D.maps[e.i]
          local sel = e.i == D.current
          local confirm = S.pending == ("map:" .. e.i)
          B(mp.name .. (mp.saved and "  *" or ""), "r" .. n, nx, rc, nameW, 0.46, sel and WINE or LEATHER, PARCH_TXT,
            tr("Clique para carregar   |   * = tem estado salvo"))
          B(confirm and "?" or "x", "x" .. n, W / 2 - 0.27, rc, 0.54, 0.46, BRICK, PARCH_TXT,
            confirm and tr("Clique de novo para apagar") or tr("Apagar mapa"))
        end
      elseif n == 1 then
        T(tr("Nenhum mapa ainda. Adicione um acima."), 0, rc, 0.3, MUTED)
      end
    end
    c = line(0.45)
    B("<", "a_prev", -W / 3, c, 1.0, 0.45)
    T(S.page .. " / " .. pages, 0, c, 0.3, MUTED)
    B(">", "a_next", W / 3, c, 1.0, 0.45)
    gap(0.05)
    c = line(0.5)
    B(tr("Salvar estado"), "a_save", x2[1], c, half, 0.5, MOSS, PARCH_TXT, tr("Guarda a posição dos props e tokens neste mapa"))
    B(S.pending == "restore" and tr("Confirmar?") or tr("Restaurar"), "a_restore", x2[2], c, half, 0.5, BRICK, PARCH_TXT,
      tr("Volta ao último estado salvo"))

  elseif S.tab == "imagem" then
    if needMap() then
      heading(tr("Como exibir"))
      c = line(0.55)
      B(tr("Na mesa"), "f_mesa", x3[1], c, third, 0.55, on(m.fit == "mesa"), PARCH_TXT, tr("Imagem direto na parte customizável da mesa"))
      B(tr("Caber"), "f_caber", x3[2], c, third, 0.55, on(m.fit == "caber"), PARCH_TXT, tr("Imagem inteira, mantendo a proporção"))
      B(tr("Preencher"), "f_preencher", x3[3], c, third, 0.55, on(m.fit == "preencher"), PARCH_TXT, tr("Cobre a área toda"))
      gap(0.15)
      heading(tr("Ajuste fino (Caber / Preencher)"))
      c = line(0.55)
      B(tr("Zoom -"), "j_zout", x3[1], c, third, 0.55)
      B(tr("Zoom +"), "j_zin", x3[2], c, third, 0.55)
      B(tr("Girar 90"), "j_rot", x3[3], c, third, 0.55)
      c = line(0.55)
      B("<", "j_left", x4[1], c, quarter, 0.55)
      B("^", "j_up", x4[2], c, quarter, 0.55)
      B("v", "j_down", x4[3], c, quarter, 0.55)
      B(">", "j_right", x4[4], c, quarter, 0.55)
      c = line(0.5)
      B(tr("Resetar ajuste"), "j_reset", 0, c, W, 0.5, LEATHER_SOFT)
    end

  elseif S.tab == "grade" then
    if needMap() then
      local g = m.grid or {}
      c = line(0.55)
      B(g.on and tr("Grade: ligada") or tr("Grade: desligada"), "g_on", x2[1], c, half, 0.55, on(g.on))
      B(g.snap ~= false and tr("Encaixe: ligado") or tr("Encaixe: desligado"), "g_snap", x2[2], c, half, 0.55, on(g.snap ~= false),
        PARCH_TXT, tr("Peças encaixam no centro dos quadrados"))
      gap(0.15)
      heading(tr("Tamanho do quadrado"))
      c = line(0.55)
      B("-", "g_less", x3[1], c, third, 0.55)
      T(tostring(g.size or 1), x3[2], c, 0.4, INK)
      B("+", "g_more", x3[3], c, third, 0.55)
      heading(tr("Intensidade das linhas"))
      c = line(0.55)
      B(tr("Mais clara"), "g_light", x2[1], c, half, 0.55)
      B(tr("Mais escura"), "g_dark", x2[2], c, half, 0.55)
      heading(tr("Alinhar com o desenho do mapa"))
      c = line(0.55)
      B("<", "g_left", x4[1], c, quarter, 0.55)
      B("^", "g_up", x4[2], c, quarter, 0.55)
      B("v", "g_down", x4[3], c, quarter, 0.55)
      B(">", "g_right", x4[4], c, quarter, 0.55)
    end

  elseif S.tab == "nevoa" then
    if needMap() then
      local f = m.fog or {}
      c = line(0.55)
      B(f.on and tr("Névoa: ligada") or tr("Névoa: desligada"), "n_on", x2[1], c, half, 0.55, on(f.on))
      B(tr("Resetar névoa"), "n_reset", x2[2], c, half, 0.55, LEATHER, PARCH_TXT, tr("Cobre o mapa todo de novo"))
      T(tr("Sente no Black para ver tudo (mestre)."), 0, line(0.3), 0.26, MUTED)
      gap(0.1)

      heading(tr("Reveladores (selecione e clique)"))
      c = line(0.55)
      B(tr("Criar revelador"), "v_spawn", 0, c, W, 0.55, MOSS, PARCH_TXT, tr("Cria uma peça que revela a névoa em volta dela"))
      c = line(0.5)
      B(tr("Marcar revelador"), "v_reveal", x2[1], c, half, 0.5, LEATHER, PARCH_TXT,
        tr("Os objetos selecionados passam a revelar a névoa"))
      B(tr("Desmarcar"), "v_clear", x2[2], c, half, 0.5, LEATHER_SOFT, PARCH_TXT, tr("Tira a revelação dos objetos selecionados"))
      local v = S.lastVision or DEFAULT_VISION
      c = line(0.5)
      B(tr("Alcance -"), "v_rless", x3[1], c, third, 0.5)
      T(tr("Alcance ") .. v.range, x3[2], c, 0.32, INK)
      B(tr("Alcance +"), "v_rmore", x3[3], c, third, 0.5)
      c = line(0.5)
      B(tr("Ângulo -"), "v_aless", x3[1], c, third, 0.5, LEATHER, PARCH_TXT, tr("360° = círculo; menos = cone de visão"))
      T(tr("Ângulo ") .. v.angle .. "°", x3[2], c, 0.32, INK)
      B(tr("Ângulo +"), "v_amore", x3[3], c, third, 0.5, LEATHER, PARCH_TXT, tr("360° = círculo; menos = cone de visão"))
      c = line(0.5)
      B(tr("Girar visão 90"), "v_rot", 0, c, W, 0.5, LEATHER, PARCH_TXT, tr("Se o cone aponta para o lado errado do token"))
      T(#getObjectsWithTag(TAG_REVEAL) .. tr(" revelador(es)   "), 0, line(0.3), 0.26, MUTED)
      gap(0.1)

      heading(tr("Dicas"))
      T(tr("Clique direito no revelador > Reveal Fog of War: alcance e cor."), 0, line(0.28), 0.25, INK)
      T(tr("Modo sobrevivência: clique na névoa > ReHide Objects."), 0, line(0.28), 0.25, INK)
    end

  elseif S.tab == "area" then
    heading(tr("Área do mapa na mesa"))
    T(string.format("%.1f x %.1f  (%s)", D.area.w, D.area.d, D.area.manual and tr("calibrada") or tr("automática")),
      0, line(0.35), 0.32, INK)
    c = line(0.55)
    B(tr("Detectar"), "z_auto", x2[1], c, half, 0.55, LEATHER, PARCH_TXT, tr("Detecta a área customizável pela própria mesa"))
    B(S.calib and tr("Canto 2...") or tr("Calibrar"), "z_calib", x2[2], c, half, 0.55, on(S.calib ~= nil), PARCH_TXT,
      tr("Clique e mire o mouse no canto da área em 3s"))
    c = line(0.55)
    B(tr("Mostrar área"), "z_show", x2[1], c, half, 0.55)
    B(tr("Fixar selecionados"), "z_fix", x2[2], c, half, 0.55, LEATHER, PARCH_TXT, tr("Objetos fixos não trocam com o mapa"))
    gap(0.2)
    heading(tr("Idioma") .. " / Language")
    c = line(0.55)
    B("Português", "l_pt", x2[1], c, half, 0.55, on(D.lang ~= "en"))
    B("English", "l_en", x2[2], c, half, 0.55, on(D.lang == "en"))
  end
end
