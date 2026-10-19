--[[
  Névoa de Guerra (Fog of War) — objeto separado do Atlas do Mestre.

  Como o spawner do OneWorld: um objeto com o botão NÉVOA que cobre o mapa com o Fog of War nativo do
  TTS. Tudo que fica dentro da névoa (o mapa, objetos e tokens) é escondido dos jogadores; os reveladores
  abrem a névoa por onde passam. Quem está no Black (mestre/host) enxerga tudo.

  A área coberta é a mesma do Atlas do Mestre (automática ou calibrada na aba Área). Sem o Atlas na mesa,
  usa uma área padrão de 95 x 72 (como o OneWorld).

  Os ajustes da névoa e dos reveladores (alcance, cor, ReHide Objects, Fog Height...) são os do próprio TTS:
  clique esquerdo na névoa e, no revelador, Toggles > Reveal Fog of War.

  Instalação:
    1. Objects > Components > Custom > Model
         Model/Mesh: assets/nevoa.obj    Diffuse/Image: assets/nevoa.png    (aceite subir para a Cloud)
       (ou use qualquer objeto pequeno, ou o objeto salvo assets/nevoa_objeto.json em Saves/Saved Objects)
    2. Clique direito > Scripting > Scripting Editor, cole este arquivo, Save & Play.
    3. Para o Atlas informar área, mapa e idioma, ele precisa da função getInfo() (já está no Atlas.lua deste repositório).

  Uso:
    * Botão NÉVOA: cria a névoa sobre o mapa (de novo: remove).
    * Clique direito no objeto: informações, remover todas as névoas, esconder tudo de novo, criar revelador
      e marcar os objetos selecionados como reveladores.
    * Cada mapa do Atlas guarda a própria névoa e o que já foi revelado; ao trocar de mapa ela volta como estava.
]]

--------------------------------------------------------------------------
-- Estado (vai para o save do objeto)
--------------------------------------------------------------------------
F = {
  maps = {},          -- por mapa do Atlas: { on = bool, revealed = RevealedLocations (tabelas simples) }
  area = nil,         -- área própria (usada só quando o Atlas não está na mesa)
  lang = "pt",
}

-- Estado só da sessão
S = { key = nil, areaSig = nil, building = false, lang = nil }

-- Atenção: não use as tags "Fog", "AtlasNevoa", "AtlasRevelador" ou "AtlasVisao": o Atlas as apaga ao carregar.
local TAG_ZONE, TAG_REVEAL = "NevoaZona", "NevoaRevelador"
local ZONE_HEIGHT = 20                                    -- igual ao spawner do OneWorld
local DEFAULT_AREA = { x = 0, y = 0.91, z = 0, w = 95, d = 72 }
local POLL = 1                                            -- segundos entre as checagens do Atlas
local MODEL_TOP = 1.02                                    -- altura do topo do modelo assets/nevoa.obj

