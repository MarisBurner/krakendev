local api = require("api")
local keepShellFlag = true
local newShellFlag = false

local function testPath(path)
  if fs.exists(path) then
    return path
  end
end

local sysDir = testPath("~/krakendev") or testPath("./krakendev") or ""

local function split(str, sep)
  if sep == nil then
    sep = "%s"
  end
  local t = {}
  for word in string.gmatch(str, "([^" .. sep .. "]+)") do
    table.insert(t, word)
  end
  return t
end

local function printHelpInfo(head,info,psize,pid)
  term.setTextColor(colors.gray)
  print((head or "Command Info:") .. "\n")
  pid, psize = pid or 0, psize or 8
  local pcount = math.ceil(#info / psize)
  local pid = math.min(math.floor(math.max(pid,1)),pcount)-1
  local pagetop = (psize*pid)+1
  for i = 1, psize do
    local t = info[i + pagetop - 1]
    if t then
      term.setTextColor(colors.lightBlue)
      term.write(t[1])
      if t[2] then
        term.setTextColor(colors.green)
        term.write(" "..t[2])
      end
      term.setTextColor(colors.gray)
      print(" - "..(t[3] or "[Missing Info]"))
    end
  end
  print()
  term.setTextColor(colors.gray)
  term.write(string.format("Page %s of %s",pid+1,pcount))
end

local function runCommand(cmd)
  local toks = split(cmd)
  local c = toks[1]
  if c == "help" then
    local commandInfo = {
      {"kd help",nil,"Get help with the KrakenDev API"},
      {"info",nil,"Provides system and engine info"},
      {"help","<page>","Check out all of the different commands"},
      {"exit",nil,"Leave the shell"},
      {"clear",nil,"Flushes the terminal"},
      {"ls","[dir]","List a directory's contents"},
      {"cd","<dir>","Enter a directory"},
      {"mkdir","<dir>","Create a directory"},
      {"del","<path>","Delete a path"},
      {"delete",nil,"Same as 'del'"},
    }
    printHelpInfo("Shell Commands Reference:",commandInfo,5,toks[2])
  elseif c == "info" then
    assert(#toks == 1, "Invalid arguments (expected 0)")
    local enginePath = fs.find(fs.combine(sysDir, "kdev-runtime*"))[1]
    print(string.format("Runtime = '%s'", enginePath or "Not Found"))
  elseif c == "ls" then
    local cdir
    if #toks == 1 then
      cdir = shell.resolve(".")
    elseif #toks == 2 then
      cdir = fs.combine(shell.resolve("."), toks[2])
    else
      error("Invalid arguments (expected 1-2)")
    end
    local paths = fs.list(cdir)
    for _, p in ipairs(paths) do
      local apath = fs.combine(cdir, p)
      if fs.isDir(apath) then
        term.setTextColor(colors.pink)
      else
        term.setTextColor(colors.gray)
      end
      print(p)
    end
  elseif c == "cd" then
    assert(#toks == 2, "Invalid arguments (expected 1)")
    local ndir = fs.combine(shell.resolve("."), toks[2])
    assert(fs.exists(ndir) and fs.isDir(ndir), "This is not a Directory.")
    shell.setDir(ndir)
  elseif c == "mkdir" then
    assert(#toks == 2, "Invalid arguments (expected 1)")
    local ndir = fs.combine(shell.resolve("."), toks[2])
    assert(not fs.exists(ndir), "This name already exists.")
    fs.makeDir(ndir)
    return "Successfully created directory!"
  elseif c == "delete" or c == "del" then
    assert(#toks == 2, "Invalid arguments (expected 1)")
    local ndir = fs.combine(shell.resolve("."), toks[2])
    assert(fs.exists(ndir), "File/Directory doesn't exist.")
    fs.delete(ndir)
    while not fs.exists(shell.resolve(".")) do
      shell.setDir(fs.combine(shell.resolve("."), ".."))
    end
    return "Successfully deleted!"
  elseif c == "exit" then
    assert(#toks == 1, "Invalid arguments (expected 0)")
    keepShellFlag = false
    shell.setDir("")
    return "Exiting..."
  elseif c == "kd" then
    if toks[2] == "run" then
      assert(#toks == 3, "Invalid arguments (expected 1)")
      api.run(toks[3])
      runCommand("clear")
    elseif toks[2] == "pack" then
      assert(#toks == 4 or #toks == 5, "Invalid arguments (expected 2-3)")
      api.carts.package(toks[3], toks[4], toks[5])
      return string.format("Successfully packed up cart '%s'", toks[4])
    elseif toks[2] == "unpack" then
      assert(#toks == 4 or #toks == 5, "Invalid arguments (expected 2-3)")
      api.carts.unpackage(toks[3], toks[4], toks[5])
      return string.format("Successfully unpacked cart '%s'", toks[3])
    elseif toks[2] == "cinfo" then
      assert(#toks == 3, "Invalid arguments (expected 1)")
      return textutils.serialise(api.carts.getInfo(toks[3]))
    elseif toks[2] == nil or toks[2] == "help" then
      local commandInfo = {
        {"kd run",nil,"Runs a project folder"},
        {"kd pack","<proj_dir> <odir> [pass]","Packages a project file into a cart"},
        {"kd unpack","<cart_dir> <ndir> [pass]","Unpacks a cart into a project file"},
        {"kd cinfo","<cart_dir>","Returns info about the cart from its config"},
        {"kd help","<page>", "Check out all of the different commands"}
      }
      printHelpInfo("Kraken Dev Commands:",commandInfo,5,toks[3])
    else
      error("Unknown KrakenDev command")
    end
  elseif c == "clear" then
    assert(#toks == 1, "Invalid arguments (expected 0)")
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
    term.setCursorPos(1, 0)
  else
    error("Unknown Command")
  end
end

term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()
term.setCursorPos(1, 1)
while keepShellFlag do
  term.setTextColor(colors.magenta)
  term.write(string.format(("$kdev/%s> "):sub(-12), shell.resolve(".")))
  term.setTextColor(colors.white)
  local cmd = io.read()
  local suc, res = pcall(function()
    term.setTextColor(colors.gray)
    return runCommand(cmd)
  end)
  if suc then
    term.setTextColor(colors.gray)
    print(tostring(res or ""))
  else
    term.setTextColor(colors.red)
    print(string.format("Error: %s", tostring(res)))
  end
  sleep(0)
end
