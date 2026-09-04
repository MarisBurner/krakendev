local api = {}

function api.run(pDir)
  local entDir = shell.resolve(".")

  local suc, res = pcall(function()
    assert(type(pDir) == "string", "Project Path not provided")
    assert(fs.exists(pDir) and fs.isDir(pDir), "Project Path doesn't exist or is not a directory")

    local sysDir
    local function testPath(path)
      if fs.exists(path) then
        return path
      end
    end

    -- Get & Enter Library Directory
    sysDir = testPath("~/krakendev") or testPath("./krakendev") or 0
    if sysDir == 0 then
      error("Couldn't find 'krakendev' engine folder")
    end
    shell.setDir(sysDir)

    -- Get Runtime
    local enginePath = fs.find(fs.combine(shell.resolve("."),"kdev-runtime*"))[1]
    assert(enginePath, "Couldn't find suitable kdev-runtime")

    local reng, err = loadfile(enginePath)
    assert(not err, string.format("Runtime '%s' failed to load: %s",enginePath,err))

    reng()(sysDir, pDir, shell, require)
    return "Instance Ended Successfully!"
  end)

  shell.setDir(entDir)
  return suc, res
end

return api