--------------------------------------------------------------------------
-- Idioma (segue o do Atlas quando ele está na mesa)
--------------------------------------------------------------------------
local EN = {
  ["NÉVOA"] = "FOG", ["NÉVOA ON"] = "FOG ON", ["Névoa de guerra"] = "Fog of war",
  ["Só o mestre (host/admin) pode usar a névoa."] = "Only the game master (host/admin) can use the fog.",
  ["Informações"] = "Info", ["Remover todas as névoas"] = "Remove all fogs",
  ["Esconder tudo de novo"] = "Hide everything again", ["Criar revelador"] = "Create revealer",
  ["Marcar selecionados como reveladores"] = "Make selected objects revealers",
  ["Névoa criada: %.1f x %.1f"] = "Fog created: %.1f x %.1f",
  ["O TTS não criou a zona de névoa."] = "TTS did not create the fog zone.",
  ["Névoa removida."] = "Fog removed.", ["Nenhuma névoa encontrada."] = "No fog found.",
  ["Névoa escondendo tudo de novo..."] = "Fog hiding everything again...",
  ["Revelador"] = "Revealer",
  ["Arraste pelo mapa: a névoa some por onde ele passa."] = "Drag it over the map: the fog disappears where it passes.",
  ["Revelador criado. Arraste para onde quiser."] = "Revealer created. Drag it anywhere.",
  ["Selecione objetos primeiro (clique, ou arraste uma caixa)."] = "Select objects first (click, or drag a box).",
  [" objeto(s) agora revelam a névoa."] = " object(s) now reveal the fog.",
  ["Não consegui ligar o Reveal Fog of War em '%s'. Ligue em Toggles > Reveal Fog of War."] =
    "Could not turn on Reveal Fog of War for '%s'. Turn it on in Toggles > Reveal Fog of War.",
  ["--- Informações da névoa ---"] = "--- Fog info ---",
  ["Área %.1f x %.1f em (%.1f, %.1f), altura %.2f. Fonte: %s."] = "Area %.1f x %.1f at (%.1f, %.1f), height %.2f. Source: %s.",
  ["Você está no assento: %s. O Black (mestre) enxerga tudo na névoa: para ver o efeito, troque para outra cor."] =
    "You are seated as: %s. Black (the GM) sees everything in the fog: to see the effect, switch to another color.",
  ["Nenhuma zona de névoa na mesa."] = "No fog zone on the table.",
  ["Zona: centro (%.1f, %.1f, %.1f), tamanho %.1f x %.1f x %.1f, base em y=%.2f."] =
    "Zone: center (%.1f, %.1f, %.1f), size %.1f x %.1f x %.1f, base at y=%.2f.",
  ["Zona: HideObjects=%s, ReHideObjects=%s, Height=%s, áreas reveladas=%d"] =
    "Zone: HideObjects=%s, ReHideObjects=%s, Height=%s, revealed areas=%d",
  ["Nenhum objeto com 'Reveal Fog of War' ligado."] = "No object has 'Reveal Fog of War' on.",
  ["Revelador '%s' em (%.1f, %.1f, %.1f): alcance=%s, cor=%s. %s"] =
    "Revealer '%s' at (%.1f, %.1f, %.1f): range=%s, color=%s. %s",
  ["DENTRO da zona."] = "INSIDE the zone.",
  ["FORA da zona (a névoa só revela dentro dela)."] = "OUTSIDE the zone (the fog only reveals inside it).",
  ["Atlas"] = "Atlas", ["estado salvo do Atlas"] = "Atlas saved state", ["área própria"] = "own area",
  ["área padrão"] = "default area",
}

function tr(s)
  if (S.lang or F.lang) == "en" then return EN[s] or s end
  return s
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

function isGM(color)
  local p = Player[color]
  if p and (p.host or p.admin or color == "Black") then return true end
  say(color, tr("Só o mestre (host/admin) pode usar a névoa."))
  return false
end

local function sig(a)
  return string.format("%.2f|%.2f|%.2f|%.2f|%.2f", a.x, a.z, a.w, a.d, a.y or 0)
end

-- O TTS devolve vetores como userdata, que o JSON.encode não aceita: copia tudo para tabelas simples.
local function plain(v, depth)
  depth = depth or 0
  local t = type(v)
  if t == "number" or t == "string" or t == "boolean" or t == "nil" then return v end
  if depth > 6 then return nil end
  if t == "table" then
    local r = {}
    if #v > 0 then   -- lista: mantém a ordem e descarta o que não der para converter
      for i = 1, #v do
        local x = plain(v[i], depth + 1)
        if x ~= nil then table.insert(r, x) end
      end
    else
      for k, x in pairs(v) do
        local kk = (type(k) == "number" or type(k) == "string") and k or tostring(k)
        r[kk] = plain(x, depth + 1)
      end
    end
    return r
  end
  local r = {}   -- userdata (Vector, Color...): só x/y/z
  for _, f in ipairs({ "x", "y", "z" }) do
    local ok, val = pcall(function() return v[f] end)
    if ok and type(val) == "number" then r[f] = val end
  end
  if next(r) == nil then return nil end
  return r
end

--------------------------------------------------------------------------
-- Área e mapa: vêm do Atlas (getInfo) — automática ou calibrada, igual à do mapa
--------------------------------------------------------------------------
local function atlasObj()
  for _, o in ipairs(getObjectsWithTag("AtlasMesa")) do
    if o ~= self then return o end
  end
  return nil
