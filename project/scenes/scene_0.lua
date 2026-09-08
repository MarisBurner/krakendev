local graphics = _ENGINE.graphics
local audio = _ENGINE.audio
local controls = _ENGINE.controls

function Init()
  audio.loadSound("song1","TestBop1.dfpwm")
  audio.loadSound("sfx1","TestSfx1.dfpwm")
end

function Update()
  graphics.flush("#ffffff","#000000")
  graphics.writeAt("Hello, World!",1,1)
  if controls.keyPressed and controls.keys.a then
    audio.playSFX("sfx1")
  end
end
