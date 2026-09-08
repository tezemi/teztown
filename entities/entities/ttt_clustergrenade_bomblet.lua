---- One of the four submunitions a cluster grenade scatters on detonation.
--
-- Just a smaller, shorter-fused grenade -- ttt_basegrenade_proj already
-- provides the physics (thrown/tumbling model, gravity) and the timer/Think
-- logic that calls Explode() once GetExplodeTime() passes. The parent
-- grenade (ttt_clustergrenade_proj.lua) spawns these, gives each a shove,
-- and sets that timer directly; this file only needs its own model and its
-- own (smaller) blast.

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "ttt_basegrenade_proj"
ENT.Model = Model("models/weapons/w_eq_fraggrenade_thrown.mdl")

local BLAST_RADIUS = 180
local BLAST_DAMAGE = 35

local boomsound = Sound("BaseExplosionEffect.Sound")

function ENT:Explode(tr)
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
   else
      self:SetDetonateExact(0)
   end
end
