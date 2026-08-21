-- traitor equipment: eviscerator
--
-- One-shot cone-of-death weapon. Everyone caught in the blast dies instantly
-- and their body is disintegrated with the same env_entity_dissolver effect
-- HL2 uses for the AR2/Combine Ball's energy kills.

AddCSLuaFile()

SWEP.HoldType              = "ar2"

if CLIENT then
   SWEP.PrintName          = "eviscerator_name"
   SWEP.Slot               = 6

   SWEP.ViewModelFlip      = false
   SWEP.ViewModelFOV       = 54
   SWEP.DrawCrosshair      = false

   SWEP.EquipMenuData = {
      type = "item_weapon",
      desc = "eviscerator_desc"
   };

   SWEP.Icon               = "vgui/ttt/icon_splode"
end

SWEP.Base                  = "weapon_tttbase"

SWEP.ViewModel             = Model("models/weapons/v_irifle.mdl")
SWEP.WorldModel            = Model("models/weapons/w_irifle.mdl")
SWEP.UseHands              = true

SWEP.Primary.ClipSize      = -1
SWEP.Primary.DefaultClip   = -1
SWEP.Primary.Automatic     = false
SWEP.Primary.Ammo          = "none"
SWEP.Primary.Delay         = 1
SWEP.Primary.Sound         = Sound("weapons/ar2/npc_ar2_altfire.wav")

SWEP.Secondary.ClipSize    = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic   = false
SWEP.Secondary.Ammo        = "none"

SWEP.Kind                  = WEAPON_EQUIP2
SWEP.CanBuy                = {ROLE_TRAITOR} -- only traitors can buy
SWEP.WeaponID               = AMMO_EVISCERATOR
SWEP.Price                  = 3

SWEP.LimitedStock           = true -- only buyable once
SWEP.NoSights               = true
SWEP.AllowDrop              = true -- can be handed off before it's used

-- How the kill-cone is shaped: everyone within this range of the muzzle and
-- within this many degrees of dead-center aim, with a clear line of sight,
-- dies. Not a bullet trace, so it can hit multiple people in one blast.
SWEP.ConeRange               = 300
SWEP.ConeAngle               = 25

AccessorFuncDT(SWEP, "used", "Used")

function SWEP:SetupDataTables()
   self:DTVar("Bool", 0, "used")

   return self.BaseClass.SetupDataTables(self)
end

if SERVER then
   -- Gives the corpse the same "vaporized by an energy weapon" look the
   -- Combine Ball uses on its kills.
   local function DissolveRagdoll(rag)
      if not IsValid(rag) then return end

      rag:SetName("eviscerated_" .. rag:EntIndex())

      local dissolver = ents.Create("env_entity_dissolver")
      if not IsValid(dissolver) then return end

      dissolver:SetPos(rag:GetPos())
      dissolver:SetKeyValue("dissolvetype", "0") -- 0 = energy (the AR2/Combine Ball look)
      dissolver:Spawn()
      dissolver:Fire("Dissolve", rag:GetName(), 0)

      SafeRemoveEntityDelayed(dissolver, 5)
   end

   function SWEP:Eviscerate(victim)
      local ply = self:GetOwner()

      local dmginfo = DamageInfo()
      dmginfo:SetDamage(10000)
      dmginfo:SetAttacker(ply)
      dmginfo:SetInflictor(self)
      dmginfo:SetDamageType(DMG_DISSOLVE)
      dmginfo:SetDamageForce((victim:GetPos() - ply:GetPos()):GetNormalized())
      dmginfo:SetDamagePosition(victim:GetPos())

      local effect = EffectData()
      effect:SetOrigin(victim:GetPos())
      effect:SetEntity(victim)
      util.Effect("cball_explode", effect, true, true)

      victim:TakeDamageInfo(dmginfo)

      -- DoPlayerDeath runs synchronously above, so the corpse ragdoll (if
      -- any -- the victim might already have been dead) already exists here
      if IsValid(victim.server_ragdoll) then
         DissolveRagdoll(victim.server_ragdoll)
      end
   end

   function SWEP:FireCone()
      local ply = self:GetOwner()
      if not IsValid(ply) then return end

      local origin = ply:GetShootPos()
      local aimvec = ply:GetAimVector()
      local mincos = math.cos(math.rad(self.ConeAngle))

      local effect = EffectData()
      effect:SetOrigin(origin)
      effect:SetNormal(aimvec)
      effect:SetScale(self.ConeRange)
      effect:SetMagnitude(self.ConeAngle)
      util.Effect("eviscerator_cone", effect, true, true)

      for _, victim in ipairs(player.GetAll()) do
         if IsValid(victim) and victim != ply and victim:IsTerror() and victim:Alive() then
            local targetpos = victim:GetPos() + victim:OBBCenter()
            local diff = targetpos - origin
            local dist = diff:Length()

            if dist > 0 and dist <= self.ConeRange then
               local dir = diff / dist

               if dir:Dot(aimvec) >= mincos then
                  -- only world/props can block the blast, not other players
                  -- standing in front of each other
                  local tr = util.TraceLine({start = origin, endpos = targetpos,
                                              filter = player.GetAll(), mask = MASK_SOLID})

                  if not tr.Hit then
                     self:Eviscerate(victim)
                  end
               end
            end
         end
      end
   end
end

function SWEP:PrimaryAttack()
   self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)

   if self:GetUsed() then return end

   -- runs on both realms, like a normal gunshot, so the firer hears it too
   self:EmitSound(self.Primary.Sound)

   if SERVER then
      self:SetUsed(true)

      self:FireCone()

      self:Remove()
   end
end

function SWEP:SecondaryAttack()
end

function SWEP:Reload()
   return false
end

if CLIENT then
   function SWEP:Initialize()
      self:AddHUDHelp("eviscerator_help_primary", nil, true)

      return self.BaseClass.Initialize(self)
   end
end

function SWEP:ShootEffects() end
