local lib = {}

assert(_ENGINE.system, "Core Library Missing System Permissions")

lib.global = {}
lib.loadedScenes = {}
local global = lib.global
global.gameVars = {}
global.sceneVars = {}

function lib.loadSandbox(path)
  assert(fs.exists(path),string.format("Cannot find lua file '%s'",path))

  local sbox = _ENGINE.system.sandboxFunction(loadfile(path))
  local senv = getfenv(sbox)
  sbox()
  return senv
end

function global.loadScene(id)
  id = fs.combine("/",id)
  local spath = fs.combine(_ENGINE.project.path, "scenes", id)..".lua"
  local senv = lib.loadSandbox(spath)
  local vector = _ENGINE.vector
  global.sceneEntity = lib.createEntity(nil,nil,{},{})
  global.sceneVars = {}
  lib.sceneEnv = senv
  if not lib.loadedScenes[id] then
    senv.DataInit()
    lib.loadedScenes[id] = true
  end
  senv.Init()
end

function lib.onload()
  lib.lastTick = os.epoch("utc")
  lib.lastTime = os.epoch("utc")
  global.camera = _ENGINE.vector.create2d(1,1)
end

function lib.polygonsIntersect(pointsA, pointsB)
  local axes = {}
  for _, a in ipairs(pointsA) do axes[#axes+1] = a end
  for _, a in ipairs(pointsB) do axes[#axes+1] = a end

  local function project(points, axisX, axisY)
    local minP, maxP = math.huge, -math.huge
    for _, p in ipairs(points) do
      local d = p.x*axisX + p.y*axisY
      minP = math.min(minP, d)
      maxP = math.max(maxP, d)
    end
    return minP, maxP
  end

  for _, axis in ipairs(axes) do
    local minA, maxA = project(pointsA, axis.x, axis.y)
    local minB, maxB = project(pointsB, axis.x, axis.y)
    if maxA < minB or maxB < minA then
      return false
    end
  end
  return true
end

lib.entities = {}
lib.entitylib = {}
local entitylib = lib.entitylib

function lib.recurseEntityGet(e,fn,default)
  local r
  r = fn(e)
  if r ~= nil then
    return r
  end
  for i = 1, #e.children do
    r = lib.recurseEntityGet(e.children[i],fn)
    if r ~= nil then
      return r
    end
  end
  return default
end

function lib.recurseEntity(e,fn,onend)
  fn(e)
  for i = 1, #e.children do
    lib.recurseEntity(e.children[i],fn,onend)
  end
  if onend then
    onend(e)
  end
end

function entitylib.addRectHitbox(e,x,y,w,h)
  local vector = _ENGINE.vector
  local l, r, t, b = x, x+w-1, y, y+h-1
  local tl, tr, br, bl = vector.create2d(l,t), vector.create2d(r,t), vector.create2d(r,b), vector.create2d(l,b)
  local points = {tl, tr, br, bl}
  e.hitbox = points
end

function entitylib.collideWith(e1,e2)
  local fgraphics = _ENGINE.globals.graphics
  local graphics = _ENGINE.graphics
  assert(e1.hitbox, "Attempted entity collision with no hitbox.")
  fgraphics.push()
    lib.applyEntityTransform(e1)
    local mainHitbox = graphics.applyAllTrans(e1.hitbox)
  fgraphics.pop()
  return lib.recurseEntityGet(e2,function (e)
    if not e.hitbox then
      return
    end
    fgraphics.push()
      lib.applyEntityTransform(e)
      local hitbox = graphics.applyAllTrans(e.hitbox)
    fgraphics.pop()
    if lib.polygonsIntersect(mainHitbox,hitbox) then
      return e
    end
  end)
end

function entitylib.addChild(p,c)
  assert(not c.parent, "Cannot add child entity because it already has a parent!")
  p.children[#p.children+1] = c
  c.parent = p
end

function entitylib.kill(e)
  e.flags.kill = true
end

function global.createTransform(position,scale,rot)
  local vector = _ENGINE.vector
  return {
    pos = position or vector.create3d(1,1,0), -- X, Y, Z Buffer
    scale = scale or vector.create2d(1,1),
    rot = rot or 0
  }
end

function lib.applyEntityTransform(entity)
  local abst = entity.transform
  local fgraphics = _ENGINE.globals.graphics
  fgraphics.scale(abst.scale.x, abst.scale.y)
  fgraphics.rotate(abst.rot)
  fgraphics.translate(abst.pos.x-1, abst.pos.y-1)
end

function lib.createEntity(trans,rtrans,config,preset)
  local e = {}
  e.transform = trans or global.createTransform()
  e.rtransform = rtrans or global.createTransform()
  e.children = {}
  e.flags = {}
  e.config = config
  e.preset = preset
  setmetatable(e,{
    __index=function(t,k)
      if k == "preset" then
        return nil
      end
      return rawget(lib.entitylib,k) or rawget(t,k)
    end,
    __newindex=function (t,k,v)
      if k == "preset" then
        return
      end
      rawset(t,k,v)
    end
  })
  if e.preset.script then
    if e.preset.script.Init then
      e.preset.script.Init(e)
    end
  end
  return e
end

lib.entityPresets = {}

function global.loadPreset(id,path)
  path = fs.combine("/",path)
  local graphics = _ENGINE.graphics
  local objPath = fs.combine(_ENGINE.project.path, "presets", path)
  local kobj = textutils.unserialise(_ENGINE.system.readAll(objPath))
  if kobj.shader then
    local shader 
    if kobj.shader == "builtin/image" then
      shader = graphics.createLoadedImageShader
    elseif kobj.shader == "builtin/solid" then
      shader = graphics.createRGBSolidShader
    else
      shader = graphics.shaders[kobj.shader]
    end
    if kobj.shaderargs then
      shader = shader(unpack(kobj.shaderargs))
    end
    assert(type(shader) == "function", string.format("Failed to load shader '%s'",kobj.shader))
    kobj.shader = shader
  else
    kobj.shader = graphics.shaders.empty
  end
  if kobj.script then
    local scriptPath = fs.combine(_ENGINE.project.path,"scripts",fs.combine("/",kobj.script))
    kobj.script = lib.loadSandbox(scriptPath)
  end
  lib.entityPresets[id] = kobj
end

function global.createEntity(transform,renderTransform,presetId,config)
  local preset = lib.entityPresets[presetId]
  assert(preset, string.format("Entity preset doesn't exist '%s'",presetId))
  return lib.createEntity(transform,renderTransform,config or {},preset)
end

global.fps = 0
global.frames = 0
lib.lastFrame = 0
lib.tickpriority = 0
local psr = 1 / 60
function lib.everytick()
  local ctime = os.epoch("utc")

  local tickDist = ctime - lib.lastTick
  if tickDist > 100 then
    global.fps = ((global.frames - lib.lastFrame) / tickDist) * 1000
    lib.lastTick = ctime
    lib.lastFrame = global.frames
  end

  local delta = (ctime - lib.lastTime)*psr
  lib.sceneEnv.Update(delta)

  lib.recurseEntity(global.sceneEntity,function(e)
    local p = rawget(e,"preset")
    if p.script then
      p.script.Update(e,delta)
    end
  end)

  local graphics = _ENGINE.graphics
  local fgraphics = _ENGINE.globals.graphics
  fgraphics.push()
  fgraphics.translate(global.camera.x,global.camera.y)
  lib.recurseEntity(global.sceneEntity,function(e)
    local p = rawget(e,"preset")
    local rt = e.rtransform
    local abst = e.transform
    fgraphics.push()
      --Applied to all shapes
      lib.applyEntityTransform(e)
      fgraphics.push()
      -- Purely Rendering
      if p.centerGraphics then
        fgraphics.centerRect(rt.scale.x,rt.scale.y)
      end
      fgraphics.rotate(rt.rot)
      graphics.renderRect(rt.pos.x-1,rt.pos.y-1,rt.scale.x,rt.scale.y,p.shader,rt.pos.z,graphics.gbuffer)
      fgraphics.pop()
  end,function()
    fgraphics.pop()
  end)
  fgraphics.pop()

  if lib.sceneEnv.AfterEntities then
    lib.sceneEnv.AfterEntities(delta)
  end

  lib.lastTime = ctime
  global.frames = global.frames + 1
end

return "world", lib
