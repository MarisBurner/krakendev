local graphics = _ENGINE.graphics
local audio = _ENGINE.audio
local world = _ENGINE.world
local controls = _ENGINE.controls
local vector = _ENGINE.vector

function Init()
  audio.loadSound("song1","TestBop1.dfpwm")
  audio.loadSound("sfx1","TestSfx1.dfpwm")
  graphics.loadImage("test","Test.ttbl","tiletable")
end

local a = 0
function Update(delta)
  graphics.flush("#ffffff","#000000")
  graphics.writeAt(delta,1,1)
  a = a + (math.rad(5) * delta)
  graphics.push()
    graphics.centerRect(5,5)
    graphics.translate(15,10)
    graphics.image(0,0,5,5,"test")
  graphics.pop()

  graphics.push()
    graphics.centerRect(5,5)
    graphics.rotate(a)
    graphics.translate(10,10)
    graphics.image(0,0,5,5,"test")
  graphics.pop()
end
