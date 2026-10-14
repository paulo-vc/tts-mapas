--[[
  TTS Mapas v0.2 — script do objeto "Controle de Mapas"
  1. Objects > Blocks > Square (qualquer bloco serve)
  2. Clique direito no bloco > Scripting > Scripting Editor, cole este arquivo e clique em Save & Play.
  O bloco vira um painel com os botões. Se aparecer de cabeça para baixo, gire o bloco 180°.
]]

D = {
  area = { x = 0, y = 1.0, z = 0, w = 32, d = 19 },
  maps = {},
  current = nil,
  sized = false,
}

newName, newUrl = "", ""
page = 1
pendingDelete = nil
calibCorner1 = nil

local U = 450          -- unidades de botão por unidade do mundo (ajuste se os botões ficarem grandes/pequenos)
local BOARD = { w = 8, d = 16.5 }   -- mesma proporção de assets/tabula.png
local ROWS = 7
local GRID_STEP = 0.25
local MOVE_STEP = 0.5
local ZOOM_STEP = 1.1

--------------------------------------------------------------------------
-- Ciclo de vida
--------------------------------------------------------------------------
function onLoad(saved)
  if saved and saved ~= "" then
    local ok, t = pcall(JSON.decode, saved)
    if ok and type(t) == "table" and t.area then D = t end
  end
  D.maps = D.maps or {}
  self.setName("Controle de Mapas")
  self.addTag("Fixo")
  D.folders = D.folders or {}
  if not D.area.manual then autoArea() end
  addHotkey("Fog: revelar (segure)", function(color, obj, pos, up) hotkeyBrush(color, up, true) end, true)
  addHotkey("Fog: esconder (segure)", function(color, obj, pos, up) hotkeyBrush(color, up, false) end, true)
  -- As peças de fog ficam no save da mesa; recria a partir dos dados para não duplicar.
  Wait.frames(function()
    fitBoard()
    buildFog()
    -- espera a nova escala valer antes de posicionar os botões
    Wait.frames(build, 3)
  end, 3)
end

-- Fração da mesa ocupada pela parte customizável (a área "amarela"), por tipo de mesa.
local TABLE_FRACTION = {
  Table_RPG = { 0.80, 0.69 },
  Table_Custom = { 0.95, 0.95 },
  Table_Custom_Square = { 0.95, 0.95 },
}

-- Descobre a área do mapa a partir da própria mesa, sem calibração.
function autoArea()
  local t = Tables.getTableObject()
  if not t then return end
  local b = t.getBounds()
  local f = TABLE_FRACTION[Tables.getTable()] or { 0.85, 0.85 }
  D.area = {
    x = b.center.x, z = b.center.z,
    y = b.center.y + b.size.y / 2,
    w = b.size.x * f[1], d = b.size.z * f[2],
    manual = false,
  }
end

function trim(s)
  s = s or ""
  local i, j = 1, #s
  while i <= j and s:sub(i, i):find("%s") do i = i + 1 end
  while j >= i and s:sub(j, j):find("%s") do j = j - 1 end
  return s:sub(i, j)
end

function onSave()
  return JSON.encode(D)
end

--------------------------------------------------------------------------
-- Utilitários
--------------------------------------------------------------------------
function say(color, text)
  printToColor(text, color, { 1, 0.85, 0.5 })
end

function isAdmin(color)
  local p = Player[color]
  if p and (p.admin or p.host) then return true end
  say(color, "Só o mestre (host/admin) pode usar o controle de mapas.")
  return false
end

function current()
  return D.current and D.maps[D.current] or nil
end

function getTile()
  return getObjectsWithTag("MapaTile")[1]
end

function removeTile()
  for _, o in ipairs(getObjectsWithTag("MapaTile")) do o.destruct() end
end

function inArea(p)
  local a = D.area
  return math.abs(p.x - a.x) <= a.w / 2 and math.abs(p.z - a.z) <= a.d / 2
end

--------------------------------------------------------------------------
-- Objetos do mapa (props e tokens)
--------------------------------------------------------------------------
-- Guarda tudo que está sobre a área. Com keep = true só tira uma "foto", sem remover nada.
function storeObjects(keep)
  local a, list = D.area, {}
  for _, o in ipairs(getObjects()) do
    if o ~= self and not o.hasTag("MapaTile") and not o.hasTag("Fixo") and not o.hasTag("Fog") then
      local p = o.getPosition()
      if inArea(p) then
        table.insert(list, { json = o.getJSON(), dx = p.x - a.x, y = p.y, dz = p.z - a.z })
        if not keep then o.destruct() end
      end
    end
  end
  return list
end

function spawnStored(list)
  local a = D.area
  for _, e in ipairs(list or {}) do
    spawnObjectJSON({ json = e.json, position = { a.x + e.dx, e.y, a.z + e.dz } })
  end
end

