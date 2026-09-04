local lib = {}

assert(_ENGINE.system, "Core Library Missing System Permissions")

lib.global = {}
local global = lib.global
lib.sounds = {}

if periphemu then
  -- Emulate Speaker (For CraftOS PC)
  lib.speaker = periphemu.create("left","speaker")
end
lib.speaker = peripheral.find("speaker")

function lib.onload()
  lib.decoder = _ENGINE.system.dfpwm.make_decoder()
end

function lib.loadSound(path)
  local spath = fs.combine(_ENGINE.project.path, "assets", path)
  assert(fs.exists(spath),string.format("Failed to find sound asset '%s'",path))
  
end

function global.loadSong(id, path)
  local spath = fs.combine(_ENGINE.project.path, "assets", path)
  assert(fs.exists(spath),string.format("Failed to find sound asset '%s'",path))
end

function global.loadSFX(id, path)
  local spath = fs.combine(_ENGINE.project.path, "assets", path)
  assert(fs.exists(spath),string.format("Failed to find sound asset '%s'",path))
end

return "audio", lib