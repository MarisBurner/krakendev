local lib = {}

assert(_ENGINE.system, "Core Library Missing System Permissions")

lib.global = {}
local global = lib.global

global.width, global.height = term.getSize()

global.palette = {}

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

-- Make sure the shade ratios are in ascending order!
lib.ditheringShades = {
  { "\145", 0.05 },
  { "\153", 0.12 },
  { "\127", 0.2 },
}
lib.enableDithering = true

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

    calcColorBuffer[rgb] = c
  end
  return calcColorBuffer[rgb]
end

-- Buffer Tile Format: Character, Text Color Blit, Background Color Blit, Z-Index

function lib.flushBuffer(ch, tc, bc, z, buff)
  for i = 1, buff.width * buff.height do
    buff[i] = { ch, tc, bc, z }
  end
  return buff
end

function lib.getBuffPos(x,y,b)
  assert(type(x) == "number" and type(y) == "number", "Tried to index buffer with non-number")
  if x < 1 or y < 1 or x > b.width or y > b.height then
    return -1
  end
  return x + (b.width * (y-1))
end

function lib.writeBuff(id,ch,tc,bc,z,buff)
  z = z or 0
  if id < 1 or id > buff.width * buff.height then
    -- Out of bounds
    return
  end
  local ctile = buff[id] and buff[id] or {}
  if ctile[4] and ctile[4] > z then
    -- Z-Buffer too low
    return
  end
  buff[id] = { ch or ctile[1], tc or ctile[2], bc or ctile[3], z }
end

function lib.writeBuffPos(x,y,ch,tc,bc,z,buff)
  local id = lib.getBuffPos(x,y,buff)
  if id ~= -1 then
    lib.writeBuff(id,ch,tc,bc,z,buff)
  end
end

function lib.createBuffer(w, h)
  local b = {
    width = w,
    height = h,
    p = {}
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

function global.flush(tc, bc, ch)
  tc = lib.estimateRGB(tc)
  bc = lib.estimateRGB(bc)
  lib.flushBuffer(ch or " ", tc, bc, -math.huge, lib.gbuffer)
end

function global.writeAt(txt, x, y, tc, bc, z)
  txt = tostring(txt)
  tc = lib.estimateRGB(tc)
  bc = lib.estimateRGB(bc)

  for i = 1, txt:len() do
    lib.writeBuffPos(x+i-1,y,txt:sub(i,i),tc,bc,z,lib.gbuffer)
  end
end

function lib.onload()
  global.loadColorPalette(lib.colors)
  global.flush("#ffffff","#000000"," ")
end

lib.tickpriority = math.huge
function lib.everytick()
  local i = 0
  for y = 1, global.height do
    for x = 1, global.width do
      i = i + 1
      term.setCursorPos(x, y)
      local ch, tc, bc = table.unpack(lib.gbuffer[i] or {})
      term.setTextColor(tc or colors.white)
      term.setBackgroundColor(bc or colors.black)
      term.write(ch or " ")
    end
  end
end

return "graphics", lib
