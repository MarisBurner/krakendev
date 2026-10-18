local graphics = _ENGINE.graphics
local audio = _ENGINE.audio
local world = _ENGINE.world
local vector = _ENGINE.vector
local utils = _ENGINE.utils

local player

function DataInit()
	-- Sounds
	-- audio.loadSound("song1","TestBop1.dfpwm")
	-- audio.loadSound("sfx1","TestSfx1.dfpwm")
	-- Images
	graphics.loadImage("test", "Test.ttbl", "tiletable")
	graphics.loadImage("player", "Player.ttbl", "tiletable")
	graphics.loadImage("sword", "Sword.ttbl", "tiletable")
	-- Object Presets
	world.loadPreset("player", "player.kobj")
	world.loadPreset("block", "block.kobj")
	world.loadPreset("sword", "sword.kobj")
end

function Init()
	-- ANB16 Color Pallete
	graphics.loadColorPalette({
		"#0a080d",
		"#697594",
		"#dfe9f5",
		"#f7aaa8",
		"#d4689a",
		"#782c96",
		"#e83562",
		"#f2825c",
		"#ffc76e",
		"#88c44d",
		"#3f9e59",
		"#373461",
		"#4854a8",
		"#7199d9",
		"#9e5252",
		"#4d2536",
	})
	player = world.createEntity(
		world.createTransform(nil, vector.create2d(1, 1)),
		world.createTransform(
			nil,
			vector.create2d(5, 5) -- Object Render Size
		),
		"player"
	)
	player:createRigidBody()
	player:addRectHitbox(1, 1, 5, 5)

	player:addChild(world.createEntity(
		world.createTransform(vector.create3d(6, 1)),
		world.createTransform(
			nil,
			vector.create2d(5, 5) -- Object Render Size
		),
		"sword"
	))
	world.sceneEntity:addChild(player)

	world.sceneVars.floor = world.createEntity(
		world.createTransform(vector.create3d(10, 10)),
		world.createTransform(
			nil,
			vector.create2d(5, 5) -- Object Render Size
		),
		"block"
	)
	world.sceneVars.floor:createRigidBody()
	--world.sceneVars.floor:setStatic(true)
	world.sceneVars.floor:addRectHitbox(1, 1, 5, 5)
	world.sceneEntity:addChild(world.sceneVars.floor)
end

function Update(delta)
	graphics.flush("#8888ff", "#000000")
	graphics.writeAt(string.format("fps %s | delta %s",utils.trunc(world.fps,1),delta), 1, 1)
	graphics.writeAt(player.velocity, 1, 2)
end
