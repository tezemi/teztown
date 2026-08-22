-- shared equipment: defibrillator

AddCSLuaFile()

SWEP.HoldType               = "normal"

if CLIENT then
   SWEP.PrintName           = "defib_name"
   SWEP.Slot                = 6

   SWEP.ViewModelFOV        = 10
   SWEP.ViewModelFlip       = false
   SWEP.DrawCrosshair       = false

   SWEP.EquipMenuData = {
      type = "item_weapon",
      desc = "defib_desc"
   };

   SWEP.Icon                = "vgui/ttt/icon_health"
end

SWEP.Base                   = "weapon_tttbase"

SWEP.ViewModel               = Model("models/weapons/v_crowbar.mdl")
SWEP.WorldModel              = Model("models/Items/battery.mdl")

SWEP.Primary.ClipSize        = -1
SWEP.Primary.DefaultClip     = -1
SWEP.Primary.Automatic       = false
SWEP.Primary.Ammo            = "none"
SWEP.Primary.Delay           = 1

SWEP.Secondary.ClipSize      = -1
SWEP.Secondary.DefaultClip   = -1
SWEP.Secondary.Automatic     = false
SWEP.Secondary.Ammo          = "none"

SWEP.Kind                    = WEAPON_EQUIP
SWEP.CanBuy                  = {ROLE_TRAITOR, ROLE_DETECTIVE}
SWEP.WeaponID                = AMMO_DEFIB
SWEP.Price                   = 2

SWEP.LimitedStock            = true -- only buyable once
SWEP.NoSights                = true
SWEP.AllowDrop               = true

SWEP.Range                   = 100

AccessorFuncDT(SWEP, "used", "Used")

function SWEP:SetupDataTables()
   self:DTVar("Bool", 0, "used")

   return self.BaseClass.SetupDataTables(self)
end

CreateConVar("ttt_defib_jolt_delay",   "1.5")
CreateConVar("ttt_defib_revive_delay", "1.5")

local joltsound   = Sound("ambient/energy/spark6.wav")
local revivesound = Sound("buttons/blip2.wav")

if SERVER then
   -- Not tied to the weapon: once the sequence starts, it always finishes,
   -- even if the medic dies, drops the weapon, or disconnects.
   local function DoRevive(rag, medicsid)
      if not IsValid(rag) then return end

      local target = CORPSE.GetPlayer(rag)
      if not IsValid(target) or target:Alive() then
         rag.being_revived = nil
         return
      end

      -- round-flag state that a bare respawn would otherwise wipe
      local credits         = target:GetCredits()
      local equipment_items = target.equipment_items
      local bought          = target.bought
      local kills           = target.kills
      local bomb_wire       = target.bomb_wire
      local radar_charge    = target.radar_charge
      local decoy           = target.decoy

      local pos = rag:GetPos()
      local ang = rag:GetAngles()

      rag:Remove()

      target:SetTeam(TEAM_TERROR)
      target:Spawn()

      target:SetCredits(credits)
      target.equipment_items = equipment_items or EQUIP_NONE
      target.bought          = bought
      target.kills           = kills or {}
      target.bomb_wire       = bomb_wire
      target.radar_charge    = radar_charge or 0
      target.decoy           = decoy

      target:SetPos(pos + Vector(0, 0, 4))
      target:SetAngles(Angle(0, ang.y, 0))
      target:SetEyeAngles(Angle(0, ang.y, 0))
      target:SetHealth(target:GetMaxHealth())

      sound.Play(revivesound, pos, 75, 100)

      local medic = player.GetBySteamID(medicsid)
      if IsValid(medic) then
         LANG.Msg(medic, "defib_used", {player = target:Nick()})
         SCORE:HandleRevive(medic, target)
      end

      LANG.Msg(target, "defib_revived", {player = IsValid(medic) and medic:Nick() or "???"})
   end

   local function DoJolt(rag, medicsid)
      if not IsValid(rag) then return end

      local pos = rag:GetPos()

      sound.Play(joltsound, pos, 75, 100)

      local phys = rag:GetPhysicsObject()
      if IsValid(phys) then
         phys:ApplyForceCenter(VectorRand() * 2500 + Vector(0, 0, 3500))
      end

      timer.Simple(GetConVarNumber("ttt_defib_revive_delay"), function() DoRevive(rag, medicsid) end)
   end

   function SWEP:UseOnCorpse(rag)
      local ply = self:GetOwner()
      if not IsValid(ply) then return end

      local target = CORPSE.GetPlayer(rag)
      if not IsValid(target) or target:Alive() then
         LANG.Msg(ply, "defib_no_target")
         return
      end

      if rag.being_revived then
         LANG.Msg(ply, "defib_already_reviving")
         return
      end

      self:SetUsed(true)
      rag.being_revived = true

      LANG.Msg(ply, "defib_charging")

      timer.Simple(GetConVarNumber("ttt_defib_jolt_delay"), function() DoJolt(rag, ply:SteamID()) end)

      self:Remove()
   end
end

function SWEP:PrimaryAttack()
   self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)

   if self:GetUsed() then return end

   local ply = self:GetOwner()
   if not IsValid(ply) then return end

   local spos = ply:GetShootPos()
   local sdest = spos + (ply:GetAimVector() * self.Range)

   local tr = util.TraceLine({start = spos, endpos = sdest, filter = ply, mask = MASK_SHOT})
   local ent = tr.Entity

   if not (IsValid(ent) and ent:GetClass() == "prop_ragdoll" and ent.player_ragdoll) then
      if SERVER then
         LANG.Msg(ply, "defib_no_target")
      end
      return
   end

   if SERVER then
      self:UseOnCorpse(ent)
   end
end

function SWEP:SecondaryAttack()
end

function SWEP:Reload()
   return false
end

if CLIENT then
   function SWEP:Initialize()
      self:AddHUDHelp("defib_help_primary", nil, true)

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
