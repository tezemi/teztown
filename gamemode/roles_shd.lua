---- Role Variants: registry and per-player state.
--
-- A variant is a specialised version of one of the four base roles. It does
-- NOT replace the base role -- the player still has a normal ROLE_ value, so
-- every existing win condition, karma rule, radar check and scoreboard
-- colour keeps working untouched. The variant is an extra layer on top,
-- which later steps can hang custom behaviour, equipment and HUD off.
--
-- Register one from anywhere (both realms -- keep it in a shared file so the
-- client knows the name/colour too):
--
--   ROLES.Register({
--      id      = "hypnotist",       -- unique, used in convars
--      name    = "role_hypnotist",  -- language string key
--      base    = ROLE_TRAITOR,      -- base role it sits on
--      color   = Color(180, 50, 50),
--      -- optional: HUD role-text colour, when `color` would clash with the
--      -- base role's HUD tab. Defaults to `color`.
--      hud_color = COLOR_BLACK,
--
--      enabled = false,  -- ttt_variant_hypnotist_enabled
--      pct     = 0.25,   -- ttt_variant_hypnotist_pct     (of all players)
--      min     = 1,      -- ttt_variant_hypnotist_min     (count floor)
--      max     = 1,      -- ttt_variant_hypnotist_max     (count ceiling)
--      chance  = 0.5     -- ttt_variant_hypnotist_chance  (odds it appears)
--   })
--
-- Every tuning value above becomes a server convar, so the values passed
-- here are only defaults -- admins get the final say per variant.
--
-- Optional capability flags, honoured by the systems they name so that
-- variants don't have to special-case themselves all over the gamemode:
--
--   no_team_chat   -- cut out of their role's team chat and team voice, in
--                     both directions (gamemsg.lua)
--   no_team_list   -- never told who shares their role (traitor_state.lua,
--                     init.lua's TellTraitorsAboutTraitors)
--   reveal_to_team -- everyone sharing their base role is told they hold
--                     this variant (roles.lua)
--   credits        -- extra starting credits on top of their base role's
--                     (player_ext.lua's SetDefaultCredits)
--   announce       -- a language key, broadcast once at round start to
--                     whoever announce_role names, or (if that's omitted)
--                     to everyone off this variant's own base role. Never
--                     names the holder -- just that the variant exists.
--                     (roles.lua's BriefHolders)
--   announce_role  -- narrows announce to one specific ROLE_ value instead
--                     of "everyone not on my side" -- eg. the Spy wants
--                     only traitors warned, not also detectives.
--
--   disguise_role  -- a ROLE_ value: players who genuinely hold that role
--                     see this player as one of their own (scoreboard,
--                     radar, target ID, the ally list, all of it), even
--                     though their real role never changes. One-directional
--                     and never told to anyone else. (traitor_state.lua,
--                     init.lua's TellTraitorsAboutTraitors, radar.lua)
--   suppress_team_chat_for -- a ROLE_ value: while this variant is alive,
--                     that role's entire team chat/voice channel is down
--                     for everyone on it, not just this player (gamemsg.lua)
--   credit_cap_role / credit_cap_amount -- while this variant is alive, no
--                     player holding credit_cap_role can carry more than
--                     credit_cap_amount credits -- every gain is clamped the
--                     moment it happens (player_ext.lua's SetCredits)
--   shop_as_role   -- a ROLE_ value: the equipment menu and purchase checks
--                     treat this player as if they held that role instead of
--                     their real one (ROLES.ShopRole, below). Their real role
--                     is untouched, so eg. credit_cap_role still keys off
--                     what they actually are. (cl_equip.lua, weaponry.lua)
--   win_check      -- function(ply) -> bool, checked every win-condition
--                     poll for each living holder. The first one to return
--                     true wins the round for their side (WIN_NEUTRAL) and
--                     is recorded as GAMEMODE.NeutralWinner. Neutral-base
--                     variants need this since they have no built-in win
--                     condition the way traitors/innocents do.
--                     (init.lua's TTTCheckForWin)
--
-- Selection itself lives in roles.lua (server), and the whole system is off
-- unless ttt_role_variants is 1.

ROLES = ROLES or {}

ROLES.Variants = ROLES.Variants or {}
ROLES.Order = ROLES.Order or {}

-- Registering the same id twice overwrites, so a variant file can be
-- reloaded in place without duplicating it in the selection pool.
function ROLES.Register(data)
   if not data or not data.id then
      ErrorNoHalt("ROLES.Register: variant needs an id\n")
      return
   end

   if not ROLES.Variants[data.id] then
      table.insert(ROLES.Order, data.id)
   end

   data.base    = data.base or ROLE_INNOCENT
   data.name    = data.name or data.id
   data.color   = data.color or COLOR_WHITE

   data.enabled = data.enabled or false
   data.pct     = data.pct or 0
   data.min     = data.min or 1
   data.max     = data.max or 1
   data.chance  = data.chance or 1

   ROLES.Variants[data.id] = data

   return data
end

function ROLES.Get(id)
   return id and ROLES.Variants[id] or nil
end

-- In registration order, so selection is deterministic before it shuffles.
function ROLES.GetAll()
   local out = {}
   for _, id in ipairs(ROLES.Order) do
      local v = ROLES.Variants[id]
      if v then table.insert(out, v) end
   end

   return out
end

---- Per-player state

local plymeta = FindMetaTable("Player")
if not plymeta then return end

-- Variant id string, or nil for a plain base role.
function plymeta:GetRoleVariant() return self.role_variant end

function plymeta:HasRoleVariant(id)
   return self.role_variant != nil and (id == nil or self.role_variant == id)
end

-- The registered variant table, or nil.
function plymeta:GetRoleVariantData()
   return ROLES.Get(self.role_variant)
end

-- Capability flag check (see the flag list at the top of this file). Safe on
-- players with no variant, which is the common case.
function ROLES.HasFlag(ply, flag)
   if not IsValid(ply) then return false end

   local v = ply:GetRoleVariantData()

   return v != nil and v[flag] == true
end

-- Printable variant name. Falls back to the plain role name, so this is
-- always safe to display. TryTranslation is clientside only (it lives in
-- cl_lang.lua), hence the guard -- the server gets the raw key.
function plymeta:GetRoleVariantString()
   local v = self:GetRoleVariantData()
   if not v then return self:GetRoleString() end

   return LANG.TryTranslation and LANG.TryTranslation(v.name) or v.name
end

-- The role a player should shop as (see shop_as_role above) -- their real
-- role, unless a variant overrides it. Shared because both the client's
-- equipment menu and the server's purchase validation need to agree on it.
function ROLES.ShopRole(ply)
   if not IsValid(ply) then return ROLE_INNOCENT end

   local v = ply:GetRoleVariantData()
   if v and v.shop_as_role then return v.shop_as_role end

   return ply:GetRole()
end

if SERVER then
   -- Tells recipients what variant ply holds. Carries the entity rather than
   -- assuming the recipient, so a variant can be revealed to teammates (see
   -- the reveal_to_team flag) as well as to its owner. No recipients means
   -- broadcast, which is how clears are pushed so nobody keeps a stale
   -- reveal from last round.
   function ROLES.NetworkVariant(ply, recipients)
      if not IsValid(ply) then return end

      net.Start("TTT_RoleVariant")
         net.WriteEntity(ply)
         net.WriteString(ply.role_variant or "")

      if recipients then net.Send(recipients) else net.Broadcast() end
   end

   function plymeta:SetRoleVariant(id)
      self.role_variant = id

      ROLES.NetworkVariant(self, self)
   end
else
   function plymeta:SetRoleVariant(id)
      self.role_variant = id
   end

   net.Receive("TTT_RoleVariant", function()
      local ply = net.ReadEntity()
      local id = net.ReadString()

      if IsValid(ply) then
         ply.role_variant = (id != "") and id or nil
      end
   end)
end
