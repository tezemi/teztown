---- The cluster grenade's main body.
--
-- Thrown and fused exactly like any other ttt_basegrenade_proj. On
-- detonation it does a normal (if middling) grenade blast, then scatters
-- four ttt_clustergrenade_bomblet submunitions outward, each of which goes
-- off shortly after on its own short fuse -- a second, smaller wave of
-- explosions right as anyone who dove clear of the first one lands.

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "ttt_basegrenade_proj"
ENT.Model = Model("models/weapons/w_eq_fraggrenade_thrown.mdl")

local BLAST_RADIUS = 300
local BLAST_DAMAGE = 60

local BOMBLET_COUNT = 4
local BOMBLET_SPEED = 350
local BOMBLET_FUSE_MIN = 0.6
local BOMBLET_FUSE_MAX = 1.0

local boomsound = Sound("BaseExplosionEffect.Sound")

local function ScatterBomblets(pos, dmgowner)
   for i = 1, BOMBLET_COUNT do
      local bomblet = ents.Create("ttt_clustergrenade_bomblet")
      if IsValid(bomblet) then
         bomblet:SetPos(pos)
         bomblet:SetOwner(dmgowner)
         bomblet:SetThrower(dmgowner)
         bomblet:Spawn()
         bomblet:PhysWake()

         -- Spread the four out roughly evenly, with some randomness so they
         -- don't land in a perfectly even ring every time, and toss them up
         -- and out rather than skimming along the floor.
         local yaw = (360 / BOMBLET_COUNT) * i + math.random(-25, 25)
         local dir = Angle(0, yaw, 0):Forward()
         dir.z = math.Rand(0.4, 0.8)
         dir:Normalize()

         local phys = bomblet:GetPhysicsObject()
         if IsValid(phys) then
            phys:SetVelocity(dir * BOMBLET_SPEED)
         end

         bomblet:SetDetonateExact(CurTime() + math.Rand(BOMBLET_FUSE_MIN, BOMBLET_FUSE_MAX))
      end
   end
end

function ENT:Explode(tr)
   hook.Call("TTTClusterGrenadeExplode", nil, self)

   if SERVER then
      self:SetNoDraw(true)
      self:SetSolid(SOLID_NONE)

      -- pull out of the surface
      if tr.Fraction != 1.0 then
         self:SetPos(tr.HitPos + tr.HitNormal * 0.6)
      end

      local pos = self:GetPos()
      local dmgowner = self:GetThrower()
      dmgowner = IsValid(dmgowner) and dmgowner or self

      -- self is the inflictor, so deal damage before removing it
      util.BlastDamage(self, dmgowner, pos, BLAST_RADIUS, BLAST_DAMAGE)

      self:Remove()

      local effect = EffectData()
      effect:SetStart(pos)
      effect:SetOrigin(pos)
      effect:SetScale(BLAST_RADIUS)
      effect:SetRadius(BLAST_RADIUS)
      effect:SetMagnitude(BLAST_DAMAGE)
      if tr.Fraction != 1.0 then
         effect:SetNormal(tr.HitNormal)
      end

      util.Effect("Explosion", effect, true, true)

      sound.Play(boomsound, pos, 100, 100)

      ScatterBomblets(pos, dmgowner)
   else
      self:SetDetonateExact(0)
   end
end
