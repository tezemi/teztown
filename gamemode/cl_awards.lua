
-- Award/highlight generator functions take the events and the scores as
-- produced by SCORING/CLSCORING and return a table if successful, or nil if
-- not and another one should be tried.

-- some globals we'll use a lot
local table = table
local pairs = pairs

local is_dmg = function(dmg_t, bit)
                  -- deal with large-number workaround for TableToJSON by
                  -- parsing back to number here
                  return util.BitSet(tonumber(dmg_t), bit)
               end

-- so much text here I'm using shorter names than usual
local T = LANG.GetTranslation
local PT = LANG.GetParamTranslation

-- a common pattern
local function FindHighest(tbl)
   local m_num = 0
   local m_id = nil
   for id, num in pairs(tbl) do
      if num > m_num then
         m_id = id
         m_num = num
      end
   end

   return m_id, m_num
end

local function FirstSuicide(events, scores, players, traitors)
   local fs = nil
   local fnum = 0
   for k, e in pairs(events) do
      if e.id == EVENT_KILL and e.att.sid == e.vic.sid then
         fnum = fnum + 1
         if fs == nil then
            fs = e
         end
      end
   end

   if fs then
      local award = {nick=fs.att.ni}
      if not award.nick then return nil end

      award.category = "bad"

      if fnum > 1 then
         award.title = T("aw_sui1_title")
         award.text =  T("aw_sui1_text")
      else
         award.title = T("aw_sui2_title")
         award.text = T("aw_sui2_text")
      end

      -- only high interest if many people died this way
      award.priority = fnum

      return award
   else
      return nil
   end
end

local function ExplosiveGrant(events, scores, players, traitors)
   local bombers = {}
   for k, e in pairs(events) do
      if e.id == EVENT_KILL and is_dmg(e.dmg.t, DMG_BLAST) then
         bombers[e.att.sid] = (bombers[e.att.sid] or 0) + 1
      end
   end

   local award = {title = T("aw_exp1_title"), category = "neutral"}

   if not table.IsEmpty(bombers) then
      for sid, num in pairs(bombers) do
         -- award goes to whoever reaches this first I guess
         if num > 2 then
            award.nick = players[sid]
            if not award.nick then return nil end -- if player disconnected or something

            award.text = PT("aw_exp1_text", {num = num})

            -- rare award, high interest
            award.priority = 10 + num

            return award
         end
      end
   end

   return nil
end

local function ExplodedSelf(events, scores, players, traitors)
   for k, e in pairs(events) do
      if e.id == EVENT_KILL and is_dmg(e.dmg.t, DMG_BLAST) and e.att.sid == e.vic.sid then
         return {title=T("aw_exp2_title"), text=T("aw_exp2_text"), nick=e.vic.ni, priority=math.random(1, 4), category="bad"}
      end
   end

   return nil
end

local function FirstBlood(events, scores, players, traitors)
   for k, e in pairs(events) do
      if e.id == EVENT_KILL and e.att.sid != e.vic.sid and e.att.sid != -1 then
         local award = {nick=e.att.ni}
         if not award.nick or award.nick == "" then return nil end

         if e.att.tr and not e.vic.tr then -- traitor legit k
            award.title = T("aw_fst1_title")
            award.text = T("aw_fst1_text")
            award.category = "good"
         elseif e.att.tr and e.vic.tr then -- traitor tk
            award.title = T("aw_fst2_title")
            award.text = T("aw_fst2_text")
            award.category = "bad"
         elseif not e.att.tr and not e.vic.tr then -- inno tk
            award.title = T("aw_fst3_title")
            award.text = T("aw_fst3_text")
            award.category = "bad"
         else -- inno legit k
            award.title = T("aw_fst4_title")
            award.text = T("aw_fst4_text")
            award.category = "good"
         end

         -- more interesting if there were many players and therefore many kills
         award.priority = math.random(-3, math.Round(table.Count(players) / 4))

         return award
      end
   end
