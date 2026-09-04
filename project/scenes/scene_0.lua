local graphics = _ENGINE.graphics
local audio = _ENGINE.audio

function Init()
  audio.loadSong("song1","TestBop1.dfpwm")
  audio.loadSFX("sfx1","TestSfx1.dfpwm")
end

function Update()
  graphics.flush("#ffffff","#000000")
  graphics.writeAt("Hello, World!",1,1)
end
