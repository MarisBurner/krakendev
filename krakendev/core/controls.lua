local lib = {}

assert(_ENGINE.system, "Core Library Missing System Permissions")

lib.global = {}
local global = lib.global
global.keys = {}
global.lastKey = ""
global.keyDown = false
global.keyPressed = false

-- Control Tick happens after World Tick
lib.tickpriority = 1
function lib.everytick()
  global.keyPressed = false
end

function lib.process()
  while true do
    local event = { os.pullEvent() }
    local e = event[1]
    if e == "terminate" then
      break
    elseif e == "key" then
      local k = keys.getName(event[2])
      global.keys[k] = true
      global.lastKey = k
      global.keyDown = true
      global.keyPressed = true
    elseif e == "key_up" then
      local k = keys.getName(event[2])
      global.keys[k] = false
      global.keyDown = false
    end
  end
end

return "controls", lib