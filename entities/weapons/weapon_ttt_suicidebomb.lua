-- traitor equipment: suicide bomb

AddCSLuaFile()

SWEP.HoldType               = "slam"

if CLIENT then
   SWEP.PrintName           = "suicidebomb_name"
   SWEP.Slot                = 6

   SWEP.ViewModelFlip       = false
   SWEP.ViewModelFOV        = 54
   SWEP.DrawCrosshair       = false

   SWEP.EquipMenuData = {
      type = "item_weapon",
      desc = "suicidebomb_desc"
   };

   SWEP.Icon                = "vgui/ttt/icon_c4"
end

SWEP.Base                   = "weapon_tttbase"

SWEP.Kind                   = WEAPON_EQUIP2
SWEP.CanBuy                 = {ROLE_TRAITOR} -- only traitors can buy
SWEP.WeaponID               = AMMO_SUICIDEBOMB

SWEP.UseHands                = true
SWEP.ViewModel               = Model("models/weapons/cstrike/c_c4.mdl")
SWEP.WorldModel              = Model("models/weapons/w_c4.mdl")

SWEP.Primary.ClipSize        = -1
SWEP.Primary.DefaultClip     = -1
SWEP.Primary.Automatic       = false
SWEP.Primary.Ammo            = "none"
SWEP.Primary.Delay           = 1

SWEP.Secondary.ClipSize      = -1
SWEP.Secondary.DefaultClip   = -1
SWEP.Secondary.Automatic     = false
SWEP.Secondary.Ammo          = "none"

SWEP.NoSights                = true
SWEP.AllowDrop               = false -- once you're wearing it, it's yours

AccessorFuncDT(SWEP, "armed", "Armed")

function SWEP:SetupDataTables()
   self:DTVar("Bool", 0, "armed")

   return self.BaseClass.SetupDataTables(self)
end

CreateConVar("ttt_suicidebomb_delay",  "3")
CreateConVar("ttt_suicidebomb_radius", "400")
CreateConVar("ttt_suicidebomb_damage", "300")

local armsound = Sound("ttt/kirk.wav")
local boomsound = Sound("c4.explode")

-- Custom content sounds only resolve reliably clientside in this gamemode, so
-- the server tells clients to play it themselves rather than emitting it.
-- Emitted on the bomber so it tracks them as they move.
if CLIENT then
   net.Receive("TTT_SuicideBombArm", function()
                                        local ply = net.ReadEntity()
                                        if IsValid(ply) then
                                           ply:EmitSound(armsound, 100, 100)
                                        end
                                     end)
end

function SWEP:PrimaryAttack()
   self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)

   if self:GetArmed() then return end

   if SERVER then
      self:SetArmed(true)

      local ply = self:GetOwner()
      if IsValid(ply) then
         net.Start("TTT_SuicideBombArm")
            net.WriteEntity(ply)
         net.Broadcast()

         LANG.Msg(ply, "suicidebomb_armed")
      end

      timer.Simple(GetConVarNumber("ttt_suicidebomb_delay"), function() self:Detonate() end)
   end
end

function SWEP:SecondaryAttack()
end

if SERVER then
   function SWEP:Detonate()
      if not IsValid(self) then return end

      local ply = self:GetOwner()
      if IsValid(ply) then
         local pos = ply:GetPos() + ply:OBBCenter()
         local radius = GetConVarNumber("ttt_suicidebomb_radius")

         util.BlastDamage(self, ply, pos, radius, GetConVarNumber("ttt_suicidebomb_damage"))

         local effect = EffectData()
         effect:SetStart(pos)
         effect:SetOrigin(pos)
         effect:SetScale(radius)
         effect:SetRadius(radius)
         effect:SetMagnitude(GetConVarNumber("ttt_suicidebomb_damage"))
         util.Effect("Explosion", effect, true, true)

         sound.Play(boomsound, pos, 100, 100)
      end

      self:Remove()
   end
end

function SWEP:Reload()
   return false
end

if CLIENT then
   function SWEP:Initialize()
      self:AddHUDHelp("suicidebomb_help_primary", nil, true)

      return self.BaseClass.Initialize(self)
   end
end

function SWEP:Deploy()
   if SERVER and IsValid(self:GetOwner()) then
      self:GetOwner():DrawViewModel(false)
   end

   return true
end

function SWEP:ShootEffects() end
