---- Traitor Tester Parts: an optional objective for the innocent side.
--
-- When enabled, a handful of the items that spawned around the map are
-- swapped for weapon_ttt_tester_part at the start of each round. How many
-- scales with the number of non-traitors playing. A player can carry one
-- part at a time and can drop it.
--
-- The set doesn't complete on pickup: every part has to end up in the same
-- place at the same time, with someone on the innocent side standing there
-- to put it together. That means the holders have to physically meet up,
-- which is the risky part. Assembling it immediately outs a random living
-- traitor to the whole server.
--
-- Traitors see loose parts through walls at any range (cl_testerparts.lua)
-- and can carry one themselves to keep it away from the meeting point.
--
-- Progress is published as globals so any client can draw it:
--   ttt_tester_parts_total, ttt_tester_parts_held

TESTERPARTS = TESTERPARTS or {}

local PART_CLASS = "weapon_ttt_tester_part"
local ASSEMBLE_TIMER = "TesterParts_Assemble"

-- How often the assembly check, traitor credit drain and hurt-trigger scan
-- all run.
local TICK = 0.5

local enabled     = CreateConVar("ttt_tester_parts_enabled", "0", FCVAR_NOTIFY)
local per_inno    = CreateConVar("ttt_tester_parts_per_innocent", "0.5", FCVAR_NOTIFY)
local max_parts   = CreateConVar("ttt_tester_parts_max", "6", FCVAR_NOTIFY)
local assemble_range = CreateConVar("ttt_tester_assemble_range", "400", FCVAR_NOTIFY)

-- Traitors bleed a credit per this many seconds of carrying a part, and once
-- broke start losing equipment instead. Hold time accumulates on the player,
-- so dropping the part just before a tick doesn't dodge the cost.
local drain_time  = CreateConVar("ttt_tester_part_drain_time", "30", FCVAR_NOTIFY)
local part_health = CreateConVar("ttt_tester_part_health", "50", FCVAR_NOTIFY)

function TESTERPARTS.IsEnabled() return enabled:GetBool() end

local function SetProgress(held, total)
   SetGlobalInt("ttt_tester_parts_held", held)
   SetGlobalInt("ttt_tester_parts_total", total)
end

local function FindParts()
   local out = {}
   for _, wep in ipairs(ents.FindByClass(PART_CLASS)) do
      if IsValid(wep) then
         table.insert(out, wep)
      end
   end

   return out
end

-- Where a part effectively is: on its carrier, or where it's lying.
local function PartPos(wep)
   local owner = wep:GetOwner()

   return IsValid(owner) and owner:GetPos() or wep:GetPos()
end

local function SpawnPart(pos, ang)
   local part = ents.Create(PART_CLASS)
   if not IsValid(part) then return nil end

   part:SetPos(pos)
   if ang then part:SetAngles(ang) end
   part:Spawn()
   part:PhysWake()

   -- Equipment that hasn't been "dropped" gets picked up just by walking over
   -- it. Picking up an objective item should be deliberate, so flag it the
   -- way a dropped weapon is: +use required (see GM:PlayerCanPickupWeapon).
   part.IsDropped = true

   return part
end

function TESTERPARTS.Reset()
   timer.Remove(ASSEMBLE_TIMER)

   for _, wep in ipairs(FindParts()) do
      SafeRemoveEntity(wep)
   end

   TESTERPARTS.sabotaged = false
   TESTERPARTS.holders = {}

   for _, ply in ipairs(player.GetAll()) do
      if IsValid(ply) then ply.testerpart_carried = 0 end
   end

   SetProgress(0, 0)
end

-- Called from weapon_ttt_tester_part.lua's SWEP:Equip. Anyone who ever
-- carries a part is remembered for the rest of the round, whether or not
-- they're still holding one (or anything at all) by the time -- or if --
-- the set is actually assembled. Read back in Assemble() below to credit
-- everyone who helped, not just whoever was holding the final piece.
function TESTERPARTS.RecordHolder(ply)
   if not (IsValid(ply) and ply:IsPlayer()) then return end

   TESTERPARTS.holders = TESTERPARTS.holders or {}
   TESTERPARTS.holders[ply:SteamID()] = true
end

