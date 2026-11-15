-- GULOSO - um jogo de labirinto para o R36S (LÖVE 11.x)
-- Coma todas as pastilhas, fuja dos besouros e use as pastilhas de poder
-- para virar o jogo.

local W, H = 640, 480
local TILE = 22
local OX, OY = 9, 9

local MAZE = {
  "#####################",
  "#.........#.........#",
  "#o##.###..#..###.##o#",
  "#...................#",
  "#.##.#.#######.#.##.#",
  "#....#...###...#....#",
  "####.### ### ###.####",
  "   #.#         #.#   ",
  "####.# ###-### #.####",
  "    .  #GGGGG#  .    ",
  "####.# ####### #.####",
  "   #.#         #.#   ",
  "####.# ####### #.####",
  "#.........#.........#",
  "#.##.###..#..###.##.#",
  "#o.#......P......#.o#",
  "##.#.#.#######.#.#.##",
  "#....#.........#....#",
  "#.######.###.######.#",
  "#...................#",
  "#####################",
}
local COLS, ROWS = #MAZE[1], #MAZE

local DIRS = {
  up = { x = 0, y = -1, a = -math.pi / 2 },
  down = { x = 0, y = 1, a = math.pi / 2 },
  left = { x = -1, y = 0, a = math.pi },
  right = { x = 1, y = 0, a = 0 },
}
local DIR_ORDER = { "up", "left", "down", "right" }
local OPP = { up = "down", down = "up", left = "right", right = "left" }

local THEMES = {
  { fill = { 0.05, 0.07, 0.25 }, edge = { 0.25, 0.55, 1.0 } },
  { fill = { 0.20, 0.04, 0.18 }, edge = { 1.0, 0.35, 0.75 } },
  { fill = { 0.03, 0.18, 0.10 }, edge = { 0.30, 1.0, 0.55 } },
  { fill = { 0.22, 0.10, 0.02 }, edge = { 1.0, 0.65, 0.20 } },
  { fill = { 0.10, 0.04, 0.24 }, edge = { 0.70, 0.45, 1.0 } },
}

local FRUITS = {
  { name = "Cereja", pts = 100, color = { 0.95, 0.15, 0.25 } },
  { name = "Laranja", pts = 300, color = { 1.0, 0.6, 0.1 } },
  { name = "Uva", pts = 500, color = { 0.6, 0.25, 0.85 } },
  { name = "Limão", pts = 700, color = { 0.85, 0.95, 0.2 } },
  { name = "Melão", pts = 1000, color = { 0.4, 0.9, 0.45 } },
  { name = "Estrela", pts = 2000, color = { 1.0, 0.9, 0.3 } },
  { name = "Diamante", pts = 5000, color = { 0.5, 0.9, 1.0 } },
}

local GHOST_DEFS = {
  { name = "BRASA", desc = "persegue você", color = { 1.0, 0.25, 0.2 }, corner = { 20, -1 }, home = { 10, 7 }, release = 0 },
  { name = "FADA", desc = "arma emboscadas", color = { 1.0, 0.55, 0.85 }, corner = { 0, -1 }, home = { 10, 9 }, release = 1.5 },
  { name = "GELO", desc = "imprevisível", color = { 0.3, 0.9, 1.0 }, corner = { 20, 21 }, home = { 8.5, 9 }, release = 4.5 },
  { name = "MEL", desc = "tímido", color = { 1.0, 0.7, 0.2 }, corner = { 0, 21 }, home = { 11.5, 9 }, release = 8 },
}

local MODE_SCHEDULE = { 7, 20, 7, 20, 5, 20, 5, math.huge }

local canvas, mazeCanvas
local fonts = {}
local sfx = {}
local grid, pellets, pelletsLeft, pelletsEaten
local player, ghosts
local fruit, popups
local game

---------------------------------------------------------------------------
-- Utilidades
---------------------------------------------------------------------------
local function round(v) return math.floor(v + 0.5) end
local function wrapX(x) return x % COLS end

local function tileAt(x, y)
  if y < 0 or y >= ROWS then return "#" end
  return grid[y + 1][wrapX(x) + 1]
end

local function canWalk(x, y)
  local t = tileAt(x, y)
  return t ~= "#" and t ~= "-" and t ~= "G"
end

local function px(x) return OX + x * TILE + TILE / 2 end
local function py(y) return OY + y * TILE + TILE / 2 end

local function isCenter(v) return math.abs(v - round(v)) < 1e-4 end

local function setColor(c, a) love.graphics.setColor(c[1], c[2], c[3], a or 1) end

local function playSfx(name)
  local s = sfx[name]
  if not s then return end
  s:stop()
  s:play()
end

---------------------------------------------------------------------------
-- Sons sintetizados
---------------------------------------------------------------------------
local RATE = 22050

local function wave(kind, phase)
  local p = phase % 1
  if kind == "square" then return p < 0.5 and 0.6 or -0.6
  elseif kind == "tri" then return 4 * math.abs(p - 0.5) - 1
  elseif kind == "noise" then return love.math.random() * 2 - 1
  else return math.sin(p * math.pi * 2) end
end

-- notes: lista de { freqInicial, freqFinal, duração, forma, volume }
local function synth(notes, loop)
  local total = 0
  for _, n in ipairs(notes) do total = total + n[3] end
  local count = math.max(1, math.floor(total * RATE))
  local sd = love.sound.newSoundData(count, RATE, 16, 1)
  local i, phase = 0, 0
  for _, n in ipairs(notes) do
    local len = math.floor(n[3] * RATE)
    for k = 0, len - 1 do
      if i >= count then break end
      local t = k / len
      local f = n[1] + (n[2] - n[1]) * t
      phase = phase + f / RATE
      local env = 1
      if not loop then
        env = math.min(1, k / (RATE * 0.004)) * math.min(1, (1 - t) * 6)
      end
      local s = 0
      if f > 0 then s = wave(n[4] or "square", phase) * (n[5] or 0.3) * env end
      sd:setSample(i, s)
      i = i + 1
    end
  end
  local src = love.audio.newSource(sd, "static")
  src:setLooping(loop or false)
  return src
