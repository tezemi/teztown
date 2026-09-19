---- Role variant: Joker (neutral).
--
-- A prankster who's dangerous to nobody: deals_no_damage (roles_shd.lua)
-- means every hit he lands on another player does nothing at all, no
-- matter what he shoots or swings at them -- he's not disarmed, just
-- harmless. He looks exactly like a normal innocent to everyone -- no
-- disguise, no reveal, no announce -- but shops from the traitor
-- catalogue, the same shape as the Rogue.
--
-- sees_traitors makes him traitor-aware despite being neutral: he gets the
-- real, live traitor list, the same traitor ring/label on target ID a real
-- traitor sees, and the same red scoreboard row -- entirely one-directional,
-- traitors are never told about him in return -- so he has a fighting
-- chance to actually steer into (or away from) the people who can kill him.
--
-- He has no win_check of his own (unlike the Rogue), so while he's alive
-- he's invisible to the win tally exactly like a dormant Sleeper Agent --
-- the traitors and innocents fight their normal round around him, and if
-- either side wins outright he just loses along with whoever he wasn't on.
-- His only path to victory is dying to a genuine innocent specifically
-- (checked in DoPlayerDeath below) -- being killed by a traitor, a fellow
-- neutral, the world, or himself is simply a loss. A win ends the round on
-- the spot via the TTTCheckForWin hook, the same style of override
-- GAMEMODE.MapWin uses, so nothing in init.lua needed to change at all.

ROLES.Register({
   id    = "joker",
   name  = "role_joker",
   desc  = "role_joker_desc",
   base  = ROLE_NEUTRAL,
   color = Color(190, 60, 190),
   -- The HUD role tab is already neutral purple, so the name goes on it in
   -- black rather than vanishing into it (same reasoning as the Rogue).
   hud_color = COLOR_BLACK,

   enabled = true,
   pct     = 0.34,  -- min 0 / max 1 means this only matters if max is raised
   min     = 0,
   max     = 1,
   chance  = 0.1,   -- ttt_variant_joker_chance: odds he appears at all this round

   credits         = 3,            -- his entire starting credits, see SetDefaultCredits
   shop_as_role    = ROLE_TRAITOR, -- same catalogue and purchase rules as a traitor
   deals_no_damage = true,         -- can attack, but never actually hurts anyone
   sees_traitors   = true          -- knows who the traitors are, so he knows who to avoid
})

if not SERVER then return end

-- Killed by a genuine innocent specifically -- not a detective, not a
-- fellow neutral, not a traitor -- while the round's still live: that's
-- the win. Recorded on the gamemode rather than the (now-dead) player, and
-- picked up by the TTTCheckForWin hook below on its next poll.
hook.Add("DoPlayerDeath", "RoleVariants_JokerCheck", function(victim, attacker)
   if GetRoundState() != ROUND_ACTIVE then return end
   if not IsValid(victim) or not victim:IsPlayer() or not victim:HasRoleVariant("joker") then return end
   if not IsValid(attacker) or not attacker:IsPlayer() or attacker:GetRole() != ROLE_INNOCENT then return end

   GAMEMODE.JokerWinner = victim
end)

-- Short-circuits GM:TTTCheckForWin entirely the moment a Joker has scored
-- their win (hook.Call returns the first non-nil result from a hook.Add'd
-- function without ever reaching the gamemode method) -- so this doesn't
-- need to touch init.lua's win tally at all, the same way GAMEMODE.MapWin
-- preempts it for map-triggered endings.
hook.Add("TTTCheckForWin", "RoleVariants_JokerWin", function()
   local winner = GAMEMODE.JokerWinner
   if not IsValid(winner) then return end

   GAMEMODE.NeutralWinner = winner
   return WIN_NEUTRAL
end)

-- Cleared every round so a stale winner from a previous round -- players
-- persist as entities between rounds -- can never leak into a new one.
hook.Add("TTTPrepareRound", "RoleVariants_JokerReset", function()
   GAMEMODE.JokerWinner = nil
end)
