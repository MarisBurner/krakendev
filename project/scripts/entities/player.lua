local controls = _ENGINE.controls
local vector = _ENGINE.vector
local world = _ENGINE.world

function Init(self)

end

function Update(self, delta)
end

function FixedUpdate(self, delta)
  if controls.mouseDown then
    self:addImpulse((controls.mouse.pos - self.pos) * 0.1)
  else
    -- if self:collideWith(world.sceneVars.floor) then
    --   self.transform.pos = self.transform.pos + vector.create2d(1,0)
    -- end
  end
end