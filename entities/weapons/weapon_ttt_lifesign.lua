-- detective equipment: lifesign scanner
--
-- Scans a player into a tracked list. While deployed, shows that list with a
-- live alive/dead status for each. Also plays an alert sound the instant a
-- tracked player dies, even if this weapon isn't the one currently out --
-- the death hook checks every lifesign scanner in every player's inventory,
-- not just the active weapon.

AddCSLuaFile()

SWEP.HoldType              = "normal"

if CLIENT then
   SWEP.PrintName          = "lifesign_name"
   SWEP.Slot               = 8

   SWEP.ViewModelFOV       = 10
   SWEP.DrawCrosshair      = false

   SWEP.EquipMenuData = {
      type = "item_weapon",
      desc = "lifesign_desc"
   };

   SWEP.Icon               = "vgui/ttt/icon_list"
end

SWEP.Base                  = "weapon_tttbase"

SWEP.ViewModel             = "models/weapons/v_crowbar.mdl"
SWEP.WorldModel            = "models/props_lab/reciever01b.mdl"

SWEP.Primary.ClipSize      = -1
SWEP.Primary.DefaultClip   = -1
SWEP.Primary.Automatic     = false
SWEP.Primary.Delay         = 1
SWEP.Primary.Ammo          = "none"

SWEP.Secondary.ClipSize    = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic   = false
SWEP.Secondary.Ammo        = "none"

-- Same slot as the DNA scanner: the two compete for one equip slot, and sit
-- at the same position in the weapon-select wheel.
SWEP.Kind                  = WEAPON_EQUIP2
SWEP.CanBuy                = {ROLE_DETECTIVE}
SWEP.WeaponID               = AMMO_LIFESIGN

SWEP.AutoSpawnable         = false
SWEP.NoSights              = true

SWEP.Range                 = 175

local MAX_TRACKED = 16

local heartbeep = Sound("hl1/fvox/flatline.wav")

if CLIENT then
   local T = LANG.GetTranslation

   local tracked_list = {}

   net.Receive("TTT_LifesignUpdate", function()
      local beep = net.ReadBit() == 1
      local count = net.ReadUInt(8)

      tracked_list = {}
      for i = 1, count do
         local nick = net.ReadString()
         local alive = net.ReadBit() == 1
         table.insert(tracked_list, {nick = nick, alive = alive})
      end

      if beep then
         surface.PlaySound(heartbeep)
      end
   end)

   function SWEP:Initialize()
      self:AddHUDHelp("lifesign_help_primary", nil, true)

      return self.BaseClass.Initialize(self)
   end

   function SWEP:DrawHUD()
      self:DrawHelp()

      -- Crosshair: green over a scannable player, red over anything else
      -- solid, white over nothing. Same style as the DNA scanner's.
      local owner = self:GetOwner()
      local spos = owner:GetShootPos()
      local sdest = spos + (owner:GetAimVector() * self.Range)

      local tr = util.TraceLine({start = spos, endpos = sdest, filter = owner, mask = MASK_SHOT})

      local length = 20
      local gap = 6

      local ent = tr.Entity
      if IsValid(ent) and ent:IsPlayer() then
         surface.SetDrawColor(0, 255, 0, 255)
         gap = 0
      elseif IsValid(ent) then
         surface.SetDrawColor(255, 0, 0, 200)
         gap = 0
      else
         surface.SetDrawColor(255, 255, 255, 200)
      end

      local cx = ScrW() / 2.0
      local cy = ScrH() / 2.0

      surface.DrawLine(cx - length, cy, cx - gap, cy)
      surface.DrawLine(cx + length, cy, cx + gap, cy)
      surface.DrawLine(cx, cy - length, cx, cy - gap)
      surface.DrawLine(cx, cy + length, cx, cy + gap)

      -- Tracked list
      local x = 20
      local y = ScrH() / 2 - ((#tracked_list + 1) * 18) / 2

      draw.SimpleText(T("lifesign_hud_title"), "DefaultBold", x, y, COLOR_WHITE)
      y = y + 20

      for _, entry in ipairs(tracked_list) do
         local clr = entry.alive and Color(80, 220, 80) or Color(220, 60, 60)
         local status = entry.alive and T("lifesign_alive") or T("lifesign_dead")

         draw.SimpleText(entry.nick .. " - " .. status, "DefaultBold", x, y, clr)
         y = y + 18
      end
   end
end

if SERVER then
   function SWEP:SendList(beep)
      local ply = self:GetOwner()
      if not IsValid(ply) then return end

      local list = {}
      for _, data in pairs(self.Tracked or {}) do
         table.insert(list, data)
      end

      net.Start("TTT_LifesignUpdate")
         net.WriteBit(beep)
         net.WriteUInt(#list, 8)
         for _, data in ipairs(list) do
            net.WriteString(data.nick)
            net.WriteBit(data.alive)
         end
      net.Send(ply)
   end

   function SWEP:ScanPlayer(target)
      local ply = self:GetOwner()
      if not IsValid(ply) or not IsValid(target) then return end

      self.Tracked = self.Tracked or {}

      -- Keyed by EntIndex rather than SteamID: bots don't have unique
      -- SteamIDs (they share a placeholder), which was causing every bot
      -- after the first to look like a duplicate scan.
      local idx = target:EntIndex()

      if self.Tracked[idx] then
         LANG.Msg(ply, "lifesign_already", {player = target:Nick()})
         return
      end

      if table.Count(self.Tracked) >= MAX_TRACKED then
         LANG.Msg(ply, "lifesign_limit")
         return
      end

      self.Tracked[idx] = {nick = target:Nick(), alive = target:Alive() and target:IsTerror()}

      LANG.Msg(ply, "lifesign_scanned", {player = target:Nick()})

      self:SendList(false)
   end

   -- Checks every lifesign scanner in every player's inventory, active or
   -- not, so tracked-target deaths are caught even when holstered.
   hook.Add("DoPlayerDeath", "LifesignScanner_DeathAlert", function(victim)
      if not IsValid(victim) then return end

      local idx = victim:EntIndex()

      for _, ply in ipairs(player.GetAll()) do
         for _, wep in ipairs(ply:GetWeapons()) do
            if IsValid(wep) and wep:GetClass() == "weapon_ttt_lifesign" and wep.Tracked then
               local entry = wep.Tracked[idx]
               if entry and entry.alive then
                  entry.alive = false
                  wep:SendList(true)
               end
            end
         end
      end
   end)
end

local beep_miss = Sound("player/suit_denydevice.wav")
function SWEP:PrimaryAttack()
   self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)

   local ply = self:GetOwner()
   if not IsValid(ply) then return end

   local spos = ply:GetShootPos()
   local sdest = spos + (ply:GetAimVector() * self.Range)

   local tr = util.TraceLine({start = spos, endpos = sdest, filter = ply, mask = MASK_SHOT})
   local ent = tr.Entity

   if IsValid(ent) and ent:IsPlayer() then
      if SERVER then
         self:ScanPlayer(ent)
      end
   else
      if CLIENT then
         ply:EmitSound(beep_miss)
      end
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
      self:SendList(false)
   end
   return true
end

if CLIENT then
   function SWEP:DrawWorldModel()
      if not IsValid(self:GetOwner()) then
         self:DrawModel()
      end
   end
end
