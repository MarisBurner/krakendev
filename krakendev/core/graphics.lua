local lib = {}

assert(_ENGINE.system, "Core Library Missing System Permissions")

lib.global = {}
local global = lib.global

global.width, global.height = term.getSize()

global.palette = {}
global.colorBufferLimit = 5000

lib.epsilon = 1e-9
lib.flags = {}

-- Standard SWEETIE 16 color palette.
global.palette.SWEETIE = {
  "#1a1c2c",
  "#5d275d",
  "#b13e53",
  "#ef7d57",
  "#ffcd75",
  "#a7f070",
  "#38b764",
  "#257179",
  "#29366f",
  "#3b5dc9",
  "#41a6f6",
  "#73eff7",
  "#f4f4f4",
  "#94b0c2",
  "#566c86",
  "#333c57",
}
-- Commodore 64 color palette.
global.palette.Commodore = {
  "#000000",
  "#626262",
  "#898989",
  "#adadad",
  "#ffffff",
  "#9f4e44",
  "#cb7e75",
  "#6d5412",
  "#a1683c",
  "#c9d487",
  "#9ae29b",
  "#5cab5e",
  "#6abfc6",
  "#887ecb",
  "#50459b",
  "#a057a3",
}
-- MIYAZAKI 16 color palette.
global.palette.MIYAZAKI = {
  "#232228",
  "#284261",
  "#5f5854",
  "#878573",
  "#b8b095",
  "#c3d5c7",
  "#ebecdc",
  "#2485a6",
  "#54bad2",
  "#754d45",
  "#c65046",
  "#e6928a",
  "#1e7453",
  "#55a058",
  "#a1bf41",
  "#e3c054",
}
-- PICO8 color palette.
global.palette.PICO8 = {
  "#000000",
  "#1D2B53",
  "#7E2553",
  "#008751",
  "#AB5236",
  "#5F574F",
  "#C2C3C7",
  "#FFF1E8",
  "#FF004D",
  "#FFA300",
  "#FFEC27",
  "#00E436",
  "#29ADFF",
  "#83769C",
  "#FF77A8",
  "#FFCCAA",
}
-- Pastel Horizon Palette.
global.palette.PastelHorizon = {
  "#53437f",
  "#a89fcc",
  "#ffffff",
  "#ffd9e8",
  "#ff9bb6",
  "#9968e2",
  "#be9bff",
  "#7fceff",
  "#6d81ff",
  "#2c6f99",
  "#00bcaa",
  "#c48f9e",
  "#8e586f",
  "#ff5470",
  "#ff9b71",
  "#ffd9ae",
}
-- ComputerCraft Standard Palette.
global.palette.CC = {
  "#111111",
  "#CC4C4C",
  "#57A64E",
  "#7F664C",
  "#3366CC",
  "#B266E5",
  "#4C99BC",
  "#999999",
  "#4C4C4C",
  "#F2B2CC",
  "#7FCC19",
  "#DEDE6C",
  "#99B2F2",
  "#E57FD8",
  "#F2B233",
  "#F0F0F0",
}

lib.colors = global.palette.SWEETIE

lib.images = {}
function global.loadImage(id, path, type)
  type = type or "tiletable"
  path = fs.combine("/",path)
  local spath = fs.combine(_ENGINE.project.path, "assets", path)
  assert(fs.exists(spath), string.format("Failed to find image asset '%s'",path))
  local imgData = _ENGINE.system.readAll(spath)
  local imgBuff
  if type == "tiletable" then
    local obj = textutils.unserialise(imgData)
    imgBuff = lib.createBuffer(obj.size[1],obj.size[2])
    for i, t in ipairs(obj.tiles) do
      lib.writeBuff(i,t[1],lib.estimateRGB(t[2]),lib.estimateRGB(t[3]),0,imgBuff)
    end
  else
    error(string.format("Cannot format image '%s' to format '%s'",id,type))
  end
  lib.images[id] = {buffer=imgBuff}
end