--------------------------------------------------------------------------
-- Exibição do mapa
--------------------------------------------------------------------------
function fitTile(o, m)
  local a = D.area
  local s0 = o.getScale().x
  local b = o.getBoundsNormalized().size
  local bw, bd = b.x / s0, b.z / s0
  if bw <= 0 or bd <= 0 then return end
  local base
  if m.fit == "preencher" then
    base = math.max(a.w / bw, a.d / bd)
  else
    base = math.min(a.w / bw, a.d / bd)
  end
  local s = base * (m.zoom or 1)
  o.setScale({ s, 1, s })
  o.setPosition({ a.x + (m.ox or 0), a.y + 0.06, a.z + (m.oz or 0) })
end

function spawnTile(m)
  removeTile()
  local a = D.area
  local o = spawnObject({
    type = "Custom_Tile",
    position = { a.x, a.y + 0.06, a.z },
    rotation = { 0, m.rot or 0, 0 },
    callback_function = function(obj)
      obj.addTag("MapaTile")
      obj.setLock(true)
      obj.setName("Mapa: " .. m.name)
      obj.interactable = false
      Wait.frames(function() fitTile(obj, m) end, 5)
    end,
  })
  o.setCustomObject({ image = m.url, type = 0, thickness = 0.1, stretch = false })
end

function showMap(m)
  if m.fit == "mesa" then
    removeTile()
    Tables.setCustomURL(m.url)
  else
    spawnTile(m)
  end
end

function refit()
  local m, t = current(), getTile()
  if not (m and t) then return end
  t.setRotation({ 0, m.rot or 0, 0 })
  Wait.frames(function() fitTile(t, m) end, 3)
end

function switchTo(i)
  local old = current()
  if old then old.objects = storeObjects() end
  D.current = i
  local m = D.maps[i]
  showMap(m)
  applyGrid()
  stopBrush()
  buildFog()
  Wait.frames(function()
    spawnStored(m.objects)
    m.objects = {}
  end, 10)
  pendingDelete = nil
  build()
end

function deleteMap(i, color)
  if pendingDelete ~= "m" .. i then
    pendingDelete = "m" .. i
    say(color, "Clique com o botão direito de novo para apagar \"" .. D.maps[i].name .. "\".")
    return
  end
  pendingDelete = nil
  if i == D.current then
    storeObjects()
    removeTile()
    stopBrush()
    clearFog()
    D.current = nil
  elseif D.current and i < D.current then
    D.current = D.current - 1
  end
  table.remove(D.maps, i)
  build()
end

function showArea()
  local a = D.area
  local y, hw, hd = a.y + 0.15, a.w / 2, a.d / 2
  Global.setVectorLines({ {
    points = {
      { a.x - hw, y, a.z - hd }, { a.x + hw, y, a.z - hd },
      { a.x + hw, y, a.z + hd }, { a.x - hw, y, a.z + hd },
      { a.x - hw, y, a.z - hd },
    },
    color = { 1, 0.35, 0.1 },
    thickness = 0.15,
  } })
  Wait.time(function() Global.setVectorLines({}) end, 6)
end

--------------------------------------------------------------------------
-- Botões
--------------------------------------------------------------------------
function noop() end

function in_name(obj, color, value, editing) newName = value end
function in_url(obj, color, value, editing) newUrl = value end

function b_add(obj, color)
  if not isAdmin(color) then return end
  local url = trim(newUrl)
  if url == "" then return say(color, "Cole o link da imagem do mapa, ou use \"Custom\" para um arquivo seu.") end
  addMap(newName, url)
end