end

local function AllKills(events, scores, players, traitors)
   -- see if there is one killer responsible for all kills of either team

   local tr_killers = {}
   local in_killers = {}
   for id, s in pairs(scores) do
      if s.innos > 0 then
         table.insert(in_killers, id)
      elseif s.traitors > 0 then
         table.insert(tr_killers, id)
      end
   end

   if #tr_killers == 1 then
      local id = tr_killers[1]
      if not table.HasValue(traitors, id) then
         local killer = players[id]
         if not killer then return nil end

         return {nick=killer, title=T("aw_all1_title"), text=T("aw_all1_text"), priority=math.random(0, table.Count(players)), category="good"}
      end
   end

   if #in_killers == 1 then
      local id = in_killers[1]
      if table.HasValue(traitors, id) then
         local killer = players[id]
         if not killer then return nil end

         return {nick=killer, title=T("aw_all2_title"), text=T("aw_all2_text"), priority=math.random(0, table.Count(players)), category="good"}
      end
   end

   return nil
end

local function NumKills_Traitor(events, scores, players, traitors)
   local trs = {}
   for id, s in pairs(scores) do
      if table.HasValue(traitors, id) then
         if s.innos > 0 then
            table.insert(trs, id)
         end
      end
   end

   local choices = table.Count(trs)
   if choices > 0 then
      -- award a random killer
      local pick = math.random(1, choices)
      local sid = trs[pick]
      local nick = players[sid]
      if not nick then return nil end

      local kills = scores[sid].innos
      if kills == 1 then
         return {title=T("aw_nkt1_title"), nick=nick, text=T("aw_nkt1_text"), priority=0, category="good"}
      elseif kills == 2 then
         return {title=T("aw_nkt2_title"), nick=nick, text=T("aw_nkt2_text"), priority=1, category="good"}
      elseif kills == 3 then
         return {title=T("aw_nkt3_title"), nick=nick, text=T("aw_nkt3_text"), priority=kills, category="good"}
      elseif kills >= 4 and kills < 7 then
         return {title=T("aw_nkt4_title"), nick=nick, text=PT("aw_nkt4_text", {num = kills}), priority=kills + 2, category="good"}
      elseif kills >= 7 then
         return {title=T("aw_nkt5_title"), nick=nick, text=T("aw_nkt5_text"), priority=kills + 5, category="good"}
      end
   else
      return nil
   end
end

local function NumKills_Inno(events, scores, players, traitors)
   local ins = {}
   for id, s in pairs(scores) do
      if not table.HasValue(traitors, id) then
         if s.traitors > 0 then
            table.insert(ins, id)
         end
      end
   end

   local choices = table.Count(ins)
   if not table.IsEmpty(ins) then
      -- award a random killer
      local pick = math.random(1, choices)
      local sid = ins[pick]
      local nick = players[sid]
      if not nick then return nil end

      local kills = scores[sid].traitors
      if kills == 1 then
         return {title=T("aw_nki1_title"), nick=nick, text=T("aw_nki1_text"), priority = 0, category="good"}
      elseif kills == 2 then
         return {title=T("aw_nki2_title"), nick=nick, text=T("aw_nki2_text"), priority = 1, category="good"}
      elseif kills == 3 then
         return {title=T("aw_nki3_title"), nick=nick, text=T("aw_nki3_text"), priority= 5, category="good"}
      elseif kills >= 4 then
         return {title=T("aw_nki4_title"), nick=nick, text=T("aw_nki4_text"), priority=kills + 10, category="good"}
      end
   else
      return nil
   end
end

local function FallDeath(events, scores, players, traitors)
   for k, e in pairs(events) do
      if e.id == EVENT_KILL and is_dmg(e.dmg.t, DMG_FALL) then
         if e.att.ni != "" then
            return {title=T("aw_fal1_title"), nick=e.att.ni, text=T("aw_fal1_text"), priority=math.random(7, 15), category="good"}
         else
            return {title=T("aw_fal2_title"), nick=e.vic.ni, text=T("aw_fal2_text"), priority=math.random(1, 5), category="bad"}
         end
      end
   end

   return nil
