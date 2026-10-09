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

api.engineDir = engineDir

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

    reng()(api, sysDir, pDir, shell, require)
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

local function buildHasher()
  -- From http://pastebin.com/gsFrNjbt linked from http://www.computercraft.info/forums2/index.php?/topic/8169-sha-256-in-pure-lua/

  --
  --  Adaptation of the Secure Hashing Algorithm (SHA-244/256)
  --  Found Here: http://lua-users.org/wiki/SecureHashAlgorithm
  --
  --  Using an adapted version of the bit library
  --  Found Here: https://bitbucket.org/Boolsheet/bslf/src/1ee664885805/bit.lua
  --

  local MOD = 2 ^ 32
  local MODM = MOD - 1

  local function memoize(f)
    local mt = {}
    local t = setmetatable({}, mt)
    function mt:__index(k)
      local v = f(k)
      t[k] = v
      return v
    end

    return t
  end

  local function make_bitop_uncached(t, m)
    local function bitop(a, b)
      local res, p = 0, 1
      while a ~= 0 and b ~= 0 do
        local am, bm = a % m, b % m
        res = res + t[am][bm] * p
        a = (a - am) / m
        b = (b - bm) / m
        p = p * m
      end
      res = res + (a + b) * p
      return res
    end
    return bitop
  end

  local function make_bitop(t)
    local op1 = make_bitop_uncached(t, 2 ^ 1)
    local op2 = memoize(function(a) return memoize(function(b) return op1(a, b) end) end)
    return make_bitop_uncached(op2, 2 ^ (t.n or 1))
  end

  local bxor1 = make_bitop({ [0] = { [0] = 0, [1] = 1 }, [1] = { [0] = 1, [1] = 0 }, n = 4 })

  local function bxor(a, b, c, ...)
    local z = nil
    if b then
      a = a % MOD
      b = b % MOD
      z = bxor1(a, b)
      if c then z = bxor(z, c, ...) end
      return z
    elseif a then
      return a % MOD
    else
      return 0
    end
  end

  local function band(a, b, c, ...)
    local z
    if b then
      a = a % MOD
      b = b % MOD
      z = ((a + b) - bxor1(a, b)) / 2
      if c then z = bit32_band(z, c, ...) end
      return z
    elseif a then
      return a % MOD
    else
      return MODM
    end
  end

  local function bnot(x) return (-1 - x) % MOD end

  local function rshift1(a, disp)
    if disp < 0 then return lshift(a, -disp) end
    return math.floor(a % 2 ^ 32 / 2 ^ disp)
  end

  local function rshift(x, disp)
    if disp > 31 or disp < -31 then return 0 end
    return rshift1(x % MOD, disp)
  end

  local function lshift(a, disp)
    if disp < 0 then return rshift(a, -disp) end
    return (a * 2 ^ disp) % 2 ^ 32
  end

  local function rrotate(x, disp)
    x = x % MOD
    disp = disp % 32
    local low = band(x, 2 ^ disp - 1)
    return rshift(x, disp) + lshift(low, 32 - disp)
  end

  local k = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
    0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
  }

  local function str2hexa(s)
    return (string.gsub(s, ".", function(c) return string.format("%02x", string.byte(c)) end))
  end

  local function num2s(l, n)
    local s = ""
    for i = 1, n do
      local rem = l % 256
      s = string.char(rem) .. s
      l = (l - rem) / 256
    end
    return s
  end

  local function s232num(s, i)
    local n = 0
    for i = i, i + 3 do n = n * 256 + string.byte(s, i) end
    return n
  end

  local function preproc(msg, len)
    local extra = 64 - ((len + 9) % 64)
    len = num2s(8 * len, 8)
    msg = msg .. "\128" .. string.rep("\0", extra) .. len
    assert(#msg % 64 == 0)
    return msg
  end

  local function initH256(H)
    H[1] = 0x6a09e667
    H[2] = 0xbb67ae85
    H[3] = 0x3c6ef372
    H[4] = 0xa54ff53a
    H[5] = 0x510e527f
    H[6] = 0x9b05688c
    H[7] = 0x1f83d9ab
    H[8] = 0x5be0cd19
    return H
  end

  local function digestblock(msg, i, H)
    local w = {}
    for j = 1, 16 do w[j] = s232num(msg, i + (j - 1) * 4) end
    for j = 17, 64 do
      local v = w[j - 15]
      local s0 = bxor(rrotate(v, 7), rrotate(v, 18), rshift(v, 3))
      v = w[j - 2]
      w[j] = w[j - 16] + s0 + w[j - 7] + bxor(rrotate(v, 17), rrotate(v, 19), rshift(v, 10))
    end

    local a, b, c, d, e, f, g, h = H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]
    for i = 1, 64 do
      local s0 = bxor(rrotate(a, 2), rrotate(a, 13), rrotate(a, 22))
      local maj = bxor(band(a, b), band(a, c), band(b, c))
      local t2 = s0 + maj
      local s1 = bxor(rrotate(e, 6), rrotate(e, 11), rrotate(e, 25))
      local ch = bxor(band(e, f), band(bnot(e), g))
      local t1 = h + s1 + ch + k[i] + w[i]
      h, g, f, e, d, c, b, a = g, f, e, d + t1, c, b, a, t1 + t2
    end

    H[1] = band(H[1] + a)
    H[2] = band(H[2] + b)
    H[3] = band(H[3] + c)
    H[4] = band(H[4] + d)
    H[5] = band(H[5] + e)
    H[6] = band(H[6] + f)
    H[7] = band(H[7] + g)
    H[8] = band(H[8] + h)
  end

  local function sha256(msg)
    msg = preproc(msg, #msg)
    local H = initH256({})
    for i = 1, #msg, 64 do digestblock(msg, i, H) end
    return str2hexa(num2s(H[1], 4) .. num2s(H[2], 4) .. num2s(H[3], 4) .. num2s(H[4], 4) ..
      num2s(H[5], 4) .. num2s(H[6], 4) .. num2s(H[7], 4) .. num2s(H[8], 4))
  end

  return sha256
end

api.sha256 = buildHasher()
local sha256 = api.sha256

api.certs = {}
function api.getCertificate(name)
  if api.certs[name] then
    return api.certs[name]
  end
  local path = fs.combine(engineDir, "certs", fs.combine(name))
  if fs.exists(path) and not fs.isDir(path) then
    api.certs[name] = readFile(path)
    return api.certs[name]
  end
end

function api.verifyCertificate(certPath,  data)
  data = tostring(data) -- Force data into string
  assert(fs.exists(certPath) and not fs.isDir(certPath), "Cannot verify certificate which doesn't exist.")
  local cname = fs.getName(certPath)

  local c = api.getCertificate(cname)
  if c and sha256(c..data) == readFile(certPath) then
    return true
  end
  return false
end

function api.provideCertificate(certPath, data, destPath)
  local c = api.getCertificate(certPath)
  assert(c, "Certificate doesn't exist in 'krakendev/certs'.")
  data = tostring(data)
  fs.delete(destPath)
  writeFile(destPath, sha256(c..data))
end

function api.provideFileCertificate(certPath, filePath, destPath)
  local sysDir = shell.resolve(".")
  filePath = fs.combine(sysDir, filePath)
  destPath = fs.combine(sysDir, destPath)
  local data = readFile(filePath)
  return api.provideCertificate(certPath,data,destPath)
end

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
        else -- float: mantissa * 2^exp, trailing zero bits stripped
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
        b(0) -- end of hash part
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

  --public API
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
