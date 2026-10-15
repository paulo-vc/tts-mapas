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
  pending = nil, calib = nil, brush = nil, brushRadius = 1.5, showingArea = false,
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
-- Ciclo de vida
--------------------------------------------------------------------------
function onLoad(saved)
  if saved and saved ~= "" then
    local ok, t = pcall(JSON.decode, saved)
    if ok and type(t) == "table" and t.area then D = t end
  end
  D.maps = D.maps or {}
  D.folders = D.folders or {}
  self.setName("Atlas do Mestre")
  self.addTag("Fixo")
  self.addTag("AtlasMesa")

  if isModel() then
    self.setScale({ 1, 1, 1 })
  else
    self.setScale({ INNER.w + 0.8, 0.3, INNER.d + 0.8 })
    self.setColorTint({ 0.36, 0.23, 0.12 })
  end

  addHotkey("Atlas: revelar névoa (segure)", function(color, _, _, up) hotkeyBrush(color, up, true) end, true)
  addHotkey("Atlas: cobrir névoa (segure)", function(color, _, _, up) hotkeyBrush(color, up, false) end, true)

  Wait.frames(function()
    if not D.area.manual then autoArea() end
    applyGrid()
    buildFog()
    build()
    Wait.time(visionTick, 0.25, -1)
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
  say(color, "Só o mestre (host/admin) pode usar o Atlas.")
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
  return o == self or o.hasTag("MapaTile") or o.hasTag("Fog") or o.hasTag("Fixo") or o.hasTag("AtlasMesa")
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
  buildFog()
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
      obj.setName("Mapa: " .. m.name)
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
  stopBrush()
  D.current = i
  local m = D.maps[i]
  showMap(m)
  buildFog()
  Wait.frames(function()
    spawnStored(m.objects)
    m.objects = {}
  end, 15)
  S.pending = nil
  build()
end

function addMap(name, url)
  name = trim(name)
  if name == "" then name = "Mapa " .. (#D.maps + 1) end
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
-- Névoa: Hidden Zones rentes ao mapa (sem colisão; o dono enxerga através).
-- Para não pesar, células cobertas vizinhas na mesma linha viram UMA zona (uma "faixa"),
-- as zonas são criadas aos poucos (algumas por frame) e só as linhas que mudaram são refeitas.
--------------------------------------------------------------------------
fogRows = {}                 -- linha j -> lista de faixas { i0, i1, obj, dead }
local spawnQueue, pumping = {}, false
local SPAWN_PER_FRAME = 6

function fogOf(m)
  m = m or current()
  if not m then return nil end
  m.fog = m.fog or { on = false, cell = 2, open = {}, owner = "Black" }
  m.fog.open = m.fog.open or {}
  return m.fog
end

function fogGrid(f)
  local a = D.area
  local nx = math.max(1, math.ceil(a.w / f.cell))
  local nz = math.max(1, math.ceil(a.d / f.cell))
  return nx, nz, a.w / nx, a.d / nz
end

function cellCenter(i, j, cw, cd)
  local a = D.area
  return a.x - a.w / 2 + (i - 0.5) * cw, a.z - a.d / 2 + (j - 0.5) * cd
end

-- Faixa de células (i0..i1, j0..j1) que um círculo de raio r em volta de p pode tocar.
function cellRange(p, r, nx, nz, cw, cd)
  local a = D.area
  local x0, z0 = a.x - a.w / 2, a.z - a.d / 2
  local i0 = math.max(1, math.floor((p.x - r - x0) / cw) + 1)
  local i1 = math.min(nx, math.floor((p.x + r - x0) / cw) + 1)
  local j0 = math.max(1, math.floor((p.z - r - z0) / cd) + 1)
  local j1 = math.min(nz, math.floor((p.z + r - z0) / cd) + 1)
  return i0, i1, j0, j1
end

function pumpSpawns()
  local n = 0
  while #spawnQueue > 0 and n < SPAWN_PER_FRAME do
    local r = table.remove(spawnQueue, 1)
    if not r.dead then
      r.obj = spawnObject({
        type = "FogOfWar", position = r.pos, scale = r.scale, sound = false,
        callback_function = function(o)
          o.setValue(r.owner)
          o.addTag("Fog")
        end,
      })
      n = n + 1
    end
  end
  if #spawnQueue > 0 then Wait.frames(pumpSpawns, 1) else pumping = false end
end

function enqueue(r)
  table.insert(spawnQueue, r)
  if not pumping then
    pumping = true
    Wait.frames(pumpSpawns, 1)
  end
end

function killRun(r)
  r.dead = true
  if r.obj then r.obj.destruct() end
  r.obj = nil
end

function clearFog()
  for _, runs in pairs(fogRows) do
    for _, r in ipairs(runs) do killRun(r) end
  end
  for _, r in ipairs(spawnQueue) do r.dead = true end
  spawnQueue = {}
  fogRows = {}
  for _, o in ipairs(getObjectsWithTag("Fog")) do o.destruct() end
end

function isCovered(f, key)
  return not f.open[key] and not (S.seen and S.seen[key])
end

-- Refaz só o que mudou numa linha: mantém as faixas iguais, apaga as que sumiram, cria as novas.
function syncRow(f, j, nx, cw, cd)
  local want, i = {}, 1
  while i <= nx do
    if isCovered(f, i .. ":" .. j) then
      local i0 = i
      while i <= nx and isCovered(f, i .. ":" .. j) do i = i + 1 end
      table.insert(want, { i0, i - 1 })
    else
      i = i + 1
    end
  end
  local byKey = {}
  for _, r in ipairs(fogRows[j] or {}) do byKey[r.i0 .. "," .. r.i1] = r end
  local a, rows = D.area, {}
  for _, w in ipairs(want) do
    local k = w[1] .. "," .. w[2]
    local r = byKey[k]
    if r then
      byKey[k] = nil
    else
      local width = (w[2] - w[1] + 1) * cw
      local x = a.x - a.w / 2 + (w[1] - 1) * cw + width / 2
      local _, z = cellCenter(1, j, cw, cd)
      r = {
        i0 = w[1], i1 = w[2], owner = f.owner or "Black",
        pos = { x, a.y + FOG_HEIGHT / 2 - 0.05, z },
        scale = { width, FOG_HEIGHT, cd },
      }
      enqueue(r)
    end
    table.insert(rows, r)
  end
  for _, r in pairs(byKey) do killRun(r) end
  fogRows[j] = rows
end

function syncRows(f, dirty)
  local nx, _, cw, cd = fogGrid(f)
  for j in pairs(dirty) do syncRow(f, j, nx, cw, cd) end
end

function buildFog()
  clearFog()
  S.seen, S.poses, S.coneSig = {}, {}, nil
  local f = current() and current().fog
  if not (f and f.on) then return end
  local nx, nz, cw, cd = fogGrid(f)
  for j = 1, nz do syncRow(f, j, nx, cw, cd) end
end

function paintFog(pos, open, radius)
  local f = fogOf()
  if not (f and f.on and pos) then return end
  local nx, nz, cw, cd = fogGrid(f)
  local reach = (radius or S.brushRadius) + math.max(cw, cd) / 2
  local i0, i1, j0, j1 = cellRange(pos, reach, nx, nz, cw, cd)
  local dirty = {}
  for i = i0, i1 do
    for j = j0, j1 do
      local x, z = cellCenter(i, j, cw, cd)
      local dx, dz = x - pos.x, z - pos.z
      if dx * dx + dz * dz <= reach * reach then
        local key = i .. ":" .. j
        if open and not f.open[key] then
          f.open[key] = true
          dirty[j] = true
        elseif not open and f.open[key] then
          f.open[key] = nil
          dirty[j] = true
        end
      end
    end
  end
  if next(dirty) then syncRows(f, dirty) end
end

--------------------------------------------------------------------------
-- Tokens que mexem na névoa
--   Revelador: limpa a névoa de forma permanente num raio em volta dele.
--   Visão em cone (modo sobrevivência): só enxerga um cone à frente; a névoa volta quando o cone sai.
-- As configurações ficam no próprio objeto (tags + memo), então sobrevivem à troca de mapa.
-- Obs.: Hidden Zones não mudam por jogador, então a visão aberta vale para todos os jogadores.
--------------------------------------------------------------------------
local TAG_REVEAL, TAG_CONE = "AtlasRevelador", "AtlasVisao"
local DEFAULT_VISION = { range = 6, angle = 90, rot = 0, radius = 2 }

function visionOf(o)
  local ok, t = pcall(JSON.decode, o.memo or "")
  t = (ok and type(t) == "table") and t or {}
  for k, v in pairs(DEFAULT_VISION) do if t[k] == nil then t[k] = v end end
  return t
end

function setVision(o, t) o.memo = JSON.encode(t) end

-- "Pose" arredondada do token: se não mudou desde a última vez, não há nada a recalcular.
function poseOf(o)
  local p, r = o.getPosition(), o.getRotation()
  return string.format("%.1f|%.1f|%d|%s", p.x, p.z, math.floor(r.y / 5), o.memo or "")
end

-- Células que um token com visão enxerga agora: um cone à frente + um círculo pequeno em volta.
function coneCells(o, v, f, set)
  local nx, nz, cw, cd = fogGrid(f)
  local p = o.getPosition()
  local fw = o.getTransformForward()
  local a = math.rad(v.rot or 0)
  local fx = fw.x * math.cos(a) - fw.z * math.sin(a)
  local fz = fw.x * math.sin(a) + fw.z * math.cos(a)
  local len = math.sqrt(fx * fx + fz * fz)
  if len < 1e-6 then fx, fz, len = 0, 1, 1 end
  fx, fz = fx / len, fz / len
  local cosHalf = math.cos(math.rad(v.angle / 2))
  local near = math.max(cw, cd) * 0.75
  local i0, i1, j0, j1 = cellRange(p, v.range + math.max(cw, cd), nx, nz, cw, cd)
  for i = i0, i1 do
    for j = j0, j1 do
      local x, z = cellCenter(i, j, cw, cd)
      local dx, dz = x - p.x, z - p.z
      local dist = math.sqrt(dx * dx + dz * dz)
      if dist <= near or (dist <= v.range and (dx * fx + dz * fz) / dist >= cosHalf) then
        set[i .. ":" .. j] = true
      end
    end
  end
end

function visionTick()
  local m = current()
  local f = m and m.fog
  if not (f and f.on) then return end
  S.poses = S.poses or {}

  -- Reveladores: só pintam quando se mexem (e não enquanto estão na mão de alguém).
  for _, o in ipairs(getObjectsWithTag(TAG_REVEAL)) do
    local p = o.getPosition()
    if inArea(p) and not o.held_by_color then
      local pose = poseOf(o)
      if S.poses[o.getGUID()] ~= pose then
        S.poses[o.getGUID()] = pose
        paintFog(p, true, visionOf(o).radius)
      end
    end
  end

  if not f.survival then return end

  -- Cones: só recalcula se algum token com visão mexeu, girou ou mudou de ajuste.
  local cones, sig = {}, {}
  for _, o in ipairs(getObjectsWithTag(TAG_CONE)) do
    if inArea(o.getPosition()) then
      table.insert(cones, o)
      table.insert(sig, o.getGUID() .. "=" .. poseOf(o))
    end
  end
  table.sort(sig)
  sig = table.concat(sig, ";")
  if sig == S.coneSig then return end
  S.coneSig = sig

  local visible = {}
  for _, o in ipairs(cones) do coneCells(o, visionOf(o), f, visible) end
  local dirty = {}
  S.seen = S.seen or {}
  for key in pairs(visible) do
    if not f.open[key] and not S.seen[key] then
      S.seen[key] = true
      dirty[tonumber(key:match(":(%d+)"))] = true
    end
  end
  for key in pairs(S.seen) do
    if not visible[key] then
      S.seen[key] = nil
      dirty[tonumber(key:match(":(%d+)"))] = true
    end
  end
  if next(dirty) then syncRows(f, dirty) end
end

-- Aplica uma mudança em todos os objetos selecionados (exceto o próprio Atlas).
function eachSelected(c, fn)
  local sel = Player[c].getSelectedObjects()
  local n = 0
  for _, o in ipairs(sel) do
    if o ~= self and not o.hasTag("Fog") and not o.hasTag("MapaTile") then
      fn(o)
      n = n + 1
    end
  end
  if n == 0 then say(c, "Selecione um token ou prop primeiro (clique nele, ou arraste uma caixa).") end
  return n
end

function startBrush(color, open)
  stopBrush()
  local id = Wait.time(function()
    local p = Player[color]
    if p and p.seated then paintFog(p.getPointerPosition(), open) end
  end, 0.1, -1)
  S.brush = { color = color, open = open, waitId = id }
end

function stopBrush()
  if S.brush then Wait.stop(S.brush.waitId) end
  S.brush = nil
end

function hotkeyBrush(color, up, open)
  local p = Player[color]
  if not (p and (p.host or p.admin)) then return end
  if up then
    stopBrush()
    build()
  elseif fogOf() and fogOf().on then
    startBrush(color, open)
  else
    say(color, "Ligue a névoa primeiro (aba Névoa).")
  end
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
  if url == "" then return say(c, "Cole o link da imagem (.jpg ou .png).") end
  addMap(S.newName, url)
end

-- Arquivo do PC: o mestre escolhe a imagem no menu Custom do TTS (que sobe para a Cloud).
function a_addFile(_, c)
  if not isGM(c) then return end
  local name, a = S.newName, D.area
  local tile = spawnObject({ type = "Custom_Tile", position = { a.x, a.y + 3, a.z }, scale = { 3, 1, 3 } })
  tile.setName("Novo mapa: clique direito > Custom")
  local guid = tile.getGUID()
  say(c, "Clique com o botão direito no tile no meio da mesa > Custom > escolha a imagem > Import. Aceite subir para a Cloud.")
  Wait.condition(function()
    local t = getObjectFromGUID(guid)
    local url = t.getCustomObject().image
    t.destruct()
    addMap(name, url)
    say(c, "Mapa adicionado!")
  end, function()
    local t = getObjectFromGUID(guid)
    if not t or t.spawning then return false end
    local co = t.getCustomObject()
    return co and co.image and co.image ~= ""
  end, 600, function() say(c, "Tempo esgotado esperando a imagem. Tente de novo.") end)
end

function a_newFolder(_, c)
  if not isGM(c) then return end
  local name = trim(S.newName)
  if name == "" then return say(c, "Digite o nome da pasta no campo Nome.") end
  for _, f in ipairs(D.folders) do
    if f == name then return say(c, "Já existe uma pasta com esse nome.") end
  end
  table.insert(D.folders, name)
  S.newName = ""
  build()
end

function a_moveHere(_, c)
  if not isGM(c) then return end
  local m = current()
  if not m then return say(c, "Nenhum mapa ativo.") end
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
  if not m then return say(c, "Nenhum mapa ativo.") end
  m.saved = storeObjects(true)
  say(c, "Estado de \"" .. m.name .. "\" salvo (" .. #m.saved .. " objetos).")
  build()
end

function a_restore(_, c)
  if not isGM(c) then return end
  local m = current()
  if not (m and m.saved) then return say(c, "Este mapa ainda não tem estado salvo.") end
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
        stopBrush()
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
  if m.fit == "mesa" then return say(c, "Ajustes funcionam nos modos Caber e Preencher.") end
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
  if not m then return say(c, "Nenhum mapa ativo.") end
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
  if not f then return say(c, "Nenhum mapa ativo.") end
  if k == "on" then
    f.on, f.owner = not f.on, c
    if not f.on then stopBrush() end
    buildFog()
  elseif k == "cover" then
    f.on, f.open, f.owner = true, {}, c
    buildFog()
  elseif k == "clear" then
    local nx, nz = fogGrid(f)
    for i = 1, nx do for j = 1, nz do f.open[i .. ":" .. j] = true end end
    buildFog()
  elseif k == "reveal" or k == "hide" then
    if not f.on then return say(c, "Ligue a névoa primeiro.") end
    local open = (k == "reveal")
    if S.brush and S.brush.open == open then stopBrush() else startBrush(c, open) end
  elseif k == "rless" then S.brushRadius = math.max(0.5, S.brushRadius - 0.5)
  elseif k == "rmore" then S.brushRadius = S.brushRadius + 0.5
  else
    local new = math.max(0.5, f.cell + (k == "cmore" and 0.5 or -0.5))
    if next(f.open) and S.pending ~= "cell" then
      S.pending = "cell"
      return build()
    end
    S.pending = nil
    f.cell, f.open = new, {}
    buildFog()
  end
  build()
end
function n_on(_, c) fog(c, "on") end
function n_cover(_, c) fog(c, "cover") end
function n_clear(_, c) fog(c, "clear") end
function n_reveal(_, c) fog(c, "reveal") end
function n_hide(_, c) fog(c, "hide") end
function n_rless(_, c) fog(c, "rless") end
function n_rmore(_, c) fog(c, "rmore") end
function n_cless(_, c) fog(c, "cless") end
function n_cmore(_, c) fog(c, "cmore") end

-- Tokens da névoa
function n_surv(_, c)
  if not isGM(c) then return end
  local f = fogOf()
  if not f then return say(c, "Nenhum mapa ativo.") end
  f.survival = not f.survival
  buildFog()
  build()
end

function markTokens(c, tag, other, label)
  if not isGM(c) then return end
  eachSelected(c, function(o)
    if o.hasTag(tag) then
      o.removeTag(tag)
      say(c, (o.getName() ~= "" and o.getName() or o.type) .. ": não é mais " .. label)
    else
      o.removeTag(other)
      o.addTag(tag)
      setVision(o, visionOf(o))
      say(c, (o.getName() ~= "" and o.getName() or o.type) .. ": " .. label)
    end
  end)
  build()
end
function v_reveal(_, c) markTokens(c, TAG_REVEAL, TAG_CONE, "revelador") end
function v_cone(_, c) markTokens(c, TAG_CONE, TAG_REVEAL, "visão em cone") end

function v_clear(_, c)
  if not isGM(c) then return end
  eachSelected(c, function(o)
    o.removeTag(TAG_REVEAL)
    o.removeTag(TAG_CONE)
  end)
  build()
end

-- Ajustes valem para os tokens selecionados (revelador usa o raio; cone usa alcance, ângulo e direção).
function tune(c, fn)
  if not isGM(c) then return end
  local last
  eachSelected(c, function(o)
    local v = visionOf(o)
    fn(v, o.hasTag(TAG_CONE))
    setVision(o, v)
    last = v
  end)
  S.lastVision = last or S.lastVision
  build()
end
function v_rless(_, c) tune(c, function(v, cone)
  if cone then v.range = math.max(1, v.range - 1) else v.radius = math.max(0.5, v.radius - 0.5) end end) end
function v_rmore(_, c) tune(c, function(v, cone)
  if cone then v.range = v.range + 1 else v.radius = v.radius + 0.5 end end) end
function v_aless(_, c) tune(c, function(v) v.angle = math.max(20, v.angle - 15) end) end
function v_amore(_, c) tune(c, function(v) v.angle = math.min(360, v.angle + 15) end) end
function v_rot(_, c) tune(c, function(v) v.rot = ((v.rot or 0) + 90) % 360 end) end

-- Área
function z_auto(_, c)
  if not isGM(c) then return end
  autoArea()
  afterAreaChange()
  build()
end
function z_show() showArea() end
function z_fix(_, c)
  if not isGM(c) then return end
  local sel = Player[c].getSelectedObjects()
  if #sel == 0 then return say(c, "Selecione objetos primeiro (arraste uma caixa ou Ctrl+clique).") end
  for _, o in ipairs(sel) do
    if o ~= self then
      if o.hasTag("Fixo") then o.removeTag("Fixo") else o.addTag("Fixo") end
      say(c, (o.getName() ~= "" and o.getName() or o.type) .. (o.hasTag("Fixo") and ": fixo" or ": não é mais fixo"))
    end
  end
end
function z_calib(_, c)
  if not isGM(c) then return end
  local step = S.calib and 2 or 1
  say(c, "Mire o mouse no canto " .. step .. " da área... (3s)")
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
    T("Carregue um mapa na aba Mapas.", 0, line(0.4), 0.32, MUTED)
    return false
  end

  -- Cabeçalho
  T("Atlas do Mestre", 0, line(0.6), 0.6, WINE_TXT)
  T(m and ("Mapa ativo: " .. m.name) or "Nenhum mapa ativo", 0, line(0.36), 0.36, MUTED)
  gap(0.05)

  -- Abas
  local c = line(0.55)
  local tabs = { { "mapas", "Mapas" }, { "imagem", "Imagem" }, { "grade", "Grade" }, { "nevoa", "Névoa" }, { "area", "Área" } }
  local tw = W / #tabs
  for k, t in ipairs(tabs) do
    local sel = S.tab == t[1]
    B(t[2], "t_" .. t[1], -W / 2 + tw * (k - 0.5), c, tw - 0.08, 0.55, sel and WINE or LEATHER_SOFT, PARCH_TXT)
  end
  gap(0.2)

  if S.tab == "mapas" then
    I("in_name", "Nome do mapa ou da pasta", S.newName, 0, line(0.5), W, 0.5)
    I("in_url", "Link da imagem (.jpg / .png)", S.newUrl, 0, line(0.5), W, 0.5)
    c = line(0.5)
    B("+ Link", "a_addLink", x2[1], c, half, 0.5, MOSS, PARCH_TXT, "Adiciona o mapa do link")
    B("+ Arquivo do PC", "a_addFile", x2[2], c, half, 0.5, MOSS, PARCH_TXT, "Escolher uma imagem do computador")
    c = line(0.5)
    B("+ Pasta", "a_newFolder", x2[1], c, half, 0.5, LEATHER, PARCH_TXT, "Cria uma pasta com o nome digitado")
    B("Mover mapa p/ cá", "a_moveHere", x2[2], c, half, 0.5, LEATHER, PARCH_TXT, "Move o mapa ativo para a pasta aberta")
    gap(0.05)
    heading(D.openFolder and ("Pasta: " .. D.openFolder) or "Seus mapas")

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
          B("< Voltar", "r" .. n, 0, rc, W, 0.46, LEATHER_SOFT)
        elseif e.kind == "folder" then
          local confirm = S.pending == ("folder:" .. e.fi)
          B("Pasta: " .. e.name .. "   (" .. e.count .. ")", "r" .. n, nx, rc, nameW, 0.46, LEATHER_SOFT, PARCH_TXT,
            "Clique para abrir")
          B(confirm and "?" or "x", "x" .. n, W / 2 - 0.27, rc, 0.54, 0.46, BRICK, PARCH_TXT,
            confirm and "Clique de novo para apagar a pasta" or "Apagar pasta")
        else
          local mp = D.maps[e.i]
          local sel = e.i == D.current
          local confirm = S.pending == ("map:" .. e.i)
          B(mp.name .. (mp.saved and "  *" or ""), "r" .. n, nx, rc, nameW, 0.46, sel and WINE or LEATHER, PARCH_TXT,
            "Clique para carregar   |   * = tem estado salvo")
          B(confirm and "?" or "x", "x" .. n, W / 2 - 0.27, rc, 0.54, 0.46, BRICK, PARCH_TXT,
            confirm and "Clique de novo para apagar" or "Apagar mapa")
        end
      elseif n == 1 then
        T("Nenhum mapa ainda. Adicione um acima.", 0, rc, 0.3, MUTED)
      end
    end
    c = line(0.45)
    B("<", "a_prev", -W / 3, c, 1.0, 0.45)
    T(S.page .. " / " .. pages, 0, c, 0.3, MUTED)
    B(">", "a_next", W / 3, c, 1.0, 0.45)
    gap(0.05)
    c = line(0.5)
    B("Salvar estado", "a_save", x2[1], c, half, 0.5, MOSS, PARCH_TXT, "Guarda a posição dos props e tokens neste mapa")
    B(S.pending == "restore" and "Confirmar?" or "Restaurar", "a_restore", x2[2], c, half, 0.5, BRICK, PARCH_TXT,
      "Volta ao último estado salvo")

  elseif S.tab == "imagem" then
    if needMap() then
      heading("Como exibir")
      c = line(0.55)
      B("Na mesa", "f_mesa", x3[1], c, third, 0.55, on(m.fit == "mesa"), PARCH_TXT, "Imagem direto na parte customizável da mesa")
      B("Caber", "f_caber", x3[2], c, third, 0.55, on(m.fit == "caber"), PARCH_TXT, "Imagem inteira, mantendo a proporção")
      B("Preencher", "f_preencher", x3[3], c, third, 0.55, on(m.fit == "preencher"), PARCH_TXT, "Cobre a área toda")
      gap(0.15)
      heading("Ajuste fino (Caber / Preencher)")
      c = line(0.55)
      B("Zoom -", "j_zout", x3[1], c, third, 0.55)
      B("Zoom +", "j_zin", x3[2], c, third, 0.55)
      B("Girar 90", "j_rot", x3[3], c, third, 0.55)
      c = line(0.55)
      B("<", "j_left", x4[1], c, quarter, 0.55)
      B("^", "j_up", x4[2], c, quarter, 0.55)
      B("v", "j_down", x4[3], c, quarter, 0.55)
      B(">", "j_right", x4[4], c, quarter, 0.55)
      c = line(0.5)
      B("Resetar ajuste", "j_reset", 0, c, W, 0.5, LEATHER_SOFT)
    end

  elseif S.tab == "grade" then
    if needMap() then
      local g = m.grid or {}
      c = line(0.55)
      B(g.on and "Grade: ligada" or "Grade: desligada", "g_on", x2[1], c, half, 0.55, on(g.on))
      B(g.snap ~= false and "Encaixe: ligado" or "Encaixe: desligado", "g_snap", x2[2], c, half, 0.55, on(g.snap ~= false),
        PARCH_TXT, "Peças encaixam no centro dos quadrados")
      gap(0.15)
      heading("Tamanho do quadrado")
      c = line(0.55)
      B("-", "g_less", x3[1], c, third, 0.55)
      T(tostring(g.size or 1), x3[2], c, 0.4, INK)
      B("+", "g_more", x3[3], c, third, 0.55)
      heading("Intensidade das linhas")
      c = line(0.55)
      B("Mais clara", "g_light", x2[1], c, half, 0.55)
      B("Mais escura", "g_dark", x2[2], c, half, 0.55)
      heading("Alinhar com o desenho do mapa")
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
      B(f.on and "Névoa: ligada" or "Névoa: desligada", "n_on", 0, c, W, 0.55, on(f.on))
      T("Você (" .. (f.owner or "Black") .. ") enxerga através; os jogadores não.", 0, line(0.3), 0.26, MUTED)
      c = line(0.5)
      B("Cobrir tudo", "n_cover", x2[1], c, half, 0.5)
      B("Revelar tudo", "n_clear", x2[2], c, half, 0.5)
      gap(0.1)
      heading("Pincel")
      local rev = S.brush and S.brush.open
      local hid = S.brush and not S.brush.open
      c = line(0.55)
      B(rev and "Revelando..." or "Revelar", "n_reveal", x2[1], c, half, 0.55, rev and MOSS or LEATHER, PARCH_TXT,
        "Liga/desliga: revela por onde o mouse passa")
      B(hid and "Cobrindo..." or "Cobrir", "n_hide", x2[2], c, half, 0.55, hid and BRICK or LEATHER, PARCH_TXT,
        "Liga/desliga: cobre por onde o mouse passa")
      c = line(0.5)
      B("Raio -", "n_rless", x3[1], c, third, 0.5)
      T("Raio " .. S.brushRadius, x3[2], c, 0.32, INK)
      B("Raio +", "n_rmore", x3[3], c, third, 0.5)
      c = line(0.5)
      B("Célula -", "n_cless", x3[1], c, third, 0.5)
      T(S.pending == "cell" and "Confirmar?" or ("Célula " .. (f.cell or 2)), x3[2], c, 0.32,
        S.pending == "cell" and WINE_TXT or INK)
      B("Célula +", "n_cmore", x3[3], c, third, 0.5)
      T("Atalhos: Options > Game Keys > Atlas", 0, line(0.3), 0.26, MUTED)

      heading("Tokens (selecione e clique)")
      c = line(0.5)
      B("Revelador", "v_reveal", x3[1], c, third, 0.5, LEATHER, PARCH_TXT,
        "Limpa a névoa por onde o token passa (permanente)")
      B("Visão em cone", "v_cone", x3[2], c, third, 0.5, LEATHER, PARCH_TXT,
        "Modo sobrevivência: só enxerga à frente do token")
      B("Desmarcar", "v_clear", x3[3], c, third, 0.5, LEATHER_SOFT, PARCH_TXT, "Tira o token da névoa")
      local v = S.lastVision or DEFAULT_VISION
      c = line(0.5)
      B("Alcance -", "v_rless", x3[1], c, third, 0.5, LEATHER, PARCH_TXT, "Raio do revelador / alcance do cone")
      T(string.format("Raio %.1f  Cone %d", v.radius, v.range), x3[2], c, 0.28, INK)
      B("Alcance +", "v_rmore", x3[3], c, third, 0.5, LEATHER, PARCH_TXT, "Raio do revelador / alcance do cone")
      c = line(0.5)
      B("Ângulo -", "v_aless", x3[1], c, third, 0.5)
      T("Ângulo " .. v.angle .. "°", x3[2], c, 0.3, INK)
      B("Ângulo +", "v_amore", x3[3], c, third, 0.5)
      c = line(0.55)
      B(f.survival and "Sobrevivência: ligada" or "Sobrevivência: desligada", "n_surv", x2[1], c, half, 0.55,
        on(f.survival), PARCH_TXT, "Tokens com visão em cone só enxergam à frente; a névoa volta atrás deles")
      B("Girar cone 90", "v_rot", x2[2], c, half, 0.55, LEATHER, PARCH_TXT,
        "Se o cone aponta para o lado errado do token")
      T(#getObjectsWithTag(TAG_REVEAL) .. " revelador(es)   " .. #getObjectsWithTag(TAG_CONE) .. " com visão",
        0, line(0.3), 0.26, MUTED)
    end

  elseif S.tab == "area" then
    heading("Área do mapa na mesa")
    T(string.format("%.1f x %.1f  (%s)", D.area.w, D.area.d, D.area.manual and "calibrada" or "automática"),
      0, line(0.35), 0.32, INK)
    c = line(0.55)
    B("Detectar", "z_auto", x2[1], c, half, 0.55, LEATHER, PARCH_TXT, "Detecta a área customizável pela própria mesa")
    B(S.calib and "Canto 2..." or "Calibrar", "z_calib", x2[2], c, half, 0.55, on(S.calib ~= nil), PARCH_TXT,
      "Clique e mire o mouse no canto da área em 3s")
    c = line(0.55)
    B("Mostrar área", "z_show", x2[1], c, half, 0.55)
    B("Fixar selecionados", "z_fix", x2[2], c, half, 0.55, LEATHER, PARCH_TXT, "Objetos fixos não trocam com o mapa")
  end
end
