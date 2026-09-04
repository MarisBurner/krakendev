local lib = {}

assert(_ENGINE.system, "Core Library Missing System Permissions")

lib.globals = {}

function lib.mergeTables(t1, t2)
  local result = {}
  for k, v in pairs(t1) do
    result[k] = v
  end
  for k, v in pairs(t2) do
    result[k] = v
  end
  return result
end

function lib.tableMap(tbl, func)
  local result = {}
  for k, v in pairs(tbl) do
    result[k] = func(v, k)
  end
  return result
end

function lib.shallowCopy(original)
  local copy = {}
  for key, value in pairs(original) do
    copy[key] = value
  end
  return copy
end

function lib.onload()
  -- This core library is safe, so just make it global
  _ENGINE.globals.utils = lib
end

return "utils", lib
