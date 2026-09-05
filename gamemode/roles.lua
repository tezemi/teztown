---- Role Variants: convars and selection.
--
-- Runs at the end of SelectRoles (init.lua), once base roles are settled but
-- before credits are handed out, and promotes some of those players to
-- registered variants (see roles_shd.lua for the registry and the shape of a
-- variant).
--
-- A variant takes over players who already hold its base role, so promoting
-- traitor variants never changes how many traitors the round has -- it only
-- changes what kind of traitor they are. ROLE_NEUTRAL is the exception,
-- since base selection never produces neutrals: those are converted out of
-- the innocent pool.

-- Archived like ttt_sherlock_mode and friends, so once it's set on the
-- server it survives map changes rather than reverting to 0.
local enabled = CreateConVar("ttt_role_variants", "0", FCVAR_ARCHIVE + FCVAR_NOTIFY)

function ROLES.IsEnabled() return enabled:GetBool() end

---- Per-variant convars
--
-- Created lazily on first use rather than at registration time, so variants
-- registered from anywhere (including a file loaded after this one) still
-- get their convars.

local cvars_made = {}

local function VariantCvars(v)
   if cvars_made[v.id] then return cvars_made[v.id] end

   local prefix = "ttt_variant_" .. v.id .. "_"

   local made = {
      enabled = CreateConVar(prefix .. "enabled", v.enabled and "1" or "0", FCVAR_NOTIFY),
      pct     = CreateConVar(prefix .. "pct",     tostring(v.pct),    FCVAR_NOTIFY),
      min     = CreateConVar(prefix .. "min",     tostring(v.min),    FCVAR_NOTIFY),
      max     = CreateConVar(prefix .. "max",     tostring(v.max),    FCVAR_NOTIFY),
      chance  = CreateConVar(prefix .. "chance",  tostring(v.chance), FCVAR_NOTIFY)
   }

   cvars_made[v.id] = made

   return made
end

-- How many of this variant this round would want, given the playercount --
-- before checking how many candidates are actually available. Returns 0 if
-- it's switched off or loses its spawn roll.
--
-- roll is passed in so the status command can report counts without
-- consuming a random number or reporting a different answer every call.
local function WantedCount(v, total, roll)
   local cv = VariantCvars(v)

   if not cv.enabled:GetBool() then return 0, 0 end
   if roll > cv.chance:GetFloat() then return 0, 0 end

   local min = cv.min:GetInt()
   local max = math.max(min, cv.max:GetInt())

   return math.Clamp(math.floor(total * cv.pct:GetFloat()), min, max), min
end

---- Selection

function ROLES.ClearAll()
   for _, ply in ipairs(player.GetAll()) do
      if IsValid(ply) then
         ply.role_variant = nil

         -- Broadcast rather than telling just the owner: a variant may have
         -- been revealed to teammates, and they need to drop it too.
         ROLES.NetworkVariant(ply)
      end
   end
end

-- Tell everyone sharing ply's base role which variant they hold. Used for
-- variants their own team is meant to be able to identify.
function ROLES.RevealToTeam(ply)
   if not IsValid(ply) then return end

   local role = ply:GetRole()
   local mates = {}

   for _, other in ipairs(player.GetAll()) do
      if IsValid(other) and other != ply and other:GetRole() == role then
         table.insert(mates, other)
      end
   end

   if #mates > 0 then
      ROLES.NetworkVariant(ply, mates)
   end
end

-- Which players a variant can be drawn from. Neutrals have no base-selection
-- pool of their own, so they come out of the innocents.
local function PoolFor(v, pools)
   if v.base == ROLE_NEUTRAL then return pools[ROLE_INNOCENT] end

   return pools[v.base]
end

