-- Traitor Tester Part: carried, droppable, one per player.
--
-- Spawned around the map in place of ordinary loot (gamemode/testerparts.lua).
-- Carrying one does nothing on its own -- the holders have to bring every
-- part into one place, which outs a random living traitor to everyone.

AddCSLuaFile()

SWEP.HoldType              = "normal"

if CLIENT then
   SWEP.PrintName          = "tester_part_name"
   SWEP.Slot               = 2

   SWEP.ViewModelFOV       = 10
   SWEP.DrawCrosshair      = false

   SWEP.EquipMenuData = {
      type = "item_weapon",
      desc = "tester_part_desc"
   };

   SWEP.Icon               = "vgui/ttt/icon_cse"
end

SWEP.Base                  = "weapon_tttbase"

SWEP.ViewModel             = "models/weapons/v_crowbar.mdl"
SWEP.WorldModel            = "models/props_lab/reciever01b.mdl"

SWEP.Primary.ClipSize      = -1
SWEP.Primary.DefaultClip   = -1
SWEP.Primary.Automatic     = false
SWEP.Primary.Ammo          = "none"

SWEP.Secondary.ClipSize    = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic   = false
SWEP.Secondary.Ammo        = "none"

-- Takes your primary slot: carrying a part means giving up your gun, and you
-- can only ever hold one. Picking one up tosses whatever primary you had
-- (see Equip below) rather than being refused like a normal full slot.
SWEP.Kind                  = WEAPON_HEAVY
SWEP.WeaponID              = AMMO_TESTERPART

SWEP.AutoSpawnable         = false
SWEP.NoSights              = true
SWEP.AllowDrop             = true

if SERVER then
   function SWEP:Initialize()
      -- Traitors are meant to see parts anywhere on the map, and a halo can
      -- only draw an entity the client actually has. Force this one to be
      -- networked regardless of PVS.
      self:AddEFlags(EFL_FORCE_CHECK_TRANSMIT)

      return self.BaseClass.Initialize(self)
   end

   function SWEP:UpdateTransmitState()
      return TRANSMIT_ALWAYS
   end

   function SWEP:Equip(newowner)
      if not (IsValid(newowner) and newowner:IsPlayer()) then return end

      -- Remembered for destruction blame: a part a traitor was carrying that
      -- ends up in a hurt trigger is still on the traitor.
      self.held_by_traitor = newowner:IsTraitor()

      -- Credit for helping assemble the set later, even if they drop this
      -- (or it gets taken) before that actually happens.
      TESTERPARTS.RecordHolder(newowner)

      LANG.Msg(newowner, "tester_part_picked")

      if self.held_by_traitor then
         -- Upfront cost for grabbing one at all, on top of the periodic
         -- drain (gamemode/testerparts.lua) for however long they hold it.
         TESTERPARTS.DrainTraitor(newowner)
      end

      -- Make room in the primary slot. Deferred a frame so we're clear of
      -- the engine's pickup handling before touching their inventory.
      local ply = newowner
      timer.Simple(0, function()
         if not IsValid(ply) or not IsValid(self) then return end

         for _, wep in ipairs(ply:GetWeapons()) do
            if IsValid(wep) and wep != self and wep.Kind == WEAPON_HEAVY then
               WEPS.DropNotifiedWeapon(ply, wep, false)
            end
         end
      end)
   end
end

if CLIENT then
   function SWEP:Initialize()
      self:AddHUDHelp("tester_part_help", nil, true)

      return self.BaseClass.Initialize(self)
   end

   function SWEP:DrawHUD()
      self:DrawHelp()
   end

   function SWEP:DrawWorldModel()
      if not IsValid(self:GetOwner()) then
         self:DrawModel()
      end
   end
end

function SWEP:PrimaryAttack() end
function SWEP:SecondaryAttack() end

function SWEP:Reload()
   return false
end

function SWEP:Deploy()
   if SERVER and IsValid(self:GetOwner()) then
      self:GetOwner():DrawViewModel(false)
   end

   return true
end