-- Parts sit in the primary slot, but unlike a normal full slot picking one
-- up isn't refused -- it displaces the gun you were holding (SWEP:Equip).
-- Any hook.Add callback returning non-nil here fully replaces the
-- gamemode's own GM:PlayerCanPickupWeapon (weaponry.lua) for this pickup, so
-- its own reliability fix -- repositioning a weapon that's embedded in the
-- ground so the touch reliably registers -- has to be repeated here too, or
-- parts intermittently refuse to be picked up until jostled loose.
hook.Add("PlayerCanPickupWeapon", "TesterParts_Pickup", function(ply, wep)
   if not enabled:GetBool() then return end
   if not IsValid(wep) or wep:GetClass() != PART_CLASS then return end

   if not IsValid(ply) or not ply:Alive() or not ply:IsTerror() then return false end
   if ply:HasWeapon(PART_CLASS) then return false end
   if not ply:KeyDown(IN_USE) then return false end

   local tr = util.TraceEntity({start = wep:GetPos(), endpos = ply:GetShootPos(), mask = MASK_SOLID}, wep)
   if tr.Fraction == 1.0 or tr.Entity == ply then
      wep:SetPos(ply:GetShootPos())
   end

   return true
end)

-- Non-traitor terrorists, ie. innocents and detectives -- detectives are on
-- the innocent side, so they count towards the target too.
local function CountInnocents()
   local n = 0
   for _, ply in ipairs(player.GetAll()) do
      if IsValid(ply) and ply:IsTerror() and not ply:IsTraitor() then
         n = n + 1
      end
   end

   return n
end

-- Every loose world item that can stand in for a part: guns lying on the
-- ground (not ones a player is carrying) and ammo boxes.
local function FindReplaceableItems()
   local ammo_classes = {}
   for _, cls in ipairs(ents.TTT.GetSpawnableAmmo()) do
      ammo_classes[cls] = true
   end

   local out = {}
   for _, ent in ipairs(ents.GetAll()) do
      if IsValid(ent) and not IsValid(ent:GetOwner()) then
         local cls = ent:GetClass()

         if ammo_classes[cls] then
            table.insert(out, ent)
         elseif ent:IsWeapon() and ent.AutoSpawnable and not WEPS.IsEquipment(ent) then
            table.insert(out, ent)
         end
      end
   end

   return out
end

local function ReplaceWithPart(item)
   local pos = item:GetPos()
   local ang = item:GetAngles()

   SafeRemoveEntity(item)

   return IsValid(SpawnPart(pos, ang))
end