local function ApplyVariant(v, pools, total)
   local pool = PoolFor(v, pools)
   if not pool or #pool == 0 then return end

   local count, min = WantedCount(v, total, math.Rand(0, 1))
   if count <= 0 then return end

   -- Not enough candidates to meet the minimum: skip entirely rather than
   -- spawning a short-handed version of it.
   if #pool < min then return end

   count = math.min(count, #pool)

   for i = 1, count do
      local pick = math.random(#pool)
      local ply = pool[pick]
      table.remove(pool, pick)

      if IsValid(ply) then
         ply:SetRole(v.base)
         ply:SetRoleVariant(v.id)
      end
   end
end

-- Called from SelectRoles once base roles are assigned.
function ROLES.SelectVariants(plys)
   ROLES.ClearAll()

   if not enabled:GetBool() then return end

   local pools = {
      [ROLE_INNOCENT]  = {},
      [ROLE_TRAITOR]   = {},
      [ROLE_DETECTIVE] = {}
   }

   local total = 0
   for _, ply in ipairs(plys or player.GetAll()) do
      if IsValid(ply) and not ply:IsSpec() then
         total = total + 1

         local pool = pools[ply:GetRole()]
         if pool then table.insert(pool, ply) end
      end
   end

   if total == 0 then return end

   -- Shuffled so that when several variants draw from the same pool, the
   -- same one doesn't always get first pick of it.
   local variants = ROLES.GetAll()
   table.Shuffle(variants)

   for _, v in ipairs(variants) do
      ApplyVariant(v, pools, total)
   end

   -- Done as a second pass so every variant is settled first, otherwise a
   -- reveal could go out to a teammate who is themselves about to be
   -- promoted out of that role.
   for _, ply in ipairs(player.GetAll()) do
      if IsValid(ply) and ROLES.HasFlag(ply, "reveal_to_team") then
         ROLES.RevealToTeam(ply)
      end
   end

   -- Tell holders what they got. Without this a variant is silent from the
   -- inside, and one flagged no_team_list doesn't even get the usual
   -- round-start ally message to hint that something is different. Delayed
   -- to land with the other round-start messages rather than before them.
   timer.Simple(1.5, ROLES.BriefHolders)
end

function ROLES.BriefHolders()
   local announced = {}

   for _, ply in ipairs(player.GetAll()) do
      local v = IsValid(ply) and ply:GetRoleVariantData()

      if v then
         LANG.Msg(ply, "variant_you_are", {variant = LANG.NameParam(v.name)})

         if v.desc then LANG.Msg(ply, v.desc) end

         -- reveal_to_team (roles_shd.lua) only pushes the data silently, so
         -- teammates know who to draw with the variant's colour etc, but
         -- nothing actually told them out loud who it is. Do that here,
         -- timed with the rest of this round-start briefing.
         if v.reveal_to_team then
            local mates = {}
            for _, other in ipairs(player.GetAll()) do
               if IsValid(other) and other != ply and other:GetRole() == ply:GetRole() then
                  table.insert(mates, other)
               end
            end

            if #mates > 0 then
               LANG.Msg(mates, "variant_revealed", {player = ply:Nick(), variant = LANG.NameParam(v.name)})
            end
         end

         -- Some variants are public knowledge to the other side. Announced
         -- once per variant however many holders it ended up with, and only
         -- to players who aren't on its base role.
         if v.announce and not announced[v.id] then
            announced[v.id] = true

            local enemies = {}
            for _, other in ipairs(player.GetAll()) do
               if IsValid(other) and other:GetRole() != v.base then
                  table.insert(enemies, other)
               end
            end

            if #enemies > 0 then LANG.Msg(enemies, v.announce) end
         end
      end
   end
end

hook.Add("TTTPrepareRound", "RoleVariants_Clear", ROLES.ClearAll)

-- Variants flagged sees_team_bodies are shown where anyone sharing their
-- base role died. Reuses the beacon the "call detective" feature already
-- draws (TTT_CorpseCall, see cl_radar.lua) rather than inventing a second
-- world marker -- it takes a position and nothing else.
hook.Add("DoPlayerDeath", "RoleVariants_TeamBodies", function(victim)
   if not IsValid(victim) or not victim:IsPlayer() then return end

   local role = victim:GetRole()
   local watchers = {}

   for _, ply in ipairs(player.GetAll()) do
      if IsValid(ply) and ply != victim and ply:IsTerror()
         and ply:GetRole() == role and ROLES.HasFlag(ply, "sees_team_bodies") then
         table.insert(watchers, ply)
      end
   end

   if #watchers == 0 then return end

   net.Start("TTT_CorpseCall")
      net.WriteVector(victim:GetPos())
   net.Send(watchers)

   for _, ply in ipairs(watchers) do
      LANG.Msg(ply, "variant_team_body", {player = victim:Nick()})
   end
end)

---- Admin visibility
--
-- Variant assignment is invisible by design, so without this there's no way
-- to tell "switched off", "lost its spawn roll" and "no candidates" apart.
concommand.Add("ttt_variant_status", function(ply)
   if IsValid(ply) and not ply:IsAdmin() then return end

   local function say(msg)
      if IsValid(ply) then
         ply:PrintMessage(HUD_PRINTCONSOLE, msg)
      else
         print(msg)
      end
   end

   local variants = ROLES.GetAll()

   say(Format("[role variants] ttt_role_variants=%s registered=%d",
              tostring(enabled:GetBool()), #variants))

   if #variants == 0 then
      say("  none registered -- see ROLES.Register in gamemode/roles_shd.lua")
      return
   end

   local total = 0
   for _, p in ipairs(player.GetAll()) do
      if IsValid(p) and not p:IsSpec() then total = total + 1 end
   end

   for _, v in ipairs(variants) do
      local cv = VariantCvars(v)

      -- roll of 0 always passes, so this reports the count it would pick
      -- assuming the spawn chance hits, rather than rolling for real.
      local count = WantedCount(v, total, 0)

      say(Format("  %s: base=%d enabled=%s chance=%.2f -> %d of %d players",
                 v.id, v.base, tostring(cv.enabled:GetBool()),
                 cv.chance:GetFloat(), count, total))
   end

   local holders = {}
   for _, p in ipairs(player.GetAll()) do
      if IsValid(p) and p:HasRoleVariant() then
         table.insert(holders, p:Nick() .. "=" .. p:GetRoleVariant())
      end
   end

   say("  currently assigned: " .. (#holders > 0 and table.concat(holders, ", ") or "nobody"))
end)
