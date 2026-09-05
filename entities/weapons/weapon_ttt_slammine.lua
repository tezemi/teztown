-- traitor equipment: SLAM tripwire mine
--
-- Borrows HL2:Deathmatch's SLAM view/world models and sounds (see
-- entities/entities/ttt_slammine.lua for the placed mine itself). Requires
-- HL2:DM content mounted to actually see/hear it -- without it, this is
-- still fully functional, just shows the missing-model placeholder.

AddCSLuaFile()

SWEP.HoldType               = "slam"

if CLIENT then
   SWEP.PrintName           = "slammine_name"
   SWEP.Slot                = 6

   SWEP.ViewModelFlip       = false
   SWEP.ViewModelFOV        = 54
   SWEP.DrawCrosshair       = false

   SWEP.EquipMenuData = {
      type = "item_weapon",
      desc = "slammine_desc"
   };

   SWEP.Icon                = "vgui/ttt/icon_splode"
end

SWEP.Base                   = "weapon_tttbase"

SWEP.Kind                   = WEAPON_EQUIP
-- SWEP.CanBuy              = {ROLE_TRAITOR} -- disabled: remove the CanBuy = nil line and uncomment this to re-enable
SWEP.CanBuy                 = nil
SWEP.WeaponID               = AMMO_SLAMMINE
SWEP.Price                  = 1

SWEP.UseHands                = true
SWEP.ViewModel               = Model("models/weapons/v_slam.mdl")
SWEP.WorldModel              = Model("models/weapons/w_slam.mdl")

SWEP.Primary.ClipSize        = -1
SWEP.Primary.DefaultClip     = -1
SWEP.Primary.Automatic       = false
SWEP.Primary.Ammo            = "none"
SWEP.Primary.Delay           = 1.0

SWEP.Secondary.ClipSize      = -1
SWEP.Secondary.DefaultClip   = -1
SWEP.Secondary.Automatic     = false
SWEP.Secondary.Ammo          = "none"

SWEP.NoSights                = true

local placesound = Sound("Weapon_SLAM.SatchelThrow")

-- Sticks the mine to the first solid surface aimed at, facing straight out
-- along the wall's normal -- same trace-and-orient approach weapon_ttt_c4's
-- BombStick uses.
function SWEP:PrimaryAttack()
   self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)

   local ply = self:GetOwner()
   if not IsValid(ply) then return end

   if self.Placed then return end

   if SERVER then
      local ignore = {ply, self}
      local spos = ply:GetShootPos()
      local epos = spos + ply:GetAimVector() * 80

      local tr = util.TraceLine({start = spos, endpos = epos, filter = ignore, mask = MASK_SOLID})

      if tr.HitWorld then
         local mine = ents.Create("ttt_slammine")
         if IsValid(mine) then
            local ang = tr.HitNormal:Angle()
            ang:RotateAroundAxis(ang:Right(), -90)
            ang:RotateAroundAxis(ang:Up(), 180)

            mine:SetPos(tr.HitPos)
            mine:SetAngles(ang)
            mine:SetOwner(ply)
            mine:SetThrower(ply)
            mine:Spawn()

            mine.fingerprints = self.fingerprints

            self.Placed = true
            self:Remove()
         end
      end

      ply:SetAnimation(PLAYER_ATTACK1)
   end

   self:EmitSound(placesound)
   self:SendWeaponAnim(ACT_VM_SECONDARYATTACK)
end

function SWEP:SecondaryAttack()
end

function SWEP:Reload()
   return false
end

function SWEP:OnRemove()
   if CLIENT and IsValid(self:GetOwner()) and self:GetOwner() == LocalPlayer() and self:GetOwner():Alive() then
      RunConsoleCommand("lastinv")
   end
end