end

-- Devolve { area = {x,y,z,w,d}, map = índice|nil, mapName = nome|nil, lang = "pt"|"en"|nil, source = texto }
function info()
  local at = atlasObj()
  if at then
    local ok, r = pcall(function() return at.call("getInfo") end)
    if ok and type(r) == "table" and type(r.area) == "table" and (r.area.w or 0) > 0 then
      r.source = "Atlas"
      return r
    end
    -- Atlas sem getInfo: lê o estado que ele salvou (pode estar um pouco desatualizado)
    local ok2, st = pcall(JSON.decode, at.script_state or "")
    if ok2 and type(st) == "table" and type(st.area) == "table" and (st.area.w or 0) > 0 then
      local m = st.current and st.maps and st.maps[st.current]
      return { area = st.area, map = st.current, mapName = m and m.name or nil, lang = st.lang,
               source = "estado salvo do Atlas" }
    end
  end
  if F.area then return { area = F.area, source = "área própria" } end
  return { area = DEFAULT_AREA, source = "área padrão" }
end

local function mapKey(i)
  if i.map then return tostring(i.map) .. ":" .. tostring(i.mapName or "") end
  return "_"
end

local function mapState(key)
  F.maps[key] = F.maps[key] or { on = false, revealed = {} }
  return F.maps[key]
end

-- Altura do pano: a área do Atlas, ou o topo do tile do mapa se ele estiver por cima.
local function surfaceTop(area)
  local top = area.y or 0
  for _, t in ipairs(getObjectsWithTag("MapaTile")) do
    local b = t.getBounds()
    top = math.max(top, b.center.y + b.size.y / 2)
  end
  return top
end

--------------------------------------------------------------------------
-- A zona de névoa (Fog of War nativo)
--------------------------------------------------------------------------
function fogZone() return getObjectsWithTag(TAG_ZONE)[1] end

-- Qualquer Fog of War na mesa (inclusive de outros mods), como o "Remove All Fogs" do OneWorld.
local function allFogs()
  local list = {}
  for _, o in ipairs(getObjects()) do
    if o ~= self and o.type == "FogOfWar" then table.insert(list, o) end
  end
  return list
end

local function destroyZones()
  local n = 0
  for _, o in ipairs(allFogs()) do o.destruct(); n = n + 1 end
  return n
end

-- O que já foi revelado na zona atual (RevealedLocations), em tabelas simples, para voltar igual depois.
local function captureReveals()
  local z = fogZone() or allFogs()[1]
  if not z then return nil end
  local ok, data = pcall(z.getData)
  if ok and type(data) == "table" and type(data.FogOfWar) == "table" then
    return plain(data.FogOfWar.RevealedLocations or {})
  end
  return nil
end

-- Campos iguais aos do spawner do OneWorld.
local function zoneData(revealed)
  return {
    Name = "FogOfWar",
    Transform = { posX = 0, posY = 0, posZ = 0, rotX = 0, rotY = 0, rotZ = 0, scaleX = 1, scaleY = 1, scaleZ = 1 },
    Nickname = tr("Névoa de guerra"),
    Description = "",
    GMNotes = "",
    ColorDiffuse = { r = 0.25, g = 0.25, b = 0.25, a = 0.1025644 },
    LayoutGroupSortIndex = 0,
    Value = 0,
    Locked = true,
    Grid = true,
    Snap = true,
    IgnoreFoW = false,
    MeasureMovement = false,
    DragSelectable = true,
    Autoraise = true,
    Sticky = true,
    Tooltip = true,
    GridProjection = false,
    HideWhenFaceDown = false,
    Hands = false,
    FogOfWar = {
      HideGmPointer = false,
      HideObjects = true,
      ReHideObjects = false,
      Height = 0,
      RevealedLocations = revealed or {},
    },
    LuaScript = "",
    LuaScriptState = "",
    XmlUI = "",
  }
end

