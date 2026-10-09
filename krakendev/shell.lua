local api = require("api")
local keepShellFlag = true
local twidth, theight = term.getSize()

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
      {"help","[page]","Check out all of the different commands"},
      {"exit",nil,"Leave the shell"},
      {"reboot",nil,"Reboot the computer"},
      {"clear",nil,"Flushes the terminal"},
      {"ls","[dir]","List a directory's contents"},
      {"l","[dir]","Raw 'ls'"},
      {"cd","<dir>","Enter a directory"},
      {"mkdir","<dir>","Create a directory"},
      {"copy, cp","<source> <path>","Copy a file or directory"},
      {"delete, rm","<path>","Delete a file or directory"},
    }
    printHelpInfo("Shell Commands Reference:",commandInfo,5,toks[2])
  elseif c == "info" then
    assert(#toks == 1, "Invalid arguments (expected 0)")
    local enginePath = fs.find(fs.combine(sysDir, "kdev-runtime*"))[1]
    term.setTextColor(colors.pink)
    print("# KrakenDev Shell 1")
    print("@ By KrakenCorp\n")
    print(string.format("Engine = %s", fs.getName(enginePath) or "Not Found"))
  elseif c == "l" then
    local cdir
    if #toks == 1 then
      cdir = shell.resolve(".")
    elseif #toks == 2 then
      cdir = fs.combine(shell.resolve("."), toks[2])
    else
      error("Invalid arguments (expected 0-1)")
    end
    local allPaths = {}
    local paths = fs.list(cdir)
    for _, p in ipairs(paths) do
      allPaths[#allPaths+1] = p
    end
    return table.concat(allPaths, " ")
  elseif c == "ls" then
    local cdir
    if #toks == 1 then
      cdir = shell.resolve(".")
    elseif #toks == 2 then
      cdir = fs.combine(shell.resolve("."), toks[2])
    else
      error("Invalid arguments (expected 0-1)")
    end
    local paths = fs.list(cdir)
    print(string.format("/ %s | Type",((cdir:sub(-12,-1))..((" "):rep(12))):sub(1,12)))
    print(("-"):rep(21))
    for i, p in ipairs(paths) do
      local dinfo = ""
      local col = colors.gray
      local apath = fs.combine(cdir, p)
      if fs.isDir(apath) then
        if p == "krakendev" then
          dinfo = "ENGI"
          col = colors.blue
        elseif fs.exists(fs.combine(apath,".cartdata")) then
          dinfo = "Cart"
          col = colors.yellow
        elseif #fs.find(fs.combine(apath,"*.kproj")) > 0 then
          dinfo = "Proj"
          col = colors.purple
        else
          dinfo = "Dir"
          col = colors.green
        end
      end
      term.setTextColor(colors.gray)
      term.write(i == #paths and "\\ " or "| ")
      term.setTextColor(col)
      if p:len() > 12 then
        p = p:sub(1,9) .. "..."
      end
      term.write((p..((" "):rep(12))):sub(1,12))
      term.setTextColor(colors.gray)
      term.write(" | ")
      term.setTextColor(col)
      print(dinfo)
      local cx, cy = term.getCursorPos()
      if i+3 >= theight then
        term.setTextColor(colors.gray)
        term.write("...")
        os.pullEvent("key")
        term.setCursorPos(1,cy)
      end
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
  elseif c == "cp" or c == "copy" then
    assert(#toks == 3, "Invalid arguments (expected 2)")
    local adir = fs.combine(shell.resolve("."), toks[2])
    assert(fs.exists(adir), "Couldn't find source directory.")
    local bdir = fs.combine(shell.resolve("."), toks[3])
    if fs.exists(bdir) then
      term.write("Path exists. Overwrite? [y,N] ")
      local r = read()
      if r == "y" then
        fs.delete(bdir)
      else
        return
      end
    end
    fs.copy(adir,bdir)
    return "Successfully copied directory!"
  elseif c == "delete" or c == "rm" then
    assert(#toks == 2, "Invalid arguments (expected 1)")
    local ndir = fs.combine(shell.resolve("."), toks[2])
    assert(fs.exists(ndir), "File/Directory doesn't exist.")
    fs.delete(ndir)
    local retDir = shell.resolve(".")
    while not fs.exists(retDir) do
      retDir = fs.combine(retDir, "..")
    end
    shell.setDir(retDir)
    return "Successfully deleted!"
  elseif c == "reboot" then
    os.reboot()
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
    elseif toks[2] == "certs" then
      assert(#toks == 2, "Invalid arguments (expected 0)")
      return table.concat(fs.list(fs.combine(api.engineDir,"certs")),", ")
    elseif toks[2] == "fsign" then
      assert(#toks == 5, "Invalid arguments (expected 3)")
      api.provideFileCertificate(toks[3], toks[4], toks[5])
      return string.format("Successfully provided certificate for file '%s'", toks[4])
    elseif toks[2] == "lsign" then
      assert(#toks == 4, "Invalid arguments (expected 2)")
      api.provideFileCertificate(toks[4], toks[3], fs.combine(fs.getDir(toks[3]),toks[4]))
      return string.format("Successfully provided certificate for file '%s'", toks[3])
    elseif toks[2] == "pack" then
      assert(#toks == 4 or #toks == 5, "Invalid arguments (expected 2-3)")
      api.carts.package(toks[3], toks[4], toks[5])
      return string.format("Successfully packed up cart '%s'", toks[4])
    elseif toks[2] == "unpack" then
      assert(#toks == 4 or #toks == 5, "Invalid arguments (expected 2-3)")
      api.carts.unpackage(toks[3], toks[4], toks[5])
      return string.format("Successfully unpacked cart '%s'", toks[3])
    elseif toks[2] == "crun" then
      assert(#toks == 3 or #toks == 4, "Invalid arguments (expected 1-2)")
      api.carts.unpackRun(toks[3], toks[4])
      runCommand("clear")
    elseif toks[2] == "cinfo" then
      assert(#toks == 3, "Invalid arguments (expected 1)")
      return textutils.serialise(api.carts.getInfo(toks[3]))
    elseif toks[2] == nil or toks[2] == "help" then
      local commandInfo = {
        {"kd help","[page]", "Check out all of the different commands"},
        {"kd run",nil,"Runs a project folder"},
        {"kd crun","<cart_dir> [pass]","Unpacks a cart into temp memory before playing it"},
        {"kd pack","<proj_dir> <odir> [pass]","Packages a project file into a cart"},
        {"kd unpack","<cart_dir> <ndir> [pass]","Unpacks a cart into a project file"},
        {"kd cinfo","<cart_dir>","Returns info about the cart from its config"},
        {"kd certs",nil,"Shows all certificates"},
        {"kd fsign","<cert_name> <file> <dest>","Creates a certificate from a file signed with a system certificate"},
        {"kd lsign","<file> <cert_name>","Quickly generates a certificate for a library directory source file"},
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
  term.write(string.format("$kdev/%s> ", shell.resolve(".")):sub(-22))
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
