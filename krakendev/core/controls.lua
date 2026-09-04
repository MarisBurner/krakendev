local lib = {}

assert(_ENGINE.system, "Core Library Missing System Permissions")

lib.globals = {}

function lib.process()
  while true do
    local e = { os.pullEvent() }
    if e[1] == "terminate" then
      break
    end
  end
end

return "controls", lib