-- Cria a névoa cobrindo a área. A base fica logo ACIMA do pano (ou do tile do mapa): o plano preto é
-- desenhado na base da zona, e abaixo da superfície ele sumiria embaixo da mesa.
function buildFog(revealed)
  if S.building then return end
  S.building = true
  Wait.time(function() S.building = false end, 3)
  local a = info().area
  local py = surfaceTop(a) + 0.03 + ZONE_HEIGHT / 2
  local zone = spawnObjectData({
    data = zoneData(revealed),
    position = { x = a.x, y = 100, z = a.z },
    rotation = { x = 0, y = 0, z = 0 },
    scale = { x = a.w, y = ZONE_HEIGHT, z = a.d },
    sound = false,
    callback_function = function(o)
      o.addTag(TAG_ZONE)
      o.addTag("Fixo")   -- o Atlas não guarda nem apaga este objeto ao trocar de mapa
      o.setPositionSmooth({ a.x, py, a.z })
      S.building = false
      S.areaSig = sig(a)
      local b = o.getBounds().size
      say(nil, string.format(tr("Névoa criada: %.1f x %.1f"), b.x, b.z))
    end,
  })
  if not zone then
    S.building = false
    say(nil, tr("O TTS não criou a zona de névoa."))
  end
end

--------------------------------------------------------------------------
-- Ações (botão e menu de contexto)
--------------------------------------------------------------------------
function fogToggle(c)
  if c and not isGM(c) then return end
  local ms = mapState(S.key or mapKey(info()))
  if #allFogs() > 0 then
    ms.revealed = captureReveals() or ms.revealed
    destroyZones()
    ms.on = false
    say(c, tr("Névoa removida."))
  else
    ms.on = true
    buildFog(ms.revealed)
  end
  Wait.time(refreshButton, 0.8)
end

function fogRemoveAll(c)
  if c and not isGM(c) then return end
  local n = destroyZones()
  local ms = mapState(S.key or mapKey(info()))
  ms.on = false
  say(c, n > 0 and tr("Névoa removida.") or tr("Nenhuma névoa encontrada."))
  Wait.time(refreshButton, 0.8)
end

-- Esconder tudo: apaga o que já foi revelado e recria a névoa.
function fogReset(c)
  if c and not isGM(c) then return end
  local ms = mapState(S.key or mapKey(info()))
  ms.revealed = {}
  ms.on = true
  destroyZones()
  say(c, tr("Névoa escondendo tudo de novo..."))
  Wait.frames(function() buildFog({}) end, 6)
  Wait.time(refreshButton, 1.5)
end

-- Recria a zona mantendo o que já foi revelado (mudou a área do Atlas).
local function rebuildKeeping()
  local ms = mapState(S.key or mapKey(info()))
  ms.revealed = captureReveals() or ms.revealed
  destroyZones()
  Wait.frames(function() buildFog(ms.revealed) end, 6)
end

--------------------------------------------------------------------------
-- Reveladores: só liga o Reveal Fog of War; alcance, cor etc. se ajustam no próprio objeto (como no TTS)
--------------------------------------------------------------------------
local function applyReveal(o, c)
  o.addTag(TAG_REVEAL)
  o.addTag("Fixo")   -- fica na mesa quando o Atlas troca de mapa
  o.setFogOfWarReveal({ reveal = true })
  -- confere depois de um instante: se o TTS não ligou, avisa em vez de falhar calado
  Wait.frames(function()
    local ok, r = pcall(o.getFogOfWarReveal)
    if not (ok and type(r) == "table" and r.reveal) then
      pcall(function() o.setFogOfWarReveal({ reveal = true }) end)
      Wait.frames(function()
        local ok2, r2 = pcall(o.getFogOfWarReveal)
        if not (ok2 and type(r2) == "table" and r2.reveal) then
          say(c, string.format(tr("Não consegui ligar o Reveal Fog of War em '%s'. Ligue em Toggles > Reveal Fog of War."),
            o.getName() ~= "" and o.getName() or o.type))
        end
      end, 20)
    end
  end, 15)
end