end

local function note(n) return 440 * 2 ^ ((n - 69) / 12) end

local function melody(seq, step, kind, vol)
  local notes = {}
  for _, m in ipairs(seq) do
    local f = m[1] == 0 and 0 or note(m[1])
    notes[#notes + 1] = { f, f, step * (m[2] or 1), kind or "square", vol or 0.25 }
  end
  return synth(notes)
end

local function buildSounds()
  sfx.chomp1 = synth({ { 480, 260, 0.075, "tri", 0.45 } })
  sfx.chomp2 = synth({ { 260, 480, 0.075, "tri", 0.45 } })
  sfx.power = synth({ { 180, 900, 0.18, "square", 0.25 }, { 900, 400, 0.12, "square", 0.2 } })
  sfx.eatGhost = synth({ { 200, 1400, 0.25, "square", 0.25 } })
  sfx.fruit = melody({ { 76 }, { 79 }, { 84 }, { 88, 2 } }, 0.06, "square", 0.22)
  sfx.extra = melody({ { 72 }, { 76 }, { 79 }, { 84 }, { 79 }, { 84, 3 } }, 0.08, "tri", 0.4)
  local death = {}
  for k = 0, 11 do
    local a = 700 - k * 50
    death[#death + 1] = { a, a - 120, 0.1, "square", 0.22 }
  end
  death[#death + 1] = { 120, 40, 0.3, "noise", 0.25 }
  sfx.death = synth(death)
  sfx.start = melody({
    { 67 }, { 0 }, { 72 }, { 74 }, { 76 }, { 0 }, { 74 }, { 72 },
    { 69 }, { 0 }, { 71 }, { 72 }, { 74, 2 }, { 0 }, { 67 },
    { 72 }, { 74 }, { 76 }, { 79 }, { 0 }, { 77 }, { 76 }, { 74, 2 }, { 72, 4 },
  }, 0.085, "square", 0.2)
  sfx.clear = melody({ { 72 }, { 76 }, { 79 }, { 84 }, { 0 }, { 84 }, { 88, 3 } }, 0.1, "tri", 0.4)
  sfx.fright = synth({ { 300, 520, 0.2, "tri", 0.18 }, { 520, 300, 0.2, "tri", 0.18 } }, true)
  sfx.siren = synth({ { 380, 560, 0.35, "sine", 0.08 }, { 560, 380, 0.35, "sine", 0.08 } }, true)
  sfx.eyes = synth({ { 900, 1400, 0.08, "square", 0.08 }, { 1400, 900, 0.08, "square", 0.08 } }, true)
  sfx.menu = synth({ { 660, 660, 0.05, "square", 0.2 }, { 990, 990, 0.08, "square", 0.2 } })
end

---------------------------------------------------------------------------
-- Labirinto
---------------------------------------------------------------------------
local function buildMazeCanvas()
  local theme = THEMES[(game.level - 1) % #THEMES + 1]
  mazeCanvas = love.graphics.newCanvas(COLS * TILE, ROWS * TILE)
  love.graphics.setCanvas(mazeCanvas)
  love.graphics.clear(0, 0, 0, 0)
  local function wall(x, y)
    if x < 0 or x >= COLS or y < 0 or y >= ROWS then return true end
    return grid[y + 1][x + 1] == "#"
  end
  for y = 0, ROWS - 1 do
    for x = 0, COLS - 1 do
      local t = grid[y + 1][x + 1]
      local X, Y = x * TILE, y * TILE
      if t == "#" then
        setColor(theme.fill)
        love.graphics.rectangle("fill", X, Y, TILE, TILE)
      elseif t == "-" then
        love.graphics.setColor(1, 0.6, 0.8)
        love.graphics.rectangle("fill", X, Y + TILE / 2 - 2, TILE, 4)
      end
    end
  end
  setColor(theme.edge)
  love.graphics.setLineWidth(2)
  local i = 3
  for y = 0, ROWS - 1 do
    for x = 0, COLS - 1 do
      if wall(x, y) then
        local X, Y = x * TILE, y * TILE
        local up, dn, lf, rt = not wall(x, y - 1), not wall(x, y + 1), not wall(x - 1, y), not wall(x + 1, y)
        local x1 = lf and X + i or X
        local x2 = rt and X + TILE - i or X + TILE
        local y1 = up and Y + i or Y
        local y2 = dn and Y + TILE - i or Y + TILE
        if up then love.graphics.line(x1, Y + i, x2, Y + i) end
        if dn then love.graphics.line(x1, Y + TILE - i, x2, Y + TILE - i) end
        if lf then love.graphics.line(X + i, y1, X + i, y2) end
        if rt then love.graphics.line(X + TILE - i, y1, X + TILE - i, y2) end
      end
    end
  end
  love.graphics.setCanvas()
end

local function resetPellets()
  grid, pellets = {}, {}
  pelletsLeft, pelletsEaten = 0, 0
  for y = 1, ROWS do
    grid[y], pellets[y] = {}, {}
    for x = 1, COLS do
      local c = MAZE[y]:sub(x, x)
      if c == "." then
        pellets[y][x] = 1; pelletsLeft = pelletsLeft + 1; c = " "
      elseif c == "o" then
        pellets[y][x] = 2; pelletsLeft = pelletsLeft + 1; c = " "
      elseif c == "P" then
        c = " "
      end
      grid[y][x] = c
    end
  end
end

---------------------------------------------------------------------------
-- Movimento em grade
---------------------------------------------------------------------------
-- Move a entidade 'dist' casas na direção atual. Ao passar pelo centro de
-- uma casa chama onCenter(e); se retornar true, o movimento termina.
local function moveEntity(e, dist, onCenter)
  local guard = 0
  while dist > 1e-6 and guard < 8 do
    guard = guard + 1
    if isCenter(e.x) and isCenter(e.y) then
      e.x, e.y = round(e.x), round(e.y)
      if e.x < 0 then e.x = COLS - 1 elseif e.x > COLS - 1 then e.x = 0 end
      if onCenter(e) then return end
      local d = DIRS[e.dir]
      if not canWalk(e.x + d.x, e.y + d.y) then
        e.moving = false
        return
      end
    end
    e.moving = true
    local d = DIRS[e.dir]
    if d.x ~= 0 then
      local target = d.x > 0 and math.floor(e.x + 1e-4) + 1 or math.ceil(e.x - 1e-4) - 1
      local rem = math.abs(target - e.x)
      if dist >= rem then e.x = target; dist = dist - rem
      else e.x = e.x + d.x * dist; dist = 0 end
    else
      local target = d.y > 0 and math.floor(e.y + 1e-4) + 1 or math.ceil(e.y - 1e-4) - 1
      local rem = math.abs(target - e.y)
      if dist >= rem then e.y = target; dist = dist - rem
      else e.y = e.y + d.y * dist; dist = 0 end
    end
  end
  if isCenter(e.x) and e.x < -0.5 + 1e-4 then e.x = COLS - 1 end
end

local function speedScale() return 1 + 0.05 * math.min(game.level - 1, 6) end

---------------------------------------------------------------------------
-- Reinícios
---------------------------------------------------------------------------
local function resetActors()
  player = { x = 10, y = 15, dir = "left", want = "left", moving = false, anim = 0 }
  ghosts = {}
  for i, def in ipairs(GHOST_DEFS) do
    ghosts[i] = {
      def = def, x = def.home[1], y = def.home[2],
      dir = i == 1 and "left" or (i % 2 == 0 and "up" or "down"),
      state = i == 1 and "active" or "house",
      frightened = false, reverse = false, anim = love.math.random() * 10,
      release = math.max(0, def.release - (game.level - 1) * 0.6),
    }
  end
  game.houseTimer = 0
  game.modeIndex, game.modeTimer = 1, 0
  game.fright = 0
  game.combo = 0
  fruit = nil
  popups = {}
end

local function stopLoops()
  sfx.fright:stop(); sfx.siren:stop(); sfx.eyes:stop()
end

local function startLevel(first)
  resetPellets()
  buildMazeCanvas()
  resetActors()
  game.state = "ready"
  game.timer = first and 2.4 or 1.6
  stopLoops()
end

local function loadHiscore()
  if not love.filesystem.getInfo("hiscore.txt") then return 0 end
  local ok, data = pcall(love.filesystem.read, "hiscore.txt")
  return (ok and tonumber(data)) or 0
end

local function saveHiscore()
  pcall(love.filesystem.write, "hiscore.txt", tostring(game.hiscore))
end

local function newGame()
  game.score, game.lives, game.level = 0, 3, 1
  game.extraGiven = false
  game.fruitsTaken = {}
  startLevel(true)
  playSfx("start")
end

local function addScore(n)
  game.score = game.score + n
  if not game.extraGiven and game.score >= 10000 then
    game.extraGiven = true
    game.lives = game.lives + 1
    playSfx("extra")
  end
  if game.score > game.hiscore then game.hiscore = game.score end
end

---------------------------------------------------------------------------
-- Entrada (direcional, analógico, teclado)
---------------------------------------------------------------------------
local function heldDirections()
  local held = {}
  local function mark(d) held[d] = true end
  local kb = love.keyboard.isDown
  if kb("up", "w") then mark("up") end
  if kb("down", "s") then mark("down") end
  if kb("left", "a") then mark("left") end
  if kb("right", "d") then mark("right") end
  for _, j in ipairs(love.joystick.getJoysticks()) do
    local ax, ay = 0, 0
    if j:isGamepad() then
      if j:isGamepadDown("dpup") then mark("up") end
      if j:isGamepadDown("dpdown") then mark("down") end
      if j:isGamepadDown("dpleft") then mark("left") end
      if j:isGamepadDown("dpright") then mark("right") end
      ax, ay = j:getGamepadAxis("leftx"), j:getGamepadAxis("lefty")
    else
      if j:getHatCount() > 0 then
        local h = j:getHat(1)
        if h:find("u") then mark("up") end
        if h:find("d") then mark("down") end
        if h:find("l") then mark("left") end
        if h:find("r") then mark("right") end
      end
      if j:getAxisCount() >= 2 then ax, ay = j:getAxis(1), j:getAxis(2) end
    end
    if math.abs(ax) > 0.5 or math.abs(ay) > 0.5 then
      if math.abs(ax) > math.abs(ay) then mark(ax > 0 and "right" or "left")
      else mark(ay > 0 and "down" or "up") end
    end
  end
  return held
end

local function readPlayerInput()
  local held = heldDirections()
  local list = {}
  for _, d in ipairs(DIR_ORDER) do if held[d] then list[#list + 1] = d end end
  if #list == 1 then
    player.want = list[1]
  elseif #list > 1 then
    -- Na diagonal, prefira a direção perpendicular ao movimento atual
    for _, d in ipairs(list) do
      if DIRS[d].x ~= DIRS[player.dir].x and DIRS[d].y ~= DIRS[player.dir].y then
        if d ~= OPP[player.dir] then player.want = d end
      end
    end
  end
end

---------------------------------------------------------------------------
-- Jogador
---------------------------------------------------------------------------
local function frighten()
  game.fright = math.max(1.5, 7 - (game.level - 1) * 0.8)
  game.combo = 0
  for _, g in ipairs(ghosts) do
    if g.state ~= "eyes" and g.state ~= "entering" then
      g.frightened = true
      if g.state == "active" then g.reverse = true end
    end
  end
end

local function eatAt(x, y)
  x = wrapX(x)
  local row = pellets[y + 1]
  if not row then return end
  local p = row[x + 1]
  if not p then return end
  row[x + 1] = nil
  pelletsLeft = pelletsLeft - 1
  pelletsEaten = pelletsEaten + 1
  game.chompToggle = not game.chompToggle
  playSfx(game.chompToggle and "chomp1" or "chomp2")
  if p == 2 then
    addScore(50)
    frighten()
    playSfx("power")
  else
    addScore(10)
  end
  if pelletsEaten == 50 or pelletsEaten == 120 then
    local f = FRUITS[math.min(game.level, #FRUITS)]
    fruit = { x = 10, y = 11, t = 9.5, def = f }
  end
  if pelletsLeft <= 0 then
    game.state = "clear"
    game.timer = 2.4
    stopLoops()
    playSfx("clear")
  end
end

local function updatePlayer(dt)
  readPlayerInput()
  if player.want == OPP[player.dir] then player.dir = player.want end
  local speed = 6.4 * speedScale()
  if game.fright > 0 then speed = speed * 1.08 end
  moveEntity(player, speed * dt, function(e)
    local w = DIRS[e.want]
    if canWalk(e.x + w.x, e.y + w.y) then e.dir = e.want end
    return false
  end)
  if player.moving then player.anim = player.anim + dt * 14 end
  eatAt(round(player.x), round(player.y))
end

---------------------------------------------------------------------------
-- Besouros (inimigos)
---------------------------------------------------------------------------
local function isScatter() return game.modeIndex % 2 == 1 end

local function ghostTarget(g)
  local p, pd = player, DIRS[player.dir]
  local px_, py_ = round(p.x), round(p.y)
  if g.state == "eyes" then return 10, 7 end
  if isScatter() then return g.def.corner[1], g.def.corner[2] end
  local name = g.def.name
  if name == "BRASA" then
    return px_, py_
  elseif name == "FADA" then
    return px_ + pd.x * 4, py_ + pd.y * 4
  elseif name == "GELO" then
    local b = ghosts[1]
    local vx, vy = px_ + pd.x * 2, py_ + pd.y * 2
    return vx * 2 - round(b.x), vy * 2 - round(b.y)
  else
    local dx, dy = g.x - p.x, g.y - p.y
    if dx * dx + dy * dy > 49 then return px_, py_ end
    return g.def.corner[1], g.def.corner[2]
  end
end

local function chooseDir(g)
  local opts = {}
  for _, d in ipairs(DIR_ORDER) do
    local v = DIRS[d]
    if d ~= OPP[g.dir] and canWalk(g.x + v.x, g.y + v.y) then opts[#opts + 1] = d end
  end
  if #opts == 0 then return OPP[g.dir] end
  if g.frightened and g.state == "active" then return opts[love.math.random(#opts)] end
  local tx, ty = ghostTarget(g)
  local best, bestD = opts[1], math.huge
  for _, d in ipairs(opts) do
    local v = DIRS[d]
    local dx, dy = g.x + v.x - tx, g.y + v.y - ty
    local dd = dx * dx + dy * dy
    if dd < bestD then best, bestD = d, dd end
  end
  return best
end

local function approach(cur, target, step)
  if cur < target then return math.min(target, cur + step) end
  return math.max(target, cur - step)
end

local function updateGhost(g, dt)
  g.anim = g.anim + dt
  local scale = speedScale()
  if g.state == "house" then
    g.y = g.def.home[2] + math.sin(g.anim * 6) * 0.25
    if game.houseTimer >= g.release then g.state = "leaving" end
    return
  elseif g.state == "leaving" then
    local step = 3 * dt
    if math.abs(g.x - 10) > 1e-4 then
      if math.abs(g.y - 9) > 1e-4 then g.y = approach(g.y, 9, step)
      else g.x = approach(g.x, 10, step) end
    else
      g.x = 10
      g.y = approach(g.y, 7, step)
      if math.abs(g.y - 7) < 1e-4 then
        g.y = 7
        g.state = "active"
        g.dir = love.math.random() < 0.5 and "left" or "right"
      end
    end
    g.dir = g.dir or "up"
    return
  elseif g.state == "entering" then
    g.y = approach(g.y, 9, 8 * dt)
    if math.abs(g.y - 9) < 1e-4 then
      g.y = 9
      g.state = "leaving"
      g.frightened = false
    end
    return
  end

  if g.reverse then
    g.reverse = false
    g.dir = OPP[g.dir]
  end
  local speed
  if g.state == "eyes" then speed = 12
  elseif g.frightened then speed = 3.4 * scale
  else
    speed = 5.9 * scale
    if g.def.name == "BRASA" and pelletsLeft < 25 then speed = speed * 1.1 end
  end
  if g.state ~= "eyes" and round(g.y) == 9 and (g.x < 4.5 or g.x > 15.5) then
    speed = speed * 0.55
  end
  moveEntity(g, speed * dt, function(e)
    if e.state == "eyes" and e.x == 10 and e.y == 7 then
      e.state = "entering"
      e.dir = "down"
      return true
    end
    e.dir = chooseDir(e)
    return false
  end)
end

local function updateMode(dt)
  if game.fright > 0 then
    game.fright = game.fright - dt
    if game.fright <= 0 then
      game.fright = 0
      for _, g in ipairs(ghosts) do g.frightened = false end
    end
    return
  end
  game.modeTimer = game.modeTimer + dt
  if game.modeTimer >= MODE_SCHEDULE[game.modeIndex] then
    game.modeTimer = 0
    game.modeIndex = math.min(game.modeIndex + 1, #MODE_SCHEDULE)
    for _, g in ipairs(ghosts) do
      if g.state == "active" then g.reverse = true end
    end
  end
end

local function popup(x, y, text, color)
  popups[#popups + 1] = { x = x, y = y, text = text, t = 1.2, color = color or { 0.4, 1, 1 } }
end

local function checkCollisions()
  for _, g in ipairs(ghosts) do
    if g.state == "active" then
      local dx, dy = g.x - player.x, g.y - player.y
      if dx * dx + dy * dy < 0.36 then
        if g.frightened then
          g.frightened = false
          g.state = "eyes"
          game.combo = game.combo + 1
          local pts = 100 * 2 ^ game.combo
          addScore(pts)
          popup(g.x, g.y, tostring(pts))
          playSfx("eatGhost")
          game.freeze = 0.45
        else
          game.state = "dying"
          game.timer = 1.8
          stopLoops()
          playSfx("death")
          return
        end
      end
    end
  end
  if fruit then
    local dx, dy = fruit.x - player.x, fruit.y - player.y
    if dx * dx + dy * dy < 0.4 then
      addScore(fruit.def.pts)
      popup(fruit.x, fruit.y, tostring(fruit.def.pts), { 1, 0.8, 1 })
      table.insert(game.fruitsTaken, fruit.def)
      if #game.fruitsTaken > 6 then table.remove(game.fruitsTaken, 1) end
      fruit = nil
      playSfx("fruit")
    end
  end
end

local function updateLoops()
  local eyes = false
  for _, g in ipairs(ghosts) do
    if g.state == "eyes" or g.state == "entering" then eyes = true end
  end
  local want = eyes and "eyes" or (game.fright > 0 and "fright" or "siren")
  for _, n in ipairs({ "siren", "fright", "eyes" }) do
    if n == want then
      if not sfx[n]:isPlaying() then sfx[n]:play() end
    elseif sfx[n]:isPlaying() then
      sfx[n]:stop()
    end
  end
end

---------------------------------------------------------------------------
-- LÖVE callbacks
---------------------------------------------------------------------------
function love.load()
  love.graphics.setDefaultFilter("nearest", "nearest")
  love.mouse.setVisible(false)
  canvas = love.graphics.newCanvas(W, H)
  fonts.huge = love.graphics.newFont(48)
  fonts.big = love.graphics.newFont(28)
  fonts.mid = love.graphics.newFont(18)
  fonts.small = love.graphics.newFont(13)
  buildSounds()
  game = { state = "title", timer = 0, score = 0, hiscore = loadHiscore(), lives = 3, level = 1,
           fruitsTaken = {}, freeze = 0, clock = 0 }
  resetPellets()
  buildMazeCanvas()
  resetActors()
end

local function onStartButton()
  if game.state == "title" then
    playSfx("menu")
    newGame()
  elseif game.state == "gameover" and game.timer <= 0 then
    game.state = "title"
    playSfx("menu")
  elseif game.state == "play" then
    game.state = "paused"
    stopLoops()
  elseif game.state == "paused" then
    game.state = "play"
  end
end

function love.update(dt)
  dt = math.min(dt, 1 / 30)
  game.clock = game.clock + dt

  -- SELECT + START = sair
  for _, j in ipairs(love.joystick.getJoysticks()) do
    if j:isGamepad() and j:isGamepadDown("back") and j:isGamepadDown("start") then
      love.event.quit()
    end
  end

  for i = #popups, 1, -1 do
    popups[i].t = popups[i].t - dt
    if popups[i].t <= 0 then table.remove(popups, i) end
  end

  local s = game.state
  if s == "title" then
    for _, g in ipairs(ghosts) do g.anim = g.anim + dt end
    player.anim = player.anim + dt * 10
  elseif s == "ready" then
    game.timer = game.timer - dt
    if game.timer <= 0 then game.state = "play" end
  elseif s == "play" then
    if game.freeze > 0 then
      game.freeze = game.freeze - dt
      return
    end
    game.houseTimer = game.houseTimer + dt
    updateMode(dt)
    updatePlayer(dt)
    if game.state ~= "play" then return end
    checkCollisions()
    if game.state ~= "play" then return end
    for _, g in ipairs(ghosts) do updateGhost(g, dt) end
    checkCollisions()
    if fruit then
      fruit.t = fruit.t - dt
      if fruit.t <= 0 then fruit = nil end
    end
    if game.state == "play" then updateLoops() end
  elseif s == "dying" then
    game.timer = game.timer - dt
    if game.timer <= 0 then
      game.lives = game.lives - 1
      if game.lives <= 0 then
        game.state = "gameover"
        game.timer = 1.0
        saveHiscore()
      else
        resetActors()
        game.state = "ready"
        game.timer = 1.6
      end
    end
  elseif s == "clear" then
    game.timer = game.timer - dt
    if game.timer <= 0 then
      game.level = game.level + 1
      saveHiscore()
      startLevel(false)
    end
  elseif s == "gameover" then
    game.timer = game.timer - dt
  end
end

function love.keypressed(key)
  if key == "return" or key == "space" or key == "kpenter" then
    onStartButton()
  elseif key == "p" then
    if game.state == "play" or game.state == "paused" then onStartButton() end
  elseif key == "escape" then
    if game.state == "play" then onStartButton()
    elseif game.state == "title" then
      if love.system.getOS() ~= "Web" then love.event.quit() end
    else game.state = "title"; stopLoops() end
  end
end

function love.gamepadpressed(j, button)
  if button == "start" then
    if j:isGamepadDown("back") then love.event.quit() return end
    onStartButton()
  elseif button == "a" or button == "b" or button == "x" or button == "y" then
    if game.state == "title" or game.state == "gameover" or game.state == "paused" then
      onStartButton()
    end
  elseif button == "back" and game.state == "paused" then
    game.state = "title"
  end
end

-- Toque / mouse: deslize para mudar de direção, toque para começar ou pausar
local swipe
function love.mousepressed(x, y)
  swipe = { x = x, y = y, moved = false }
end

function love.mousemoved(x, y)
  if not swipe then return end
  local dx, dy = x - swipe.x, y - swipe.y
  if dx * dx + dy * dy > 18 * 18 then
    if math.abs(dx) > math.abs(dy) then player.want = dx > 0 and "right" or "left"
    else player.want = dy > 0 and "down" or "up" end
    swipe.x, swipe.y, swipe.moved = x, y, true
  end
end

function love.mousereleased()
  if swipe and not swipe.moved and game.state ~= "play" then onStartButton() end
  swipe = nil
end

function love.joystickpressed(j, button)
  if not j:isGamepad() then onStartButton() end
end

function love.quit()
  if game then saveHiscore() end
end

---------------------------------------------------------------------------
-- Desenho
---------------------------------------------------------------------------
local function drawPlayer(x, y, dir, anim, dyingT)
  local cx, cy = x, y
  local r = 9.5
  local a = DIRS[dir].a
  local mouth = 0.1 + math.abs(math.sin(anim)) * 0.6
  if dyingT then
    mouth = math.min(math.pi, 0.3 + dyingT * math.pi)
    r = r * math.max(0, 1 - math.max(0, dyingT - 0.7) * 2)
    a = -math.pi / 2
    if r <= 0.5 then return end
  end
  -- folhinha na cabeça
  love.graphics.setColor(0.2, 0.7, 0.2)
  love.graphics.ellipse("fill", cx + 2, cy - r - 1, 3.5, 2)
  love.graphics.setColor(0.6, 1.0, 0.3)
  love.graphics.arc("fill", cx, cy, r, a + mouth, a + math.pi * 2 - mouth)
  love.graphics.setColor(0.35, 0.75, 0.15)
  love.graphics.setLineWidth(1.5)
  love.graphics.arc("line", "open", cx, cy, r, a + mouth, a + math.pi * 2 - mouth)
  if not dyingT then
    local ex, ey = 1.5, -5
    if dir == "left" then ex = -1.5
    elseif dir == "up" then ex, ey = 5, -1.5
    elseif dir == "down" then ex, ey = 5, 1.5 end
    love.graphics.setColor(1, 1, 1)
    love.graphics.circle("fill", cx + ex, cy + ey, 2.6)
    love.graphics.setColor(0.05, 0.05, 0.1)
    love.graphics.circle("fill", cx + ex + DIRS[dir].x * 0.9, cy + ey + DIRS[dir].y * 0.9, 1.4)
  end
end

local function drawGhost(g, x, y)
  local cx, cy = x, y
  local d = DIRS[g.dir] or DIRS.up
  local fr = g.frightened and (g.state == "active" or g.state == "house" or g.state == "leaving")
  local eyesOnly = g.state == "eyes" or g.state == "entering"
  if not eyesOnly then
    local body = g.def.color
    if fr then
      body = { 0.2, 0.25, 0.95 }
      if game.fright < 2 and math.floor(game.clock * 6) % 2 == 0 then body = { 0.95, 0.95, 1 } end
    end
    -- patinhas
    local leg = math.sin(g.anim * 18) * 2
    love.graphics.setColor(body[1] * 0.6, body[2] * 0.6, body[3] * 0.6)
    love.graphics.setLineWidth(2)
    for k = -1, 1 do
      local o = k * 5
      local l = (k % 2 == 0) and leg or -leg
      love.graphics.line(cx - 7, cy + o + 1, cx - 11, cy + o + 1 + l)
      love.graphics.line(cx + 7, cy + o + 1, cx + 11, cy + o + 1 - l)
    end
    -- antenas
    love.graphics.setLineWidth(1.5)
    love.graphics.line(cx - 3, cy - 8, cx - 6, cy - 12 + leg * 0.3)
    love.graphics.line(cx + 3, cy - 8, cx + 6, cy - 12 - leg * 0.3)
    love.graphics.circle("fill", cx - 6, cy - 12 + leg * 0.3, 1.5)
    love.graphics.circle("fill", cx + 6, cy - 12 - leg * 0.3, 1.5)
    -- casco
    setColor(body)
    love.graphics.ellipse("fill", cx, cy + 1, 8.5, 9)
    love.graphics.setColor(1, 1, 1, 0.25)
    love.graphics.ellipse("fill", cx - 3, cy - 3, 3, 2)
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.setLineWidth(1)
    love.graphics.line(cx, cy + 2, cx, cy + 9)
    if fr then
      love.graphics.setColor(1, 0.8, 0.8)
      love.graphics.circle("fill", cx - 3, cy - 2, 1.6)
      love.graphics.circle("fill", cx + 3, cy - 2, 1.6)
      love.graphics.setLineWidth(1.2)
      love.graphics.line(cx - 5, cy + 4, cx - 2.5, cy + 2, cx, cy + 4, cx + 2.5, cy + 2, cx + 5, cy + 4)
      return
    end
  end
  for s = -1, 1, 2 do
    love.graphics.setColor(1, 1, 1)
    love.graphics.ellipse("fill", cx + s * 3.5, cy - 2, 3, 3.6)
    love.graphics.setColor(0.1, 0.1, 0.4)
    love.graphics.circle("fill", cx + s * 3.5 + d.x * 1.4, cy - 2 + d.y * 1.6, 1.7)
  end
end

local function drawFruit(def, cx, cy, s)
  s = s or 1
  setColor(def.color)
  if def.name == "Estrela" then
    local pts = {}
    for k = 0, 9 do
      local r = (k % 2 == 0) and 8 * s or 3.5 * s
      local a = -math.pi / 2 + k * math.pi / 5
      pts[#pts + 1] = cx + math.cos(a) * r
      pts[#pts + 1] = cy + math.sin(a) * r
    end
    love.graphics.polygon("fill", pts)
  elseif def.name == "Diamante" then
    love.graphics.polygon("fill", cx, cy - 8 * s, cx + 7 * s, cy - 2 * s, cx, cy + 8 * s, cx - 7 * s, cy - 2 * s)
  elseif def.name == "Cereja" or def.name == "Uva" then
    love.graphics.circle("fill", cx - 3.5 * s, cy + 3 * s, 4 * s)
    love.graphics.circle("fill", cx + 3.5 * s, cy + 3 * s, 4 * s)
    if def.name == "Uva" then love.graphics.circle("fill", cx, cy - 2 * s, 4 * s) end
    love.graphics.setColor(0.3, 0.8, 0.3)
    love.graphics.setLineWidth(1.5)
    love.graphics.line(cx - 3 * s, cy, cx + 1 * s, cy - 8 * s, cx + 3.5 * s, cy)
  else
    love.graphics.circle("fill", cx, cy + 1 * s, 7 * s)
    love.graphics.setColor(0.3, 0.8, 0.3)
    love.graphics.ellipse("fill", cx + 3 * s, cy - 6 * s, 3.5 * s, 1.8 * s)
  end
  love.graphics.setColor(1, 1, 1, 0.5)
  love.graphics.circle("fill", cx - 2 * s, cy - 1 * s, 1.3 * s)
end

local function drawPellets()
  for y = 1, ROWS do
    for x = 1, COLS do
      local p = pellets[y][x]
      if p == 1 then
        love.graphics.setColor(1, 0.9, 0.75)
        love.graphics.rectangle("fill", px(x - 1) - 2, py(y - 1) - 2, 4, 4)
      elseif p == 2 then
        if game.state ~= "play" or math.floor(game.clock * 4) % 2 == 0 then
          love.graphics.setColor(1, 0.85, 0.5)
          love.graphics.circle("fill", px(x - 1), py(y - 1), 6)
        end
      end
    end
  end
end

local function centerText(text, font, cx, y, color)
  love.graphics.setFont(font)
  setColor(color or { 1, 1, 1 })
  love.graphics.print(text, math.floor(cx - font:getWidth(text) / 2), math.floor(y))
end

local function drawHud()
  local x0 = OX + COLS * TILE + 8
  local cx = x0 + (W - x0) / 2
  centerText("GULOSO", fonts.big, cx, 14, { 0.6, 1, 0.3 })
  centerText("PONTOS", fonts.small, cx, 70, { 0.7, 0.7, 0.9 })
  centerText(tostring(game.score), fonts.mid, cx, 88)
  centerText("RECORDE", fonts.small, cx, 130, { 0.7, 0.7, 0.9 })
  centerText(tostring(game.hiscore), fonts.mid, cx, 148, { 1, 0.85, 0.4 })
  centerText("FASE", fonts.small, cx, 190, { 0.7, 0.7, 0.9 })
  centerText(tostring(game.level), fonts.mid, cx, 208)
  centerText("VIDAS", fonts.small, cx, 250, { 0.7, 0.7, 0.9 })
  local shown = math.min(game.lives - ((game.state == "play" or game.state == "dying" or game.state == "paused" or game.state == "ready" or game.state == "clear") and 1 or 0), 6)
  if game.state == "title" or game.state == "gameover" then shown = 0 end
  for i = 1, math.max(0, shown) do
    local col = (i - 1) % 3
    local row = math.floor((i - 1) / 3)
    drawPlayer(cx - 26 + col * 26, 285 + row * 26, "right", 0.6)
  end
  if #game.fruitsTaken > 0 then
    centerText("FRUTAS", fonts.small, cx, 345, { 0.7, 0.7, 0.9 })
    for i, f in ipairs(game.fruitsTaken) do
      local col = (i - 1) % 3
      local row = math.floor((i - 1) / 3)
      drawFruit(f, cx - 26 + col * 26, 378 + row * 24, 0.9)
    end
  end
  centerText("START: pausa", fonts.small, cx, 440, { 0.5, 0.5, 0.65 })
  centerText("SELECT+START: sair", fonts.small, cx, 456, { 0.5, 0.5, 0.65 })
end

local function drawTitle()
  love.graphics.setColor(0, 0, 0, 0.82)
  love.graphics.rectangle("fill", 0, 0, W, H)
  local t = game.clock
  local colors = { { 0.6, 1, 0.3 }, { 1, 0.85, 0.3 }, { 1, 0.45, 0.6 }, { 0.4, 0.85, 1 } }
  love.graphics.setFont(fonts.huge)
  local title = "GULOSO"
  local tw = fonts.huge:getWidth(title)
  local x = W / 2 - tw / 2
  for i = 1, #title do
    local ch = title:sub(i, i)
    setColor(colors[(i + math.floor(t * 3)) % #colors + 1])
    love.graphics.print(ch, x, 40 + math.sin(t * 4 + i) * 5)
    x = x + fonts.huge:getWidth(ch)
  end
  centerText("Coma todas as pastilhas e fuja dos besouros!", fonts.small, W / 2, 112, { 0.8, 0.8, 1 })

  drawPlayer(W / 2 - 150, 170, "right", t * 10)
  local function leftText(text, font, x, y, color)
    love.graphics.setFont(font)
    setColor(color)
    love.graphics.print(text, x, y)
  end
  leftText("GULOSO - você", fonts.mid, W / 2 - 115, 160, { 0.6, 1, 0.3 })
  for i, g in ipairs(ghosts) do
    local y = 205 + (i - 1) * 36
    local fake = { def = g.def, dir = "right", state = "active", frightened = false, anim = g.anim }
    drawGhost(fake, W / 2 - 150, y + 10)
    leftText(g.def.name .. " - " .. g.def.desc, fonts.mid, W / 2 - 115, y, g.def.color)
  end
  local tiny = { def = GHOST_DEFS[1], dir = "left", state = "active", frightened = true, anim = t }
  local saveFright = game.fright
  game.fright = 5
  drawGhost(tiny, W / 2 - 150, 360)
  game.fright = saveFright
  leftText("Pastilha grande: os besouros ficam comíveis", fonts.small, W / 2 - 115, 352, { 0.6, 0.7, 1 })

  if math.floor(t * 2) % 2 == 0 then
    centerText("Pressione START", fonts.big, W / 2, 392, { 1, 1, 0.5 })
  end
  centerText("Direcional / analógico: mover    START: pausa    SELECT+START: sair", fonts.small, W / 2, 440, { 0.6, 0.6, 0.75 })
  centerText("RECORDE: " .. game.hiscore, fonts.small, W / 2, 458, { 1, 0.85, 0.4 })
end

local function drawGame()
  love.graphics.clear(0.01, 0.01, 0.04)
  local flashing = game.state == "clear" and math.floor(game.timer * 5) % 2 == 0
  if flashing then
    love.graphics.setColor(1, 1, 1, 0.35)
    love.graphics.draw(mazeCanvas, OX, OY)
  else
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(mazeCanvas, OX, OY)
  end

  love.graphics.setScissor(OX, OY, COLS * TILE, ROWS * TILE)
  drawPellets()
  if fruit then
    local blink = fruit.t > 2 or math.floor(fruit.t * 6) % 2 == 0
    if blink then drawFruit(fruit.def, px(fruit.x), py(fruit.y)) end
  end

  local s = game.state
  if s ~= "clear" and s ~= "gameover" and s ~= "title" then
    if s ~= "dying" or game.timer > 1.4 then
      for _, g in ipairs(ghosts) do
        drawGhost(g, px(g.x), py(g.y))
        -- cópia do outro lado no túnel
        if g.x < 0 then drawGhost(g, px(g.x + COLS), py(g.y)) end
        if g.x > COLS - 1 then drawGhost(g, px(g.x - COLS), py(g.y)) end
      end
    end
  end
  if s ~= "gameover" and s ~= "title" then
    local dyingT = (s == "dying" and game.timer < 1.4) and (1.4 - game.timer) or nil
    drawPlayer(px(player.x), py(player.y), player.dir, player.anim, dyingT)
    if player.x < 0 then drawPlayer(px(player.x + COLS), py(player.y), player.dir, player.anim, dyingT) end
    if player.x > COLS - 1 then drawPlayer(px(player.x - COLS), py(player.y), player.dir, player.anim, dyingT) end
  end
  for _, p in ipairs(popups) do
    centerText(p.text, fonts.small, px(p.x), py(p.y) - 8 - (1.2 - p.t) * 10, p.color)
  end
  love.graphics.setScissor()

  local mid = px(10)
  if s == "ready" then
    centerText("PRONTO!", fonts.mid, mid, py(11) - 10, { 1, 1, 0.3 })
    if game.level > 1 and game.timer > 0.8 then
      centerText("FASE " .. game.level, fonts.mid, mid, py(7) - 10, { 0.4, 1, 1 })
    end
  elseif s == "gameover" then
    centerText("FIM DE JOGO", fonts.mid, mid, py(11) - 10, { 1, 0.3, 0.3 })
    if game.timer <= 0 and math.floor(game.clock * 2) % 2 == 0 then
      centerText("START: voltar ao menu", fonts.small, mid, py(13) - 7, { 1, 1, 1 })
    end
  elseif s == "clear" then
    centerText("FASE COMPLETA!", fonts.mid, mid, py(11) - 10, { 0.4, 1, 0.4 })
  end

  drawHud()

  if s == "paused" then
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, W, H)
    centerText("PAUSA", fonts.huge, W / 2, H / 2 - 60, { 1, 1, 0.5 })
    centerText("START / A: continuar", fonts.mid, W / 2, H / 2 + 10)
    centerText("SELECT: menu    SELECT+START: sair", fonts.small, W / 2, H / 2 + 40, { 0.7, 0.7, 0.8 })
  elseif s == "title" then
    drawTitle()
  end
end

function love.draw()
  love.graphics.setCanvas(canvas)
  love.graphics.origin()
  drawGame()
  love.graphics.setCanvas()

  local ww, wh = love.graphics.getDimensions()
  local scale = math.min(ww / W, wh / H)
  if scale >= 1 then scale = math.floor(scale) end
  love.graphics.clear(0, 0, 0)
  love.graphics.setColor(1, 1, 1)
  love.graphics.draw(canvas, math.floor((ww - W * scale) / 2), math.floor((wh - H * scale) / 2), 0, scale, scale)
end
