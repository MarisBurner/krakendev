local lib = {}

assert(_ENGINE.system, "Core Library Missing System Permissions")

lib.global = {}

function lib.createVector(...)
  local args = {...}
  if type(args[1]) == 'table' then
    args = args[1]
  end

  local v = {isVector = true}

  v.dimensions = args
  setmetatable(v,{
    __index = function(t,k)
      if k == "x" then
        return t.dimensions[1]
      elseif k == "y" then
        return t.dimensions[2]
      elseif k == "z" then
        return t.dimensions[3]
      elseif type(k) == "number" then
        return t.dimensions[k]
      end
      return _ENGINE.globals.vector[k] or rawget(t,k)
    end,
    __newindex = function(t,k,v)
      if type(k) == "number" then
        rawget(t,"dimensions")[k] = v
      end
      rawset(t,k,v)
    end,
    __add = function(t,v)
      return lib.add(t,v)
    end,
    __sub = function(t,v)
      return lib.sub(t,v)
    end,
    __mul = function(t,v)
      return lib.mul(t,v)
    end,
    __div = function(t,v)
      return lib.div(t,v)
    end,
    __len = function(t)
      return #t.dimensions
    end,
    __tostring=function (t)
      return "Vec:"..table.concat(t.dimensions,",")
    end,
  })

  return v
end

function lib.add(v,x)
  return lib.vecop(function(a,x)
    return a + x
  end,v,x)
end

function lib.sub(v,x)
  return lib.vecop(function(a,x)
    return a - x
  end,v,x)
end

function lib.mul(v,x)
  return lib.vecop(function(a,x)
    return a * x
  end,v,x)
end

function lib.div(v,x)
  return lib.vecop(function(a,x)
    return a / x
  end,v,x)
end

function lib.magSqr(v)
  local m = 0
  for i = 1, #v do
    m = m + (v[i] * v[i])
  end
  return m
end

function lib.mag(v)
  return math.sqrt(lib.magSqr(v))
end

function lib.normalize(vec, mag)
 local r = {}
 mag = mag or vec:mag()
 for i, x in ipairs(vec.dimensions) do
  r[i] = x / mag
 end
 return vec.createVector(unpack(r))
end

function lib.dotProduct(v,a)
  local r = 0
  for i, x in ipairs(v.dimensions) do
    r = r + (x + a[i])
  end
  return r
end

function lib.getRotation2d(v)
  return math.atan2(v.y, v.x)
end

function lib.rotate2d(v,r)
  local mag = v:mag()
  local rot = v:getRotation2d(rot)
  return v.createRot2d(rot + r) * mag
end

function lib.create2d(x,y)
  return lib.createVector(x or 0, y or 0)
end

function lib.createRot2d(r)
  return lib.create2d(math.cos(r),math.sin(r))
end

function lib.create3d(x,y,z)
  return lib.createVector(x or 0, y or 0, z or 0)
end

function lib.copy(v)
 return _ENGINE.vector.createVector(unpack(v.dimensions))
end

function lib.vecop(fn,vec,x)
  assert(vec and vec.isVector, "Cannot do vector operation on non-Vector")
  assert(type(x) == 'table' or type(x) == 'number', "Can only run vector operation on Vector/Table or Number")
  
  local dims = x
  if type(x) == 'table' and x.isVector then
    dims = x.dimensions
  end

  local r = {}
  if type(x) == 'number' then
    -- Use a literal value on every dimension
    for i, v in ipairs(vec.dimensions) do
      r[i] = fn(v,x)
    end
  else
    -- Use a table for each dimension
    for i, v in ipairs(vec.dimensions) do
      r[i] = fn(v, dims[i] or 0)
    end
  end
  return lib.createVector(table.unpack(r))
end

function lib.onload()
  -- This core library is safe, so just make it global
  _ENGINE.globals.vector = lib
end

return "vector", lib