function newRevealer(c)
  if c and not isGM(c) then return end
  local a = info().area
  local n = #getObjectsWithTag(TAG_REVEAL)
  spawnObject({
    type = "backgammon_piece_white",
    position = { a.x - a.w / 2 + 4 + (n % 8) * 3, surfaceTop(a) + 3, a.z + a.d / 2 + 3 },
    rotation = { 0, 0, 0 },
    scale = { 1.4, 1.4, 1.4 },
    sound = false,
    callback_function = function(o)
      o.setName(tr("Revelador"))
      o.setDescription(tr("Arraste pelo mapa: a névoa some por onde ele passa."))
      o.setColorTint({ 1, 0.85, 0.3 })
      applyReveal(o, c)
    end,
  })
  say(c, tr("Revelador criado. Arraste para onde quiser."))
end

function markSelected(c)
  if not isGM(c) then return end
  local n = 0
  for _, o in ipairs(Player[c].getSelectedObjects()) do
    if o ~= self and o.type ~= "FogOfWar" and not o.hasTag("MapaTile") and not o.hasTag("AtlasMesa") then
      applyReveal(o, c)
      n = n + 1
    end
  end
  if n == 0 then
    say(c, tr("Selecione objetos primeiro (clique, ou arraste uma caixa)."))
  else
    say(c, n .. tr(" objeto(s) agora revelam a névoa."))
  end
end

