---- Mystery Box: pluggable pool of "what's inside the crate" outcomes.
--
-- weapon_ttt_mysterybox.lua calls MYSTERYBOX.SpawnRandom(pos, ang, activator)
-- once the thrown crate breaks open. To add a new outcome later, anywhere,
-- just call:
--
--   MYSTERYBOX.AddOutcome("name", weight, function(pos, ang, activator)
--      -- spawn whatever you want at/around pos
--   end)
--
-- weight is relative to the other outcomes (default 1, so plain
-- table.insert-style additions are all equally likely unless you care to
-- tune them). activator is the player who threw the box, and may be invalid
-- by the time the crate breaks (they could die or disconnect in the
-- meantime), so outcomes that use it must handle that.

MYSTERYBOX = MYSTERYBOX or {}
MYSTERYBOX.Outcomes = MYSTERYBOX.Outcomes or {}

function MYSTERYBOX.AddOutcome(name, weight, fn)
   table.insert(MYSTERYBOX.Outcomes, {name = name, weight = weight or 1, fn = fn})
end

-- Picks one outcome (weighted) and runs it. Returns the outcome's name, or
-- nil if none are registered.
function MYSTERYBOX.SpawnRandom(pos, ang, activator)
   if #MYSTERYBOX.Outcomes == 0 then return nil end

   local total = 0
   for _, o in ipairs(MYSTERYBOX.Outcomes) do
      total = total + o.weight
   end

   local roll = math.random() * total
   local acc = 0

   for _, o in ipairs(MYSTERYBOX.Outcomes) do
      acc = acc + o.weight
      if roll <= acc then
         o.fn(pos, ang, activator)
         return o.name
      end
   end
end

---- Shared helper for outcomes

-- Spawns `count` entities of `cls` scattered in a small radius around pos,
-- and gives physics-enabled ones a scatter impulse so they don't all land in
-- a single stack.
local function ScatterEntities(cls, pos, count, radius, impulse)
   for i = 1, count do
      local ent = ents.Create(cls)
      if IsValid(ent) then
         local offset = VectorRand() * (radius or 30)
         offset.z = math.abs(offset.z)

         ent:SetPos(pos + offset + Vector(0, 0, 12))
         ent:SetAngles(VectorRand():Angle())
         ent:Spawn()
         ent:Activate()

         local phys = ent:GetPhysicsObject()
         if IsValid(phys) then
            phys:Wake()
            phys:ApplyForceCenter(VectorRand() * (impulse or 150) + Vector(0, 0, impulse or 150))
         end
      end
   end
end
MYSTERYBOX.ScatterEntities = ScatterEntities

---- Outcomes

-- A bunch of health vials
MYSTERYBOX.AddOutcome("health_vials", 1, function(pos, ang)
   ScatterEntities("item_healthvial", pos, 6, 30, 120)
end)

-- A bunch of random weapons and ammo. Reuses the same dummy spawner
-- entities the map-placed weapon spawns already use, so this always spawns
-- something the round's spawn system already considers valid.
MYSTERYBOX.AddOutcome("random_weapons", 1, function(pos, ang)
   ScatterEntities("ttt_random_weapon", pos, 3, 30, 0)
   ScatterEntities("ttt_random_ammo", pos, 2, 30, 0)
end)

-- A bunch of armed incendiary grenades -- already primed, not pickups.
MYSTERYBOX.AddOutcome("incendiary_grenades", 1, function(pos, ang, activator)
   for i = 1, 4 do
      local nade = ents.Create("ttt_firegrenade_proj")
      if IsValid(nade) then
         local offset = VectorRand() * 40
         offset.z = math.abs(offset.z)

         nade:SetPos(pos + offset + Vector(0, 0, 12))
         nade:SetAngles(VectorRand():Angle())
         nade:Spawn()
         nade:Activate()

         nade:SetThrower(activator)
         nade:SetRadius(200)
         nade:SetDmg(20)
         nade:SetDetonateTimer(math.Rand(1, 3))

         local phys = nade:GetPhysicsObject()
         if IsValid(phys) then
            phys:Wake()
            phys:ApplyForceCenter(VectorRand() * 100)
         end
      end
   end
end)

-- Several headcrabs
MYSTERYBOX.AddOutcome("headcrabs", 1, function(pos, ang)
   for i = 1, 4 do
      local crab = ents.Create("npc_headcrab")
      if IsValid(crab) then
         local offset = VectorRand() * 40
         offset.z = math.abs(offset.z)

         crab:SetPos(pos + offset + Vector(0, 0, 12))
         crab:SetAngles(Angle(0, math.random(0, 360), 0)) -- NPCs: yaw only
         crab:Spawn()
         crab:Activate()
      end
   end
end)

-- An eviscerator
MYSTERYBOX.AddOutcome("eviscerator", 1, function(pos, ang)
   local wep = ents.Create("weapon_ttt_eviscerator")
   if IsValid(wep) then
      wep:SetPos(pos + Vector(0, 0, 12))
      wep:SetAngles(ang)
      wep:Spawn()
      wep:PhysWake()
   end
end)

-- A bunch of baby doll props
-- TODO: no confirmed baby-doll model exists in this mod's mounted content --
-- this is a placeholder (a plain battery prop, already used safely
-- elsewhere in this mod) so the outcome doesn't spawn an error/checkerboard
-- model. Swap BABYDOLL_MODEL for the real path once you have one.
local BABYDOLL_MODEL = "models/props_c17/doll01.mdl"
MYSTERYBOX.AddOutcome("baby_dolls", 1, function(pos, ang)
   for i = 1, 6 do
      local prop = ents.Create("prop_physics")
      if IsValid(prop) then
         local offset = VectorRand() * 30
         offset.z = math.abs(offset.z)

         prop:SetModel(BABYDOLL_MODEL)
         prop:SetPos(pos + offset + Vector(0, 0, 12))
         prop:SetAngles(VectorRand():Angle())
         prop:Spawn()
         prop:Activate()

         local phys = prop:GetPhysicsObject()
         if IsValid(phys) then
            phys:Wake()
            phys:ApplyForceCenter(VectorRand() * 150 + Vector(0, 0, 150))
         end
      end
   end
end)

-- HL2 Kleiner NPC
MYSTERYBOX.AddOutcome("kleiner", 1, function(pos, ang)
   local npc = ents.Create("npc_kleiner")
   if IsValid(npc) then
      npc:SetPos(pos + Vector(0, 0, 12))
      npc:SetAngles(Angle(0, ang.y, 0)) -- NPCs: yaw only
      npc:Spawn()
      npc:Activate()
   end
end)
