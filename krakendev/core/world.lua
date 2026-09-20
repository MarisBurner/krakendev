local lib = {}

assert(_ENGINE.system, "Core Library Missing System Permissions")

lib.global = {}
local global = lib.global

function global.loadScene(id)
  local spath = fs.combine(_ENGINE.project.path, "scenes", id)..".lua"
  assert(fs.exists(spath),string.format("Cannot find scene '%s'",id))

  local scene = _ENGINE.system.sandboxFunction(loadfile(spath))
  local senv = getfenv(scene)
  scene()
  senv.Init()
  lib.sceneEnv = senv
end

function lib.onload()
  lib.lastTick = os.epoch("utc")
  lib.lastTime = os.epoch("utc")
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

  lib.sceneEnv.Update((ctime - lib.lastTime)*psr)
  
  lib.lastTime = ctime
  global.frames = global.frames + 1
end

return "world", lib