function lib.blitFromIndex(i)
  return colors.fromBlit(string.format("%x", bit.band(tonumber(i) - 1, 0xf)))
end

function global.loadColorPalette(pal)
  assert(#pal == 16, "Color palette must have 16 color entries!")
  lib.colors = pal
  lib.calculateColorMap()
end

function global.colorID(id)
  return lib.colors[id]
end

function lib.calculateColorMap()
  -- Required whenever changing the Color Palette
  lib.calcColorBuffer = {}
  lib.colorMap = {}
  for i = 1, 16 do
    local blit = lib.blitFromIndex(17-i)
    term.setPaletteColor(blit, tonumber(lib.colors[i]:sub(-6), 16))
    lib.colorMap[17-i] = _ENGINE.vector.create3d(term.getPaletteColor(blit))
  end
end

function global.RGB(r, g, b)
  local function safeValue(x)
    return bit.band(x,0xff) or 0
  end
  r = safeValue(r)
  g = safeValue(g)
  b = safeValue(b)
  local c = bit.blshift(r,16) + bit.blshift(g,8) + b
  return string.format("000000%X",c):sub(-6)
end

function lib.estimateRGB(pcolor)
  if type(pcolor) == "nil" then return end
  local vector = _ENGINE.vector
  local rgb
  local calcColorBuffer = lib.calcColorBuffer
  pcolor = pcolor or 0
  if type(pcolor) == "number" then
    rgb = bit.band(math.floor(pcolor), 0xffffff)
  elseif type(pcolor) == "string" then
    rgb = bit.band(tonumber(pcolor:sub(-6), 16), 0xffffff)
  end
  local rgbVec = vector.create3d(colors.unpackRGB(rgb))

  assert(rgb, string.format("Invalid RGB color '%s'", tostring(pcolor)))
  if not calcColorBuffer[rgb] then
    local c

    local rcmap = _ENGINE.utils.tableMap(lib.colorMap, function(v, i)
      return { vector.magSqr(v - rgbVec), i }
    end)

    -- Sort Closest Colors
    table.sort(rcmap, function(a, b)
      return a[1] < b[1]
    end)

    c = lib.blitFromIndex(rcmap[1][2])

    calcColorBuffer[rgb] = {c, os.epoch("utc")}
    lib.flags.cbPurge = true -- Trigger Color Purge
  end
  return calcColorBuffer[rgb][1]
end

-- Buffer Tile Format: Character, Background Color Blit, Text Color Blit, Z-Index

function lib.flushBuffer(ch, bc, tc, z, buff)
  for i = 1, buff.width * buff.height do
    buff[i] = { ch, bc, tc, z }
  end
  return buff
end

function lib.getBuffPos(x,y,b)
  assert(type(x) == "number" and type(y) == "number", "Tried to index buffer with non-number")
  if x < 1 or y < 1 or x > b.width or y > b.height then
    return -1
  end
  return math.floor(x + (b.width * (y-1)))
end

function lib.writeBuff(id,ch,bc,tc,z,buff)
  z = z or 0
  if id < 1 or id > buff.size then
    -- Out of bounds
    return
  end
  local ctile = buff[id] and buff[id] or {}
  if ctile[4] and ctile[4] > z then
    -- Z-Buffer too low
    return
  end
  buff[id] = { ch or ctile[1], bc or ctile[2], tc or ctile[3], z }
end

function lib.writeBuffPos(x,y,ch,bc,tc,z,buff)
  local id = lib.getBuffPos(x,y,buff)
  if id ~= -1 then
    lib.writeBuff(id,ch,bc,tc,z,buff)
  end
end

lib.shaders = {}
global.shaders = {}

function lib.shaders.placeholder(x,y,u,v,w)
  return lib.estimateRGB(global.RGB(u*255,v*255,w*255)), 1, " "
end

function lib.shaders.placeholderRect(x,y,u,v,w,uu,vv)
  return lib.estimateRGB(global.RGB(uu*255,vv*255,0)), 1, " "
end

function lib.shaders.empty(x,y,u,v,w,uu,vv)
  return nil, nil, nil
end

function lib.createSolidShader(bc,tc,t)
  return function(x,y,u,v,w)
    return bc, tc, t
  end
end

function lib.createRGBSolidShader(bc,tc,t)
  if bc then
    bc = lib.estimateRGB(bc)
  end
  if tc then
    tc = lib.estimateRGB(tc)
  end
  return function(x,y,u,v,w)
    return bc, tc, t
  end
end

function lib.createImageShader(imgBuff,tlx,tly)
  local rtx, rty = tlx or 1, tly or 1
  local edgeX, edgeY = (imgBuff.width*rtx) - 1, (imgBuff.height*rty) - 1
  return function(x,y,u,v,w,uu,vv)
    local uu = uu * rtx
    local vv = vv * rty
    local rx = math.min(math.floor(uu * imgBuff.width), edgeX) % imgBuff.width 
    local ry = math.min(math.floor(vv * imgBuff.height), edgeY) % imgBuff.height
    local tl = imgBuff[lib.getBuffPos(rx+1,ry+1,imgBuff)]
    return tl[2], tl[3], tl[1]
  end
end

function lib.createLoadedImageShader(imgId,tx,ty)
  local imgData = lib.images[imgId]
  assert(imgData,string.format("Cannot load shader, Image '%s' doesn't exist",imgId))
  return lib.createImageShader(imgData.buffer,tx,ty)
end

function lib.drawLineBuffer(x1,y1,x2,y2,shader,z,buff)
  local flr = math.floor
  local abs = math.abs
  x1, x2, y1, y2 = flr(x1), flr(x2), flr(y1), flr(y2)

  local function writeAt(x,y,i)
    local bc, tc, t = shader(x,y,i,0,0)
    lib.writeBuffPos(flr(x),flr(y),t,bc,tc,z,buff)
  end

  local xdr = x2 - x1
  local xd = abs(xdr)
  local xstep = 0
  if xdr > 0 then
    xstep = 1
  elseif xdr < 0 then
    xstep = -1
  end

  local ydr = y2 - y1
  local yd = abs(y2 - y1)
  local ystep = ydr / xd
  local fac

  if xstep == 0 then
    -- Vertical Line
    ystep = (ydr < 0) and -1 or 1
    fac = 1 / yd
    for i = 0, yd do
      writeAt(x1, y1 + (i * ystep),i*fac)
    end
  elseif yd > xd then
    -- Y Gaps too big, replace with YStep
    ystep = (ydr < 0) and -1 or 1
    xstep = xdr / yd
    fac = 1 / yd
    for i = 0, yd do
      writeAt(x1 + (i * xstep), y1+(i*ystep),i*fac)
    end
  else
    -- Regular Line
    fac = 1 / xd
    for i = 0, xd do
      writeAt(x1+(xstep*i), y1 + (i * ystep),i*fac)
    end
  end
end

function lib.drawTriangleBuffer(x1,y1,x2,y2,x3,y3,ruv,shader,z,buff)
  local flr, ceil = math.floor, math.ceil
  local max = math.max
  local min = math.min

  local uv1, uv2, uv3
  if ruv then
    uv1, uv2, uv3 = table.unpack(ruv)
  end

  local function writeAt(x,y,u,v,w,ou,ov)
    local bc, tc, ch = shader(x,y,u,v,w,ou,ov)
    lib.writeBuffPos(x,y,ch,bc,tc,z,buff)
  end

  local EPS = lib.epsilon

  local e0x, e0y = x2 - x1, y2 - y1
  local e1x, e1y = x3 - x1, y3 - y1

  local d00 = e0x*e0x + e0y*e0y
  local d01 = e0x*e1x + e0y*e1y
  local d11 = e1x*e1x + e1y*e1y

  local denom = d00*d11 - d01*d01
  if denom == 0 then return end -- degenerate triangle / no area
  local inv = 1 / denom

  local l, r = flr(min(x1, x2, x3)), ceil(max(x1,x2,x3))
  local top, bot = flr(min(y1, y2, y3)), ceil(max(y1, y2, y3))

  for y = top, bot do
    local ry = y - y1
    for x = l, r do
      local rx = x - x1
      local d02 = e0x*rx + e0y*ry
      local d12 = e1x*rx + e1y*ry

      local v = (d11*d02 - d01*d12) * inv
      local w = (d00*d12 - d01*d02) * inv
      local u = 1 - v - w
      if u >= -EPS and v >= -EPS and w >= -EPS then
        u = max(u,0)
        v = max(v,0)
        w = max(w,0)
        if ruv then
          local outU = u*uv1[1] + v*uv2[1] + w*uv3[1]
          local outV = u*uv1[2] + v*uv2[2] + w*uv3[2]
          writeAt(x,y,u,v,w,outU,outV)
        else
          writeAt(x,y,u,v,w)
        end
      end
    end
  end
end

function lib.drawRectBuffer(x1,y1,x2,y2,x3,y3,x4,y4,shader,z,buff)
  lib.drawTriangleBuffer(x1,y1,x2,y2,x3,y3,{ {0,0}, {1,0}, {1,1} }, shader, z, buff)
  lib.drawTriangleBuffer(x1,y1,x3,y3,x4,y4,{ {0,0}, {1,1}, {0,1} }, shader, z, buff)
end

-- Rendering Pipeline
lib.transStack = {{}}

function lib.applyTrans(point)
  r = point
  for i = #lib.transStack, 1, -1 do
    local transLayer = lib.transStack[i]
    for j = 1, #transLayer do
      r = transLayer[j](r)
    end
  end
  return r
end

function lib.applyAllTrans(points)
  local r = {}
  for i = 1, #points do
    r[i] = lib.applyTrans(points[i])
  end
  return r
end

function global.push()
  lib.transStack[#lib.transStack + 1] = {}
end

function global.pop()
  table.remove(lib.transStack,#lib.transStack)
  if #lib.transStack < 1 then
    lib.transStack = {{}}
  end
end

function lib.addTrans(fn)
  local layer = lib.transStack[#lib.transStack]
  layer[#layer+1] = fn
end

function global.translate(x,y)
  local vector = _ENGINE.vector
  lib.addTrans(function(p)
    return p + vector.create2d(x,y)
  end)
end

function global.centerRect(w,h)
  global.translate(-((w-1)/2), -((h-1)/2))
end

function global.scale(x,y)
  local vector = _ENGINE.vector
  lib.addTrans(function(p)
    return p * vector.create2d(x,y)
  end)
end

function global.rotate(r)
  local vector = _ENGINE.vector
  lib.addTrans(function(p)
    return p:rotate2d(r)
  end)
end

function lib.renderRect(x,y,w,h,shader,z,buff)
  local vector = _ENGINE.vector
  local l, r, t, b = x, x+(w-1), y, y+(h-1)
  local tl, tr, br, bl = vector.create2d(l,t), vector.create2d(r,t), vector.create2d(r,b), vector.create2d(l,b)
  local points = {tl, tr, br, bl}
  local tPoints = lib.applyAllTrans(points)
  lib.drawRectBuffer(
    tPoints[1].x,tPoints[1].y,
    tPoints[2].x,tPoints[2].y,
    tPoints[3].x,tPoints[3].y,
    tPoints[4].x,tPoints[4].y,
    shader,z,buff
  )
end

function global.rect(x,y,w,h,bc,tc,ch,z)
  local ch = tostring(ch or " ")
  local bc = lib.estimateRGB(bc)
  local tc = lib.estimateRGB(tc)
  local shader = lib.createSolidShader(bc,tc,ch)
  lib.renderRect(x,y,w,h,shader,z,lib.gbuffer)
end

function global.image(x,y,w,h,imgId,tx,ty,z)
  local shader = lib.createLoadedImageShader(imgId,tx,ty)
  lib.renderRect(x,y,w,h,shader,z,lib.gbuffer)
end

function lib.createBuffer(w, h)
  local b = {
    width = w,
    height = h,
    size = w * h,
    p = {},
  }
  setmetatable(b, {
    __index = function(t, k)
      if type(k) == "number" then
        return rawget(t, "p")[k]
      end
      return rawget(t, k)
    end,
    __newindex = function(t, k, v)
      if type(k) == "number" then
        rawget(t, "p")[k] = v
      end
    end,
  })
  return b
end

lib.gbuffer = lib.createBuffer(global.width, global.height)

-- Global Drawing Functions

function global.flush(bc, tc, ch)
  bc = lib.estimateRGB(bc)
  tc = lib.estimateRGB(tc)
  lib.flushBuffer(ch or " ", bc, tc, -math.huge, lib.gbuffer)
end

function global.drawLine(x1, y1, x2, y2, bc, tc, t, z)
  t = tostring(t or " ")
  bc = lib.estimateRGB(bc)
  tc = lib.estimateRGB(tc)
  local shader = lib.createSolidShader(bc,tc,t)
  lib.drawLineBuffer(x1,y1,x2,y2,shader,z,lib.gbuffer)
end

function global.drawRectPoints(x1,y1,x2,y2,x3,y3,x4,y4,bc,tc,ch,z)
  c = tostring(t or " ")
  bc = lib.estimateRGB(bc)
  tc = lib.estimateRGB(tc)
  local shader = lib.createSolidShader(bc,tc,t)
  lib.drawRectBuffer(x1,y1,x2,y2,x3,y3,x4,y4,shader,z,lib.gbuffer)
end

function global.drawRect(x1,y1,x2,y2,bc,tc,ch,z)
  local max = math.max
  local min = math.min
  local l, r, t, b = min(x1,x2), max(x1,x2), min(y1,y2), max(y1,y2)
  global.drawRectPoints(l,t, r,t, r,b, l,b, bc,tc,ch,z)
end

function global.drawTriangle(x1, y1, x2, y2, x3, y3, bc, tc, t, z)
  t = tostring(t or " ")
  bc = lib.estimateRGB(bc)
  tc = lib.estimateRGB(tc)
  local shader = lib.createSolidShader(bc,tc,t)
  lib.drawTriangleBuffer(x1,y1,x2,y2,x3,y3,nil,shader,z,lib.gbuffer)
end

function global.writeAt(txt, x, y, bc, tc, z)
  txt = tostring(txt)
  bc = lib.estimateRGB(bc)
  tc = lib.estimateRGB(tc)

  for i = 1, txt:len() do
    lib.writeBuffPos(x+i-1,y,txt:sub(i,i),bc,tc,z,lib.gbuffer)
  end
end

function lib.onload()
  global.loadColorPalette(lib.colors)
  global.flush("#000000","#ffffff"," ")
end

lib.tickpriority = math.huge
function lib.everytick()
  local i = 0
  for y = 1, global.height do
    for x = 1, global.width do
      i = i + 1
      term.setCursorPos(x, y)
      local ch, bc, tc = table.unpack(lib.gbuffer[i] or {})
      term.setTextColor(tc or colors.white)
      term.setBackgroundColor(bc or colors.black)
      term.write(ch or " ")
    end
  end

  if lib.flags.cbPurge then
    -- Purge Color Buffer
    local nbuff = {}
    local ctime = os.epoch("utc")
    local cbuff = {}
    
    for k, v in pairs(lib.calcColorBuffer) do
      cbuff[#cbuff + 1] = {k,v,ctime-v[2]}
    end

    table.sort(cbuff,function(a,b)
      return a[3] < b[3]
    end)

    local i = 0
    for id = 1, #cbuff do
      i = i + 1
      if i > global.colorBufferLimit then
        break
      end

      local k, v = cbuff[id][1], cbuff[id][2]
      nbuff[k] = v
    end

    lib.calcColorBuffer = nbuff
  end
  lib.transStack = {{}}
end

return "graphics", lib
