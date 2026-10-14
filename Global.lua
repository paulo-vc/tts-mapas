--[[
  Atlas do Mestre v2 — cole este arquivo no script Global (Modding > Scripting > Global).

  Interface:
    - Painel na tela: botão "Atlas" no canto superior direito (só host/admins veem).
    - Painel na mesa: aba Área > "Criar painel na mesa" (ou qualquer objeto com a tag "PainelMapas").
  Os dois painéis são a mesma interface, controlada por este script.
]]

--------------------------------------------------------------------------
-- Estado
--------------------------------------------------------------------------
D = {
  area = { x = 0, y = 1, z = 0, w = 30, d = 20, manual = false },
  maps = {},
  folders = {},
  current = nil,
  openFolder = nil,
}

-- Estado da interface (não precisa ir para o save)
S = {
  tab = "mapas",
  page = 1,
  newName = "",
  newUrl = "",
  open = true,
  pending = nil,      -- confirmações de 2 cliques
  calib = nil,        -- primeiro canto da calibração
  brush = nil,        -- { color, open, waitId }
  brushRadius = 1.5,
  showingArea = false,
}

local ROWS = 8
local MOVE_STEP = 0.5
local ZOOM_STEP = 1.1
local GRID_STEP = 0.25
local FOG_HEIGHT = 4

-- Fração da mesa ocupada pela parte customizável, por tipo de mesa.
local TABLE_FRACTION = {
  Table_RPG = { 0.80, 0.69 },
  Table_Custom = { 0.95, 0.95 },
  Table_Custom_Square = { 0.95, 0.95 },
}

-- Painel na mesa: ajuste fino caso a interface apareça deslocada ou virada.
local OBJ_UI = {
  pxPerUnit = 100,       -- pixels de UI por unidade local do objeto
  rotation = "0 0 180",  -- orientação da UI sobre o objeto
  lift = -52,            -- altura acima do centro do objeto (negativo = para cima)
}

-- Visual (fantasia / pergaminho)
local C = {
  parch = "#E8D5A9",
  parchDark = "#D2B985",
  leather = "#5B3A1E",
  ink = "#3A2814",
  inkSoft = "#6E5536",
  wine = "#7B2D26",
  gold = "#B8862B",
  moss = "#4F5D2F",
  light = "#F6ECD2",
}
local BTN_COLORS = "#C9AE78|#DCC491|#A88B55|#C9AE7888"
local ACTIVE_COLORS = "#7B2D26|#923A31|#5E211C|#7B2D2688"
local GOOD_COLORS = "#4F5D2F|#5E6E39|#3C4723|#4F5D2F88"
local DANGER_COLORS = "#8A3A24|#A0462D|#6B2C1B|#8A3A2488"

local PW, PH = 440, 680  -- tamanho do painel em pixels

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

  addHotkey("Atlas: revelar névoa (segure)", function(color, _, _, up) hotkeyBrush(color, up, true) end, true)
  addHotkey("Atlas: cobrir névoa (segure)", function(color, _, _, up) hotkeyBrush(color, up, false) end, true)

  Wait.frames(function()
    if not D.area.manual then autoArea() end
    applyGrid()
    buildFog()
    render()
  end, 10)
end

function onSave()
  return JSON.encode(D)
end

--------------------------------------------------------------------------
-- Utilitários
--------------------------------------------------------------------------
function say(color, text)
  if color and Player[color] and Player[color].seated then
    printToColor(text, color, { 0.95, 0.85, 0.6 })
  else
    broadcastToAll(text, { 0.95, 0.85, 0.6 })
  end
end

function isGM(player)
  if player and (player.host or player.admin) then return true end
  if player then say(player.color, "Só o mestre (host/admin) pode usar o Atlas.") end
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
  return o.hasTag("MapaTile") or o.hasTag("Fog") or o.hasTag("Fixo") or o.hasTag("PainelMapas")
end

--------------------------------------------------------------------------
-- Área do mapa e superfície da mesa
--------------------------------------------------------------------------
-- Altura real da superfície (o pano da mesa), lançando um raio de cima para baixo.
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
  D.area = {
    x = b.center.x, z = b.center.z,
    w = b.size.x * f[1], d = b.size.z * f[2],
    manual = false,
  }
  D.area.y = surfaceY(D.area.x, D.area.z)
end

