local api = {}

local function testPath(path)
  if fs.exists(path) then
    return path
  end
end

local function writeFile(path, d)
  local file = fs.open(path, "w")
  file.write(d)
  file.close()
end
api.writeFile = writeFile

local function readFile(path)
  local file = fs.open(path, "r")
  local r = file.readAll()
  file.close()
  return r
end
api.readFile = readFile

local function readConfig(path)
  local file = fs.open(path, "r")
  local r = file.readAll()
  file.close()
  return textutils.unserialize(r)
end
api.readConfig = readConfig

local engineDir = testPath("~/krakendev") or testPath("./krakendev") or 0
if engineDir == 0 then
  error("Couldn't find 'krakendev' engine folder")
end

-- Get Runtime
local enginePath = fs.find(fs.combine(engineDir, "kdev-runtime*"))[1]
assert(enginePath, "Couldn't find suitable kdev-runtime")

api.engineVersion = fs.getName(enginePath)

local tempDir = fs.combine(engineDir, "temp")
fs.delete(tempDir)

local crypto = peripheral.find("cryptographic_accelerator")

function api.run(pDir)
  local entDir = shell.resolve(".")

  local suc, res = pcall(function()
    assert(type(pDir) == "string", "Project Path not provided")
    assert(fs.exists(pDir) and fs.isDir(pDir), "Project Path doesn't exist or is not a directory")

    local sysDir = engineDir
    -- Get & Enter Library Directory
    shell.setDir(sysDir)

    local reng, err = loadfile(enginePath)
    assert(not err, string.format("Runtime '%s' failed to load: %s", enginePath, err))

    reng()(sysDir, pDir, shell, require)
    return "Instance Ended Successfully!"
  end)

  shell.setDir(entDir)
  return suc, res
end

api.carts = {}

local function serializeDir(dir)
  local r = {}
  if not fs.isDir(dir) then
    return r
  end -- Fallback to missing directory
  local paths = fs.list(dir)
  for _, p in ipairs(paths) do
    local apath = fs.combine(dir, p)
    if fs.isDir(apath) then
      r[p] = serializeDir(apath)
    else
      r[p] = readFile(apath)
    end
  end
  return r
end
api.serialiseDir = serializeDir

local function unserialiseDir(dir, data)
  fs.delete(dir)
  fs.makeDir(dir)
  for k, d in pairs(data) do
    local apath = fs.combine(dir, k)
    if type(d) == "table" then
      unserialiseDir(apath, d)
    else
      writeFile(apath, d)
    end
  end
end
api.unserialiseDir = unserialiseDir

-- Run length encoding functions (to compress strings)
function api.smallify(str)
  local out = {}
  local flag = 0
  local runLen = 0

  local function flush()
    local n = runLen
    while n >= 255 do
      out[#out + 1] = string.char(255)
      n = n - 255
    end
    out[#out + 1] = string.char(n)
    flag = 1 - flag
    runLen = 0
  end

  for i = 1, #str do
    local byte = str:byte(i)
    for k = 7, 0, -1 do
      local bit = math.floor(byte / 2 ^ k) % 2
      if bit == flag then
        runLen = runLen + 1
      else
        flush()
        runLen = 1
      end
    end
  end

  if #str > 0 then
    flush()
  end

  return table.concat(out)
end

function api.largify(enc)
  local out = {}
  local flag = 0
  local count = 0
  local cur, nbits = 0, 0

  local function pushBits(v, n)
    for _ = 1, n do
      cur = cur * 2 + v
      nbits = nbits + 1
      if nbits == 8 then
        out[#out + 1] = string.char(cur)
        cur, nbits = 0, 0
      end
    end
  end

  for i = 1, #enc do
    local b = enc:byte(i)
    count = count + b
    if b ~= 255 then
      pushBits(flag, count)
      flag = 1 - flag
      count = 0
    end
  end

  if count ~= 0 or nbits ~= 0 then
    error("malformed RLE data: incomplete run or bit count not a multiple of 8")
  end

  return table.concat(out)
end

function api.carts.getInfo(dir)
  local sysDir = shell.resolve(".")
  local dir = fs.combine(sysDir, dir)
  local conf = readConfig(fs.combine(dir, "cart.config"))
  return {
    isSecure = not not conf.sec,
    sec = conf.sec,
    info = conf.info,
  }
end

function api.carts.package(dir, odir, pass)
  local sysDir = shell.resolve(".")
  local dir, odir = fs.combine(sysDir, dir), fs.combine(sysDir, odir)
  assert(dir ~= odir, "Packing project path cannot be the same as the project")

  local conf = {}
  local projDataRaw = serializeDir(dir)
  local projData = textutils.serialise(projDataRaw, { compact = true })
  fs.delete(odir)
  fs.makeDir(odir)
  if pass then
    assert(crypto, "To use a password for a cart, you must include a Cryptographic Accelerator!")
    conf.sec = {}
    conf.sec.n1 = crypto.randomBytes(16)
    conf.sec.n2 = crypto.randomBytes(16)
    projData = crypto.encryptAes(projData, pass, cert.n1)
    conf.sec.cert = crypto.sha256(conf.n2 .. pass)
  end
  local projConfPath = fs.find(fs.combine(dir, "*.kproj"))[1]
  assert(projConfPath, "Project missing .kproj configuration")
  local projConf = readConfig(projConfPath)
  conf.info = {
    name = projConf.name,
    author = projConf.author,
  }
  writeFile(fs.combine(odir, "cart.config"), textutils.serialize(conf))
  writeFile(fs.combine(odir, ".cartdata"), api.smallify(projData))
end

function api.carts.unpackage(dir, odir, pass)
  local sysDir = shell.resolve(".")
  local dir, odir = fs.combine(sysDir, dir), fs.combine(sysDir, odir)

  local cartInfo = api.carts.getInfo(dir)
  local cartData = api.largify(readFile(fs.combine(dir, ".cartdata")))
  if cartInfo.isSecure then
    assert(crypto, "Cannot unpack secure unpack cart without a Cryptographic Accelerator!")
    assert(pass, "Missing password to unpack secure cart")
    if crypto.sha256(cartInfo.sec.n2 .. pass) ~= cartInfo.cert then
      -- Failed cert test (Wrong Key)
      return false
    end
    cartData = crypto.decryptAes(cartData, pass, cert.n1)
  else
    cartData = textutils.unserialize(cartData)
  end
  unserialiseDir(odir, cartData)
  return true
end

function api.carts.unpackRun(dir, pass)
  local sysDir = shell.resolve(".")
  local dir = fs.combine(sysDir, dir)
  shell.setDir("/")
  fs.delete(tempDir)
  fs.makeDir(tempDir)
  api.carts.unpackage(dir, tempDir, pass)
  local suc, err = api.run(tempDir)
  fs.delete(tempDir)
  return suc, err
end

return api
