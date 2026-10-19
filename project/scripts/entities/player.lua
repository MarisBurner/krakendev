local controls = _ENGINE.controls
local vector = _ENGINE.vector
local world = _ENGINE.world

function Init(self)

end

function Update(self, delta)
  if controls.mouseDown then
    self:addImpulse((controls.mouse.pos - self.pos - vector.create2d(2,2)) * 0.75)
  end
end