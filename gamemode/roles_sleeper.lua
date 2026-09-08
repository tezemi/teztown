---- Role variant: Sleeper Agent (neutral).
--
-- Starts out indistinguishable from a plain innocent -- no disguise, no
-- reveal, no announce, nothing tips anyone off, same as the Rogue. Unlike
-- the Rogue, the Sleeper Agent isn't a third faction with its own win
-- condition: if they're killed while still dormant, that's the end of it,
-- and the round plays out as a normal traitor/innocent game. But if every
-- traitor dies while a Sleeper Agent is still alive, that Sleeper Agent
-- genuinely becomes a traitor (ROLE_TRAITOR, not a shop_as_role illusion --
-- SetRole, for real), with a traitor's starting credits and some bonus time
-- added to the clock so the round doesn't just end a second later. Nothing
-- about who it was is ever revealed, only that it happened.
--
-- Because activation is a real SetRole, no extra win-condition plumbing is
-- needed at all: WIN_TRAITOR/WIN_INNOCENT already work correctly once this
-- fires -- init.lua's TTTCheckForWin sees a real traitor again. A dormant
-- Sleeper Agent deliberately does NOT get a win_check of its own (unlike
-- the Rogue), and TTTCheckForWin's "a living neutral blocks both sides"
-- rule only applies to neutrals that do have one -- so while dormant, a
-- Sleeper Agent is simply invisible to the win tally, never holding up a
-- win it has no stake in either way.
--
-- If they never get triggered at all -- killed while dormant, or the round
-- just ends around them -- TTTRoundWillEnd promotes them back to a real
-- Innocent before the round report is built, so they show and score as
-- exactly what they actually were the whole time, rather than being stuck
-- looking like some unresolved third faction. That's the whole point: a
-- Sleeper Agent always ends the round as a genuine Traitor or a genuine
-- Innocent, never as a neutral non-participant.

ROLES.Register({
   id    = "sleeper",
   name  = "role_sleeper",
   desc  = "role_sleeper_desc",
   base  = ROLE_NEUTRAL,
   color = Color(150, 70, 60),

   enabled = true,
   pct     = 0.34,  -- min 0 / max 1 means this only matters if max is raised
   min     = 0,
   max     = 1,
   chance  = 0.2,   -- ttt_variant_sleeper_chance: odds he appears at all this round

   -- No disguise_role, no reveal_to_team, no announce -- total silence
   -- until activation. shop_as_role isn't set either: a dormant Sleeper
   -- Agent has no shop access, exactly like a normal innocent.
})

if not SERVER then return end

local bonus_minutes = CreateConVar("ttt_sleeper_bonus_minutes", "2", FCVAR_NOTIFY)

-- Turns every currently-living Sleeper Agent into a real traitor. Safe to
-- call more than once a round (eg. max raised above 1, and the newly-woken
-- Sleeper later dies too) -- it only ever touches players who are both
-- alive and still holding the variant, so an already-activated or already-
-- dead one is simply skipped the next time around.
local function ActivateSleepers()
   local woke_any = false
   local starting_credits = math.ceil(GetConVarNumber("ttt_credits_starting"))

   for _, ply in ipairs(player.GetAll()) do
      if IsValid(ply) and ply:Alive() and ply:IsTerror() and ply:HasRoleVariant("sleeper") then
         ply:SetRole(ROLE_TRAITOR)

         -- Nobody else is told -- no list broadcast, no reveal -- so to
         -- everyone but this player, they're still just an innocent who
         -- happens to be alive.
         net.Start("TTT_Role")
            net.WriteUInt(ROLE_TRAITOR, 2)
         net.Send(ply)

         ply:AddCredits(starting_credits)

         LANG.Msg(ply, "sleeper_activated_you", {num = starting_credits})

         woke_any = true
      end
   end

   if woke_any then
      -- Bring the round report's final role bucket in line with what
      -- actually happened -- CLSCORE:Init only ever reads the LAST
      -- EVENT_SELECTED in the log (see scoring.lua/cl_scoring.lua), so
      -- simply logging a fresh one is enough to correct it after the fact.
      SCORE:HandleSelection()

      LANG.Msg("sleeper_activated_announce")

      IncRoundEnd(bonus_minutes:GetFloat() * 60)
   end
end

-- Any traitor's death might be the one that empties the team, so check
-- right after each rather than polling every tick -- cheaper, and it's the
-- exact moment that matters.
hook.Add("DoPlayerDeath", "RoleVariants_SleeperCheck", function(victim)
   if GetRoundState() != ROUND_ACTIVE then return end
   if not IsValid(victim) or not victim:IsPlayer() or not victim:IsTraitor() then return end

   for _, ply in ipairs(player.GetAll()) do
      if IsValid(ply) and ply:Alive() and ply:IsTerror() and ply:IsTraitor() then
         return -- someone's still holding the fort
      end
   end

   ActivateSleepers()
end)

-- If the round ends before a Sleeper Agent ever got the chance to activate,
-- they were just an innocent this whole time -- promote them for real
-- (dead or alive; a dead one gets this purely so the round report reads
-- "Innocent", not "Neutral", for someone who never did anything but be
-- one) rather than leaving them stuck in variant limbo. This runs
-- regardless of who actually won: it's a correction of what they truly
-- were, not a reward for the innocents winning specifically -- a dormant
-- Sleeper Agent still loses right along with the rest of the innocents if
-- the traitors won without ever being wiped out.
hook.Add("TTTRoundWillEnd", "RoleVariants_SleeperRevert", function(wintype)
   local reverted_any = false

   for _, ply in ipairs(player.GetAll()) do
      if IsValid(ply) and ply:IsNeutral() and ply:HasRoleVariant("sleeper") then
         ply:SetRole(ROLE_INNOCENT)
         reverted_any = true
      end
   end

   if reverted_any then
      SCORE:HandleSelection()
   end
end)