--------------------------------------------------------------------------
-- Informações: área usada, zona e reveladores (ajuda a achar o problema quando algo não funciona)
--------------------------------------------------------------------------
function showInfo(c)
  if not isGM(c) then return end
  local i = info()
  local a = i.area
  say(c, tr("--- Informações da névoa ---"))
  say(c, string.format(tr("Área %.1f x %.1f em (%.1f, %.1f), altura %.2f. Fonte: %s."),
    a.w, a.d, a.x, a.z, surfaceTop(a), tr(i.source)))
  say(c, string.format(tr("Você está no assento: %s. O Black (mestre) enxerga tudo na névoa: para ver o efeito, troque para outra cor."), tostring(c)))
  local z = fogZone() or allFogs()[1]
  local zb
  if not z then
    say(c, tr("Nenhuma zona de névoa na mesa."))
  else
    zb = z.getBounds()
    local sz = zb.size
    say(c, string.format(tr("Zona: centro (%.1f, %.1f, %.1f), tamanho %.1f x %.1f x %.1f, base em y=%.2f."),
      zb.center.x, zb.center.y, zb.center.z, sz.x, sz.y, sz.z, zb.center.y - sz.y / 2))
    local ok, data = pcall(z.getData)
    local f = ok and type(data) == "table" and data.FogOfWar or {}
    say(c, string.format(tr("Zona: HideObjects=%s, ReHideObjects=%s, Height=%s, áreas reveladas=%d"),
      tostring(f.HideObjects), tostring(f.ReHideObjects), tostring(f.Height), #(f.RevealedLocations or {})))
  end
  local n = 0
  for _, o in ipairs(getObjects()) do
    local ok, r = pcall(o.getFogOfWarReveal)
    if ok and type(r) == "table" and r.reveal then
      n = n + 1
      local p = o.getPosition()
      local where = ""
      if zb then
        local inside = math.abs(p.x - zb.center.x) <= zb.size.x / 2 and math.abs(p.z - zb.center.z) <= zb.size.z / 2
          and p.y >= zb.center.y - zb.size.y / 2 and p.y <= zb.center.y + zb.size.y / 2
        where = inside and tr("DENTRO da zona.") or tr("FORA da zona (a névoa só revela dentro dela).")
      end
      say(c, string.format(tr("Revelador '%s' em (%.1f, %.1f, %.1f): alcance=%s, cor=%s. %s"),
        o.getName() ~= "" and o.getName() or o.type, p.x, p.y, p.z, tostring(r.range), tostring(r.color), where))
    end
  end
  if n == 0 then say(c, tr("Nenhum objeto com 'Reveal Fog of War' ligado.")) end
end

--------------------------------------------------------------------------
-- Botão e menu de contexto
--------------------------------------------------------------------------
function buttonClick(_, c) fogToggle(c) end

local function isModel()
  local ok, co = pcall(self.getCustomObject)
  return ok and type(co) == "table" and co.mesh ~= nil and co.mesh ~= ""
end

local function buildButton()
  self.clearButtons()
  local b = {
    label = tr("NÉVOA"),
    click_function = "buttonClick",
    function_owner = self,
    color = { 0, 0, 0, 0 },
    hover_color = { 1, 1, 1, 0.12 },
    press_color = { 1, 1, 1, 0.25 },
    font_color = { 0.95, 0.84, 0.55 },
  }
  if isModel() then
    -- modelo assets/nevoa.obj (escala 1): disco de ardósia no topo, rótulo logo abaixo do olho
    b.position = { 0, MODEL_TOP + 0.02, -1.45 }
    b.rotation = { 0, 0, 0 }
    b.width, b.height, b.font_size = 1500, 420, 330
    b.color = { 0, 0, 0, 0 }
  else
    -- objeto simples (como o spawner do OneWorld)
    b.position = { 0, 0.3, 0 }
    b.rotation = { 0, 180, 0 }
    b.width, b.height, b.font_size = 800, 350, 250
    b.color = { 0, 0, 0 }
    b.font_color = { 1, 1, 1 }
  end
  self.createButton(b)
end

function refreshButton()
  local on = #allFogs() > 0
  pcall(function()
    self.editButton({
      index = 0,
      label = on and tr("NÉVOA ON") or tr("NÉVOA"),
      font_color = on and { 0.55, 0.95, 0.8 } or { 0.95, 0.84, 0.55 },
    })
  end)
end

local function buildMenu()
  self.clearContextMenu()
  self.addContextMenuItem(tr("Informações"), showInfo)
  self.addContextMenuItem(tr("Remover todas as névoas"), fogRemoveAll)
  self.addContextMenuItem(tr("Esconder tudo de novo"), fogReset)
  self.addContextMenuItem(tr("Criar revelador"), newRevealer)
  self.addContextMenuItem(tr("Marcar selecionados como reveladores"), markSelected)
end

--------------------------------------------------------------------------
-- Ligação com o Atlas: acompanha a troca de mapa e a calibragem da área
--------------------------------------------------------------------------
function poll()
  local i = info()
  if i.lang and i.lang ~= S.lang then
    S.lang = i.lang
    buildButton(); buildMenu()
  end
  local key, now = mapKey(i), sig(i.area)
  if S.key == nil then
    -- primeira leitura: adota o estado atual (a zona já pode ter vindo no save da mesa)
    S.key, S.areaSig = key, now
    local ms = mapState(key)
    if #allFogs() > 0 then ms.on = true end
  elseif key ~= S.key then
    -- troca de mapa: guarda o que o mapa antigo tinha revelado e devolve o do novo
    local old = F.maps[S.key]
    local rev = captureReveals()
    if old and rev then old.revealed = rev end
    S.key, S.areaSig = key, now
    local ms = mapState(key)
    destroyZones()
    if ms.on then Wait.frames(function() buildFog(ms.revealed) end, 8) end
  elseif now ~= S.areaSig and not S.building then
    -- mudou/calibrou a área: refaz a névoa com o que já foi revelado
    S.areaSig = now
    if fogZone() then rebuildKeeping() end
  end
  refreshButton()
end

--------------------------------------------------------------------------
-- Ciclo de vida
--------------------------------------------------------------------------
function onLoad(saved)
  if saved and saved ~= "" then
    local ok, t = pcall(JSON.decode, saved)
    if ok and type(t) == "table" then
      F.maps = type(t.maps) == "table" and t.maps or {}
      F.area = type(t.area) == "table" and t.area or nil
      F.lang = t.lang or F.lang
    end
  end
  self.setName(tr("Névoa de guerra"))
  self.addTag("Fixo")
  self.addTag("NevoaMesa")
  buildButton()
  buildMenu()
  Wait.time(poll, 1.5)
  Wait.time(poll, POLL, -1)
end

function onSave()
  local rev = captureReveals()
  if rev and S.key and F.maps[S.key] then F.maps[S.key].revealed = rev end
  local ok, text = pcall(JSON.encode, F)
  if ok then return text end
  -- se algum dado não couber no JSON, guarda o resto e só perde o "já revelado"
  local safe = { area = plain(F.area), lang = F.lang, maps = {} }
  for k, m in pairs(F.maps) do safe.maps[k] = { on = m.on == true, revealed = {} } end
  return JSON.encode(safe)
end
