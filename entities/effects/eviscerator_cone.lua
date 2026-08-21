-- Fan of laser beams + a flash of light approximating the eviscerator's
-- kill-cone: origin/normal/range/angle are packed into the EffectData by
-- weapon_ttt_eviscerator.lua's FireCone().

local NUM_BEAMS = 10
local LIFETIME  = 0.35

local mat_beam    = Material("cable/physbeam")
local color_beam  = Color(140, 220, 255)

function EFFECT:Init(data)
   self.Origin = data:GetOrigin()
   self.Dir    = data:GetNormal()
   self.Range  = data:GetScale()
   self.Angle  = data:GetMagnitude()

   self.StartTime = CurTime()
   self.EndTime   = self.StartTime + LIFETIME

   local ang = self.Dir:Angle()
   self.Forward = ang:Forward()
   self.Right   = ang:Right()
   self.Up      = ang:Up()

   self.HalfRad = math.rad(self.Angle)

   local rb = self.Range
   self:SetRenderBounds(self.Origin - Vector(rb, rb, rb), self.Origin + Vector(rb, rb, rb))

   local dlight = DynamicLight(self:EntIndex())
   if dlight then
      dlight.pos = self.Origin
      dlight.r, dlight.g, dlight.b = 140, 220, 255
      dlight.brightness = 4
      dlight.decay = 2000
      dlight.size = 300
      dlight.dietime = self.StartTime + 0.3
   end
end

function EFFECT:Think()
   return CurTime() < self.EndTime
end

function EFFECT:Render()
   local frac = (CurTime() - self.StartTime) / LIFETIME
   if frac >= 1 then return end

   local clr = ColorAlpha(color_beam, 255 * (1 - frac))

   render.SetMaterial(mat_beam)

   -- center spike
   render.DrawBeam(self.Origin, self.Origin + self.Dir * self.Range, 6, 0, 1, clr)

   -- fan around the cone's edge
   for i = 0, NUM_BEAMS - 1 do
      local theta = math.rad(i * (360 / NUM_BEAMS))
      local dir = self.Forward * math.cos(self.HalfRad)
                  + (self.Right * math.cos(theta) + self.Up * math.sin(theta)) * math.sin(self.HalfRad)

      render.DrawBeam(self.Origin, self.Origin + dir * self.Range, 4, 0, 1, clr)
   end
end