--------------------------------------------------------------------------
-- Imagem do mapa
--------------------------------------------------------------------------
function getTile()
  return getObjectsWithTag("MapaTile")[1]
end

function removeTile()
  for _, o in ipairs(getObjectsWithTag("MapaTile")) do o.destruct() end
end

-- Topo da imagem do mapa (onde a grade é desenhada).
function mapTopY()
  local t = getTile()
  if t then
    local b = t.getBounds()
    return b.center.y + b.size.y / 2
  end
  return D.area.y
end

-- Ajusta o tile para caber/preencher a área mantendo a proporção, e assenta ele NA superfície.
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
    Wait.frames(function() applyGrid() end, 2)
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
-- Guarda tudo que está sobre a área. keep = true só tira uma "foto".
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
-- Troca de mapa
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
  render()
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

--------------------------------------------------------------------------
-- Pastas / lista
--------------------------------------------------------------------------
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
-- Grade: linhas desenhadas sobre o mapa + snap nativo do TTS
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
    Grid.show_lines = false
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
-- Névoa (fog of war) com Hidden Zones: rentes ao mapa, sem colisão,
-- o dono (mestre) enxerga através, os outros veem um bloco opaco.
--------------------------------------------------------------------------
fogZones = {}

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

function clearFog()
  for _, o in ipairs(getObjectsWithTag("Fog")) do o.destruct() end
  fogZones = {}
end

function spawnFogCell(f, i, j, cw, cd)
  local key = i .. ":" .. j
  if fogZones[key] then return end
  local x, z = cellCenter(i, j, cw, cd)
  fogZones[key] = spawnObject({
    type = "FogOfWar",
    position = { x, D.area.y + FOG_HEIGHT / 2 - 0.05, z },
    scale = { cw, FOG_HEIGHT, cd },
    sound = false,
    callback_function = function(o)
      o.setValue(f.owner or "Black")
      o.addTag("Fog")
    end,
  })
end

function buildFog()
  clearFog()
  local f = current() and current().fog
  if not (f and f.on) then return end
  local nx, nz, cw, cd = fogGrid(f)
  for i = 1, nx do
    for j = 1, nz do
      if not f.open[i .. ":" .. j] then spawnFogCell(f, i, j, cw, cd) end
    end
  end
end

function paintFog(pos, open)
  local f = fogOf()
  if not (f and f.on and pos) then return end
  local nx, nz, cw, cd = fogGrid(f)
  local reach = S.brushRadius + math.max(cw, cd) / 2
  for i = 1, nx do
    for j = 1, nz do
      local x, z = cellCenter(i, j, cw, cd)
      local dx, dz = x - pos.x, z - pos.z
      if dx * dx + dz * dz <= reach * reach then
        local key = i .. ":" .. j
        if open and not f.open[key] then
          f.open[key] = true
          if fogZones[key] then fogZones[key].destruct() end
          fogZones[key] = nil
        elseif not open and f.open[key] then
          f.open[key] = nil
          spawnFogCell(f, i, j, cw, cd)
        end
      end
    end
  end
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
    render()
  elseif fogOf() and fogOf().on then
    startBrush(color, open)
  else
    say(color, "Ligue a névoa primeiro (aba Névoa).")
  end
end

--------------------------------------------------------------------------
-- Handlers da interface — todos recebem (player, value, id)
--------------------------------------------------------------------------
function noop() end

function ui_toggle(player)
  if not isGM(player) then return end
  S.open = not S.open
  render()
end

function ui_tab(player, value, id)
  S.tab = id:sub(5)
  render()
end

function ui_name(player, value) S.newName = value end
function ui_url(player, value) S.newUrl = value end

function ui_addLink(player)
  if not isGM(player) then return end
  local url = trim(S.newUrl)
  if url == "" then return say(player.color, "Cole o link da imagem (.jpg ou .png).") end
  addMap(S.newName, url)
end

-- Arquivo do PC: o mestre escolhe a imagem no menu Custom do TTS (que sobe para a Cloud).
function ui_addFile(player)
  if not isGM(player) then return end
  local name, a = S.newName, D.area
  local tile = spawnObject({
    type = "Custom_Tile",
    position = { a.x, a.y + 3, a.z },
    scale = { 3, 1, 3 },
  })
  tile.setName("Novo mapa: clique direito > Custom")
  local guid = tile.getGUID()
  say(player.color, "Clique com o botão direito no tile no meio da mesa > Custom > escolha a imagem > Import. Aceite subir para a Cloud.")
  Wait.condition(function()
    local t = getObjectFromGUID(guid)
    local url = t.getCustomObject().image
    t.destruct()
    addMap(name, url)
    say(player.color, "Mapa adicionado!")
  end, function()
    local t = getObjectFromGUID(guid)
    if not t or t.spawning then return false end
    local co = t.getCustomObject()
    return co and co.image and co.image ~= ""
  end, 600, function()
    say(player.color, "Tempo esgotado esperando a imagem. Tente de novo.")
  end)
