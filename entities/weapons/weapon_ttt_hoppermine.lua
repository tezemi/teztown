-- traitor equipment: Combine Hopper Mine
--
-- Spawns a native "combine_mine" -- the hopping mine from Highway 17. It's a
-- real compiled entity (present in GMod's own server binary, not borrowed
-- from another game's content like the slam mine's assets are) with its own
-- built-in hop/target/explode AI, so this weapon only has to throw it and
-- manage the arm delay -- the mine handles the rest itself.
--
-- The entity defaults to armed on spawn (StartDisarmed defaults to 0 per its
-- own FGD), and its only exposed input is "InputDisarm" -- no matching "arm"
-- input exists, and writing its internal disarmed flag directly at runtime
-- did not bring it back to life in testing (it likely only reads that flag
-- once, at spawn, to pick an initial AI schedule). So rather than fighting
-- that: the "short throw, then arm" delay is done by throwing a plain
-- physics prop wearing the same model, then swapping it for a real,
-- already-armed combine_mine once it's landed and the delay is up.
--
-- Still unconfirmed without live testing: targeting. Its AI hunts by HL2's
-- NPC faction/relationship system (CLASS_PLAYER), which may or may not
-- "just work" against players in a TTT context without a relationship nudge.

AddCSLuaFile()

SWEP.HoldType               = "grenade"

if CLIENT then
   SWEP.PrintName           = "hoppermine_name"
   SWEP.Slot                = 6

   SWEP.ViewModelFlip       = false
   SWEP.ViewModelFOV        = 54
   SWEP.DrawCrosshair       = false

   SWEP.EquipMenuData = {
      type = "item_weapon",
      desc = "hoppermine_desc"
   };

   SWEP.Icon                = "vgui/ttt/icon_splode"
end

SWEP.Base                   = "weapon_tttbase"

SWEP.Kind                   = WEAPON_EQUIP
SWEP.CanBuy                 = {ROLE_TRAITOR} -- only traitors can buy
SWEP.WeaponID               = AMMO_HOPPERMINE
SWEP.Price                  = 1

SWEP.UseHands                = true
SWEP.ViewModel               = Model("models/weapons/cstrike/c_eq_fraggrenade.mdl")
SWEP.WorldModel              = Model("models/props_combine/combine_mine01.mdl")

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

-- Short toss, not a full grenade-distance throw.
local THROW_SPEED = 300
local ARM_DELAY   = 3

local MINE_MODEL = "models/props_combine/combine_mine01.mdl"

local throwsound = Sound("WeaponFrag.Throw")

if SERVER then
   -- Swaps the thrown placeholder for a real, armed combine_mine wherever
   -- it ended up. Same model, so this is visually seamless.
   local function Arm(dummy, fingerprints, owner)
      if IsValid(dummy) then
         local pos, ang = dummy:GetPos(), dummy:GetAngles()
         dummy:Remove()

         local mine = ents.Create("combine_mine")
         if IsValid(mine) then
            mine:SetPos(pos)
            mine:SetAngles(ang)
            if IsValid(owner) then mine:SetOwner(owner) end
            mine:Spawn()

            mine.fingerprints = fingerprints
            mine.ScoreName = "a Hopper Mine"
            mine.CanHavePrints = true
         end
      end
   end

   function SWEP:ThrowMine()
      local ply = self:GetOwner()
      if not IsValid(ply) then return end

      local spos = ply:GetShootPos()
      local vang = ply:GetAimVector()

      local dummy = ents.Create("prop_physics")
      if not IsValid(dummy) then return end

      dummy:SetModel(MINE_MODEL)
      dummy:SetPos(spos + vang * 16)
      dummy:SetAngles(ply:GetAngles())
      dummy:Spawn()
      dummy:PhysWake()

      local phys = dummy:GetPhysicsObject()
      if IsValid(phys) then
         phys:SetVelocity(vang * THROW_SPEED + ply:GetVelocity())
      end

      -- Captured now rather than read from self inside the timer: the
      -- weapon removes itself right after this call, and relying on a
      -- removed entity's Lua fields still being readable 3 seconds later
      -- isn't something to depend on.
      local fingerprints = self.fingerprints

      timer.Simple(ARM_DELAY, function() Arm(dummy, fingerprints, ply) end)
   end
end

function SWEP:PrimaryAttack()
   self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)

   local ply = self:GetOwner()
   if not IsValid(ply) then return end

   if self.Thrown then return end

   if SERVER then
      self:ThrowMine()

      self.Thrown = true
      self:Remove()

      ply:SetAnimation(PLAYER_ATTACK1)
   end

   self:EmitSound(throwsound)
   self:SendWeaponAnim(ACT_VM_THROW)
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
