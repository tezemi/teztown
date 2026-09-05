---- Role variant: Kingpin (traitor).
--
-- A traitor who funds the operation instead of running it. He is cut off
-- from the rest of the team -- no traitor chat, no traitor voice, and he is
-- never told who the other traitors are -- but they all know exactly who he
-- is. He starts richer than a normal traitor, earns more every time the
-- traitor side gets a kill, and can push credits out to a traitor picked at
-- random, since he has no way of knowing who he's paying.
--
-- The isolation itself is all handled by the generic variant flags (see
-- roles_shd.lua); only the money is Kingpin-specific.

ROLES.Register({
   id    = "kingpin",
   name  = "role_kingpin",
   desc  = "role_kingpin_desc",
   base  = ROLE_TRAITOR,
   color = Color(190, 140, 40),

   enabled = true,
   pct     = 0.34,  -- min/max both being 1 means this only matters if max is raised
   min     = 1,
   max     = 1,
   chance  = 1,     -- turn ttt_variant_kingpin_chance down to make him occasional

   no_team_chat     = true,  -- no traitor chat or voice, either direction
   no_team_list     = true,  -- never learns who the other traitors are
   reveal_to_team   = true,  -- but the traitors are told who he is
   sees_team_bodies = true,  -- and is shown where his traitors die
   announce         = "kingpin_announce", -- the innocent side knows one exists
   credits          = 3,     -- on top of the normal traitor starting credits

   -- Drives the equipment menu's transfer tab, which can't offer him a
   -- recipient list he isn't allowed to see (cl_transfer.lua).
   fund_command     = "ttt_kingpin_fund"
})

if not SERVER then return end

-- Credits the Kingpin earns each time a traitor kills someone who isn't on
-- the traitor side, and how many he sends per ttt_kingpin_fund.
local kill_reward = CreateConVar("ttt_kingpin_kill_credits", "1", FCVAR_NOTIFY)
local fund_amount = CreateConVar("ttt_kingpin_fund_amount", "1", FCVAR_NOTIFY)

local function GetKingpins(alive_only)
   local out = {}
   for _, ply in ipairs(player.GetAll()) do
      if IsValid(ply) and ply:HasRoleVariant("kingpin")
         and (not alive_only or ply:IsTerror()) then
         table.insert(out, ply)
      end
   end

   return out
end

---- Payroll: the traitor side killing anyone pays the Kingpin

hook.Add("DoPlayerDeath", "Kingpin_KillCredits", function(victim, attacker)
   if GetRoundState() != ROUND_ACTIVE then return end

   if not (IsValid(attacker) and attacker:IsPlayer() and attacker:IsTraitor()) then return end

   -- He has no idea who his own traitors are, so without this he'd never
   -- find out he just shot one of them.
   if IsValid(victim) and victim != attacker and victim:IsTraitor()
      and attacker:HasRoleVariant("kingpin") then
      LANG.Msg(attacker, "kingpin_killed_traitor", {player = victim:Nick()})
   end

   local reward = kill_reward:GetInt()
   if reward <= 0 then return end

   -- Only kills that actually further the traitor side pay out: no credit
   -- for killing each other, or for a traitor killing himself.
   if not IsValid(victim) or victim == attacker or victim:IsTraitor() then return end

   for _, king in ipairs(GetKingpins(true)) do
      -- A Kingpin doesn't get paid for his own work, he gets paid for
      -- everyone else's.
      if king != attacker then
         king:AddCredits(reward)
         LANG.Msg(king, "kingpin_kill_credits", {num = reward})
      end
   end
end)

---- Funding: push credits to a traitor the Kingpin can't see

local function KingpinFund(ply)
   if not IsValid(ply) or not ply:HasRoleVariant("kingpin") then return end
   if not ply:IsActiveTraitor() then return end

   local amount = math.max(1, fund_amount:GetInt())

   if ply:GetCredits() < amount then
      LANG.Msg(ply, "xfer_no_credits")
      return
   end

   local candidates = {}
   for _, other in ipairs(player.GetAll()) do
      if IsValid(other) and other != ply and other:IsActiveTraitor()
         and not other:HasRoleVariant("kingpin") then
         table.insert(candidates, other)
      end
   end

   if #candidates == 0 then
      LANG.Msg(ply, "kingpin_no_recipient")
      return
   end

   local target = candidates[math.random(#candidates)]

   ply:SubtractCredits(amount)
   target:AddCredits(amount)

   -- Deliberately not named to the Kingpin: he's paying into the
   -- organisation, not to a person he knows.
   LANG.Msg(ply, "kingpin_funded", {num = amount})
   LANG.Msg(target, "kingpin_received", {num = amount})
end
concommand.Add("ttt_kingpin_fund", KingpinFund)