end

function ui_newFolder(player)
  if not isGM(player) then return end
  local name = trim(S.newName)
  if name == "" then return say(player.color, "Digite o nome da pasta no campo Nome.") end
  for _, f in ipairs(D.folders) do
    if f == name then return say(player.color, "Já existe uma pasta com esse nome.") end
  end
  table.insert(D.folders, name)
  S.newName = ""
  render()
end

function ui_moveHere(player)
  if not isGM(player) then return end
  local m = current()
  if not m then return say(player.color, "Nenhum mapa ativo.") end
  m.folder = D.openFolder
  render()
end

function ui_entry(player, value, id)
  if not isGM(player) then return end
  local kind, n = id:match("^(%a+)_(%d+)$")
  n = tonumber(n)
  if kind == "back" then
    D.openFolder = nil
    S.page = 1
  elseif kind == "folder" then
    D.openFolder = D.folders[n]
    S.page = 1
  elseif kind == "map" then
    if n ~= D.current then return switchTo(n) end
  elseif kind == "delmap" then
    if S.pending ~= id then
      S.pending = id
      say(player.color, "Clique no x de novo para apagar \"" .. D.maps[n].name .. "\".")
      return render()
    end
    S.pending = nil
    if n == D.current then
      storeObjects()
      removeTile()
      stopBrush()
      clearFog()
      D.current = nil
      applyGrid()
    elseif D.current and n < D.current then
      D.current = D.current - 1
    end
    table.remove(D.maps, n)
  elseif kind == "delfolder" then
    local name = D.folders[n]
    if S.pending ~= id then
      S.pending = id
      say(player.color, "Clique no x de novo para apagar a pasta \"" .. name .. "\" (os mapas vão para a raiz).")
      return render()
    end
    S.pending = nil
    for _, m in ipairs(D.maps) do if m.folder == name then m.folder = nil end end
    table.remove(D.folders, n)
  end
  render()
end

