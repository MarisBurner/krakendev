local lib = {}

assert(_ENGINE.system, "Core Library Missing System Permissions")

lib.global = {}
local global = lib.global
lib.sounds = {}
lib.soundQueue = {}

if periphemu then
  -- Emulate Speaker (For CraftOS PC)
  lib.speaker = periphemu.create("left","speaker")
end
lib.speaker = peripheral.find("speaker")

function lib.linesFromDFPWM(file)
    local lines = {}
    for line in io.lines(file, 16 * 1024) do
        table.insert(lines, line)
    end
    return lines
end

function lib.stopAll()
  lib.soundQueue = {}
  if lib.speaker then
    lib.speaker.stop()
  end
end

global.stopAll = lib.stopAll

function global.loadSound(id, path)
  path = fs.combine("/",path)
  local spath = fs.combine(_ENGINE.project.path, "assets", path)
  assert(fs.exists(spath), string.format("Failed to find sound asset '%s'",path))
  lib.sounds[id] = spath
end

function global.playSFX(id)
  assert(lib.sounds[id], string.format("Sound asset doesn't exist '%s'",id))
  local decoded = _ENGINE.system.dfpwm.decode(lib.sounds[id])
  local i = 1
  local function process(t)
    local sound = decoded
    if t then
      return i > #sound
    end
    while not lib.speaker.playAudio(sound) do
      os.pullEvent("speaker_audio_empty")
    end
    i = i + 1
  end

  lib.soundQueue[#lib.soundQueue+1] = process
end

function lib.process()
  while true do
    if lib.speaker then
      parallel.waitForAll(
        table.unpack(lib.soundQueue)
      )
      -- Remove Dead Tracks
      for i = 1, #lib.soundQueue do
        local t
        if lib.soundQueue[i] then
          t = lib.soundQueue[i](true)
        else
          t = true
        end
        if t then
          table.remove(lib.soundQueue,i)
          i = i - 1
        end
      end
    else
      lib.soundQueue = {}
    end
    sleep(0)
  end
end

return "audio", lib