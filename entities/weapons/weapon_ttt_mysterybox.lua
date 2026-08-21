-- shared equipment: mystery box
--
-- Throws a crate that breaks open after a short delay and spawns something
-- from the pool of outcomes registered in gamemode/mysterybox.lua (see that
-- file to add more outcomes -- this weapon doesn't know or care what's in
-- the pool, it just tells MYSTERYBOX to pick one).

AddCSLuaFile()

SWEP.HoldType              = "normal"

if CLIENT then
   SWEP.PrintName          = "mysterybox_name"
   SWEP.Slot               = 6

   SWEP.ViewModelFOV       = 54
   SWEP.ViewModelFlip      = false
   SWEP.DrawCrosshair      = false

   SWEP.EquipMenuData = {
      type = "item_weapon",
      desc = "mysterybox_desc"
   };

   SWEP.Icon               = "vgui/ttt/icon_nades"
end

SWEP.Base                  = "weapon_tttbase"

SWEP.ViewModel             = Model("models/weapons/v_slam.mdl")
SWEP.WorldModel            = Model("models/weapons/w_slam.mdl")

SWEP.Primary.ClipSize      = -1
SWEP.Primary.DefaultClip   = -1
SWEP.Primary.Automatic     = false
SWEP.Primary.Ammo          = "none"
SWEP.Primary.Delay         = 1

SWEP.Secondary.ClipSize    = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic   = false
SWEP.Secondary.Ammo        = "none"

SWEP.Kind                  = WEAPON_EQUIP2
SWEP.CanBuy                = {ROLE_TRAITOR, ROLE_DETECTIVE}
SWEP.Price                 = 2
SWEP.WeaponID               = AMMO_MYSTERYBOX

SWEP.NoSights               = true
SWEP.AllowDrop              = true -- can be handed off before it's thrown

AccessorFuncDT(SWEP, "used", "Used")

function SWEP:SetupDataTables()
   self:DTVar("Bool", 0, "used")

   return self.BaseClass.SetupDataTables(self)
end

CreateConVar("ttt_mysterybox_delay", "4")

if SERVER then
   -- TODO: not confirmed to exist in this mod's mounted content, same
   -- caveat as the baby doll placeholder in mysterybox.lua -- swap if it
   -- turns out to be an error/checkerboard model or a silent sound.
   local crate_model = "models/props_junk/wood_crate001a.mdl"
   local break_sound = Sound("physics/wood/wood_crate_break1.wav")

   local wood_gib_models = {
      "models/gibs/wood_gib01a.mdl",
      "models/gibs/wood_gib01b.mdl",
      "models/gibs/wood_gib01c.mdl",
      "models/gibs/wood_gib01d.mdl",
      "models/gibs/wood_gib01e.mdl"
   }

   -- Neither Fire("Break") nor the BreakModel effect actually produced gibs
   -- for the crate model (it likely has no compiled break/gib data), so this
   -- fakes the shatter manually with real wood debris chunks instead, flung
   -- outward and cleaned up after a few seconds.
   local function SpawnFakeGibs(pos)
      for i = 1, 6 do
         local chunk = ents.Create("prop_physics")
         if IsValid(chunk) then
            chunk:SetModel(table.Random(wood_gib_models))
            chunk:SetPos(pos)
            chunk:SetAngles(VectorRand():Angle())
            chunk:Spawn()
            chunk:Activate()

            local phys = chunk:GetPhysicsObject()
            if IsValid(phys) then
               phys:Wake()
               phys:SetVelocity(VectorRand() * 250 + Vector(0, 0, 150))
               phys:AddAngleVelocity(VectorRand() * 500)
            end

            SafeRemoveEntityDelayed(chunk, 4)
         end
      end
   end

   function SWEP:ThrowBox(ply)
      local spos = ply:GetShootPos()
      local aimvec = ply:GetAimVector()

      local crate = ents.Create("prop_physics")
      if not IsValid(crate) then return end

      crate:SetModel(crate_model)
      crate:SetPos(spos + aimvec * 40)
      crate:SetAngles(ply:EyeAngles())
      crate:Spawn()
      crate:Activate()
      crate:SetModelScale(0.5, 0)

      local phys = crate:GetPhysicsObject()
      if IsValid(phys) then
         phys:Wake()
         phys:SetVelocity(aimvec * 300 + Vector(0, 0, 50))
      end

      timer.Simple(GetConVarNumber("ttt_mysterybox_delay"), function()
         if not IsValid(crate) then return end

         local pos = crate:GetPos()
         local ang = crate:GetAngles()

         sound.Play(break_sound, pos, 75, 100)
         SpawnFakeGibs(pos)

         crate:Remove()

         MYSTERYBOX.SpawnRandom(pos, ang, ply)
      end)
   end
end

function SWEP:PrimaryAttack()
   self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)

   if self:GetUsed() then return end

   if SERVER then
      self:SetUsed(true)

      local ply = self:GetOwner()
      if IsValid(ply) then
         self:ThrowBox(ply)
      end

      self:Remove()
   end
end

function SWEP:SecondaryAttack()
end

function SWEP:Reload()
   return false
end

function SWEP:Deploy()
   if SERVER and IsValid(self:GetOwner()) then
      self:GetOwner():DrawViewModel(false)
   end
   return true
end

if CLIENT then
   function SWEP:Initialize()
      self:AddHUDHelp("mysterybox_help_primary", nil, true)

      return self.BaseClass.Initialize(self)
   end
end