function ui_prev() if S.page > 1 then S.page = S.page - 1; render() end end
function ui_next()
  if S.page < math.ceil(#getEntries() / ROWS) then S.page = S.page + 1; render() end
end

function ui_save(player)
  if not isGM(player) then return end
  local m = current()
  if not m then return say(player.color, "Nenhum mapa ativo.") end
  m.saved = storeObjects(true)
  say(player.color, "Estado de \"" .. m.name .. "\" salvo (" .. #m.saved .. " objetos).")
  render()
end

function ui_restore(player)
  if not isGM(player) then return end
  local m = current()
  if not (m and m.saved) then return say(player.color, "Este mapa ainda não tem estado salvo.") end
  if S.pending ~= "restore" then
    S.pending = "restore"
    return say(player.color, "Clique em Restaurar de novo: a mesa volta ao estado salvo.")
  end
  S.pending = nil
  storeObjects()
  Wait.frames(function() spawnStored(m.saved) end, 5)
end

-- Imagem
function ui_fit(player, value, id)
  if not isGM(player) then return end
  local m = current()
  if not m then return end
  m.fit = id:sub(5)
  showMap(m)
  render()
end

function ui_adjust(player, value, id)
  if not isGM(player) then return end
  local m = current()
  if not m then return end
  if m.fit == "mesa" then return say(player.color, "Ajustes funcionam nos modos Caber e Preencher.") end
  local k = id:sub(5)
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

-- Grade
function gridOf(player)
  if not isGM(player) then return nil end
  local m = current()
  if not m then say(player.color, "Nenhum mapa ativo.") return nil end
  m.grid = m.grid or { on = false, size = 1, snap = true, ox = 0, oz = 0, alpha = 0.6 }
  return m.grid
end

function ui_grid(player, value, id)
  local g = gridOf(player)
  if not g then return end
  local k = id:sub(6)
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
  render()
end

-- Névoa
function ui_fog(player, value, id)
  if not isGM(player) then return end
  local f = fogOf()
  if not f then return say(player.color, "Nenhum mapa ativo.") end
  local k = id:sub(5)
  if k == "on" then
    f.on = not f.on
    f.owner = player.color
    if not f.on then stopBrush() end
    buildFog()
  elseif k == "cover" then
    f.on, f.open, f.owner = true, {}, player.color
    buildFog()
  elseif k == "clear" then
    local nx, nz = fogGrid(f)
    for i = 1, nx do for j = 1, nz do f.open[i .. ":" .. j] = true end end
    buildFog()
  elseif k == "reveal" or k == "hide" then
    if not f.on then return say(player.color, "Ligue a névoa primeiro.") end
    local open = (k == "reveal")
    if S.brush and S.brush.open == open then stopBrush() else startBrush(player.color, open) end
  elseif k == "rless" then S.brushRadius = math.max(0.5, S.brushRadius - 0.5)
  elseif k == "rmore" then S.brushRadius = S.brushRadius + 0.5
  elseif k == "cless" or k == "cmore" then
    local new = math.max(0.5, f.cell + (k == "cmore" and 0.5 or -0.5))
    if next(f.open) and S.pending ~= "cell" then
      S.pending = "cell"
      return say(player.color, "Mudar a célula cobre o mapa todo de novo. Clique outra vez para confirmar.")
    end
    S.pending = nil
    f.cell, f.open = new, {}
    buildFog()
  end
  render()
end

-- Área
function ui_area(player, value, id)
  if not isGM(player) then return end
  local k = id:sub(6)
  if k == "auto" then
    autoArea()
    say(player.color, string.format("Área detectada: %.1f x %.1f", D.area.w, D.area.d))
    afterAreaChange()
  elseif k == "show" then
    showArea()
  elseif k == "fix" then
    local sel = player.getSelectedObjects()
    if #sel == 0 then return say(player.color, "Selecione objetos primeiro.") end
    for _, o in ipairs(sel) do
      if o.hasTag("Fixo") then o.removeTag("Fixo") else o.addTag("Fixo") end
      say(player.color, (o.getName() ~= "" and o.getName() or o.type) .. (o.hasTag("Fixo") and ": fixo" or ": não é mais fixo"))
    end
  elseif k == "calib" then
    local step = S.calib and 2 or 1
    say(player.color, "Mire o mouse no canto " .. step .. " da área... (3s)")
    Wait.time(function()
      local p = player.getPointerPosition()
      if step == 1 then
        S.calib = p
        say(player.color, "Canto 1 marcado. Clique em Calibrar de novo para o canto oposto.")
      else
        local c1 = S.calib
        D.area = {
          x = (c1.x + p.x) / 2, z = (c1.z + p.z) / 2,
          w = math.abs(p.x - c1.x), d = math.abs(p.z - c1.z),
          manual = true,
        }
        D.area.y = surfaceY(D.area.x, D.area.z)
        S.calib = nil
        say(player.color, string.format("Área calibrada: %.1f x %.1f", D.area.w, D.area.d))
        afterAreaChange()
      end
      render()
    end, 3)
    return
  elseif k == "board" then
    createBoard()
  end
  render()
end

function afterAreaChange()
  showArea()
  local m = current()
  if m and m.fit ~= "mesa" then showMap(m) else applyGrid() end
  buildFog()
end

--------------------------------------------------------------------------
-- Construção da interface (XML)
--------------------------------------------------------------------------
-- O TTS espera todo atributo como texto.
function stringify(nodes)
  for _, n in ipairs(nodes) do
    for k, v in pairs(n.attributes or {}) do n.attributes[k] = tostring(v) end
    if n.children then stringify(n.children) end
  end
  return nodes
end

-- P = prefixo do alvo dos eventos ("" na tela, "Global/" no objeto)
function makeUI(P)
  local m = current()

  local function text(value, size, color, h, align, style)
    return { tag = "Text", attributes = {
      fontSize = size or 14, color = color or C.ink, preferredHeight = h or 22,
      alignment = align or "MiddleCenter", fontStyle = style or "Normal",
    }, value = value }
  end
  local function button(label, fn, id, opts)
    opts = opts or {}
    return { tag = "Button", attributes = {
      id = id, onClick = P .. fn,
      colors = opts.colors or BTN_COLORS,
      textColor = opts.textColor or C.ink,
      fontSize = opts.size or 14, fontStyle = "Bold",
      preferredHeight = opts.h or 32, flexibleWidth = opts.fw or 1,
      preferredWidth = opts.pw or -1,
      tooltip = opts.tip, tooltipPosition = "Above",
    }, value = label }
  end
  local function row(children, h)
    return { tag = "HorizontalLayout", attributes = {
      spacing = 6, preferredHeight = h or 32, childForceExpandWidth = true, childForceExpandHeight = true,
    }, children = children }
  end
  local function input(id, fn, placeholder, value)
    return { tag = "InputField", attributes = {
      id = id, onValueChanged = P .. fn, placeholder = placeholder, text = value,
      preferredHeight = 34, fontSize = 14, textColor = C.ink,
      colors = C.light .. "|#FFF8E6|#FFF8E6|#DDDDDD",
    } }
  end
  local function divider()
    return { tag = "Panel", attributes = { preferredHeight = 2, color = C.parchDark } }
  end
  local function sectionTitle(t)
    return text(t, 13, C.wine, 20, "MiddleLeft", "Bold")
  end
  local function active(flag) return flag and { colors = ACTIVE_COLORS, textColor = C.light } or nil end
  local function needMap(list)
    if m then return true end
    table.insert(list, text("Carregue um mapa na aba Mapas.", 14, C.inkSoft, 40))
    return false
  end

  local body = {}
  local function add(x) table.insert(body, x) end

  -- Cabeçalho
  add(text("Atlas do Mestre", 22, C.leather, 32, "MiddleCenter", "Bold"))
  add(text(m and ("Mapa ativo: " .. m.name) or "Nenhum mapa ativo", 13, C.inkSoft, 18))
  add(divider())

  -- Abas
  local tabs = {
    { "mapas", "Mapas" }, { "imagem", "Imagem" }, { "grade", "Grade" }, { "nevoa", "Névoa" }, { "area", "Área" },
  }
  local tabRow = {}
  for _, t in ipairs(tabs) do
    local o = active(S.tab == t[1]) or {}
    o.h, o.size = 30, 13
    table.insert(tabRow, button(t[2], "ui_tab", "tab_" .. t[1], o))
  end
  add(row(tabRow, 30))
  add(divider())

  if S.tab == "mapas" then
    add(input("in_name", "ui_name", "Nome do mapa ou da pasta", S.newName))
    add(input("in_url", "ui_url", "Link da imagem (.jpg / .png)", S.newUrl))
    add(row({
      button("+ Link", "ui_addLink", "addLink", { colors = GOOD_COLORS, textColor = C.light, tip = "Adiciona o mapa do link" }),
      button("+ Arquivo do PC", "ui_addFile", "addFile", { colors = GOOD_COLORS, textColor = C.light, tip = "Escolher uma imagem do computador" }),
    }))
    add(row({
      button("+ Pasta", "ui_newFolder", "newFolder", { tip = "Cria uma pasta com o nome digitado" }),
      button("Mover mapa p/ cá", "ui_moveHere", "moveHere", { tip = "Move o mapa ativo para a pasta aberta" }),
    }))
    add(sectionTitle(D.openFolder and ("Pasta: " .. D.openFolder) or "Seus mapas"))

    local entries = getEntries()
    local pages = math.max(1, math.ceil(#entries / ROWS))
    if S.page > pages then S.page = pages end
    for n = 1, ROWS do
      local e = entries[(S.page - 1) * ROWS + n]
      if not e then
        add({ tag = "Panel", attributes = { preferredHeight = 28 } })
      elseif e.kind == "back" then
        add(row({ button("< Voltar", "ui_entry", "back_0", { h = 28 }) }, 28))
      elseif e.kind == "folder" then
        local confirm = S.pending == ("delfolder_" .. e.fi)
        add(row({
          button("[ " .. e.name .. " ]  " .. e.count, "ui_entry", "folder_" .. e.fi,
            { h = 28, colors = "#B99A5E|#C9AE78|#9C7F48|#B99A5E88" }),
          button(confirm and "?" or "x", "ui_entry", "delfolder_" .. e.fi,
            { h = 28, fw = 0, pw = 32, colors = DANGER_COLORS, textColor = C.light, tip = "Apagar pasta" }),
        }, 28))
      else
        local mp = D.maps[e.i]
        local sel = e.i == D.current
        local o = active(sel) or {}
        o.h = 28
        local confirm = S.pending == ("delmap_" .. e.i)
        add(row({
          button(mp.name .. (mp.saved and "  *" or ""), "ui_entry", "map_" .. e.i, o),
          button(confirm and "?" or "x", "ui_entry", "delmap_" .. e.i,
            { h = 28, fw = 0, pw = 32, colors = DANGER_COLORS, textColor = C.light, tip = "Apagar mapa" }),
        }, 28))
      end
    end
    if #entries == 0 then add(text("Nenhum mapa ainda. Adicione um acima.", 13, C.inkSoft, 20)) end
    add(row({
      button("<", "ui_prev", "prev", { h = 28 }),
      text(S.page .. " / " .. pages, 13, C.inkSoft, 28),
      button(">", "ui_next", "next", { h = 28 }),
    }, 28))
    add(divider())
    add(row({
      button("Salvar estado", "ui_save", "save", { colors = GOOD_COLORS, textColor = C.light,
        tip = "Guarda a posição dos props e tokens neste mapa" }),
      button(S.pending == "restore" and "Confirmar?" or "Restaurar", "ui_restore", "restore",
        { colors = DANGER_COLORS, textColor = C.light, tip = "Volta ao último estado salvo" }),
    }))

  elseif S.tab == "imagem" then
    if needMap(body) then
      add(sectionTitle("Como exibir"))
      local o1, o2, o3 = active(m.fit == "mesa"), active(m.fit == "caber"), active(m.fit == "preencher")
      local function t(o, tip) o = o or {}; o.tip = tip; return o end
      add(row({
        button("Na mesa", "ui_fit", "fit_mesa", t(o1, "Imagem direto na parte customizável da mesa")),
        button("Caber", "ui_fit", "fit_caber", t(o2, "Imagem inteira, mantendo a proporção")),
        button("Preencher", "ui_fit", "fit_preencher", t(o3, "Cobre a área toda, mantendo a proporção")),
      }))
      add(sectionTitle("Ajuste fino (Caber / Preencher)"))
      add(row({
        button("Zoom -", "ui_adjust", "adj_zout"), button("Zoom +", "ui_adjust", "adj_zin"),
        button("Girar 90°", "ui_adjust", "adj_rot"),
      }))
      add(row({
        button("<", "ui_adjust", "adj_left"), button("^", "ui_adjust", "adj_up"),
        button("v", "ui_adjust", "adj_down"), button(">", "ui_adjust", "adj_right"),
      }))
      add(row({ button("Resetar ajuste", "ui_adjust", "adj_reset") }))
    end

  elseif S.tab == "grade" then
    if needMap(body) then
      local g = m.grid or {}
      add(row({
        button(g.on and "Grade: ligada" or "Grade: desligada", "ui_grid", "grid_on", active(g.on)),
        button(g.snap ~= false and "Encaixe: ligado" or "Encaixe: desligado", "ui_grid", "grid_snap",
          active(g.snap ~= false)),
      }))
      add(sectionTitle("Tamanho do quadrado"))
      add(row({
        button("-", "ui_grid", "grid_less"),
        text(tostring(g.size or 1), 16, C.ink, 32, "MiddleCenter", "Bold"),
        button("+", "ui_grid", "grid_more"),
      }))
      add(sectionTitle("Intensidade das linhas"))
      add(row({ button("Mais clara", "ui_grid", "grid_light"), button("Mais escura", "ui_grid", "grid_dark") }))
      add(sectionTitle("Alinhar com o desenho do mapa"))
      add(row({
        button("<", "ui_grid", "grid_left"), button("^", "ui_grid", "grid_up"),
        button("v", "ui_grid", "grid_down"), button(">", "ui_grid", "grid_right"),
      }))
    end

  elseif S.tab == "nevoa" then
    if needMap(body) then
      local f = m.fog or {}
      add(row({
        button(f.on and "Névoa: ligada" or "Névoa: desligada", "ui_fog", "fog_on", active(f.on)),
      }))
      add(text("Você (" .. (f.owner or "Black") .. ") enxerga através; os jogadores não.", 12, C.inkSoft, 18))
      add(row({ button("Cobrir tudo", "ui_fog", "fog_cover"), button("Revelar tudo", "ui_fog", "fog_clear") }))
      add(sectionTitle("Pincel"))
      local rev = S.brush and S.brush.open
      local hid = S.brush and not S.brush.open
      add(row({
        button(rev and "Revelando..." or "Revelar", "ui_fog", "fog_reveal",
          rev and { colors = GOOD_COLORS, textColor = C.light } or { tip = "Revela por onde o mouse passa" }),
        button(hid and "Cobrindo..." or "Cobrir", "ui_fog", "fog_hide",
          hid and { colors = DANGER_COLORS, textColor = C.light } or { tip = "Cobre por onde o mouse passa" }),
      }))
      add(row({
        button("Raio -", "ui_fog", "fog_rless"),
        text("Raio " .. S.brushRadius, 14, C.ink, 32, "MiddleCenter", "Bold"),
        button("Raio +", "ui_fog", "fog_rmore"),
      }))
      add(row({
        button("Célula -", "ui_fog", "fog_cless"),
        text("Célula " .. (f.cell or 2), 14, C.ink, 32, "MiddleCenter", "Bold"),
        button("Célula +", "ui_fog", "fog_cmore"),
      }))
      add(text("Dica: Options > Game Keys > \"Atlas: revelar névoa\". Segure a tecla e passe o mouse.",
        12, C.inkSoft, 34))
    end

  elseif S.tab == "area" then
    add(sectionTitle("Área do mapa"))
    add(text(string.format("%.1f x %.1f  (%s)", D.area.w, D.area.d, D.area.manual and "calibrada" or "automática"),
      14, C.ink, 22))
    add(row({
      button("Detectar automático", "ui_area", "area_auto"),
      button(S.calib and "Canto 2..." or "Calibrar", "ui_area", "area_calib", active(S.calib ~= nil)),
    }))
    add(row({
      button("Mostrar área", "ui_area", "area_show"),
      button("Fixar selecionados", "ui_area", "area_fix", { tip = "Objetos fixos não trocam com o mapa" }),
    }))
    add(divider())
    add(sectionTitle("Painel na mesa"))
    add(row({ button("Criar painel na mesa", "ui_area", "area_board",
      { tip = "Cria um objeto com esta mesma interface" }) }))
  end

  return {
    tag = "VerticalLayout",
    attributes = {
      padding = "16 16 14 14", spacing = 6,
      childForceExpandHeight = false, childForceExpandWidth = true, childAlignment = "UpperCenter",
    },
    children = body,
  }
end

function render()
  -- Tela
  UI.setXmlTable(stringify({
    { tag = "Button", attributes = {
      id = "atlasToggle", onClick = "ui_toggle", visibility = "Host|Admin",
      rectAlignment = "UpperRight", offsetXY = "-12 -78", width = 110, height = 34,
      colors = ACTIVE_COLORS, textColor = C.light, fontSize = 15, fontStyle = "Bold",
    }, value = S.open and "Fechar Atlas" or "Atlas" },
    { tag = "Panel", attributes = {
      id = "atlasPanel", visibility = "Host|Admin", active = S.open,
      rectAlignment = "UpperRight", offsetXY = "-12 -118", width = PW, height = PH,
      color = C.parch, outline = C.leather, outlineSize = "3 -3",
      allowDragging = true, returnToOriginalPositionWhenReleased = false,
    }, children = { makeUI("") } },
  }))

  -- Objetos na mesa
  for _, obj in ipairs(getObjectsWithTag("PainelMapas")) do
    obj.UI.setXmlTable(stringify({
      { tag = "Panel", attributes = {
        width = PW, height = PH,
        position = "0 0 " .. OBJ_UI.lift, rotation = OBJ_UI.rotation,
        scale = (OBJ_UI.pxPerUnit / PW) .. " " .. (OBJ_UI.pxPerUnit / PH) .. " 1",
        color = C.parch, outline = C.leather, outlineSize = "3 -3",
      }, children = { makeUI("Global/") } },
    }))
  end
end

-- Cria um bloco na beira da mesa com a mesma interface.
function createBoard()
  local a = D.area
  local o = spawnObject({
    type = "BlockSquare",
    position = { a.x + a.w / 2 + 6, a.y + 1, a.z },
    scale = { 7, 0.2, 7 * PH / PW },
    callback_function = function(obj)
      obj.setName("Atlas do Mestre")
      obj.setColorTint({ 0.36, 0.23, 0.12 })
      obj.addTag("PainelMapas")
      obj.addTag("Fixo")
      obj.setLock(true)
      Wait.frames(render, 2)
    end,
  })
end
