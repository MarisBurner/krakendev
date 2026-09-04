-- Start up KrakenDev
local kd = require("krakendev.api")

local suc, err = kd.run("/project")
term.setTextColor(colors.blue)
term.setBackgroundColor(colors.black)
term.setCursorPos(1,1)
term.clear()
print(string.format("%s | %s",suc and "Success!" or "Error!", err))