local lib = {}

assert(_ENGINE.system, "Core Library Missing System Permissions")

local vector = _ENGINE.vector
local world = _ENGINE.world
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

function entitylib.createRigidBody(e)
  e.flags.dophysics = true
  e.pos = vector.create2d(e.transform.pos.x, e.transform.pos.y)
  e.velocity = vector.create2d(0,0)
  e.angularVelocity = 0
  e.velocityScalar = vector.create3d(0.8,0.8)
  e.angularVelocityScalar = 0.8
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
	local l, r, t, b = x-1, x + w - 2, y-1, y + h - 2
	local tl, tr, br, bl = vector.create2d(l, t), vector.create2d(r, t), vector.create2d(r, b), vector.create2d(l, b)
	local points = { tl, tr, br, bl }
	e.hitbox = points
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
  e.velocity = mv + e.velocity
end

function entitylib.collideWith(e1, e2)
	assert(e1.hitbox, "Attempted entity collision with no hitbox.")
	if not e1.absHitbox then
		return
	end
	local mainHitbox = e1.absHitbox
	return world.recurseEntityGet(e2, function(e)
		local hitbox = e.absHitbox
		if not hitbox then
			return
		end
		if lib.polygonsIntersect(mainHitbox, hitbox) then
			return e
		end
	end)
end

lib.tickpriority = 1 -- Right after entity step
function lib.everytick()
  local physEnts = {}
  world.recurseEntity(world.global.sceneEntity,function(e)
    if not e.flags.dophysics then return end
    physEnts[#physEnts+1] = e
  end)
  for i = 1, #physEnts do
    local e = physEnts[i]
    local p = rawget(e, "preset")

		if p.script and p.script.FixedUpdate then
			p.script.FixedUpdate(e, lib.delta)
		end
  end
  for i = 1, #physEnts do
    local e = physEnts[i]
    if e.flags.physics_staticX then
      e.velocity.x = 0
    end
    if e.flags.physics_staticY then
      e.velocity.y = 0
    end
    if e.flags.physics_staticR then
      e.angularVelocity = 0
    end
    e.pos = e.pos + e.velocity
    e.velocity = (e.velocity * e.velocityScalar):trunc(3)
    e.transform.pos.x, e.transform.pos.y = math.floor(e.pos.x), math.floor(e.pos.y)
  end
end

return "physics2d", lib
