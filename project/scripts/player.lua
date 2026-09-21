local controls = _ENGINE.controls
local vector = _ENGINE.vector
local world = _ENGINE.world

function Init(self)

end

function Update(self,delta)
  self.transform.pos = vector.create2d(controls.mouse.x,controls.mouse.y)
  self.rtransform.rot = self.rtransform.rot + (math.rad(5) * delta)
end