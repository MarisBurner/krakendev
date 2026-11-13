local lib = {}

assert(_ENGINE.system, "Core Library Missing System Permissions")

local vector = _ENGINE.vector
local world = _ENGINE.world
local graphics = _ENGINE.graphics
local fgraphics = _ENGINE.globals.graphics
local entitylib = world.entitylib
world.physicslib = lib -- Access to special events

function lib.polygonsIntersect(pointsA, pointsB)
	local axes = {}
	for _, a in ipairs(pointsA) do
		axes[#axes + 1] = a
	end
	for _, a in ipairs(pointsB) do
		axes[#axes + 1] = a
	end

	local function project(points, axisX, axisY)
		local minP, maxP = math.huge, -math.huge
		for _, p in ipairs(points) do
			local d = p.x * axisX + p.y * axisY
			minP = math.min(minP, d)
			maxP = math.max(maxP, d)
		end
		return minP, maxP
	end

	for _, axis in ipairs(axes) do
		local minA, maxA = project(pointsA, axis.x, axis.y)
		local minB, maxB = project(pointsB, axis.x, axis.y)
		if maxA < minB or maxB < minA then
			return false
		end
	end
	return true
end

function lib.oncreate(e)
  -- Entity creation event
  
end

lib.global = {}
local global = lib.global

global.default = {}
global.default.drag = 0.8

function entitylib.createRigidBody(e)
  e.flags.dophysics = true
  e.pos = vector.create2d(e.transform.pos.x, e.transform.pos.y)
  e.rotation = 0
  e.drag = global.default.drag
  e.mass = 1
  e.force = vector.create2d(0,0)
  e.velocity = vector.create2d(0,0)
  e.angularForce = 0
  e.angularVelocity = 0
end

function entitylib.setStatic(e,v)
  e.flags.physics_staticX = v
  e.flags.physics_staticY = v
  e.flags.physics_staticR = v
end

function entitylib.setStaticX(e,v)
  e.flags.physics_staticX = v
end

function entitylib.setStaticY(e,v)
  e.flags.physics_staticY = v
end

function entitylib.setStaticRotation(e,v)
  e.flags.physics_staticR = v
end

function entitylib.addRectHitbox(e, x, y, w, h)
	local vector = _ENGINE.vector
	local l, r, t, b = x, x + w - 1, y, y + h - 1
	local tl, tr, br, bl = vector.create2d(l, t), vector.create2d(r, t), vector.create2d(r, b), vector.create2d(l, b)
	local points = { tl, tr, br, bl }
	e.hitbox = points
end

function entitylib.removeHitbox()
  e.hitbox = nil
end

function entitylib.addImpulse(e,v,y)
  local mv
  if type(y) == "nil" then
    assert(v.isVector and #v == 2,"Impulse expected either a vector2d or two numerical arguments")
    mv = v
  else
    assert(type(v)..type(y) == "numbernumber","Impulse expected either a vector2d or two numerical arguments")
    mv = vector.create2d(v,y)
  end
  e.force = mv + e.force
end

function entitylib.addAngularImpulse(e,v)
  e.angularForce = e.angularForce + v
end

global.fixedTime = 0.3
function lib.fixedStep(physEnts)
  if world.sceneEnv.AfterEntities then
    world.sceneEnv.FixedStep(global.fixedTime)
  end

  for i = 1, #physEnts do
    local e = physEnts[i]
    -- Do physics
    e.velocity = e.velocity * e.drag
    e.velocity = e.velocity + ((e.force / e.mass) * global.fixedTime)

    if e.flags.physics_staticX then
      e.velocity.x = 0
    end
    if e.flags.physics_staticY then
      e.velocity.y = 0
    end
    if e.flags.physics_staticR then
      e.angularVelocity = 0
    end
    e.rotation = e.rotation + (e.angularVelocity * global.fixedTime)
    e.pos = e.pos + (e.velocity * global.fixedTime)

    e.force = vector.create2d()
    e.angularForce = 0
  end

  for i = 1, #physEnts do
    local e = physEnts[i]
    fgraphics.push()
      world.applyAllEntityTransform(e)
      e.absHitbox = graphics.applyAllTrans(e.hitbox) -- Create an absolute hitbox
      e.collisions = {}
    fgraphics.pop()
    for j = 1, #physEnts do
      local e2 = physEnts[i]
      if e2 ~= e then
        
      end
    end
  end

  for i = 1, #physEnts do
    local e = physEnts[i]

    graphics.renderRectPoints(e.absHitbox[1],e.absHitbox[2],e.absHitbox[3],e.absHitbox[4],graphics.createRGBSolidShader(nil,"#ff00ff","/"),1,graphics.gbuffer)

    local p = rawget(e, "preset")
    if p.script and p.script.FixedUpdate then
      p.script.FixedUpdate(e) -- Fixed Step for entity
    end
  end
end

lib.physicsAccumulator = 0 -- Saves up time for each new Fixed Step to calculate
lib.tickpriority = 1 -- Right after entity step
function lib.everytick()
  local physEnts = {}
  world.recurseEntity(world.global.sceneEntity,function(e)
    if not e.flags.dophysics then return end
    physEnts[#physEnts+1] = e
  end)

  lib.physicsAccumulator = lib.physicsAccumulator + world.delta
  while lib.physicsAccumulator > global.fixedTime do
    lib.fixedStep(physEnts)
    lib.physicsAccumulator = lib.physicsAccumulator - global.fixedTime
  end

  for i = 1, #physEnts do
    local e = physEnts[i]
    -- After Physics Loop
    e.transform.pos.x, e.transform.pos.y = math.floor(e.pos.x), math.floor(e.pos.y)
    e.transform.rot = e.rotation
  end
  if world.sceneEnv.AfterEntities then
		world.sceneEnv.AfterPhysics(delta) -- After Physics Update for scene
	end
end

return "physics2d", lib
