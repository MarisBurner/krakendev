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

local function buildCompressor()
  -- Compact table serializer + LZSS compressor for Lua 5.1
  local floor, char, byte, concat = math.floor, string.char, string.byte, table.concat

  ---------------------------------------------------------------- serializer
  -- Tags: 0 nil, 1 false, 2 true, 3 +int, 4 -int, 5 +float, 12 -float,
  --       6 new string, 7 string ref, 8 table, 9 inf, 10 -inf, 11 nan,
  --       16..255 = small integer 0..239 in one byte
  local function serialize(root)
    local o, n, seen, ns, active = {}, 0, {}, 0, {}
    local function b(x)
      n = n + 1; o[n] = char(x)
    end
    local function varint(x)
      while x >= 128 do
        b(x % 128 + 128); x = floor(x / 128)
      end
      b(x)
    end
    local function ser(x)
      local t = type(x)
      if x == nil then
        b(0)
      elseif t == "boolean" then
        b(x and 2 or 1)
      elseif t == "number" then
        if x ~= x then
          b(11)
        elseif x == math.huge then
          b(9)
        elseif x == -math.huge then
          b(10)
        elseif x % 1 == 0 and x > -2 ^ 53 and x < 2 ^ 53 then
          if x >= 0 and x < 240 then
            b(16 + x)
          elseif x > 0 then
            b(3); varint(x)
          else
            b(4); varint(-x)
          end
        else     -- float: mantissa * 2^exp, trailing zero bits stripped
          local neg = x < 0
          if neg then x = -x end
          local m, e = math.frexp(x)
          m, e = floor(m * 2 ^ 53), e - 53
          while m % 2 == 0 do
            m = m / 2; e = e + 1
          end
          b(neg and 12 or 5); varint(m)
          varint(e >= 0 and e * 2 or -e * 2 - 1)
        end
      elseif t == "string" then
        local id = seen[x]
        if id then
          b(7); varint(id)
        else
          seen[x] = ns; ns = ns + 1
          b(6); varint(#x); n = n + 1; o[n] = x
        end
      elseif t == "table" then
        if active[x] then error("cyclic table") end
        active[x] = true
        local len = #x
        b(8); varint(len)
        for i = 1, len do ser(x[i]) end
        for k, v in pairs(x) do
          if not (type(k) == "number" and k % 1 == 0 and k >= 1 and k <= len) then
            ser(k); ser(v)
          end
        end
        b(0)     -- end of hash part
        active[x] = nil
      else
        error("cannot serialize " .. t)
      end
    end
    ser(root)
    return concat(o)
  end

  local function deserialize(s)
    local p, strs, ns = 1, {}, 0
    local function varint()
      local r, m = 0, 1
      while true do
        local c = byte(s, p); p = p + 1
        if c < 128 then return r + c * m end
        r = r + (c - 128) * m; m = m * 128
      end
    end
    local function de()
      local t = byte(s, p); p = p + 1
      if t >= 16 then
        return t - 16
      elseif t == 0 then
        return nil
      elseif t == 1 then
        return false
      elseif t == 2 then
        return true
      elseif t == 3 then
        return varint()
      elseif t == 4 then
        return -varint()
      elseif t == 5 or t == 12 then
        local m, z = varint(), varint()
        local x = math.ldexp(m, z % 2 == 0 and z / 2 or -(z + 1) / 2)
        return t == 12 and -x or x
      elseif t == 9 then
        return math.huge
      elseif t == 10 then
        return -math.huge
      elseif t == 11 then
        return 0 / 0
      elseif t == 6 then
        local l = varint()
        local str = s:sub(p, p + l - 1); p = p + l
        strs[ns] = str; ns = ns + 1
        return str
      elseif t == 7 then
        return strs[varint()]
      elseif t == 8 then
        local tbl = {}
        for i = 1, varint() do tbl[i] = de() end
        while byte(s, p) ~= 0 do
          local k = de(); tbl[k] = de()
        end
        p = p + 1
        return tbl
      end
      error("bad tag " .. t)
    end
    return de()
  end

  ---------------------------------------------------------------- LZSS
  -- Groups of 8 items behind a flag byte (bit set = literal byte).
  -- Match = 2 bytes: 12-bit distance (1..4096), 4-bit length (3..18).
  local function lzCompress(s)
    local n, out, grp, flag, cnt, head = #s, {}, {}, 0, 0, {}
    local function flush()
      if cnt > 0 then
        out[#out + 1] = char(flag) .. concat(grp)
        grp, flag, cnt = {}, 0, 0
      end
    end
    local function put(lit, a, c)
      if lit then flag = flag + 2 ^ cnt end
      grp[#grp + 1] = a
      if c then grp[#grp + 1] = c end
      cnt = cnt + 1
      if cnt == 8 then flush() end
    end
    local function ins(p)
      if p + 2 <= n then
        local k = s:sub(p, p + 2)
        local l = head[k]
        if l then l[#l + 1] = p else head[k] = { p } end
      end
    end
    local i = 1
    while i <= n do
      local bl, bd = 0, 0
      if i + 2 <= n then
        local l = head[s:sub(i, i + 2)]
        if l then
          for j = #l, math.max(1, #l - 23), -1 do
            local d = i - l[j]
            if d > 4096 then break end
            local k = 0
            while k < 18 and i + k <= n and byte(s, l[j] + k) == byte(s, i + k) do
              k = k + 1
            end
            if k > bl then bl, bd = k, d end
            if k == 18 then break end
          end
        end
      end
      if bl >= 3 then
        local v = (bd - 1) * 16 + bl - 3
        put(false, char(floor(v / 256)), char(v % 256))
        for q = i, i + bl - 1 do ins(q) end
        i = i + bl
      else
        put(true, s:sub(i, i)); ins(i); i = i + 1
      end
    end
    flush()
    return concat(out)
  end

  local function lzDecompress(s)
    local o, n, p, len = {}, 0, 1, #s
    while p <= len do
      local f = byte(s, p); p = p + 1
      for bit = 0, 7 do
        if p > len then break end
        if floor(f / 2 ^ bit) % 2 == 1 then
          n = n + 1; o[n] = s:sub(p, p); p = p + 1
        else
          local v = byte(s, p) * 256 + byte(s, p + 1); p = p + 2
          local d, l = floor(v / 16) + 1, v % 16 + 3
          for _ = 1, l do
            o[n + 1] = o[n + 1 - d]; n = n + 1
          end
        end
      end
    end
    return concat(o)
  end

  ---------------------------------------------------------------- public API
  local function encode(tbl)
    local raw = serialize(tbl)
    local c = lzCompress(raw)
    if #c < #raw then return "\1" .. c end
    return "\0" .. raw -- never grows by more than 1 byte
  end

  local function decode(str)
    local body = str:sub(2)
    if str:sub(1, 1) == "\1" then body = lzDecompress(body) end
    return deserialize(body)
  end

  return { encode = encode, decode = decode, serialize = serialize, deserialize = deserialize }
end
api.compressor = buildCompressor()
api.smallify = api.compressor.encode
api.largify = api.compressor.decode

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
