local graphics = _ENGINE.graphics
local audio = _ENGINE.audio
local world = _ENGINE.world
local controls = _ENGINE.controls
local vector = _ENGINE.vector

local player

function DataInit()
  -- Sounds
  audio.loadSound("song1","TestBop1.dfpwm")
  audio.loadSound("sfx1","TestSfx1.dfpwm")
  -- Images
  graphics.loadImage("test","Test.ttbl","tiletable")
  graphics.loadImage("player","Player.ttbl","tiletable")
  graphics.loadImage("sword","Sword.ttbl","tiletable")
  -- Object Presets
  world.loadPreset("player","player.kobj")
  world.loadPreset("block","block.kobj")
end

function Init()
  player = world.createEntity(
    world.createTransform(
      nil,
      vector.create2d(1.5,1.5)
    ),
    world.createTransform(
      nil,
      vector.create2d(5,5) -- Object Render Size
    ),
  "player")
  
  player:addChild(
    world.createEntity(
      world.createTransform(
        vector.create3d(6,1)
      ),
      world.createTransform(
        nil,
        vector.create2d(5,5) -- Object Render Size
      ),
    "block")
  )
  world.sceneEntity:addChild(player)
end

function Update(delta)
  graphics.flush("#8888ff","#000000")
  graphics.writeAt(world.fps,1,1)


end