end

local function FallKill(events, scores, players, traitors)
   for k, e in pairs(events) do
      if e.id == EVENT_KILL and is_dmg(e.dmg.t, DMG_CRUSH) and is_dmg(e.dmg.t, DMG_PHYSGUN) then
         if e.att.ni != "" then
            return {title=T("aw_fal3_title"), nick=e.att.ni, text=T("aw_fal3_text"), priority=math.random(10, 15), category="good"}
         end
      end
   end
end

local function Headshots(events, scores, players, traitors)
   local hs = {}
   for k, e in pairs(events) do
      if e.id == EVENT_KILL and e.dmg.h and is_dmg(e.dmg.t, DMG_BULLET) then
         hs[e.att.sid] = (hs[e.att.sid] or 0) + 1
      end
   end

   if table.IsEmpty(hs) then return nil end

   -- find the one with the most shots
   local m_id, m_num = FindHighest(hs)

   if not m_id then return nil end

   local nick = players[m_id]
   if not nick then return nil end

   local award = {nick=nick, priority=m_num / 2, category="good"}
   if m_num > 1 and m_num < 4 then
      award.title = T("aw_hed1_title")
      award.text = PT("aw_hed1_text", {num = m_num})
   elseif m_num >= 4 and m_num < 6 then
      award.title = T("aw_hed2_title")
      award.text = PT("aw_hed2_text", {num = m_num})
   elseif m_num >= 6 then
      award.title = T("aw_hed3_title")
      award.text = PT("aw_hed3_text", {num = m_num})
      award.priority = m_num + 5
   else
      return nil
   end

   return award
end

local function TeamKiller(events, scores, players, traitors)
   local num_traitors = table.Count(traitors)
   local num_inno = table.Count(players) - num_traitors

   -- find biggest tker
   local tker = nil
   local pct = 0
   for id, s in pairs(scores) do
      local kills = s.innos
      local team = num_inno - 1
      if table.HasValue(traitors, id) then
         kills = s.traitors
         team = num_traitors - 1
      end

      if kills > 0 and (kills / team) > pct then
         pct = kills / team
         tker = id
      end
   end

   -- no tks
   if pct == 0 or tker == nil then return nil end

   local nick = players[tker]
   if not nick then return nil end

   local was_traitor = table.HasValue(traitors, tker)
   local kills = (was_traitor and scores[tker].traitors > 0 and scores[tker].traitors) or (scores[tker].innos > 0 and scores[tker].innos) or 0
   local award = {nick=nick, priority=kills, category="bad"}
   if kills == 1 then
      award.title = T("aw_tkl1_title")
      award.text =  T("aw_tkl1_text")
      award.priority = 0
   elseif kills == 2 then
      award.title = T("aw_tkl2_title")
      award.text =  T("aw_tkl2_text")
   elseif kills == 3 then
      award.title = T("aw_tkl3_title")
      award.text =  T("aw_tkl3_text")
   elseif pct >= 1.0 then
      award.title = T("aw_tkl4_title")
      award.text =  T("aw_tkl4_text")
      award.priority = kills + math.random(3, 6)
   elseif pct >= 0.75 and not was_traitor then
      award.title = T("aw_tkl5_title")
      award.text =  T("aw_tkl5_text")
      award.priority = kills + 10
   elseif pct > 0.5 then
      award.title = T("aw_tkl6_title")
      award.text =  T("aw_tkl6_text")
      award.priority = kills + math.random(2, 7)
   elseif pct >= 0.25 then
      award.title = T("aw_tkl7_title")
      award.text =  T("aw_tkl7_text")
   else
      return nil
   end
   return award
