-- KrakenDev Game Engine
-- Made by Mari

return function(sysDir, pDir, shell, require)
  os.pullEvent = os.pullEventRaw

  -- ENGINE Global
  _ENGINE = {
    globals = { project = {} },
    system = { path = sysDir, updateQueue = {}, libProcs = {}, shell = shell },
    project = { path = pDir },
  }

  _ENGINE.system.dfpwm = require("cc.audio.dfpwm")

  local colorNames = {
    "black", "red", "green", "brown", "blue", "purple", "cyan", "white",
    "orange", "magenta", "lightBlue", "yellow", "lime", "pink", "gray", "lightGray"
  }

  -- Get Current Color Pallete
  local cpalette = {}
  for i, name in ipairs(colorNames) do
    cpalette[i] = colors.packRGB(term.getPaletteColor(colors[name]))
  end

  local function readonly(t)
    return setmetatable({}, {
      __index = t,
      __newindex = function() error("attempt to modify readonly table", 1) end,
      __metatable = false
    })
  end

  function _ENGINE.system.sandboxFunction(fn)
    local env = {
      -- Core language basics
      assert = assert,
      error = error,
      ipairs = ipairs,
      next = next,
      pairs = pairs,
      pcall = pcall,
      xpcall = xpcall,
      select = select,
      tonumber = tonumber,
      tostring = tostring,
      type = type,
      unpack = unpack,
      rawequal = rawequal,

      string = readonly(string),
      table = readonly(table),
      math = readonly(math),
      bit = bit,
      bit32 = bit32,

      _ENGINE = readonly(_ENGINE.globals),

      -- Give self-referencing _G so scripts behave predictably
      -- but can't touch your real global table
    }
    env._G = env
    setfenv(fn, env)
    return fn
  end

  local function readAll(path)
    local fl = fs.open(path, "r")
    local r = fl.readAll()
    fl.close()
    return r
  end

  local confDir = fs.find(fs.combine(pDir, "*.kproj"))
  assert(#confDir == 1, "Missing or conflicting .kproj configurations")
  confDir = confDir[1]
  assert(fs.exists(confDir), "Failed to get .kproj configuration")
  _ENGINE.project.config = textutils.unserialize(readAll(confDir))
  _ENGINE.globals.project.config = _ENGINE.project.config

  local function loadLibs(list, path, abs)
    local _ENGINE = _ENGINE
    local isCore = (path == "core" and not abs)

    for i, p in ipairs(list) do
      local rpath = path and fs.combine(path, p) or p
      local fpath = abs and rpath or shell.resolveProgram(rpath)
      assert(fpath and fs.exists(fpath), string.format("Couldn't find library '%s'", fpath or rpath))

      local fn = loadfile(fpath)
      -- If it isn't a core function, sandbox that shi
      if not isCore then
        _ENGINE.system.sandboxFunction(fn)
      end

      local suc, name, o = pcall(fn)
      assert(suc, string.format("Library '%s' encountered error: %s", fpath, name))

      assert(type(name) == "string", string.format("Library '%s' failed to return proper identifier", fpath))

      if _ENGINE[name] then
        error(string.format("Conflicting library identifiers '%s'", name))
      end
      _ENGINE[name] = o or {}

      if o.global then
        _ENGINE.globals[name] = o.global
      end

      if type(o) == "table" then
        if o.onload then
          local plib = o.onload()
        end
        if o.everytick then
          table.insert(_ENGINE.system.updateQueue, { o.everytick, o.tickpriority or 0 })
        end
        if o.process then
          table.insert(_ENGINE.system.libProcs, o.process)
        end
      end
    end
  end

  -- Load in all libraries included
  loadLibs({ "utils", "vector", "controls", "audio", "graphics", "world" }, "core")

  local confLibs = _ENGINE.project.config.core or _ENGINE.project.config.cores
  if confLibs then
    loadLibs(confLibs, "core")
  end

  local projLibs = fs.combine(_ENGINE.project.path, "libs")
  if fs.exists(projLibs) then
    loadLibs(fs.list(projLibs), projLibs, true)
  end

  table.sort(_ENGINE.system.updateQueue, function(a, b)
    return a[2] < b[2]
  end)

  local suc, err = pcall(function()
    parallel.waitForAny(
      function()
        _ENGINE.globals.world.loadScene(_ENGINE.project.config.start_scene)
        while true do
          for _, p in ipairs(_ENGINE.system.updateQueue) do
            p[1]()
          end
          sleep(0.1)
        end
      end,
      function()
        -- Exit Runtime Flag
        while not _ENGINE.globals._Terminate do
          sleep(0.1)
        end
      end,
      table.unpack(_ENGINE.system.libProcs)
    )
  end)

  if _ENGINE.audio then
    _ENGINE.audio.stopAll()
  end

  -- Restore Color Pallete
  for i, name in ipairs(colorNames) do
    term.setPaletteColor(colors[name], cpalette[i])
  end

  if not suc then error(err) end
end