function TESTERPARTS.Place()
   TESTERPARTS.Reset()

   if not enabled:GetBool() then return end

   local wanted = math.ceil(CountInnocents() * per_inno:GetFloat())
   wanted = math.Clamp(wanted, 1, max_parts:GetInt())

   local items = FindReplaceableItems()
   if #items == 0 then return end

   -- Fewer items on the map than parts wanted: take what there is, otherwise
   -- the set could never be completed.
   wanted = math.min(wanted, #items)

   table.Shuffle(items)

   local placed = 0
   for i = 1, #items do
      if placed >= wanted then break end

      if ReplaceWithPart(items[i]) then
         placed = placed + 1
      end
   end

   SetProgress(0, placed)

   if placed > 0 then
      LANG.Msg("tester_parts_scattered", {num = placed})

      timer.Create(ASSEMBLE_TIMER, TICK, 0, TESTERPARTS.CheckAssembly)
   end
end

---- Traitor upkeep
--
-- A part is a liability for a traitor: it costs them a credit every
-- drain_time seconds, and once they're broke it starts eating the equipment
-- they already bought.

local EQUIP_ITEM_IDS = {EQUIP_ARMOR, EQUIP_RADAR, EQUIP_DISGUISE, EQUIP_HUSH}

local function TakeRandomEquipment(ply)
   local pool = {}

   -- Bought weapons. Explicitly excluding the part itself even though it
   -- isn't WEAPON_EQUIP -- a traitor destroying their own held part this way
   -- would be a free, guaranteed way to lower the requirement.
   for _, wep in ipairs(ply:GetWeapons()) do
      if IsValid(wep) and wep:GetClass() != PART_CLASS and WEPS.IsEquipment(wep) then
         table.insert(pool, {wep = wep})
      end
   end

   for _, id in ipairs(EQUIP_ITEM_IDS) do
      if ply:HasEquipmentItem(id) then
         table.insert(pool, {item = id})
      end
   end

   if #pool == 0 then return nil end

   local taken = pool[math.random(#pool)]

   if taken.wep then
      local name = LANG.TryTranslation(taken.wep.PrintName or taken.wep:GetClass())
      ply:StripWeapon(taken.wep:GetClass())

      return name
   end

   ply.equipment_items = bit.band(ply:GetEquipmentItems(), bit.bnot(taken.item))
   ply:SendEquipment()

   local info = GetEquipmentItem(ply:GetRole(), taken.item)

   return LANG.TryTranslation(info and info.name or "")
end

-- Exposed (rather than local) so weapon_ttt_tester_part.lua's SWEP:Equip can
-- call it directly for the on-pickup drain, same as the periodic one below.
function TESTERPARTS.DrainTraitor(ply)
   if not (IsValid(ply) and ply:IsTraitor()) then return end

   if ply:GetCredits() > 0 then
      ply:SubtractCredits(1)
      LANG.Msg(ply, "tester_part_drain")
      return
   end

   local lost = TakeRandomEquipment(ply)

   if lost then
      LANG.Msg(ply, "tester_part_debt", {item = lost})
   else
      LANG.Msg(ply, "tester_part_debt_empty")
   end
end

local function ProcessDrain(dt)
   local interval = drain_time:GetFloat()
   if interval <= 0 then return end

   for _, ply in ipairs(player.GetAll()) do
      if IsValid(ply) and ply:Alive() and ply:IsTraitor() and ply:HasWeapon(PART_CLASS) then
         local carried = (ply.testerpart_carried or 0) + dt

         while carried >= interval do
            carried = carried - interval
            TESTERPARTS.DrainTraitor(ply)
         end

         ply.testerpart_carried = carried
      end
   end
end

local assemble_sound = Sound("items/ammocrate_close.wav")

function TESTERPARTS.Assemble(center)
   timer.Remove(ASSEMBLE_TIMER)

   for _, wep in ipairs(FindParts()) do
      SafeRemoveEntity(wep)
   end

   SetProgress(0, 0)

   sound.Play(assemble_sound, center, 80, 100)

   local holder_sids = {}
   for sid in pairs(TESTERPARTS.holders or {}) do
      table.insert(holder_sids, sid)
   end
   if #holder_sids > 0 then
      SCORE:HandleTesterAssembled(holder_sids)
   end

   local traitors = {}
   for _, ply in ipairs(player.GetAll()) do
      if IsValid(ply) and ply:IsTerror() and ply:Alive() and ply:IsTraitor() then
         table.insert(traitors, ply)
      end
   end

   if #traitors == 0 then
      LANG.Msg("tester_parts_nobody")
      return
   end

   local revealed = traitors[math.random(#traitors)]

   -- Same broadcast a tester scan used: the announcement plus an auto-tag on
   -- every client's scoreboard and target ID (see cl_testerparts.lua).
   net.Start("TTT_TesterScanResult")
      net.WriteEntity(revealed)
      net.WriteBit(true)
   net.Broadcast()

   LANG.Msg("tester_parts_revealed", {player = revealed:Nick()})
end

---- Destruction
--
-- Breaking a part lowers how many are needed, so smashing the set is a race
-- traitors can win outright -- destroy every part and the tester fires on
-- the spot. Doing it is still a gamble, since each break brings the reveal
-- closer for the innocents too.
--
-- Blame matters: only a traitor-caused break lowers the requirement. If an
-- innocent destroys one, they've cost their own side the objective (which
-- also stops them from cheesing an instant reveal by smashing their own
-- parts one after another).

local break_sound = Sound("physics/metal/metal_box_break1.wav")

function TESTERPARTS.DestroyPart(part, attacker)
   if not IsValid(part) or part.destroyed then return end
   part.destroyed = true

   local by_traitor
   if IsValid(attacker) and attacker:IsPlayer() then
      by_traitor = attacker:IsTraitor()
   else
      by_traitor = part.held_by_traitor == true
   end

   local pos = part:GetPos()

   SafeRemoveEntity(part)
   sound.Play(break_sound, pos, 80, 100)

   if not by_traitor then
      TESTERPARTS.sabotaged = true
      timer.Remove(ASSEMBLE_TIMER)
      SetProgress(0, 0)

      LANG.Msg("tester_parts_sabotaged")
      return
   end

   local total = GetGlobalInt("ttt_tester_parts_total", 0) - 1
   SetGlobalInt("ttt_tester_parts_total", total)

   if total <= 0 then
      TESTERPARTS.Assemble(pos)
   else
      LANG.Msg("tester_parts_destroyed", {num = total})
   end
end

local function DamagePart(part, amount, attacker)
   if not IsValid(part) or part.destroyed then return end

   part.part_health = (part.part_health or part_health:GetInt()) - amount

   if part.part_health <= 0 then
      TESTERPARTS.DestroyPart(part, attacker)
   end
end

-- trigger_hurt only damages players and NPCs, so a part sitting in lava or a
-- pit would otherwise be untouched. Check containment ourselves instead.
--
-- High enough by default that a part sitting at full health (see
-- ttt_tester_part_health) is destroyed in a single tick -- a real death pit
-- should feel instant, not like a slow burn.
local trigger_dps = CreateConVar("ttt_tester_part_trigger_dps", "150", FCVAR_NOTIFY)

local function ProcessHurtTriggers(parts, dt)
   local triggers = ents.FindByClass("trigger_hurt")
   if #triggers == 0 then return end

   local dps = trigger_dps:GetFloat()

   for _, part in ipairs(parts) do
      if IsValid(part) and not IsValid(part:GetOwner()) then
         local center = part:WorldSpaceCenter()

         for _, trig in ipairs(triggers) do
            if IsValid(trig) and not trig:GetInternalVariable("m_bDisabled") then
               local local_pos = trig:WorldToLocal(center)

               if local_pos:WithinAABox(trig:OBBMins(), trig:OBBMaxs()) then
                  DamagePart(part, dps * dt, nil)
                  break
               end
            end
         end
      end
   end
end

function TESTERPARTS.CheckAssembly()
   if not enabled:GetBool() or TESTERPARTS.sabotaged then return end

   local total = GetGlobalInt("ttt_tester_parts_total", 0)
   if total <= 0 then return end

   ProcessDrain(TICK)

   -- This can destroy parts, and destroying the last one ends the objective
   -- outright, so re-read the world afterwards instead of carrying on with a
   -- list that may now hold removed entities.
   ProcessHurtTriggers(FindParts(), TICK)

   if TESTERPARTS.sabotaged then return end

   total = GetGlobalInt("ttt_tester_parts_total", 0)
   if total <= 0 then return end

   local parts = FindParts()

   -- A break removes its own part from the requirement, so anything missing
   -- here vanished some other way (fell out of the world, engine cleanup).
   -- Lower the bar to match rather than leaving the round unwinnable.
   if #parts < total then
      total = #parts
      SetGlobalInt("ttt_tester_parts_total", total)

      if total <= 0 then
         timer.Remove(ASSEMBLE_TIMER)
         return
      end
   end

   local held = 0
   for _, wep in ipairs(parts) do
      if IsValid(wep:GetOwner()) then held = held + 1 end
   end

   if held != GetGlobalInt("ttt_tester_parts_held", 0) then
      SetProgress(held, total)
   end

   local range = assemble_range:GetFloat()
   local rsqr = range * range

   local center = Vector(0, 0, 0)
   for i = 1, #parts do
      local pos = PartPos(parts[i])
      center = center + pos

      for j = i + 1, #parts do
         if pos:DistToSqr(PartPos(parts[j])) > rsqr then return end
      end
   end
   center = center / #parts

   -- Someone on the innocent side has to actually be there to put it
   -- together, so an untouched pile of parts can't finish itself.
   local present = {}
   for _, ply in ipairs(player.GetAll()) do
      if IsValid(ply) and ply:IsTerror() and ply:Alive() and not ply:IsTraitor()
         and ply:GetPos():DistToSqr(center) <= rsqr then
         table.insert(present, ply)
      end
   end

   if #present == 0 then return end

   TESTERPARTS.Assemble(center)
end

-- TTT only drops a dead player's weapons when another player killed them and
-- wasn't carrying Hush (see GM:DoPlayerDeath), so a part could otherwise be
-- destroyed with the body -- or with a disconnecting player -- and leave the
-- set permanently uncompletable. Always put it back on the ground instead.
local function ScatterPartFrom(ply)
   if not enabled:GetBool() then return end
   if not IsValid(ply) then return end

   local wep = ply:GetWeapon(PART_CLASS)
   if not IsValid(wep) then return end

   local pos = ply:GetPos() + Vector(0, 0, 16)

   SafeRemoveEntity(wep)
   SpawnPart(pos)
end

hook.Add("DoPlayerDeath", "TesterParts_DropOnDeath", ScatterPartFrom)
hook.Add("PlayerDisconnected", "TesterParts_DropOnLeave", ScatterPartFrom)

hook.Add("TTTBeginRound", "TesterParts_Place", TESTERPARTS.Place)
hook.Add("TTTPrepareRound", "TesterParts_Reset", TESTERPARTS.Reset)

-- Assembly failing is silent by nature (it just doesn't fire), so give
-- admins a way to see which condition isn't met.
concommand.Add("ttt_tester_status", function(ply)
   if IsValid(ply) and not ply:IsAdmin() then return end

   local function say(msg)
      if IsValid(ply) then
         ply:PrintMessage(HUD_PRINTCONSOLE, msg)
      else
         print(msg)
      end
   end

   local parts = FindParts()
   local range = assemble_range:GetFloat()

   say(Format("[tester parts] enabled=%s sabotaged=%s required=%d present=%d",
              tostring(enabled:GetBool()), tostring(TESTERPARTS.sabotaged == true),
              GetGlobalInt("ttt_tester_parts_total", 0), #parts))

   local widest = 0
   for i = 1, #parts do
      local pos = PartPos(parts[i])
      local owner = parts[i]:GetOwner()

      say(Format("  part %d: held by %s, hp %d", i,
                 IsValid(owner) and owner:Nick() or "nobody",
                 parts[i].part_health or part_health:GetInt()))

      for j = i + 1, #parts do
         widest = math.max(widest, pos:Distance(PartPos(parts[j])))
      end
   end

   say(Format("  widest gap %.0f (must be <= %.0f)", widest, range))
end)