end


local function TimeOfDeath(events, scores, players, traitors)
   local near = 10
   local time_near_start = CLSCORE.StartTime + near
   local time_near_end   = nil

   local traitor_win = nil

   local e = nil
   for i=#events, 1, -1 do
      e = events[i]

      if e.id == EVENT_FINISH then
         time_near_end = e.t - near
         traitor_win = (e.win == WIN_TRAITOR)

      elseif e.id == EVENT_KILL and e.vic then

         if time_near_end and
            e.t > time_near_end and e.vic.tr == traitor_win then
            return {
               nick  = e.vic.ni,
               title = T("aw_tod1_title"),
               text  = T("aw_tod1_text"),
               priority = (e.t - time_near_end) * 2,
               category = "neutral"
            };

         elseif e.t < time_near_start then
            return {
               nick  = e.vic.ni,
               title = T("aw_tod2_title"),
               text  = T("aw_tod2_text"),
               priority = (time_near_start - e.t) * 2,
               category = "neutral"
            };
         end
      end
   end
end


-- Most purchases this round, minimum 3. Relies on EVENT_PURCHASE, logged by
-- SCORE:HandlePurchase (weaponry.lua) whenever an order goes through.
local function BigSpender(events, scores, players, traitors)
   local buys = {}
   for k, e in pairs(events) do
      if e.id == EVENT_PURCHASE then
         buys[e.sid] = (buys[e.sid] or 0) + 1
      end
   end

   if table.IsEmpty(buys) then return nil end

   local m_id, m_num = FindHighest(buys)
   if not m_id or m_num < 3 then return nil end

   local nick = players[m_id]
   if not nick then return nil end

   return {nick = nick, title = T("aw_spd1_title"), text = PT("aw_spd1_text", {num = m_num}), priority = m_num, category = "good"}
end

-- A traitor on the winning traitor team who scored no kills (of either
-- side) and dealt no damage all round. Relies on EVENT_DAMAGE, logged once
-- per player at round end by SCORE:HandleDamageSummary.
local function Carried(events, scores, players, traitors)
   local win = nil
   for i = #events, 1, -1 do
      if events[i].id == EVENT_FINISH then
         win = events[i].win
         break
      end
   end
   if win != WIN_TRAITOR then return nil end

   local dealt = {}
   for k, e in pairs(events) do
      if e.id == EVENT_DAMAGE then
         dealt[e.sid] = e.dealt
      end
   end

   for _, sid in ipairs(traitors) do
      local s = scores[sid]
      if s and s.traitors == 0 and s.innos == 0 and (dealt[sid] or 0) == 0 then
         local nick = players[sid]
         if nick then
            return {nick = nick, title = T("aw_carr1_title"), text = T("aw_carr1_text"), priority = math.random(1, 5), category = "bad"}
         end
      end
   end

   return nil
end

-- A plain innocent (not traitor, not detective) who dealt no damage,
-- received no damage, and found no bodies this round.
local function SlowDay(events, scores, players, traitors, detectives)
   local dealt, received, found = {}, {}, {}
   for k, e in pairs(events) do
      if e.id == EVENT_DAMAGE then
         dealt[e.sid] = e.dealt
         received[e.sid] = e.received
      elseif e.id == EVENT_BODYFOUND then
         found[e.sid] = true
      end
   end

   for sid, nick in pairs(players) do
      if (not table.HasValue(traitors, sid)) and (not table.HasValue(detectives, sid)) then
         if (dealt[sid] or 0) == 0 and (received[sid] or 0) == 0 and not found[sid] then
            return {nick = nick, title = T("aw_slow1_title"), text = T("aw_slow1_text"), priority = math.random(-3, 2), category = "neutral"}
         end
      end
   end

   return nil
end


