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

lib.tickpriority = 0
function lib.everytick()
  lib.sceneEnv.Update()
end

return "world", lib