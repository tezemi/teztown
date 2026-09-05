-- Traitor equipment: SLAM tripwire mine.
--
-- Stuck to a wall by weapon_ttt_slammine, facing straight out along the
-- surface normal. After a short arm delay, a laser traces out from its face
-- to wherever it hits solid geometry (or a player first); anyone standing
-- in that beam sets it off. The beam is real and visible to everyone --
-- avoiding it is the counterplay, not detecting it.

AddCSLuaFile()

if CLIENT then
   ENT.PrintName = "slammine_name"
   ENT.Icon = "vgui/ttt/icon_splode"
end

ENT.Type = "anim"
ENT.Model = Model("models/weapons/w_slam.mdl")

ENT.CanHavePrints = true

-- Raw display name for the kill log/death message (see CopyDmg in
-- scoring.lua) -- shown as-is, not run through translation.
ENT.ScoreName = "a Slam Mine"

-- Same split ttt_c4 uses: native Owner for engine-level ownership, Thrower
-- as the dedicated "who to blame for the damage" field.
AccessorFunc(ENT, "thrower", "Thrower")

AccessorFuncDT(ENT, "armed", "Armed")

function ENT:SetupDataTables()
   self:DTVar("Bool", 0, "armed")
end

local ARM_DELAY = 2
local MAX_RANGE = 4096

local DAMAGE = 150
local RADIUS = 300

function ENT:Initialize()
   self:SetModel(self.Model)

   self:SetMoveType(MOVETYPE_NONE)
   self:SetSolid(SOLID_BBOX)
   self:SetCollisionGroup(COLLISION_GROUP_WEAPON)

   if SERVER then
      timer.Simple(ARM_DELAY, function()
         if IsValid(self) then self:SetArmed(true) end
      end)

      self:NextThink(CurTime())
   end
end

-- Traces the beam out along the model's forward direction (set to the
-- wall's normal on placement). MASK_SHOT is what makes this stop on a
-- player crossing it, not just world geometry -- the same mask every
-- hitscan weapon in this codebase already relies on for hitting players.
-- Deterministic given world/player positions, so client and server tracing
-- it separately stay in sync without networking the result.
function ENT:TraceBeam()
   return util.TraceLine({
      start = self:GetPos(),
      endpos = self:GetPos() + self:GetForward() * MAX_RANGE,
      filter = self,
      mask = MASK_SHOT
   })
end

function ENT:BeamEnd()
   return self:TraceBeam().HitPos
end

if SERVER then
   function ENT:Detonate()
      if self.detonated then return end
      self.detonated = true

      local pos = self:GetPos()
      local dmgowner = self:GetThrower()
      dmgowner = IsValid(dmgowner) and dmgowner or self

      util.BlastDamage(self, dmgowner, pos, RADIUS, DAMAGE)

      local effect = EffectData()
      effect:SetOrigin(pos)
      effect:SetScale(RADIUS)
      util.Effect("Explosion", effect)

      sound.Play("c4.explode", pos, 90, 100)

      self:Remove()
   end

   function ENT:Think()
      if self:GetArmed() then
         local ent = self:TraceBeam().Entity

         if IsValid(ent) and ent:IsPlayer() and ent:Alive() and ent:IsTerror() then
            self:Detonate()
            return true
         end
      end

      self:NextThink(CurTime() + 0.05)
      return true
   end
end

if CLIENT then
   local laser_mat = Material("trails/laser")
   local laser_clr = Color(255, 20, 20, 220)

   function ENT:DrawTranslucent()
      self:DrawModel()

      if not self:GetArmed() then return end

      render.SetMaterial(laser_mat)
      render.DrawBeam(self:GetPos(), self:BeamEnd(), 1.5, 0, 4, laser_clr)
   end
end
