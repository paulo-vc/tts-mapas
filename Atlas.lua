--[[
  Atlas do Mestre v4 — script do objeto.

  Instalação:
    1. Objects > Components > Custom > Model
         Model/Mesh: assets/atlas.obj    Diffuse/Image: assets/atlas.png    (aceite subir para a Cloud)
    2. Clique direito no objeto > Scripting > Scripting Editor, cole este arquivo, Save & Play.
  Funciona também num bloco comum (Objects > Blocks > Square), sem o visual de madeira e couro.
]]

--------------------------------------------------------------------------
-- Estado (vai para o save do objeto)
--------------------------------------------------------------------------
D = {
  area = { x = 0, y = 1, z = 0, w = 30, d = 20, manual = false },
  maps = {},
  folders = {},
  current = nil,
  lang = "pt",
  origURL = nil,   -- imagem original da mesa, para o "Resetar tudo"
}

-- Estado só da sessão
S = {
  tab = "mapas", page = 1, folder = nil, sel = nil,
  pending = nil, calib = nil, showingArea = false,
  heights = nil, reliefBusy = false, reliefAgain = false,
}

local THUMB_COLS, THUMB_ROWS = 2, 3
local THUMB_W, THUMB_H = 3.9, 2.35   -- miniaturas, mais ou menos 3:2
local MOVE_STEP = 0.5
local ZOOM_STEP = 1.1
local GRID_STEP = 0.25
local U = 450                          -- unidades de botão por unidade do mundo
local INNER = { w = 10, d = 15 }       -- tampo do modelo (tools/gerar_modelo.py)
local MODEL_TOP = 0.30                 -- altura do tampo no modelo
local DECAL_ROT = { 90, 180, 0 }       -- se as miniaturas aparecerem de cabeça para baixo, use { 90, 0, 0 }

local TABLE_FRACTION = {
  Table_RPG = { 0.80, 0.69 },
  Table_Custom = { 0.95, 0.95 },
  Table_Custom_Square = { 0.95, 0.95 },
}

-- Cores da grade e espessuras (inspirado no 3D Gridlines de stom)
local GRID_COLORS = {
  { "Preto", "Black", { 0.05, 0.05, 0.05 } },
  { "Cinza escuro", "Dark grey", { 0.2, 0.2, 0.2 } },
  { "Cinza", "Grey", { 0.45, 0.45, 0.45 } },
  { "Branco", "White", { 1, 1, 1 } },
  { "Marrom", "Brown", { 0.44, 0.23, 0.09 } },
  { "Vermelho", "Red", { 0.86, 0.1, 0.09 } },
  { "Laranja", "Orange", { 0.96, 0.39, 0.11 } },
  { "Amarelo", "Yellow", { 0.9, 0.9, 0.17 } },
  { "Verde", "Green", { 0.19, 0.7, 0.17 } },
  { "Azul", "Blue", { 0.12, 0.53, 1 } },
}
local GRID_STROKES = { 0.01, 0.02, 0.03, 0.05, 0.08, 0.12 }

