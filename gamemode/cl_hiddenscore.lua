---- Hidden score: a per-player round score that's never shown to players
-- directly. It's the existing point total (see KillsToPoints in
-- scoring_shd.lua) plus the combined value of every "factor" a player
-- triggered this round -- roughly, all the good/bad/neutral moments that the
-- on-screen awards also draw from, but scored rather than just narrated.
--
-- Not stored during the round: it's entirely derived from the same event
-- log (self.Events/self.Scores/etc. on a CLSCORE, see cl_scoring.lua) that
-- already streams down for the round report, so it's cheap to recompute
-- whenever something wants it -- e.g. a future win screen.
--
-- To add a factor from anywhere:
--
--   HIDDENSCORE.AddFactor("name", "good"/"bad"/"neutral", function(events, scores, players, traitors, detectives)
--      -- return a table of steamid -> point delta for whichever players
--      -- this factor applies to this round. Return nil or {} for "nobody".
--      return {[sid] = 5}
--   end)
--
-- The category string is purely documentary -- it doesn't feed into the
-- math, the sign and size of the points you return does. It's there so
-- someone skimming this file can tell at a glance what kind of moment each
-- factor represents, same as the three examples below.

HIDDENSCORE = HIDDENSCORE or {}
HIDDENSCORE.Factors = HIDDENSCORE.Factors or {}

function HIDDENSCORE.AddFactor(name, category, fn)
   table.insert(HIDDENSCORE.Factors, {name = name, category = category, fn = fn})
end

-- Finds the round's active-play start/end time from the raw event log, the
-- same way CLSCORE:Init and CLSCORE:BuildHilitePanel do elsewhere.
local function GetRoundTimespan(events)
   local starttime, endtime = nil, nil

   for i = 1, #events do
      local e = events[i]
      if e.id == EVENT_GAME and e.state == ROUND_ACTIVE and not starttime then
         starttime = e.t
      elseif e.id == EVENT_FINISH then
         endtime = e.t
      end
   end

   return starttime, endtime
end
HIDDENSCORE.GetRoundTimespan = GetRoundTimespan

-- Same damage-type-bit check cl_awards.lua uses internally (that one's
-- local to its own file, so this is a separate copy, not a shared one).
local function is_dmg_bit(dmg_t, bit)
   return util.BitSet(tonumber(dmg_t), bit)
end

-- Returns a table of steamid -> hidden score for one round's worth of data.
-- Takes the same shape of arguments as an AWARDS generator function (see
-- cl_awards.lua), so it can be fed straight from a CLSCORE instance:
--   HIDDENSCORE.Calculate(cl.Events, cl.Scores, cl.Players, cl.TraitorIDs, cl.DetectiveIDs)
function HIDDENSCORE.Calculate(events, scores, players, traitors, detectives)
   local hidden = {}

   -- baseline: the same points total already used for real (frag) scoring
   for sid, sc in pairs(scores) do
      hidden[sid] = KillsToPoints(sc, sc.was_traitor)
   end

   for _, factor in ipairs(HIDDENSCORE.Factors) do
      local contributions = factor.fn(events, scores, players, traitors, detectives)
      if contributions then
         for sid, delta in pairs(contributions) do
            hidden[sid] = (hidden[sid] or 0) + delta
         end
      end
   end

   return hidden
end

---- Factors

-- Killed yourself: bad. Scales with how many times it happened, in the rare
-- case someone respawned and managed it twice in one round.
HIDDENSCORE.AddFactor("suicide", "bad", function(events, scores, players, traitors, detectives)
   local out = {}

   for sid, sc in pairs(scores) do
      if sc.suicides > 0 then
         out[sid] = sc.suicides * -3
      end
   end

   return out
end)

-- Killed a traitor towards the beginning of the round: good. "Beginning" is
-- the first quarter of the round's active playtime.
local EARLY_ROUND_FRACTION = 0.25
HIDDENSCORE.AddFactor("early_traitor_kill", "good", function(events, scores, players, traitors, detectives)
   local out = {}

   local starttime, endtime = GetRoundTimespan(events)
   if not starttime or not endtime or endtime <= starttime then return out end

   local cutoff = starttime + (endtime - starttime) * EARLY_ROUND_FRACTION

   for i = 1, #events do
      local e = events[i]
      if e.id == EVENT_KILL and e.t and e.t <= cutoff
         and e.att.sid != -1 and e.att.sid != e.vic.sid
         and e.vic.tr and not e.att.tr then

         out[e.att.sid] = (out[e.att.sid] or 0) + 4
      end
   end

   return out
end)

