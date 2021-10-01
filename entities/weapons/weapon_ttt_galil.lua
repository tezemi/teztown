AddCSLuaFile()

SWEP.HoldType              = "ar2"

if CLIENT then
   SWEP.PrintName          = "IMI Galil"
   SWEP.Slot               = 2

   SWEP.ViewModelFlip      = false
   SWEP.ViewModelFOV       = 64

   SWEP.Icon               = "vgui/ttt/icon_m16"
   SWEP.IconLetter         = "w"
end

SWEP.Base                  = "weapon_tttbase"

SWEP.Kind                  = WEAPON_HEAVY
SWEP.WeaponID              = AMMO_M16

SWEP.Primary.Delay         = 0.08
SWEP.Primary.Recoil        = 1.9
SWEP.Primary.Automatic     = true
SWEP.Primary.Ammo          = "Pistol"
SWEP.Primary.Damage        = 16
SWEP.Primary.Cone          = 0.068
SWEP.Primary.ClipSize      = 35
SWEP.Primary.ClipMax       = 105
SWEP.Primary.DefaultClip   = 35
SWEP.Primary.Sound         = Sound( "Weapon_M4A1.Single" )

SWEP.AutoSpawnable         = true
SWEP.Spawnable             = true
SWEP.AmmoEnt               = "item_ammo_pistol_ttt"

SWEP.UseHands              = true
SWEP.ViewModel             = "models/weapons/cstrike/c_rif_galil.mdl"
SWEP.WorldModel            = "models/weapons/w_rif_galil.mdl"

SWEP.IronSightsPos         = Vector(0.58, -9.2, 0.55)
SWEP.IronSightsAng         = Vector(2.599, 5.3, 5.6)