--------------------------------------------------------------------------
-- Idioma: tr() troca o texto em português pelo inglês quando D.lang == "en".
--------------------------------------------------------------------------
local EN = {
  ["Atlas do Mestre"] = "Game Master's Atlas",
  ["Mapas"] = "Maps", ["Imagem"] = "Image", ["Grade"] = "Grid", ["Área"] = "Area",
  ["Só o mestre (host/admin) pode usar o Atlas."] = "Only the game master (host/admin) can use the Atlas.",
  ["Mapa ativo: "] = "Active map: ", ["Nenhum mapa ativo"] = "No active map", ["Nenhum mapa ativo."] = "No active map.",
  ["Mapa "] = "Map ", ["Mapa: "] = "Map: ",
  ["+ Arquivo do PC"] = "+ File from PC", ["Link"] = "Link",
  ["Escolher uma imagem do computador (sobe para a sua Steam Cloud)"] = "Pick an image from your computer (uploads to your Steam Cloud)",
  ["Adicionar por link da web (.jpg / .png)"] = "Add by web link (.jpg / .png)",
  ["Pasta: "] = "Folder: ", ["Todos os mapas"] = "All maps", ["Sem pasta"] = "No folder",
  ["Escolher pasta para ver"] = "Choose a folder to view", ["+ Pasta"] = "+ Folder",
  ["Nome da nova pasta"] = "New folder name", ["Já existe uma pasta com esse nome."] = "A folder with that name already exists.",
  ["Nenhum mapa aqui. Use + Arquivo do PC."] = "No maps here. Use + File from PC.",
  ["Selecione um mapa para aplicar, renomear ou mover."] = "Select a map to apply, rename or move.",
  ["Aplicar na mesa"] = "Apply to table", ["Renomear"] = "Rename", ["Mover"] = "Move", ["Apagar"] = "Delete",
  ["Novo nome do mapa"] = "New map name", ["Mover para qual pasta?"] = "Move to which folder?",
  ["Apagar o mapa \""] = "Delete the map \"", ["\"? (a imagem continua na sua Cloud)"] = "\"? (the image stays in your Cloud)",
  ["Nome do mapa"] = "Map name",
  ["Novo mapa: clique direito > Custom"] = "New map: right-click > Custom",
  ["Clique com o botão direito no tile no meio da mesa > Custom > escolha a imagem > Import. Aceite subir para a Cloud."] =
    "Right-click the tile in the middle of the table > Custom > pick the image > Import. Accept the Cloud upload.",
  ["Mapa adicionado!"] = "Map added!", ["Tempo esgotado esperando a imagem. Tente de novo."] = "Timed out waiting for the image. Try again.",
  ["Cole o link da imagem (.jpg ou .png)"] = "Paste the image link (.jpg or .png)",
  ["Salvar estado"] = "Save state", ["Restaurar"] = "Restore", ["Confirmar?"] = "Confirm?",
  ["Guarda a posição dos props e tokens neste mapa"] = "Saves where the props and tokens are on this map",
  ["Volta ao último estado salvo"] = "Goes back to the last saved state",
  ["Estado salvo: "] = "State saved: ", [" objetos."] = " objects.",
  ["Este mapa ainda não tem estado salvo."] = "This map has no saved state yet.",
  ["na mesa"] = "on table",
  ["Carregue um mapa na aba Mapas."] = "Load a map in the Maps tab.",
  ["Encaixar na mesa"] = "Fit to table",
  ["A imagem vai direto na parte customizável da mesa (recomendado)"] = "The image goes straight onto the table's custom surface (recommended)",
  ["Avançado: imagem sobre a área"] = "Advanced: image over the area",
  ["Caber"] = "Fit", ["Preencher"] = "Fill",
  ["Imagem inteira, mantendo a proporção"] = "Whole image, keeping proportions", ["Cobre a área toda"] = "Covers the whole area",
  ["Zoom -"] = "Zoom -", ["Zoom +"] = "Zoom +", ["Girar 90"] = "Rotate 90", ["Resetar ajuste"] = "Reset adjustment",
  ["Ajustes funcionam nos modos Caber e Preencher."] = "Adjustments work in Fit and Fill modes.",
  ["Grade: ligada"] = "Grid: on", ["Grade: desligada"] = "Grid: off",
  ["Encaixe: ligado"] = "Snap: on", ["Encaixe: desligado"] = "Snap: off",
  ["Peças encaixam no centro dos quadrados"] = "Pieces snap to the center of the squares",
  ["Tamanho do quadrado"] = "Square size", ["Cor e espessura"] = "Color and thickness",
  ["Cor: "] = "Color: ", ["Linha -"] = "Line -", ["Linha +"] = "Line +",
  ["Mais clara"] = "Lighter", ["Mais escura"] = "Darker",
  ["Alinhar com o desenho do mapa"] = "Align with the map's drawing",
  ["Seguir relevo: ligado"] = "Follow terrain: on", ["Seguir relevo: desligado"] = "Follow terrain: off",
  ["As linhas sobem por cima de props e terrenos 3D"] = "Lines climb over 3D props and terrain",
  ["Calculando relevo..."] = "Calculating terrain...",
  ["Área do mapa na mesa"] = "Map area on the table", ["calibrada"] = "calibrated", ["automática"] = "automatic",
  ["Detectar"] = "Detect", ["Calibrar"] = "Calibrate", ["Canto 2..."] = "Corner 2...",
  ["Mostrar área"] = "Show area", ["Fixar selecionados"] = "Pin selected",
  ["Detecta a área customizável pela própria mesa"] = "Detects the custom area from the table itself",
  ["Clique e mire o mouse no canto da área em 3s"] = "Click, then point the mouse at the area's corner within 3s",
  ["Objetos fixos não trocam com o mapa"] = "Pinned objects don't change with the map",
  ["Mire o mouse no canto "] = "Point the mouse at corner ", [" da área... (3s)"] = " of the area... (3s)",
  ["Selecione objetos primeiro (arraste uma caixa ou Ctrl+clique)."] = "Select objects first (drag a box or Ctrl+click).",
  [": fixo"] = ": pinned", [": não é mais fixo"] = ": no longer pinned",
  ["Manutenção"] = "Maintenance", ["Resetar tudo"] = "Reset everything",
  ["Volta a mesa ao padrão; os mapas do Atlas continuam guardados"] = "Returns the table to default; the Atlas maps stay saved",
  ["Resetar tudo? A imagem da mesa volta ao padrão e as configurações de imagem, grade e área são apagadas. Os mapas continuam no Atlas."] =
    "Reset everything? The table image goes back to default and the image, grid and area settings are cleared. The maps stay in the Atlas.",
  ["Tudo resetado. Os mapas continuam no Atlas."] = "Everything reset. The maps stay in the Atlas.",
  ["Idioma"] = "Language",
  ["Página "] = "Page ",
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
    self.setColorTint({ 0.22, 0.14, 0.08 })
  end

  Wait.frames(function()
    cleanupLegacy()
    if D.origURL == nil then D.origURL = Tables.getCustomURL() or "" end
    if not D.area.manual then autoArea() end
    applyGrid()
    build()
  end, 10)
end

function onSave()
  return JSON.encode(D)
end

-- Remove o que versões antigas do Atlas deixavam na mesa (névoa, reveladores).
function cleanupLegacy()
  for _, tag in ipairs({ "Fog", "AtlasNevoa" }) do
    for _, o in ipairs(getObjectsWithTag(tag)) do o.destruct() end
  end
  for _, tag in ipairs({ "AtlasRevelador", "AtlasVisao" }) do
    for _, o in ipairs(getObjectsWithTag(tag)) do
      o.removeTag(tag)
      pcall(function() o.setFogOfWarReveal({ reveal = false }) end)
    end
  end
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

function gm(color)
  local p = Player[color]
  if p and (p.host or p.admin) then return p end
  say(color, tr("Só o mestre (host/admin) pode usar o Atlas."))
  return nil
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
  return o == self or o.hasTag("MapaTile") or o.hasTag("Fixo") or o.hasTag("AtlasMesa")
end

--------------------------------------------------------------------------
-- Área do mapa e superfície da mesa
--------------------------------------------------------------------------
-- Altura real do pano da mesa, lançando um raio de cima para baixo.
function surfaceY(x, z)
  local tableObj = Tables.getTableObject()
  local hits = Physics.cast({
    origin = { x = x, y = 60, z = z }, direction = { x = 0, y = -1, z = 0 },
    type = 1, max_distance = 120,
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
  if m and (m.fit == "caber" or m.fit == "preencher") then showMap(m) else applyGrid() end
end

function showArea()
  S.showingArea = true
  drawLines()
  Wait.time(function() S.showingArea = false; drawLines() end, 6)
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

-- Troca a imagem da mesa preservando as zonas de mão (como o Map changer da Workshop faz).
function setTableImage(url)
  local hands = {}
  for _, h in ipairs(Hands.getHands()) do table.insert(hands, h.getData()) end
  Tables.setCustomURL(url)
  Wait.frames(function()
    for _, h in ipairs(Hands.getHands()) do h.destruct() end
    for _, data in ipairs(hands) do spawnObjectData({ data = data }) end
  end, 1)
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
  if m.fit == "caber" or m.fit == "preencher" then
    spawnTile(m)
  else
    removeTile()
    setTableImage(m.url)
    applyGrid()
  end
end

--------------------------------------------------------------------------
-- Props e tokens de cada mapa
--------------------------------------------------------------------------
function storeObjects(keep)
  local a, list = D.area, {}
  for _, o in ipairs(getObjects()) do
    if not isOurs(o) and o.type ~= "Scripting" and o.type ~= "Hand" and o.type ~= "FogOfWar"
        and o.type ~= "FogOfWarTrigger" then
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
-- Mapas, pastas e páginas
--------------------------------------------------------------------------
function switchTo(i)
  local old = current()
  if old then old.objects = storeObjects() end
  D.current = i
  local m = D.maps[i]
  showMap(m)
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
    objects = {}, folder = S.folder,
  })
  S.sel = #D.maps
  S.page = math.max(1, math.ceil(#visibleMaps() / (THUMB_COLS * THUMB_ROWS)))
  build()
end

-- Mapas da pasta que está sendo vista (nil = todos).
function visibleMaps()
  local list = {}
  for i, m in ipairs(D.maps) do
    if S.folder == nil or m.folder == S.folder then table.insert(list, i) end
  end
  return list
end

function folderOptions(includeAll)
  local opts = {}
  if includeAll then table.insert(opts, tr("Todos os mapas")) end
  table.insert(opts, tr("Sem pasta"))
  for _, f in ipairs(D.folders) do table.insert(opts, f) end
  return opts
end

-- Texto escolhido no diálogo -> nome da pasta (nil = sem pasta); o segundo valor diz se foi "todos".
function folderFromOption(text)
  if text == tr("Todos os mapas") then return nil, true end
  if text == tr("Sem pasta") then return nil, false end
  return text, false
end

--------------------------------------------------------------------------
-- Grade: linhas por cima do mapa (planas ou seguindo o relevo) + encaixe nativo do TTS
--------------------------------------------------------------------------
function gridOf(m)
  m.grid = m.grid or {}
  local g = m.grid
  if g.size == nil then g.size = 1 end
  if g.snap == nil then g.snap = true end
  g.ox, g.oz = g.ox or 0, g.oz or 0
  g.alpha = g.alpha or 0.6
  g.color = g.color or 1
  g.stroke = g.stroke or 3
  return g
end

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
    if g.relief and not S.heights then requestRelief() end
  else
    Grid.snapping = 1
  end
  drawLines()
end

-- Cruzamentos da grade (inclui o deslocamento de alinhamento).
function gridNodes(g)
  local a = D.area
  local x0, x1 = a.x - a.w / 2, a.x + a.w / 2
  local z0, z1 = a.z - a.d / 2, a.z + a.d / 2
  local xs, zs = {}, {}
  local x = x0 + (g.ox or 0)
  while x <= x1 + 0.001 do table.insert(xs, x); x = x + g.size end
  local z = z0 + (g.oz or 0)
  while z <= z1 + 0.001 do table.insert(zs, z); z = z + g.size end
  return xs, zs
end

-- Relevo: um raio por cruzamento da grade, calculado aos poucos (corrotina) para não travar.
function requestRelief()
  S.heights = nil
  if S.reliefBusy then S.reliefAgain = true return end
  S.reliefBusy = true
  startLuaCoroutine(self, "reliefJob")
end

function reliefJob()
  local m = current()
  local g = m and m.grid
  if not (g and g.on and g.relief) then
    S.reliefBusy = false
    return 1
  end
  local xs, zs = gridNodes(g)
  local base = mapTopY()
  local tile = getTile()
  local tableObj = Tables.getTableObject()
  local heights = {}
  for i, x in ipairs(xs) do
    heights[i] = {}
    for j, z in ipairs(zs) do
      local h = base
      local hits = Physics.cast({
        origin = { x = x, y = base + 25, z = z }, direction = { x = 0, y = -1, z = 0 },
        type = 1, max_distance = 40,
      })
      for _, hit in ipairs(hits) do
        local o = hit.hit_object
        if o == tile or o == tableObj or (o.grid_projection and not isOurs(o)) then
          h = math.max(base, hit.point.y)
          break
        end
      end
      heights[i][j] = h + 0.03
    end
    if i % 4 == 0 then coroutine.yield(0) end
  end
  S.heights = heights
  S.reliefBusy = false
  drawLines()
  build()
  if S.reliefAgain then
    S.reliefAgain = false
    requestRelief()
  end
  return 1
end

function drawLines()
  local lines = {}
  local a = D.area
  local m = current()
  local g = m and m.grid
  if g and g.on then
    local c = GRID_COLORS[g.color or 1][3]
    local col = { c[1], c[2], c[3], g.alpha or 0.6 }
    local thick = GRID_STROKES[g.stroke or 3]
    local xs, zs = gridNodes(g)
    local flat = mapTopY() + 0.02
    local hs = (g.relief and S.heights and #S.heights == #xs) and S.heights or nil
    local function y(i, j) return hs and hs[i][j] or flat end
    for i, x in ipairs(xs) do
      local pts = {}
      for j, z in ipairs(zs) do table.insert(pts, { x, y(i, j), z }) end
      table.insert(lines, { points = pts, color = col, thickness = thick })
    end
    for j, z in ipairs(zs) do
      local pts = {}
      for i, x in ipairs(xs) do table.insert(pts, { x, y(i, j), z }) end
      table.insert(lines, { points = pts, color = col, thickness = thick })
    end
  end
  if S.showingArea then
    local yy = mapTopY() + 0.05
    local x0, x1 = a.x - a.w / 2, a.x + a.w / 2
    local z0, z1 = a.z - a.d / 2, a.z + a.d / 2
    table.insert(lines, {
      points = { { x0, yy, z0 }, { x1, yy, z0 }, { x1, yy, z1 }, { x0, yy, z1 }, { x0, yy, z0 } },
      color = { 1, 0.45, 0.1 }, thickness = 0.12,
    })
  end
  Global.setVectorLines(lines)
end

--------------------------------------------------------------------------
-- Resetar tudo: a mesa volta ao padrão; os mapas continuam guardados no Atlas
--------------------------------------------------------------------------
function resetAll()
  removeTile()
  cleanupLegacy()
  pcall(function() setTableImage(D.origURL or "") end)
  for _, m in ipairs(D.maps) do
    m.fit, m.zoom, m.ox, m.oz, m.rot = "mesa", 1, 0, 0, 0
    m.grid = nil
  end
  D.current = nil
  S.sel, S.pending, S.calib, S.heights = nil, nil, nil, nil
  Grid.snapping = 1
  Grid.show_lines = false
  autoArea()
  drawLines()
  build()
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
function t_area() setTab("area") end

-- Adicionar mapa por arquivo do PC (principal): o mestre escolhe a imagem no menu Custom do TTS,
-- que sobe para a Steam Cloud; depois dá um nome ao mapa.
function a_addFile(_, c)
  local p = gm(c)
  if not p then return end
  local a = D.area
  local tile = spawnObject({ type = "Custom_Tile", position = { a.x, a.y + 3, a.z }, scale = { 3, 1, 3 } })
  tile.setName(tr("Novo mapa: clique direito > Custom"))
  local guid = tile.getGUID()
  say(c, tr("Clique com o botão direito no tile no meio da mesa > Custom > escolha a imagem > Import. Aceite subir para a Cloud."))
  Wait.condition(function()
    local t = getObjectFromGUID(guid)
    local url = t.getCustomObject().image
    t.destruct()
    p.showInputDialog(tr("Nome do mapa"), tr("Mapa ") .. (#D.maps + 1), function(text)
      addMap(text, url)
      say(c, tr("Mapa adicionado!"))
    end)
  end, function()
    local t = getObjectFromGUID(guid)
    if not t or t.spawning then return false end
    local co = t.getCustomObject()
    return co and co.image and co.image ~= ""
  end, 600, function() say(c, tr("Tempo esgotado esperando a imagem. Tente de novo.")) end)
end

-- Adicionar por link (secundário)
function a_addLink(_, c)
  local p = gm(c)
  if not p then return end
  p.showInputDialog(tr("Cole o link da imagem (.jpg ou .png)"), "", function(url)
    url = trim(url)
    if url == "" then return end
    Wait.frames(function()
      p.showInputDialog(tr("Nome do mapa"), tr("Mapa ") .. (#D.maps + 1), function(text) addMap(text, url) end)
    end, 2)
  end)
end

-- Pastas
function a_pickFolder(_, c)
  local p = gm(c)
  if not p then return end
  p.showOptionsDialog(tr("Escolher pasta para ver"), folderOptions(true), function(text)
    local f, all = folderFromOption(text)
    S.folder = (not all) and f or nil
    S.page, S.sel = 1, nil
    build()
  end)
end

function a_newFolder(_, c)
  local p = gm(c)
  if not p then return end
  p.showInputDialog(tr("Nome da nova pasta"), "", function(text)
    local name = trim(text)
    if name == "" then return end
    for _, f in ipairs(D.folders) do
      if f == name then return say(c, tr("Já existe uma pasta com esse nome.")) end
    end
    table.insert(D.folders, name)
    S.folder, S.page, S.sel = name, 1, nil
    build()
  end)
end

-- Páginas
function a_prev() if S.page > 1 then S.page = S.page - 1; S.sel = nil; build() end end
function a_next()
  local pages = math.ceil(#visibleMaps() / (THUMB_COLS * THUMB_ROWS))
  if S.page < pages then S.page = S.page + 1; S.sel = nil; build() end
end

-- Miniaturas: clicar seleciona; clicar de novo no selecionado aplica na mesa
function thumb(n, c)
  if not gm(c) then return end
  local i = visibleMaps()[(S.page - 1) * THUMB_COLS * THUMB_ROWS + n]
  if not i then return end
  if S.sel == i then return switchTo(i) end
  S.sel = i
  build()
end
function m1(_, c) thumb(1, c) end
function m2(_, c) thumb(2, c) end
function m3(_, c) thumb(3, c) end
function m4(_, c) thumb(4, c) end
function m5(_, c) thumb(5, c) end
function m6(_, c) thumb(6, c) end

-- Mapa selecionado
function a_apply(_, c)
  if gm(c) and S.sel and D.maps[S.sel] then switchTo(S.sel) end
end

function a_rename(_, c)
  local p = gm(c)
  local m = S.sel and D.maps[S.sel]
  if not (p and m) then return end
  p.showInputDialog(tr("Novo nome do mapa"), m.name, function(text)
    text = trim(text)
    if text ~= "" then m.name = text; build() end
  end)
end

function a_move(_, c)
  local p = gm(c)
  local m = S.sel and D.maps[S.sel]
  if not (p and m) then return end
  p.showOptionsDialog(tr("Mover para qual pasta?"), folderOptions(false), function(text)
    m.folder = folderFromOption(text)
    build()
  end)
end

function a_delete(_, c)
  local p = gm(c)
  local i = S.sel
  local m = i and D.maps[i]
  if not (p and m) then return end
  p.showConfirmDialog(tr("Apagar o mapa \"") .. m.name .. tr("\"? (a imagem continua na sua Cloud)"), function()
    if i == D.current then
      storeObjects()
      removeTile()
      D.current = nil
      applyGrid()
    elseif D.current and i < D.current then
      D.current = D.current - 1
    end
    table.remove(D.maps, i)
    S.sel = nil
    build()
  end)
end

-- Estado (props e tokens)
function a_save(_, c)
  if not gm(c) then return end
  local m = current()
  if not m then return say(c, tr("Nenhum mapa ativo.")) end
  m.saved = storeObjects(true)
  say(c, tr("Estado salvo: ") .. #m.saved .. tr(" objetos."))
  build()
end

function a_restore(_, c)
  if not gm(c) then return end
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

-- Imagem
function setFit(c, fit)
  if not gm(c) then return end
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
  if not gm(c) then return end
  local m = current()
  if not m then return end
  if m.fit ~= "caber" and m.fit ~= "preencher" then
    return say(c, tr("Ajustes funcionam nos modos Caber e Preencher."))
  end
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
  if not gm(c) then return end
  local m = current()
  if not m then return say(c, tr("Nenhum mapa ativo.")) end
  local g = gridOf(m)
  if k == "on" then g.on = not g.on
  elseif k == "snap" then g.snap = not g.snap
  elseif k == "less" then g.size = math.max(GRID_STEP, g.size - GRID_STEP)
  elseif k == "more" then g.size = g.size + GRID_STEP
  elseif k == "light" then g.alpha = math.max(0.15, g.alpha - 0.15)
  elseif k == "dark" then g.alpha = math.min(1, g.alpha + 0.15)
  elseif k == "color" then g.color = g.color % #GRID_COLORS + 1
  elseif k == "thin" then g.stroke = math.max(1, g.stroke - 1)
  elseif k == "thick" then g.stroke = math.min(#GRID_STROKES, g.stroke + 1)
  elseif k == "relief" then g.relief = not g.relief
  else
    local dx = (k == "left" and -1) or (k == "right" and 1) or 0
    local dz = (k == "up" and 1) or (k == "down" and -1) or 0
    g.ox = (g.ox + dx * g.size / 4) % g.size
    g.oz = (g.oz + dz * g.size / 4) % g.size
  end
  -- mudou a geometria da grade: o relevo precisa ser recalculado
  if k ~= "snap" and k ~= "light" and k ~= "dark" and k ~= "color" and k ~= "thin" and k ~= "thick" then
    S.heights = nil
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
function g_color(_, c) grid(c, "color") end
function g_thin(_, c) grid(c, "thin") end
function g_thick(_, c) grid(c, "thick") end
function g_relief(_, c) grid(c, "relief") end
function g_left(_, c) grid(c, "left") end
function g_up(_, c) grid(c, "up") end
function g_down(_, c) grid(c, "down") end
function g_right(_, c) grid(c, "right") end

-- Área
function z_auto(_, c)
  if not gm(c) then return end
  autoArea()
  S.heights = nil
  afterAreaChange()
  build()
end
function z_show() showArea() end
function z_fix(_, c)
  local p = gm(c)
  if not p then return end
  local sel = p.getSelectedObjects()
  if #sel == 0 then return say(c, tr("Selecione objetos primeiro (arraste uma caixa ou Ctrl+clique).")) end
  for _, o in ipairs(sel) do
    if o ~= self then
      if o.hasTag("Fixo") then o.removeTag("Fixo") else o.addTag("Fixo") end
      say(c, (o.getName() ~= "" and o.getName() or o.type) .. (o.hasTag("Fixo") and tr(": fixo") or tr(": não é mais fixo")))
    end
  end
end
function z_calib(_, c)
  local p = gm(c)
  if not p then return end
  local step = S.calib and 2 or 1
  say(c, tr("Mire o mouse no canto ") .. step .. tr(" da área... (3s)"))
  Wait.time(function()
    local pt = p.getPointerPosition()
    if step == 1 then
      S.calib = pt
    else
      local c1 = S.calib
      D.area = {
        x = (c1.x + pt.x) / 2, z = (c1.z + pt.z) / 2,
        w = math.abs(pt.x - c1.x), d = math.abs(pt.z - c1.z), manual = true,
      }
      D.area.y = surfaceY(D.area.x, D.area.z)
      S.calib, S.heights = nil, nil
      afterAreaChange()
    end
    build()
  end, 3)
end

function z_reset(_, c)
  local p = gm(c)
  if not p then return end
  p.showConfirmDialog(tr("Resetar tudo? A imagem da mesa volta ao padrão e as configurações de imagem, grade e área são apagadas. Os mapas continuam no Atlas."),
    function()
      resetAll()
      say(c, tr("Tudo resetado. Os mapas continuam no Atlas."))
    end)
end

function l_pt(_, c) if gm(c) then D.lang = "pt"; self.setName(tr("Atlas do Mestre")); build() end end
function l_en(_, c) if gm(c) then D.lang = "en"; self.setName(tr("Atlas do Mestre")); build() end end

--------------------------------------------------------------------------
-- Desenho do painel sobre o tampo de couro
--------------------------------------------------------------------------
local CREAM = { 0.93, 0.89, 0.80 }
local MUTED = { 0.64, 0.60, 0.53 }
local GOLD = { 0.86, 0.68, 0.32 }
local DARK_TXT = { 0.12, 0.08, 0.04 }
local WALNUT = { 0.33, 0.21, 0.12 }
local SLATE = { 0.24, 0.25, 0.29 }
local BRASS = { 0.76, 0.56, 0.22 }
local TEAL = { 0.18, 0.40, 0.36 }
local BRICK = { 0.55, 0.22, 0.14 }
local CLEAR = { 0, 0, 0, 0 }

-- Coordenadas em unidades do mundo a partir do centro do tampo; z positivo = topo do painel.
-- No TTS o "para cima" do texto dos botões aponta para o -z local, então o z é invertido aqui.
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
    color = color or WALNUT, font_color = textColor or CREAM,
    hover_color = { 0.52, 0.38, 0.18 }, press_color = { 0.70, 0.52, 0.22 },
    tooltip = tip or "",
  })
end

function T(label, x, z, h, color)
  local pos, sc = place(x, z)
  self.createButton({
    label = label, click_function = "noop", function_owner = self,
    position = pos, scale = sc, width = 0, height = math.floor(h * U),
    font_size = math.floor(h * U * 0.62), font_color = color or CREAM, color = CLEAR,
  })
end

-- Botão invisível por cima de uma miniatura (para clicar nela)
function HOT(fn, x, z, w, h, tip)
  local pos, sc = place(x, z)
  self.createButton({
    label = "", click_function = fn, function_owner = self,
    position = pos, scale = sc, width = w * U, height = h * U,
    color = CLEAR, hover_color = { 1, 1, 1, 0.08 }, press_color = { 1, 1, 1, 0.15 },
    tooltip = tip or "",
  })
end

-- Miniatura do mapa desenhada no tampo (decal)
function decal(name, url, x, z, w, h)
  local s = self.getScale()
  local top = isModel() and (MODEL_TOP + 0.012) / s.y or (0.5 + 0.012 / s.y)
  return {
    name = name, url = url,
    position = { x / s.x, top, -z / s.z },
    rotation = DECAL_ROT,
    scale = { w / s.x, h / s.z, 1 },
  }
end

function build()
  self.clearButtons()
  local decals = {}
  local m = current()
  local W = INNER.w - 0.8
  local half = W / 2 - 0.06
  local third = W / 3 - 0.08
  local quarter = W / 4 - 0.08
  local x2 = { -W / 4, W / 4 }
  local x3 = { -W / 3, 0, W / 3 }
  local x4 = { -W * 3 / 8, -W / 8, W / 8, W * 3 / 8 }

  local z = INNER.d / 2 - 0.35
  local function line(h)
    local c = z - h / 2
    z = z - h - 0.12
    return c
  end
  local function gap(h) z = z - h end
  local function heading(text) T(text, -W / 2 + 0.05 + #text * 0.066, line(0.36), 0.36, GOLD) end
  local function on(flag) return flag and BRASS or WALNUT end
  local function onTxt(flag) return flag and DARK_TXT or CREAM end
  local function needMap()
    if m then return true end
    T(tr("Carregue um mapa na aba Mapas."), 0, line(0.4), 0.32, MUTED)
    return false
  end

  -- Cabeçalho
  T(tr("Atlas do Mestre"), 0, line(0.6), 0.6, GOLD)
  T(m and (tr("Mapa ativo: ") .. m.name) or tr("Nenhum mapa ativo"), 0, line(0.34), 0.34, MUTED)
  gap(0.05)
  local c = line(0.55)
  local tabs = { { "mapas", "Mapas" }, { "imagem", "Imagem" }, { "grade", "Grade" }, { "area", "Área" } }
  local tw = W / #tabs
  for k, t in ipairs(tabs) do
    local sel = S.tab == t[1]
    B(tr(t[2]), "t_" .. t[1], -W / 2 + tw * (k - 0.5), c, tw - 0.1, 0.55, sel and BRASS or SLATE, onTxt(sel))
  end
  gap(0.2)

  if S.tab == "mapas" then
    c = line(0.6)
    B(tr("+ Arquivo do PC"), "a_addFile", -W / 2 + W * 0.36, c, W * 0.72 - 0.06, 0.6, BRASS, DARK_TXT,
      tr("Escolher uma imagem do computador (sobe para a sua Steam Cloud)"))
    B(tr("Link"), "a_addLink", W / 2 - W * 0.14, c, W * 0.28 - 0.06, 0.6, SLATE, MUTED,
      tr("Adicionar por link da web (.jpg / .png)"))
    c = line(0.5)
    B(tr("Pasta: ") .. (S.folder or tr("Todos os mapas")), "a_pickFolder", -W / 2 + W * 0.36, c, W * 0.72 - 0.06, 0.5,
      WALNUT, CREAM, tr("Escolher pasta para ver"))
    B(tr("+ Pasta"), "a_newFolder", W / 2 - W * 0.14, c, W * 0.28 - 0.06, 0.5, WALNUT)
    gap(0.08)

    -- Miniaturas (2 colunas x 3 linhas por página)
    local list = visibleMaps()
    local perPage = THUMB_COLS * THUMB_ROWS
    local pages = math.max(1, math.ceil(#list / perPage))
    if S.page > pages then S.page = pages end
    local colX = { -W / 4, W / 4 }
    local cellH = THUMB_H + 0.42 + 0.14
    local gridTop = z
    for n = 1, perPage do
      local i = list[(S.page - 1) * perPage + n]
      local col = (n - 1) % THUMB_COLS + 1
      local rowN = math.floor((n - 1) / THUMB_COLS)
      local cy = gridTop - rowN * cellH - THUMB_H / 2
      if i then
        local mp = D.maps[i]
        local sel, active = S.sel == i, D.current == i
        table.insert(decals, decal("mapa" .. n, mp.url, colX[col], cy, THUMB_W, THUMB_H))
        HOT("m" .. n, colX[col], cy, THUMB_W, THUMB_H, mp.name)
        local label = mp.name .. (active and ("  (" .. tr("na mesa") .. ")") or "") .. (mp.saved and "  *" or "")
        B(label, "m" .. n, colX[col], cy - THUMB_H / 2 - 0.25, THUMB_W, 0.4,
          sel and BRASS or (active and TEAL or SLATE), sel and DARK_TXT or CREAM, mp.name)
      elseif n == 1 then
        T(tr("Nenhum mapa aqui. Use + Arquivo do PC."), 0, cy, 0.32, MUTED)
      end
    end
    z = gridTop - THUMB_ROWS * cellH - 0.05
    c = line(0.45)
    B("<", "a_prev", -W / 3, c, 1.0, 0.45, SLATE)
    T(tr("Página ") .. S.page .. " / " .. pages, 0, c, 0.3, MUTED)
    B(">", "a_next", W / 3, c, 1.0, 0.45, SLATE)
    gap(0.05)

    c = line(0.55)
    if S.sel and D.maps[S.sel] then
      B(tr("Aplicar na mesa"), "a_apply", x4[1] + quarter / 2 + 0.04, c, quarter * 2 + 0.08, 0.55, BRASS, DARK_TXT)
      B(tr("Renomear"), "a_rename", x4[3], c, quarter, 0.55)
      B(tr("Mover"), "a_move", x4[4] - quarter / 4 - 0.02, c, quarter / 2 - 0.04, 0.55)
      B(tr("Apagar"), "a_delete", x4[4] + quarter / 4 + 0.02, c, quarter / 2 - 0.04, 0.55, BRICK)
    else
      T(tr("Selecione um mapa para aplicar, renomear ou mover."), 0, c, 0.3, MUTED)
    end
    c = line(0.5)
    B(tr("Salvar estado"), "a_save", x2[1], c, half, 0.5, TEAL, CREAM, tr("Guarda a posição dos props e tokens neste mapa"))
    B(S.pending == "restore" and tr("Confirmar?") or tr("Restaurar"), "a_restore", x2[2], c, half, 0.5, BRICK, CREAM,
      tr("Volta ao último estado salvo"))

  elseif S.tab == "imagem" then
    if needMap() then
      local main = m.fit ~= "caber" and m.fit ~= "preencher"
      c = line(0.7)
      B(tr("Encaixar na mesa"), "f_mesa", 0, c, W, 0.7, on(main), onTxt(main),
        tr("A imagem vai direto na parte customizável da mesa (recomendado)"))
      gap(0.3)
      heading(tr("Avançado: imagem sobre a área"))
      c = line(0.5)
      B(tr("Caber"), "f_caber", x2[1], c, half, 0.5, on(m.fit == "caber"), onTxt(m.fit == "caber"),
        tr("Imagem inteira, mantendo a proporção"))
      B(tr("Preencher"), "f_preencher", x2[2], c, half, 0.5, on(m.fit == "preencher"), onTxt(m.fit == "preencher"),
        tr("Cobre a área toda"))
      c = line(0.5)
      B(tr("Zoom -"), "j_zout", x3[1], c, third, 0.5, SLATE)
      B(tr("Zoom +"), "j_zin", x3[2], c, third, 0.5, SLATE)
      B(tr("Girar 90"), "j_rot", x3[3], c, third, 0.5, SLATE)
      c = line(0.5)
      B("<", "j_left", x4[1], c, quarter, 0.5, SLATE)
      B("^", "j_up", x4[2], c, quarter, 0.5, SLATE)
      B("v", "j_down", x4[3], c, quarter, 0.5, SLATE)
      B(">", "j_right", x4[4], c, quarter, 0.5, SLATE)
      c = line(0.45)
      B(tr("Resetar ajuste"), "j_reset", 0, c, W, 0.45, SLATE, MUTED)
    end

  elseif S.tab == "grade" then
    if needMap() then
      local g = gridOf(m)
      c = line(0.55)
      B(g.on and tr("Grade: ligada") or tr("Grade: desligada"), "g_on", x2[1], c, half, 0.55, on(g.on), onTxt(g.on))
      B(g.snap and tr("Encaixe: ligado") or tr("Encaixe: desligado"), "g_snap", x2[2], c, half, 0.55, on(g.snap),
        onTxt(g.snap), tr("Peças encaixam no centro dos quadrados"))
      gap(0.1)
      heading(tr("Tamanho do quadrado"))
      c = line(0.5)
      B("-", "g_less", x3[1], c, third, 0.5)
      T(tostring(g.size), x3[2], c, 0.4)
      B("+", "g_more", x3[3], c, third, 0.5)
      heading(tr("Cor e espessura"))
      local colorName = D.lang == "en" and GRID_COLORS[g.color][2] or GRID_COLORS[g.color][1]
      c = line(0.5)
      B(tr("Cor: ") .. colorName, "g_color", x3[1], c, third, 0.5)
      B(tr("Linha -"), "g_thin", x3[2], c, third, 0.5)
      B(tr("Linha +"), "g_thick", x3[3], c, third, 0.5)
      c = line(0.5)
      B(tr("Mais clara"), "g_light", x2[1], c, half, 0.5, SLATE)
      B(tr("Mais escura"), "g_dark", x2[2], c, half, 0.5, SLATE)
      heading(tr("Alinhar com o desenho do mapa"))
      c = line(0.5)
      B("<", "g_left", x4[1], c, quarter, 0.5, SLATE)
      B("^", "g_up", x4[2], c, quarter, 0.5, SLATE)
      B("v", "g_down", x4[3], c, quarter, 0.5, SLATE)
      B(">", "g_right", x4[4], c, quarter, 0.5, SLATE)
      gap(0.1)
      c = line(0.55)
      local busy = g.relief and S.reliefBusy
      B(busy and tr("Calculando relevo...") or (g.relief and tr("Seguir relevo: ligado") or tr("Seguir relevo: desligado")),
        "g_relief", 0, c, W, 0.55, on(g.relief), onTxt(g.relief), tr("As linhas sobem por cima de props e terrenos 3D"))
    end

  elseif S.tab == "area" then
    heading(tr("Área do mapa na mesa"))
    T(string.format("%.1f x %.1f  (%s)", D.area.w, D.area.d, D.area.manual and tr("calibrada") or tr("automática")),
      0, line(0.35), 0.32)
    c = line(0.55)
    B(tr("Detectar"), "z_auto", x2[1], c, half, 0.55, WALNUT, CREAM, tr("Detecta a área customizável pela própria mesa"))
    B(S.calib and tr("Canto 2...") or tr("Calibrar"), "z_calib", x2[2], c, half, 0.55, on(S.calib ~= nil),
      onTxt(S.calib ~= nil), tr("Clique e mire o mouse no canto da área em 3s"))
    c = line(0.55)
    B(tr("Mostrar área"), "z_show", x2[1], c, half, 0.55)
    B(tr("Fixar selecionados"), "z_fix", x2[2], c, half, 0.55, WALNUT, CREAM, tr("Objetos fixos não trocam com o mapa"))
    gap(0.25)
    heading(tr("Idioma") .. " / Language")
    c = line(0.55)
    B("Português", "l_pt", x2[1], c, half, 0.55, on(D.lang ~= "en"), onTxt(D.lang ~= "en"))
    B("English", "l_en", x2[2], c, half, 0.55, on(D.lang == "en"), onTxt(D.lang == "en"))
    gap(0.25)
    heading(tr("Manutenção"))
    c = line(0.55)
    B(tr("Resetar tudo"), "z_reset", 0, c, W, 0.55, BRICK, CREAM, tr("Volta a mesa ao padrão; os mapas do Atlas continuam guardados"))
  end

  self.setDecals(decals)
end
