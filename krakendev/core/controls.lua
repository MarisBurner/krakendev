local lib = {}

assert(_ENGINE.system, "Core Library Missing System Permissions")

lib.global = {}
local global = lib.global
global.keys = {}
global.lastKey = ""
global.keyDown = false
global.keyPressed = false
global.mouseDown = false
global.mousePressed = false
global.mouse = {button=0,x=1,y=1}

function lib.onload()
  global.mouse.pos = _ENGINE.vector.create2d(1,1)
end

-- Controls Tick happens before first 5 ticks (World Tick, Physics Tick, ...)
lib.tickpriority = 5
function lib.everytick()
  global.keyPressed = false
  global.mousePressed = false
end

function lib.process()
  while true do
    local event = { os.pullEvent() }
    local e = event[1]
    if e == "terminate" then
      break
    elseif e == "mouse_click" or e == "mouse_drag" then
      if e == "mouse_click" then
        global.mousePressed = true
      end
      global.mouseDown = true
      global.mouse.button, global.mouse.x, global.mouse.y = event[2], event[3], event[4]
      global.mouse.pos.dimensions = {global.mouse.x, global.mouse.y}
    elseif e == "mouse_up" then
      global.mouseDown = false
      global.mouse.button, global.mouse.x, global.mouse.y = event[2], event[3], event[4]
      global.mouse.pos.dimensions = {global.mouse.x, global.mouse.y}
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