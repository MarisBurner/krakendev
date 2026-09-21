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

-- Control Tick happens after World Tick
lib.tickpriority = 1
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
    elseif e == "mouse_up" then
      global.mousePressed = true
      global.mouseDown = true
      global.mouse.button, global.mouse.x, global.mouse.y = event[2], event[3], event[4]
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