function addMap(name, url)
  name = trim(name)
  if name == "" then name = "Mapa " .. (#D.maps + 1) end
  table.insert(D.maps, {
    name = name, url = url, fit = "mesa", zoom = 1, ox = 0, oz = 0, rot = 0,
    objects = {}, folder = D.openFolder,
  })
  newName, newUrl = "", ""
  page = math.ceil(#getEntries() / ROWS)
  switchTo(#D.maps)
end

-- Custom: cria um tile vazio; o mestre escolhe o arquivo no menu Custom do próprio TTS
-- (que oferece subir para a Steam Cloud) e o mapa é adicionado sozinho quando a imagem aparece.
function b_custom(o, color)
  if not isAdmin(color) then return end
  local name = newName
  local pos = self.positionToWorld({ 0, 0, 0 })
  local tile = spawnObject({
    type = "Custom_Tile",
    position = { pos.x, pos.y + 2, pos.z },
    scale = { 2, 1, 2 },
  })
  tile.setName("Novo mapa (clique direito > Custom)")
  local guid = tile.getGUID()
  say(color, "Clique com o botão direito no tile que apareceu > Custom > escolha a imagem do seu PC > Import. "
    .. "Quando perguntar, aceite subir para a Cloud.")
  Wait.condition(function()
    local t = getObjectFromGUID(guid)
    local url = t.getCustomObject().image or ""
    t.destruct()
    addMap(name, url)
    say(color, "Mapa adicionado!")
  end, function()
    local t = getObjectFromGUID(guid)
    if not t or t.spawning then return false end
    local co = t.getCustomObject()
    return co and co.image and co.image ~= ""
  end, 600, function()
    say(color, "Tempo esgotado esperando a imagem do Custom. Tente de novo.")
  end)
end

function b_auto(o, color)
  if not isAdmin(color) then return end
  autoArea()
  say(color, string.format("Área detectada pela mesa: %.2f x %.2f", D.area.w, D.area.d))
  showArea()
  applyGrid()
  buildFog()
  local m = current()
  if m and m.fit ~= "mesa" then showMap(m) end
end

--------------------------------------------------------------------------
-- Pastas
--------------------------------------------------------------------------
-- O que aparece na lista: na raiz, as pastas e os mapas soltos; dentro de uma pasta, "Voltar" e os mapas dela.
function getEntries()
  local e = {}
  if D.openFolder then
    table.insert(e, { kind = "back" })
    for i, m in ipairs(D.maps) do
      if m.folder == D.openFolder then table.insert(e, { kind = "map", i = i }) end
    end
  else
    for _, f in ipairs(D.folders) do
      local n = 0
      for _, m in ipairs(D.maps) do if m.folder == f then n = n + 1 end end
      table.insert(e, { kind = "folder", name = f, count = n })
    end
    for i, m in ipairs(D.maps) do
      if not m.folder then table.insert(e, { kind = "map", i = i }) end
    end
  end
  return e
end

function b_newfolder(o, color)
  if not isAdmin(color) then return end
  local name = trim(newName)
  if name == "" then return say(color, "Digite o nome da pasta no campo \"Nome\".") end
  for _, f in ipairs(D.folders) do
    if f == name then return say(color, "Já existe uma pasta com esse nome.") end
  end
  table.insert(D.folders, name)
  newName = ""
  build()
end

function b_move(o, color)
  if not isAdmin(color) then return end
  local m = current()
  if not m then return say(color, "Nenhum mapa ativo para mover.") end
  m.folder = D.openFolder
  say(color, "\"" .. m.name .. "\" movido para " .. (D.openFolder and ("a pasta " .. D.openFolder) or "a raiz") .. ".")
  build()
end

function deleteFolder(name, color)
  if pendingDelete ~= "f" .. name then
    pendingDelete = "f" .. name
    say(color, "Clique com o botão direito de novo para apagar a pasta \"" .. name .. "\" (os mapas vão para a raiz).")
    return
  end
  pendingDelete = nil
  for _, m in ipairs(D.maps) do
    if m.folder == name then m.folder = nil end
  end
  for i, f in ipairs(D.folders) do
    if f == name then table.remove(D.folders, i) break end
  end
  build()
end

function slot(n, color, alt)
  if not isAdmin(color) then return end
  local e = getEntries()[(page - 1) * ROWS + n]
  if not e then return end
  if e.kind == "back" then
    D.openFolder = nil
    page = 1
    build()
  elseif e.kind == "folder" then
    if alt then return deleteFolder(e.name, color) end
    D.openFolder = e.name
    page = 1
    build()
  elseif alt then
    deleteMap(e.i, color)
  elseif e.i ~= D.current then
    switchTo(e.i)
  end
end

--------------------------------------------------------------------------
-- Estado salvo do mapa (props e tokens)
--------------------------------------------------------------------------
function b_save(o, color)
  if not isAdmin(color) then return end
  local m = current()
  if not m then return say(color, "Nenhum mapa ativo.") end
  m.saved = storeObjects(true)
  say(color, "Estado de \"" .. m.name .. "\" salvo (" .. #m.saved .. " objetos).")
end

function b_restore(o, color)
  if not isAdmin(color) then return end
  local m = current()
  if not m then return say(color, "Nenhum mapa ativo.") end
  if not m.saved then return say(color, "Este mapa ainda não tem estado salvo.") end
  if pendingDelete ~= "r" then
    pendingDelete = "r"
    return say(color, "Clique em Restaurar de novo: a mesa volta para o estado salvo e as mudanças atuais são descartadas.")
  end
  pendingDelete = nil
  storeObjects()
  Wait.frames(function() spawnStored(m.saved) end, 5)
  say(color, "\"" .. m.name .. "\" restaurado.")
end

--------------------------------------------------------------------------
-- Grade (usa a grade nativa do TTS, com snap)
--------------------------------------------------------------------------
function applyGrid()
  local m = current()
  local g = m and m.grid
  if not (g and g.on) then
    Grid.show_lines = false
    Grid.snapping = 1
    return
  end
  local a = D.area
  Grid.type = 1
  Grid.sizeX, Grid.sizeY = g.size, g.size
  Grid.offsetX = a.x - a.w / 2 + (g.ox or 0)
  Grid.offsetY = a.z - a.d / 2 + (g.oz or 0)
  Grid.color = { 0, 0, 0 }
  Grid.opacity = 0.5
  Grid.thick_lines = false
  Grid.show_lines = true
  Grid.snapping = g.snap and 3 or 1
end

function gridOf(color)
  if not isAdmin(color) then return end
  local m = current()
  if not m then say(color, "Nenhum mapa ativo.") return end
  m.grid = m.grid or { on = false, size = 1, snap = true, ox = 0, oz = 0 }
  return m.grid
end

function g_toggle(o, c) local g = gridOf(c) if g then g.on = not g.on; applyGrid(); build() end end
function g_snap(o, c) local g = gridOf(c) if g then g.snap = not g.snap; applyGrid(); build() end end
function g_less(o, c)
  local g = gridOf(c)
  if g then g.size = math.max(GRID_STEP, g.size - GRID_STEP); applyGrid(); build() end
end
function g_more(o, c) local g = gridOf(c) if g then g.size = g.size + GRID_STEP; applyGrid(); build() end end
-- Desloca a grade em 1/4 de quadrado, para alinhar com as linhas desenhadas no próprio mapa.
function gridShift(c, dx, dz)
  local g = gridOf(c)
  if not g then return end
  g.ox = ((g.ox or 0) + dx * g.size / 4) % g.size
  g.oz = ((g.oz or 0) + dz * g.size / 4) % g.size
  applyGrid()
end
function g_left(o, c) gridShift(c, -1, 0) end
function g_right(o, c) gridShift(c, 1, 0) end
function g_up(o, c) gridShift(c, 0, 1) end
function g_down(o, c) gridShift(c, 0, -1) end
function s1(o, c, a) slot(1, c, a) end
function s2(o, c, a) slot(2, c, a) end
function s3(o, c, a) slot(3, c, a) end
function s4(o, c, a) slot(4, c, a) end
function s5(o, c, a) slot(5, c, a) end
function s6(o, c, a) slot(6, c, a) end
function s7(o, c, a) slot(7, c, a) end

function b_prev() if page > 1 then page = page - 1; build() end end
function b_next()
  if page < math.ceil(#getEntries() / ROWS) then page = page + 1; build() end
end

function setFit(color, fit)
  if not isAdmin(color) then return end
  local m = current()
  if not m then return end
  m.fit = fit
  showMap(m)
  build()
end
function f_mesa(o, c) setFit(c, "mesa") end
function f_caber(o, c) setFit(c, "caber") end
function f_preencher(o, c) setFit(c, "preencher") end

function adjust(color, kind)
  if not isAdmin(color) then return end
  local m = current()
  if not m then return end
  if m.fit == "mesa" then
    return say(color, "Zoom, giro e posição funcionam nos modos Caber e Preencher.")
  end
  if kind == "zoom_in" then m.zoom = (m.zoom or 1) * ZOOM_STEP
  elseif kind == "zoom_out" then m.zoom = (m.zoom or 1) / ZOOM_STEP
  elseif kind == "rot" then m.rot = ((m.rot or 0) + 90) % 360
  elseif kind == "up" then m.oz = (m.oz or 0) + MOVE_STEP
  elseif kind == "down" then m.oz = (m.oz or 0) - MOVE_STEP
  elseif kind == "left" then m.ox = (m.ox or 0) - MOVE_STEP
  elseif kind == "right" then m.ox = (m.ox or 0) + MOVE_STEP
  elseif kind == "reset" then m.zoom, m.ox, m.oz, m.rot = 1, 0, 0, 0
  end
  if getTile() then refit() else showMap(m) end
end
function a_zout(o, c) adjust(c, "zoom_out") end
function a_zin(o, c) adjust(c, "zoom_in") end
function a_rot(o, c) adjust(c, "rot") end
function a_reset(o, c) adjust(c, "reset") end
function a_left(o, c) adjust(c, "left") end
function a_up(o, c) adjust(c, "up") end
function a_down(o, c) adjust(c, "down") end
function a_right(o, c) adjust(c, "right") end

-- Calibração: depois do clique você tem 3 segundos para mirar o mouse no canto da área.
function b_calib(o, color)
  if not isAdmin(color) then return end
  local step = calibCorner1 and 2 or 1
  say(color, "Mire o mouse no canto " .. step .. " da área amarela... (3s)")
  Wait.time(function()
    local p = Player[color].getPointerPosition()
    if step == 1 then
      calibCorner1 = p
      say(color, "Canto 1 marcado. Clique em Calibrar de novo para o canto oposto.")
    else
      local c1 = calibCorner1
      D.area = {
        x = (c1.x + p.x) / 2, z = (c1.z + p.z) / 2, y = (c1.y + p.y) / 2,
        w = math.abs(p.x - c1.x), d = math.abs(p.z - c1.z),
        manual = true,
      }
      calibCorner1 = nil
      say(color, string.format("Área calibrada: %.2f x %.2f", D.area.w, D.area.d))
      showArea()
      applyGrid()
      buildFog()
      local m = current()
      if m and m.fit ~= "mesa" then showMap(m) end
    end
    build()
  end, 3)
end

function b_area() showArea() end

--------------------------------------------------------------------------
-- Fog of war
-- A área é dividida em células; cada célula coberta é um "teto" preto flutuando acima do mapa,
-- invisível para o mestre e não-interativo (não atrapalha mover as peças por baixo).
--------------------------------------------------------------------------
local FOG_HEIGHT = 6       -- altura do teto de fog acima da mesa
local FOG_COLOR = { 0.04, 0.04, 0.06 }

fogTiles = {}   -- chave "i:j" -> objeto
brush = nil     -- { color, open, waitId }
brushRadius = 1.5
gmSeesFog = false

function fogOf(m)
  m = m or current()
  if not m then return nil end
  m.fog = m.fog or { on = false, cell = 2, open = {} }
  m.fog.open = m.fog.open or {}
  return m.fog
end

-- Dimensões da grade de fog para a área atual.
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

-- Cores que não devem ver o fog: o mestre (host/admins sentados), a não ser que "GM vê" esteja ligado.
function fogHiddenFrom()
  if gmSeesFog then return {} end
  local list = {}
  for _, p in ipairs(Player.getPlayers()) do
    if (p.admin or p.host) and p.color ~= "Grey" then table.insert(list, p.color) end
  end
  return list
end

function clearFog()
  for _, o in ipairs(getObjectsWithTag("Fog")) do o.destruct() end
  fogTiles = {}
end

function spawnFogCell(i, j, cw, cd)
  local key = i .. ":" .. j
  if fogTiles[key] then return end
  local x, z = cellCenter(i, j, cw, cd)
  local hidden = fogHiddenFrom()
  fogTiles[key] = spawnObject({
    type = "BlockSquare",
    position = { x, D.area.y + FOG_HEIGHT, z },
    scale = { cw * 1.02, 0.15, cd * 1.02 },
    sound = false,
    callback_function = function(o)
      o.setLock(true)
      o.interactable = false
      o.addTag("Fog")
      o.setName("")
      o.setColorTint(FOG_COLOR)
      o.setInvisibleTo(hidden)
    end,
  })
end

function buildFog()
  clearFog()
  local m = current()
  local f = m and m.fog
  if not (f and f.on) then return end
  local nx, nz, cw, cd = fogGrid(f)
  for i = 1, nx do
    for j = 1, nz do
      if not f.open[i .. ":" .. j] then spawnFogCell(i, j, cw, cd) end
    end
  end
end

function refreshFogVisibility()
  local hidden = fogHiddenFrom()
  for _, o in ipairs(getObjectsWithTag("Fog")) do o.setInvisibleTo(hidden) end
end

function onPlayerChangeColor() refreshFogVisibility() end
function onPlayerConnect() Wait.frames(refreshFogVisibility, 5) end

-- Revela (open = true) ou cobre (open = false) as células num círculo em volta de pos.
function paintFog(pos, open)
  local f = fogOf()
  if not (f and f.on and pos) then return end
  local nx, nz, cw, cd = fogGrid(f)
  local reach = brushRadius + math.max(cw, cd) / 2
  for i = 1, nx do
    for j = 1, nz do
      local x, z = cellCenter(i, j, cw, cd)
      local dx, dz = x - pos.x, z - pos.z
      if dx * dx + dz * dz <= reach * reach then
        local key = i .. ":" .. j
        if open then
          if not f.open[key] then
            f.open[key] = true
            if fogTiles[key] then fogTiles[key].destruct() end
            fogTiles[key] = nil
          end
        elseif f.open[key] then
          f.open[key] = nil
          spawnFogCell(i, j, cw, cd)
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
  brush = { color = color, open = open, waitId = id }
end

function stopBrush()
  if brush then Wait.stop(brush.waitId) end
  brush = nil
end

function hotkeyBrush(color, up, open)
  local p = Player[color]
  if not (p and (p.admin or p.host)) then return end
  if up then
    stopBrush()
    build()
  else
    if not (fogOf() and fogOf().on) then return say(color, "Ligue o Fog primeiro.") end
    startBrush(color, open)
  end
end

function fz_toggle(o, c)
  if not isAdmin(c) then return end
  local f = fogOf()
  if not f then return say(c, "Nenhum mapa ativo.") end
  f.on = not f.on
  if not f.on then stopBrush() end
  buildFog()
  build()
end

function fz_cover(o, c)
  if not isAdmin(c) then return end
  local f = fogOf()
  if not f then return end
  f.on = true
  f.open = {}
  buildFog()
  build()
end

function fz_clear(o, c)
  if not isAdmin(c) then return end
  local f = fogOf()
  if not f then return end
  local nx, nz = fogGrid(f)
  for i = 1, nx do for j = 1, nz do f.open[i .. ":" .. j] = true end end
  buildFog()
  build()
end

function fz_gm(o, c)
  if not isAdmin(c) then return end
  gmSeesFog = not gmSeesFog
  refreshFogVisibility()
  build()
end

function brushButton(c, open)
  if not isAdmin(c) then return end
  local f = fogOf()
  if not (f and f.on) then return say(c, "Ligue o Fog primeiro.") end
  if brush and brush.open == open then
    stopBrush()
  else
    startBrush(c, open)
    say(c, open and "Pincel REVELAR ligado: passe o mouse sobre o mapa. Clique de novo para desligar."
      or "Pincel ESCONDER ligado: passe o mouse sobre o mapa. Clique de novo para desligar.")
  end
  build()
end
function fz_reveal(o, c) brushButton(c, true) end
function fz_hide(o, c) brushButton(c, false) end

function fz_rless(o, c) if isAdmin(c) then brushRadius = math.max(0.5, brushRadius - 0.5); build() end end
function fz_rmore(o, c) if isAdmin(c) then brushRadius = brushRadius + 0.5; build() end end

-- Mudar o tamanho da célula refaz a grade de fog, então tudo volta a ficar coberto.
function cellChange(c, delta)
  if not isAdmin(c) then return end
  local f = fogOf()
  if not f then return end
  local new = math.max(0.5, f.cell + delta)
  if new == f.cell then return end
  if next(f.open) and pendingDelete ~= "cell" then
    pendingDelete = "cell"
    return say(c, "Mudar a célula cobre o mapa todo de novo. Clique outra vez para confirmar.")
  end
  pendingDelete = nil
  f.cell = new
  f.open = {}
  buildFog()
  build()
end
function fz_cless(o, c) cellChange(c, -0.5) end
function fz_cmore(o, c) cellChange(c, 0.5) end

function b_fixo(o, color)
  if not isAdmin(color) then return end
  local sel = Player[color].getSelectedObjects()
  if #sel == 0 then return say(color, "Selecione objetos primeiro (arraste uma caixa ou Ctrl+clique).") end
  for _, obj in ipairs(sel) do
    if obj.hasTag("Fixo") then
      obj.removeTag("Fixo")
      say(color, obj.getName() .. ": não é mais fixo")
    else
      obj.addTag("Fixo")
      say(color, obj.getName() .. ": fixo")
    end
  end
end


--------------------------------------------------------------------------
-- Aparência: placa de madeira
--------------------------------------------------------------------------
-- Ajusta a escala para a placa ter BOARD.w x BOARD.d no mundo, seja um bloco ou um Custom Tile com a textura.
function fitBoard()
  local co = self.getCustomObject()
  local textured = co and co.image and co.image ~= ""
  -- A lateral do Custom Tile é branca; com espessura mínima ela praticamente some.
  if textured and (co.thickness or 0) > 0.11 then
    self.setCustomObject({ image = co.image, type = co.type, thickness = 0.1, stretch = co.stretch })
    self.reload()
    return
  end
  local s = self.getScale()
  local b = self.getBoundsNormalized().size
  if b.x > 0 and b.z > 0 then
    local sx, sz = BOARD.w / (b.x / s.x), BOARD.d / (b.z / s.z)
    if math.abs(sx - s.x) > 0.01 or math.abs(sz - s.z) > 0.01 then
      self.setScale({ sx, textured and s.y or 0.2, sz })
    end
  end
  -- Sem textura (bloco comum): pelo menos fica com cor de madeira.
  if not textured then self.setColorTint({ 0.36, 0.22, 0.12 }) end
end

--------------------------------------------------------------------------
-- Layout (coordenadas em unidades do mundo, a partir do centro do painel; +z = topo)
--------------------------------------------------------------------------
local BTN = { 0.20, 0.12, 0.06, 0.93 }
local BTN_SOFT = { 0.29, 0.18, 0.09, 0.93 }
local BRASS = { 0.62, 0.45, 0.16, 0.97 }
local GREEN = { 0.27, 0.37, 0.16, 0.95 }
local RED = { 0.47, 0.16, 0.11, 0.95 }
local FOLDER = { 0.42, 0.29, 0.12, 0.95 }
local INK = { 0.97, 0.91, 0.76 }
local GOLD = { 0.98, 0.80, 0.40 }
local MUTED = { 0.80, 0.70, 0.52 }

function place(x, z)
  local s = self.getScale()
  -- Altura inteira (não a metade): o pivô do Custom Tile fica na base, não no centro como no bloco.
  local top = (self.getBoundsNormalized().size.y + 0.05) / s.y
  return { x / s.x, top, z / s.z }, { 1 / s.x, 1 / s.y, 1 / s.z }
end

function B(text, fn, x, z, w, h, color, fontColor, tip)
  local pos, sc = place(x, z)
  self.createButton({
    label = text, click_function = fn, function_owner = self,
    position = pos, scale = sc,
    width = w * U, height = h * U, font_size = math.floor(h * U * 0.45),
    color = color or BTN, font_color = fontColor or INK,
    hover_color = { 0.55, 0.38, 0.16 }, press_color = { 0.75, 0.55, 0.2 },
    tooltip = tip or "",
  })
end

function L(text, x, z, h, fontColor)
  B(text, "noop", x, z, 0, h, { 0, 0, 0, 0 }, fontColor or INK)
end

function I(fn, placeholder, value, x, z, w, h)
  local pos, sc = place(x, z)
  self.createInput({
    input_function = fn, function_owner = self, label = placeholder, value = value,
    position = pos, scale = sc, alignment = 2,
    width = w * U, height = h * U, font_size = math.floor(h * U * 0.4),
    color = { 0.93, 0.86, 0.70 }, font_color = { 0.20, 0.12, 0.06 },
  })
end

function build()
  self.clearButtons()
  self.clearInputs()
  local m = current()
  local W = BOARD.w - 1.2
  local hw = W / 2 - 0.05
  local qw = W / 4 - 0.08
  local qx = { -W * 3 / 8, -W / 8, W / 8, W * 3 / 8 }
  local cw = W / 3 - 0.08
  local cx = { -W / 3, 0, W / 3 }

  -- Cursor vertical: cada linha ocupa sua altura + um respiro.
  local z = BOARD.d / 2 - 0.5
  local function line(h)
    local c = z - h / 2
    z = z - h - 0.1
    return c
  end
  local function section(title)
    L("-  " .. title .. "  -", 0, line(0.3), 0.3, GOLD)
  end
  local function on(flag) return flag and BRASS or BTN end

  -- Cabeçalho (cai sobre a placa escura da textura)
  local c = line(0.6)
  L(D.openFolder and ("MAPAS  /  " .. D.openFolder) or "MAPAS", 0, c, 0.55, GOLD)

  c = line(0.5); I("in_name", "Nome (mapa ou pasta)", newName, 0, c, W, 0.5)
  c = line(0.5); I("in_url", "Link da imagem (.jpg / .png)", newUrl, 0, c, W, 0.5)
  c = line(0.5)
  B("+ Adicionar link", "b_add", -W / 4, c, hw, 0.5, GREEN)
  B("+ Arquivo do PC", "b_custom", W / 4, c, hw, 0.5, GREEN, INK, "Escolher uma imagem do seu PC e subir para a Cloud")
  c = line(0.5)
  B("+ Nova pasta", "b_newfolder", -W / 4, c, hw, 0.5, FOLDER, INK, "Cria uma pasta com o nome digitado")
  B("Mover atual p/ cá", "b_move", W / 4, c, hw, 0.5, FOLDER, INK, "Move o mapa ativo para a pasta aberta (ou para a raiz)")

  -- Lista
  local entries = getEntries()
  local pages = math.max(1, math.ceil(#entries / ROWS))
  if page > pages then page = pages end
  local listTop = z
  for n = 1, ROWS do
    local e = entries[(page - 1) * ROWS + n]
    local rz = listTop - (n - 1) * 0.58 - 0.24
    if e then
      if e.kind == "back" then
        B("<  Voltar", "s" .. n, 0, rz, W, 0.48, BTN_SOFT)
      elseif e.kind == "folder" then
        B("[ " .. e.name .. " ]   " .. e.count .. " mapa(s)", "s" .. n, 0, rz, W, 0.48, FOLDER, INK,
          "Clique: abrir   |   Botão direito 2x: apagar pasta")
      else
        local mp = D.maps[e.i]
        local sel = (e.i == D.current)
        B((sel and ">  " or "") .. mp.name .. (mp.saved and "  *" or ""), "s" .. n, 0, rz, W, 0.48,
          sel and BRASS or BTN, INK, "Clique: carregar   |   Botão direito 2x: apagar   |   * = tem estado salvo")
      end
    end
  end
  if #entries == 0 then L("Nenhum mapa ainda.", 0, listTop - 0.24, 0.4, MUTED) end
  z = listTop - ROWS * 0.58
  c = line(0.45)
  B("<", "b_prev", -W / 3, c, 1.1, 0.45)
  L(page .. " / " .. pages, 0, c, 0.4, MUTED)
  B(">", "b_next", W / 3, c, 1.1, 0.45)

  -- Imagem
  section("IMAGEM")
  local fit = m and m.fit or ""
  c = line(0.5)
  B("Mesa", "f_mesa", cx[1], c, cw, 0.5, on(fit == "mesa"), INK, "Imagem direto na parte customizável da mesa")
  B("Caber", "f_caber", cx[2], c, cw, 0.5, on(fit == "caber"), INK, "Tile por cima, imagem inteira visível")
  B("Preencher", "f_preencher", cx[3], c, cw, 0.5, on(fit == "preencher"), INK, "Tile por cima, cobre a área toda")
  c = line(0.5)
  B("Zoom -", "a_zout", qx[1], c, qw, 0.5)
  B("Zoom +", "a_zin", qx[2], c, qw, 0.5)
  B("Girar", "a_rot", qx[3], c, qw, 0.5)
  B("Reset", "a_reset", qx[4], c, qw, 0.5)
  c = line(0.5)
  B("<", "a_left", qx[1], c, qw, 0.5)
  B("^", "a_up", qx[2], c, qw, 0.5)
  B("v", "a_down", qx[3], c, qw, 0.5)
  B(">", "a_right", qx[4], c, qw, 0.5)

  -- Estado
  section("ESTADO")
  c = line(0.5)
  B("Salvar estado", "b_save", -W / 4, c, hw, 0.5, GREEN, INK, "Guarda a posição de todos os props e tokens em cima do mapa")
  B("Restaurar", "b_restore", W / 4, c, hw, 0.5, RED, INK, "Volta a mesa para o último estado salvo")

  -- Grade
  section("GRADE")
  local g = m and m.grid
  local gon = g and g.on
  local snap = not (g and g.snap == false)
  c = line(0.5)
  B(gon and "Grade: ON" or "Grade: OFF", "g_toggle", qx[1], c, qw, 0.5, on(gon))
  B("Tam -", "g_less", qx[2], c, qw, 0.5)
  B("Tam +  (" .. (g and g.size or 1) .. ")", "g_more", qx[3], c, qw, 0.5)
  B(snap and "Snap: ON" or "Snap: OFF", "g_snap", qx[4], c, qw, 0.5, on(snap), INK, "Peças encaixam no centro dos quadrados")
  c = line(0.4)
  B("<", "g_left", qx[1], c, qw, 0.4, BTN_SOFT, INK, "Desloca a grade para alinhar com o mapa")
  B("^", "g_up", qx[2], c, qw, 0.4, BTN_SOFT)
  B("v", "g_down", qx[3], c, qw, 0.4, BTN_SOFT)
  B(">", "g_right", qx[4], c, qw, 0.4, BTN_SOFT)

  -- Área
  section("ÁREA")
  c = line(0.45)
  B("Auto", "b_auto", qx[1], c, qw, 0.45, BTN, INK, "Detecta a área customizável pela própria mesa")
  B(calibCorner1 and "Canto 2" or "Calibrar", "b_calib", qx[2], c, qw, 0.45, on(calibCorner1 ~= nil), INK,
    "Manual: clique e mire o mouse no canto da área em 3s")
  B("Ver área", "b_area", qx[3], c, qw, 0.45)
  B("Fixar", "b_fixo", qx[4], c, qw, 0.45, BTN, INK, "Objetos selecionados não trocam junto com o mapa")

  -- Fog of war
  section("FOG OF WAR")
  local f = m and m.fog
  local fon = f and f.on
  c = line(0.5)
  B(fon and "Fog: ON" or "Fog: OFF", "fz_toggle", qx[1], c, qw, 0.5, on(fon))
  B("Cobrir tudo", "fz_cover", qx[2], c, qw, 0.5)
  B("Revelar tudo", "fz_clear", qx[3], c, qw, 0.5)
  B(gmSeesFog and "GM vê: ON" or "GM vê: OFF", "fz_gm", qx[4], c, qw, 0.5, on(gmSeesFog), INK,
    "Mostra o fog também para o mestre")
  local reveal = brush and brush.open
  local hide = brush and not brush.open
  c = line(0.5)
  B(reveal and "Revelando..." or "Pincel revelar", "fz_reveal", qx[1], c, qw, 0.5, reveal and GREEN or BTN, INK,
    "Liga/desliga: revela o fog por onde o mouse passa")
  B(hide and "Escondendo..." or "Pincel esconder", "fz_hide", qx[2], c, qw, 0.5, hide and RED or BTN, INK,
    "Liga/desliga: cobre de novo por onde o mouse passa")
  B("Raio -", "fz_rless", qx[3], c, qw, 0.5)
  B("Raio +  (" .. brushRadius .. ")", "fz_rmore", qx[4], c, qw, 0.5)
  c = line(0.4)
  B("Célula -", "fz_cless", qx[1], c, qw, 0.4, BTN_SOFT)
  B("Célula +  (" .. (f and f.cell or 2) .. ")", "fz_cmore", qx[2], c, qw, 0.4, BTN_SOFT)
  L("Atalhos: Options > Game Keys", W / 4, c, 0.3, MUTED)
end