-- Was the only traitor: neutral. Doesn't move the score at all, but it's
-- registered anyway to show a neutral factor doesn't have to be left out --
-- it's just as legitimate as a positive or negative one, and this is the
-- easiest place to see how one's set up.
HIDDENSCORE.AddFactor("solo_traitor", "neutral", function(events, scores, players, traitors, detectives)
   if #traitors != 1 then return nil end

   return {[traitors[1]] = 0}
end)

---- Factors mapped from the on-screen awards (see cl_awards.lua)
--
-- The display awards only carry a nick, not a SteamID (fine for text, not
-- for scoring -- nicks aren't guaranteed unique). Rather than resolve nicks
-- back to IDs after the fact, each of these mirrors the same detection
-- logic its award uses, but keyed by SteamID from the start. A few award
-- generators bundle outcomes with different moral weight into one function
-- (FirstBlood covers a legit kill AND a teamkill depending on who killed
-- who) -- those are split into separate factors here so each can get its
-- own value. These are first-pass judgment calls; say if any should change.
--
-- FirstSuicide and ExplodedSelf aren't separately mapped: both are just
-- "killed yourself" by a different means, already fully covered by the
-- "suicide" factor above (via scores[sid].suicides). Giving them their own
-- entries too would double/triple-penalize the same death.

-- ExplosiveGrant: someone got 3+ kills with explosives. Doesn't distinguish
-- who they killed, so this can't tell a traitor's frag-grenade rampage on
-- innocents from an accidental teamkill spree -- treated as a mild net
-- positive (it's still a skillful multi-kill) rather than strongly good.
HIDDENSCORE.AddFactor("explosive_multikill", "neutral", function(events, scores, players, traitors, detectives)
   local out = {}
   local bombers = {}

   for i = 1, #events do
      local e = events[i]
      if e.id == EVENT_KILL and is_dmg_bit(e.dmg.t, DMG_BLAST) then
         bombers[e.att.sid] = (bombers[e.att.sid] or 0) + 1
      end
   end

   for sid, num in pairs(bombers) do
      if num > 2 then
         out[sid] = 2
      end
   end

   return out
end)

-- FirstBlood, split by who killed whom:
--   traitor legit-kills someone     -> good (their role, done well)
--   traitor kills a fellow traitor  -> bad
--   innocent/detective teamkills    -> bad
--   innocent/detective legit-kills a traitor -> good
-- Only the actual first kill of the round counts, same as the award.
HIDDENSCORE.AddFactor("first_blood", "neutral", function(events, scores, players, traitors, detectives)
   for i = 1, #events do
      local e = events[i]
      if e.id == EVENT_KILL and e.att.sid != e.vic.sid and e.att.sid != -1 then
         if e.att.tr and not e.vic.tr then
            return {[e.att.sid] = 5} -- traitor legit kill
         elseif e.att.tr and e.vic.tr then
            return {[e.att.sid] = -5} -- traitor teamkill
         elseif not e.att.tr and not e.vic.tr then
            return {[e.att.sid] = -5} -- innocent teamkill
         else
            return {[e.att.sid] = 5} -- innocent/detective legit kill of a traitor
         end
      end
   end

   return nil
end)

-- AllKills: one player was solely responsible for their whole team's kills
-- this round -- a dominant solo-carry performance either way.
HIDDENSCORE.AddFactor("solo_carry", "good", function(events, scores, players, traitors, detectives)
   local tr_killers, in_killers = {}, {}

   for sid, s in pairs(scores) do
      if s.innos > 0 then
         table.insert(in_killers, sid)
      elseif s.traitors > 0 then
         table.insert(tr_killers, sid)
      end
   end

   if #tr_killers == 1 and not table.HasValue(traitors, tr_killers[1]) then
      return {[tr_killers[1]] = 8}
   end

   if #in_killers == 1 and table.HasValue(traitors, in_killers[1]) then
      return {[in_killers[1]] = 8}
   end

   return nil
end)

-- NumKills_Traitor: a traitor's innocent-kill spree. Weighted lighter than
-- the innocent-side equivalent below, matching the existing point formula's
-- own asymmetry in KillsToPoints (a traitor's kills are worth less there
-- too -- innocents surviving/killing traitors is the harder feat).
HIDDENSCORE.AddFactor("traitor_kill_spree", "good", function(events, scores, players, traitors, detectives)
   local out = {}
   for sid, s in pairs(scores) do
      if table.HasValue(traitors, sid) and s.innos > 0 then
         out[sid] = s.innos * 2
      end
   end
   return out
end)

-- NumKills_Inno: an innocent/detective's traitor-kill spree.
HIDDENSCORE.AddFactor("inno_kill_spree", "good", function(events, scores, players, traitors, detectives)
   local out = {}
   for sid, s in pairs(scores) do
      if not table.HasValue(traitors, sid) and s.traitors > 0 then
         out[sid] = s.traitors * 4
      end
   end
   return out
end)

-- FallDeath: someone pushed to their death is a kill (good for the pusher);
-- someone who just fell with no attacker is a careless accident (bad for
-- them). Only the first such death counts, same as the award.
HIDDENSCORE.AddFactor("fall_death", "neutral", function(events, scores, players, traitors, detectives)
   for i = 1, #events do
      local e = events[i]
      if e.id == EVENT_KILL and is_dmg_bit(e.dmg.t, DMG_FALL) then
         if e.att.sid != -1 then
            return {[e.att.sid] = 4} -- pushed someone off
         else
            return {[e.vic.sid] = -2} -- fell on their own
         end
      end
   end
   return nil
end)

-- FallKill: a push/physgun kill (crush damage while airborne). Good for
-- whoever did the pushing.
HIDDENSCORE.AddFactor("push_kill", "good", function(events, scores, players, traitors, detectives)
   for i = 1, #events do
      local e = events[i]
      if e.id == EVENT_KILL and is_dmg_bit(e.dmg.t, DMG_CRUSH) and is_dmg_bit(e.dmg.t, DMG_PHYSGUN) and e.att.sid != -1 then
         return {[e.att.sid] = 4}
      end
   end
   return nil
end)

-- Shared by "most kills with X" style awards (just Headshots now) -- reduces
-- to "find whoever did this the most, scale the value by how many times."
local function MostKillsFactor(matches_event, per_kill_value)
   return function(events, scores, players, traitors, detectives)
      local counts = {}
      for i = 1, #events do
         local e = events[i]
         if e.id == EVENT_KILL and matches_event(e) then
            counts[e.att.sid] = (counts[e.att.sid] or 0) + 1
         end
      end

      local best_sid, best_num = nil, 0
      for sid, num in pairs(counts) do
         if num > best_num then
            best_sid, best_num = sid, num
         end
      end

      if not best_sid or best_num < 2 then return nil end

      return {[best_sid] = best_num * per_kill_value}
   end
end

-- Headshots: good, scales with count.
HIDDENSCORE.AddFactor("headshots", "good", MostKillsFactor(
   function(e) return e.dmg.h and is_dmg_bit(e.dmg.t, DMG_BULLET) end, 2))

-- TeamKiller: bad, scaled by how many of their own team they killed and
-- what fraction of the team that was -- mirrors the award's own tiering.
HIDDENSCORE.AddFactor("team_killer", "bad", function(events, scores, players, traitors, detectives)
   local num_traitors = table.Count(traitors)
   local num_inno = table.Count(players) - num_traitors

   local tker, pct = nil, 0
   for sid, s in pairs(scores) do
      local kills = s.innos
      local team = num_inno - 1
      if table.HasValue(traitors, sid) then
         kills = s.traitors
         team = num_traitors - 1
      end

      if kills > 0 and team > 0 and (kills / team) > pct then
         pct = kills / team
         tker = sid
      end
   end

   if not tker or pct == 0 then return nil end

   local kills = table.HasValue(traitors, tker) and scores[tker].traitors or scores[tker].innos

   local value = -3
   if pct >= 1.0 then value = -15
   elseif pct >= 0.75 then value = -12
   elseif pct > 0.5 then value = -9
   elseif pct >= 0.25 then value = -5
   elseif kills >= 3 then value = -7
   elseif kills == 2 then value = -5
   end

   return {[tker] = value}
end)


-- TimeOfDeath: two bittersweet/unlucky narrative moments rather than clear
-- achievements, so these are kept small. Dying in the round's final 10
-- seconds on what turns out to be the winning side is closer to neutral
-- (their team still won) than bad; dying in the first 10 seconds is a mild
-- negative (caught out immediately).
HIDDENSCORE.AddFactor("time_of_death", "neutral", function(events, scores, players, traitors, detectives)
   local near = 10
   local starttime, endtime = GetRoundTimespan(events)
   if not starttime or not endtime then return nil end

   local time_near_start = starttime + near
   local time_near_end = endtime - near

   local traitor_win = nil
   for i = #events, 1, -1 do
      if events[i].id == EVENT_FINISH then
         traitor_win = (events[i].win == WIN_TRAITOR)
         break
      end
   end
   if traitor_win == nil then return nil end

   for i = #events, 1, -1 do
      local e = events[i]
      if e.id == EVENT_KILL and e.vic.sid != -1 then
         if e.t > time_near_end and e.vic.tr == traitor_win then
            return {[e.vic.sid] = -1} -- died just before their own side won
         elseif e.t < time_near_start then
            return {[e.vic.sid] = -2} -- died almost immediately
         end
      end
   end

   return nil
end)

-- BigSpender: good, most purchases this round (min 3). Relies on
-- EVENT_PURCHASE (SCORE:HandlePurchase in weaponry.lua).
HIDDENSCORE.AddFactor("big_spender", "good", function(events, scores, players, traitors, detectives)
   local buys = {}
   for i = 1, #events do
      local e = events[i]
      if e.id == EVENT_PURCHASE then
         buys[e.sid] = (buys[e.sid] or 0) + 1
      end
   end

   local best_sid, best_num = nil, 0
   for sid, num in pairs(buys) do
      if num > best_num then best_sid, best_num = sid, num end
   end

   if not best_sid or best_num < 3 then return nil end

   return {[best_sid] = 4}
end)

-- Carried: bad, applies to every traitor (not just one) on the winning
-- traitor team who scored no kills and dealt no damage all round. Relies on
-- EVENT_DAMAGE (SCORE:HandleDamageSummary in scoring.lua, once per player
-- at round end).
HIDDENSCORE.AddFactor("carried", "bad", function(events, scores, players, traitors, detectives)
   local win = nil
   for i = #events, 1, -1 do
      if events[i].id == EVENT_FINISH then
         win = events[i].win
         break
      end
   end
   if win != WIN_TRAITOR then return nil end

   local dealt = {}
   for i = 1, #events do
      local e = events[i]
      if e.id == EVENT_DAMAGE then
         dealt[e.sid] = e.dealt
      end
   end

   local out = {}
   for _, sid in ipairs(traitors) do
      local s = scores[sid]
      if s and s.traitors == 0 and s.innos == 0 and (dealt[sid] or 0) == 0 then
         out[sid] = -6
      end
   end

   return out
end)

-- SlowDay: neutral, applies to every plain innocent (not traitor, not
-- detective) who dealt no damage, received no damage, and found no bodies.
HIDDENSCORE.AddFactor("slow_day", "neutral", function(events, scores, players, traitors, detectives)
   local dealt, received, found = {}, {}, {}
   for i = 1, #events do
      local e = events[i]
      if e.id == EVENT_DAMAGE then
         dealt[e.sid] = e.dealt
         received[e.sid] = e.received
      elseif e.id == EVENT_BODYFOUND then
         found[e.sid] = true
      end
   end

   local out = {}
   for sid in pairs(scores) do
      if (not table.HasValue(traitors, sid)) and (not table.HasValue(detectives, sid)) then
         if (dealt[sid] or 0) == 0 and (received[sid] or 0) == 0 and not found[sid] then
            out[sid] = 0
         end
      end
   end

   return out
end)
