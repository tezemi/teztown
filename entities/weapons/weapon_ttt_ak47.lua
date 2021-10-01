AddCSLuaFile()

SWEP.HoldType              = "ar2"

if CLIENT then
   SWEP.PrintName          = "AK-47"
   SWEP.Slot               = 2

   SWEP.ViewModelFlip      = false
   SWEP.ViewModelFOV       = 64

   SWEP.Icon               = "vgui/ttt/icon_m16"
   SWEP.IconLetter         = "w"
end

SWEP.Base                  = "weapon_tttbase"

SWEP.Kind                  = WEAPON_HEAVY
SWEP.WeaponID              = AMMO_M16

SWEP.Primary.Delay         = 0.15
SWEP.Primary.Recoil        = 4
SWEP.Primary.Automatic     = true
SWEP.Primary.Ammo          = "Pistol"
SWEP.Primary.Damage        = 20
SWEP.Primary.Cone          = 0.005
SWEP.Primary.ClipSize      = 30
SWEP.Primary.ClipMax       = 90
SWEP.Primary.DefaultClip   = 30
SWEP.Primary.Sound         = Sound( "Weapon_AK47.Single" )

SWEP.AutoSpawnable         = true
SWEP.Spawnable             = true
SWEP.AmmoEnt               = "item_ammo_pistol_ttt"

SWEP.UseHands              = true
SWEP.ViewModel             = "models/weapons/cstrike/c_rif_ak47.mdl"
SWEP.WorldModel            = "models/weapons/w_rif_ak47.mdl"

SWEP.HeadshotMultiplier    = 5

SWEP.IronSightsPos         = Vector(-7.58, -9.2, 0.55)
SWEP.IronSightsAng         = Vector(2.599, -1.3, -3.6)