-- Used a defibrillator on someone: good if reviver and target are on the
-- same side (Miracle Worker), bad if opposing sides (Necromancer). Relies
-- on EVENT_REVIVE, logged by SCORE:HandleRevive (weapon_ttt_defib.lua) once
-- a revival completes.
local function MiracleWorker(events, scores, players, traitors)
   for k, e in pairs(events) do
      if e.id == EVENT_REVIVE and e.mtr == e.ttr then
         return {nick = e.ni, title = T("aw_mira1_title"), text = T("aw_mira1_text"), priority = math.random(1, 5), category = "good"}
      end
   end
   return nil
end

local function Necromancer(events, scores, players, traitors)
   for k, e in pairs(events) do
      if e.id == EVENT_REVIVE and e.mtr != e.ttr then
         return {nick = e.ni, title = T("aw_necro1_title"), text = T("aw_necro1_text"), priority = math.random(1, 5), category = "bad"}
      end
   end
   return nil
end

-- Suicide bomb kills are identifiable via dmg.g == AMMO_SUICIDEBOMB -- the
-- weapon entity is still alive (and so the resolvable inflictor) at the
-- moment its blast damage goes out; see weapon_ttt_suicidebomb.lua.

-- Killed at least one enemy (non-traitor -- the bomb is traitor-only) with a
-- suicide bomb. Picks the bomber who took the most enemies with them.
local function CarriedTheFlame(events, scores, players, traitors)
   local enemy_kills = {}
   for k, e in pairs(events) do
      if e.id == EVENT_KILL and e.dmg.g == AMMO_SUICIDEBOMB
         and e.att.sid != e.vic.sid and e.att.sid != -1 and not e.vic.tr then
         enemy_kills[e.att.sid] = (enemy_kills[e.att.sid] or 0) + 1
      end
   end

   if table.IsEmpty(enemy_kills) then return nil end

   local m_id, m_num = FindHighest(enemy_kills)
   if not m_id then return nil end

   local nick = players[m_id]
   if not nick then return nil end

   return {nick = nick, title = T("aw_flame1_title"), text = T("aw_flame1_text"), priority = m_num + 5, category = "good"}
end

-- Detonated a suicide bomb and killed nobody but themselves.
local function RebelWithoutACause(events, scores, players, traitors)
   local bombers, others_killed = {}, {}
   for k, e in pairs(events) do
      if e.id == EVENT_KILL and e.dmg.g == AMMO_SUICIDEBOMB then
         if e.att.sid == e.vic.sid then
            bombers[e.att.sid] = true
         else
            others_killed[e.att.sid] = true
         end
      end
   end

   for sid in pairs(bombers) do
      if not others_killed[sid] then
         local nick = players[sid]
         if nick then
            return {nick = nick, title = T("aw_rebel1_title"), text = T("aw_rebel1_text"), priority = math.random(1, 5), category = "bad"}
         end
      end
   end

   return nil
end

-- Killed a fellow traitor with a suicide bomb.
local function MissedInput(events, scores, players, traitors)
   for k, e in pairs(events) do
      if e.id == EVENT_KILL and e.dmg.g == AMMO_SUICIDEBOMB
         and e.att.sid != e.vic.sid and e.att.sid != -1 and e.vic.tr then
         local nick = players[e.att.sid]
         if nick then
            return {nick = nick, title = T("aw_missin1_title"), text = T("aw_missin1_text"), priority = math.random(3, 8), category = "bad"}
         end
      end
   end
   return nil
end


-- New award functions must be added to this to be used by CLSCORE.
-- Note that AWARDS is global. You can just go: table.insert(AWARDS, myawardfn) in your SWEPs.
AWARDS = { FirstSuicide, ExplosiveGrant, ExplodedSelf, FirstBlood, AllKills, NumKills_Traitor, NumKills_Inno, FallDeath, Headshots, TeamKiller, FallKill, TimeOfDeath, BigSpender, Carried, SlowDay, MiracleWorker, Necromancer, CarriedTheFlame, RebelWithoutACause, MissedInput }
