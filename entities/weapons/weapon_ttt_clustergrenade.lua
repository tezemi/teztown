-- traitor equipment: cluster grenade

AddCSLuaFile()

SWEP.HoldType           = "grenade"

if CLIENT then
   SWEP.PrintName       = "clustergrenade_name"
   SWEP.Slot            = 3

   SWEP.ViewModelFlip   = false
   SWEP.ViewModelFOV    = 54

   SWEP.EquipMenuData = {
      type = "item_weapon",
      desc = "clustergrenade_desc"
   };

   SWEP.Icon            = "vgui/ttt/icon_nades"
   SWEP.IconLetter      = "K"
end

SWEP.Base               = "weapon_tttbasegrenade"

SWEP.WeaponID           = AMMO_CLUSTERGRENADE
SWEP.Kind               = WEAPON_NADE

SWEP.CanBuy             = {ROLE_TRAITOR}
SWEP.Price              = 2

-- A little quicker than the default 5s grenade fuse
SWEP.detonate_timer     = 4

SWEP.Spawnable          = true
SWEP.AutoSpawnable      = true

SWEP.UseHands           = true
SWEP.ViewModel          = "models/weapons/cstrike/c_eq_fraggrenade.mdl"
SWEP.WorldModel         = "models/weapons/w_eq_fraggrenade.mdl"

SWEP.Weight             = 5

-- really the only difference between grenade weapons: the model and the
-- thrown ent (see ttt_clustergrenade_proj.lua for the split-into-bomblets
-- behaviour).
function SWEP:GetGrenadeName()
   return "ttt_clustergrenade_proj"
end
