-- traitor equipment: silenced sniper rifle
--
-- Based on weapon_tttbase directly (NOT weapon_ttt_g3sg1) -- the scope/zoom
-- code below is copied from weapon_ttt_g3sg1. Basing this off g3sg1 instead
-- would be neater, but g3sg1's PrimaryAttack and DrawHUD both call
-- self.BaseClass.<same function>(...); self.BaseClass here would resolve to
-- g3sg1 itself rather than weapon_tttbase, so those calls would recurse into
-- themselves forever. DrawHUD runs every frame a weapon is active, so that
-- crashed the game the instant the weapon was deployed.

AddCSLuaFile()

SWEP.HoldType              = "ar2"

if CLIENT then
   SWEP.PrintName          = "sisniper_name"
   SWEP.Slot               = 2

   SWEP.ViewModelFlip      = false
   SWEP.ViewModelFOV       = 54

   SWEP.EquipMenuData = {
      type = "item_weapon",
      desc = "sisniper_desc"
   };

   SWEP.Icon               = "vgui/ttt/icon_silenced"
end

SWEP.Base                  = "weapon_tttbase"

SWEP.Kind                  = WEAPON_EQUIP
SWEP.CanBuy                = {ROLE_TRAITOR} -- only traitors can buy
SWEP.WeaponID               = AMMO_SISNIPER
SWEP.Price                  = 2

-- Suppressed: no death sound from the victim, plus the silenced USP's shot
-- sound/level (there's no dedicated silenced sniper sound in the base
-- content, unlike the USP, so this borrows weapon_ttt_sipistol's directly).
SWEP.IsSilent               = true

-- Hits much harder than the base G3SG1, but as a slow, precise, low-capacity
-- single shot rather than its semi-auto spray.
SWEP.Primary.Delay         = 1.3
SWEP.Primary.Recoil        = 2
SWEP.Primary.Automatic     = false
SWEP.Primary.Ammo          = "357"
SWEP.Primary.Damage        = 75
SWEP.Primary.Cone          = 0.001
SWEP.Primary.ClipSize      = 5
SWEP.Primary.ClipMax       = 15
SWEP.Primary.DefaultClip   = 5
SWEP.Primary.Sound         = Sound("Weapon_USP.SilencedShot")
SWEP.Primary.SoundLevel    = 50

SWEP.Secondary.Sound       = Sound("Default.Zoom")

-- Not a map-spawnable rifle, this is bought exclusively
SWEP.AutoSpawnable          = false
SWEP.Spawnable              = false
SWEP.AmmoEnt                = "item_ammo_357_ttt"

SWEP.UseHands              = true
SWEP.ViewModel             = Model("models/weapons/cstrike/c_snip_g3sg1.mdl")
SWEP.WorldModel            = Model("models/weapons/w_snip_g3sg1.mdl")

SWEP.IronSightsPos         = Vector( 5, -15, -2 )
SWEP.IronSightsAng         = Vector( 2.6, 1.37, 3.5 )

function SWEP:SetZoom(state)
   if IsValid(self:GetOwner()) and self:GetOwner():IsPlayer() then
      if state then
         self:GetOwner():SetFOV(20, 0.3)
      else
         self:GetOwner():SetFOV(0, 0.2)
      end
   end
end

function SWEP:PrimaryAttack( worldsnd )
   self.BaseClass.PrimaryAttack( self.Weapon, worldsnd )
   self:SetNextSecondaryFire( CurTime() + 0.1 )
end

-- Add some zoom to ironsights for this gun
function SWEP:SecondaryAttack()
   if not self.IronSightsPos then return end
   if self:GetNextSecondaryFire() > CurTime() then return end

   local bIronsights = not self:GetIronsights()

   self:SetIronsights( bIronsights )

   self:SetZoom(bIronsights)
   if (CLIENT) then
      self:EmitSound(self.Secondary.Sound)
   end

   self:SetNextSecondaryFire( CurTime() + 0.3)
end

function SWEP:PreDrop()
   self:SetZoom(false)
   self:SetIronsights(false)
   return self.BaseClass.PreDrop(self)
end

function SWEP:Reload()
   if ( self:Clip1() == self.Primary.ClipSize or self:GetOwner():GetAmmoCount( self.Primary.Ammo ) <= 0 ) then return end
   self:DefaultReload( ACT_VM_RELOAD )
   self:SetIronsights( false )
   self:SetZoom( false )
end

function SWEP:Holster()
   self:SetIronsights(false)
   self:SetZoom(false)
   return true
end

-- We were bought as special equipment, give a bit of extra ammo
function SWEP:WasBought(buyer)
   if IsValid(buyer) then
      buyer:GiveAmmo(10, "357")
   end
end

if CLIENT then
   local scope = surface.GetTextureID("sprites/scope")
   function SWEP:DrawHUD()
      if self:GetIronsights() then
         surface.SetDrawColor( 0, 0, 0, 255 )

         local scrW = ScrW()
         local scrH = ScrH()

         local x = scrW / 2.0
         local y = scrH / 2.0
         local scope_size = scrH

         -- crosshair
         local gap = 80
         local length = scope_size
         surface.DrawLine( x - length, y, x - gap, y )
         surface.DrawLine( x + length, y, x + gap, y )
         surface.DrawLine( x, y - length, x, y - gap )
         surface.DrawLine( x, y + length, x, y + gap )

         gap = 0
         length = 50
         surface.DrawLine( x - length, y, x - gap, y )
         surface.DrawLine( x + length, y, x + gap, y )
         surface.DrawLine( x, y - length, x, y - gap )
         surface.DrawLine( x, y + length, x, y + gap )


         -- cover edges
         local sh = scope_size / 2
         local w = (x - sh) + 2
         surface.DrawRect(0, 0, w, scope_size)
         surface.DrawRect(x + sh - 2, 0, w, scope_size)

         -- cover gaps on top and bottom of screen
         surface.DrawLine( 0, 0, scrW, 0 )
         surface.DrawLine( 0, scrH - 1, scrW, scrH - 1 )

         surface.SetDrawColor(255, 0, 0, 255)
         surface.DrawLine(x, y, x + 1, y + 1)

         -- scope
         surface.SetTexture(scope)
         surface.SetDrawColor(255, 255, 255, 255)

         surface.DrawTexturedRectRotated(x, y, scope_size, scope_size, 0)
      else
         return self.BaseClass.DrawHUD(self)
      end
   end

   function SWEP:AdjustMouseSensitivity()
      return (self:GetIronsights() and 0.2) or nil
   end
end
