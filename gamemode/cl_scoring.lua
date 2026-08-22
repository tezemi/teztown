-- Game report

include("cl_awards.lua")

local table = table
local string = string
local vgui = vgui
local pairs = pairs

CLSCORE = {}
CLSCORE.Events = {}
CLSCORE.Scores = {}
CLSCORE.TraitorIDs = {}
CLSCORE.DetectiveIDs = {}
CLSCORE.Players = {}
CLSCORE.StartTime = 0
CLSCORE.Panel = nil

CLSCORE.EventDisplay = {}

include("scoring_shd.lua")

local skull_icon = Material("HUD/killicons/default")

surface.CreateFont("WinHuge", {
   font = "Trebuchet24",
   size = 72,
   weight = 1000,
   shadow = true,
   extended = true
})

surface.CreateFont("MVPTitle", {
   font = "Trebuchet24",
   size = 34,
   weight = 1000,
   shadow = true,
   extended = true
})

surface.CreateFont("MVPName", {
   font = "Trebuchet24",
   size = 26,
   weight = 900,
   shadow = true,
   extended = true
})

surface.CreateFont("MVPAwardTitle", {
   font = "Trebuchet24",
   size = 22,
   weight = 1000,
   shadow = true,
   extended = true
})

surface.CreateFont("MVPAwardText", {
   font = "Trebuchet24",
   size = 20,
   weight = 500,
   shadow = true,
   extended = true
})

surface.CreateFont("MVPRowRank", {
   font = "Trebuchet24",
   size = 18,
   weight = 900,
   shadow = true,
   extended = true
})

surface.CreateFont("MVPRowName", {
   font = "Trebuchet24",
   size = 16,
   weight = 700,
   shadow = true,
   extended = true
})

surface.CreateFont("MVPRowAwardName", {
   font = "Trebuchet24",
   size = 15,
   weight = 800,
   shadow = true,
   extended = true
})

surface.CreateFont("MVPRowAward", {
   font = "Trebuchet24",
   size = 15,
   weight = 400,
   shadow = true,
   extended = true
})

-- so much text here I'm using shorter names than usual
local T = LANG.GetTranslation
local PT = LANG.GetParamTranslation

function CLSCORE:GetDisplay(key, event)
   local displayfns = self.EventDisplay[event.id]
   if not displayfns then return end
   local keyfn = displayfns[key]
   if not keyfn then return end

   return keyfn(event)
end

function CLSCORE:TextForEvent(e)
   return self:GetDisplay("text", e)
end

function CLSCORE:IconForEvent(e)
   return self:GetDisplay("icon", e)
end

function CLSCORE:TimeForEvent(e)
   local t = e.t - self.StartTime
   if t >= 0 then
      return util.SimpleTime(t, "%02i:%02i")
   else
      return "     "
   end
end

-- Tell CLSCORE how to display an event. See cl_scoring_events for examples.
-- Pass an empty table to keep an event from showing up.
function CLSCORE.DeclareEventDisplay(event_id, event_fns)
   -- basic input vetting, can't check returned value types because the
   -- functions may be impure
   if not tonumber(event_id) then
      error("Event ??? display: invalid event id", 2)
   end
   if not istable(event_fns) then
      error(string.format("Event %d display: no display functions found.", event_id), 2)
   end
   if not event_fns.text then
      error(string.format("Event %d display: no text display function found.", event_id), 2)
   end
   if not event_fns.icon then
      error(string.format("Event %d display: no icon and tooltip display function found.", event_id), 2)
   end

   CLSCORE.EventDisplay[event_id] = event_fns
end

function CLSCORE:FillDList(dlst)
   local events = self.Events

   for i = 1, #events do
      local e = events[i]
      local etxt = self:TextForEvent(e)
      local eicon, ttip = self:IconForEvent(e)
      local etime = self:TimeForEvent(e)

      if etxt then
         if eicon then
            local mat = eicon
            eicon = vgui.Create("DImage")
            eicon:SetMaterial(mat)
            eicon:SetTooltip(ttip)
            eicon:SetKeepAspect(true)
            eicon:SizeToContents()
         end

         dlst:AddLine(etime, eicon, "  " .. etxt)
      end
   end
end

function CLSCORE:BuildEventLogPanel(dpanel)
   local margin = 10

   local w, h = dpanel:GetSize()

   local dlist = vgui.Create("DListView", dpanel)
   dlist:SetPos(0, 0)
   dlist:SetSize(w, h - margin*2)
   dlist:SetSortable(true)
   dlist:SetMultiSelect(false)

   local timecol = dlist:AddColumn(T("col_time"))
   local iconcol = dlist:AddColumn("")
   local eventcol = dlist:AddColumn(T("col_event"))

   iconcol:SetFixedWidth(16)
   timecol:SetFixedWidth(40)

   -- If sortable is off, no background is drawn for the headers which looks
   -- terrible. So enable it, but disable the actual use of sorting.
   iconcol.Header:SetDisabled(true)
   timecol.Header:SetDisabled(true)
   eventcol.Header:SetDisabled(true)

   self:FillDList(dlist)
end

CLSCORE.ScorePanelNames = {
   "",
   "col_player",
   "col_role",
   "col_kills1",
   "col_kills2",
   "col_points",
   "col_team",
   "col_total"
}

CLSCORE.ScorePanelColor = Color(150, 50, 50)

function CLSCORE:BuildScorePanel(dpanel)
   local margin = 10
   local w, h = dpanel:GetSize()

   local dlist = vgui.Create("DListView", dpanel)
   dlist:SetPos(0, 0)
   dlist:SetSize(w, h)
   dlist:SetSortable(true)
   dlist:SetMultiSelect(false)

   local scorenames = self.ScorePanelNames

   for i = 1, #scorenames do
      local name = scorenames[i]
	  
      if isstring(name) then
         if name == "" then
            -- skull icon column
            local c = dlist:AddColumn("")
            c:SetFixedWidth(18)
         else
            dlist:AddColumn(T(name))
         end
      end
   end

   -- the type of win condition triggered is relevant for team bonus
   local wintype = WIN_NONE
   local events = self.Events

   for i = #events, 1, -1 do
      local e = self.Events[i]
      if e.id == EVENT_FINISH then
         wintype = e.win
         break
      end
   end

   local scores = self.Scores
   local nicks = self.Players
   local bonus = ScoreTeamBonus(scores, wintype)

   for id, s in pairs(scores) do
      if id != -1 then
         local was_traitor = s.was_traitor
         local role = was_traitor and T("traitor") or (s.was_detective and T("detective") or "")

         local surv = ""
         if s.deaths > 0 then
            surv = vgui.Create("ColoredBox", dlist)
            surv:SetColor(self.ScorePanelColor)
            surv:SetBorder(false)
            surv:SetSize(18,18)

            local skull = vgui.Create("DImage", surv)
            skull:SetMaterial(skull_icon)
            skull:SetTooltip("Dead")
            skull:SetKeepAspect(true)
            skull:SetSize(18,18)
         end

         local points_own   = KillsToPoints(s, was_traitor)
         local points_team  = (was_traitor and bonus.traitors or bonus.innos)
         local points_total = points_own + points_team

         local l = dlist:AddLine(surv, nicks[id], role, s.innos, s.traitors, points_own, points_team, points_total)

         -- center align
         for k, col in pairs(l.Columns) do
            col:SetContentAlignment(5)
         end

         -- when sorting on the column showing survival, we would get an error
         -- because images can't be sorted, so instead hack in a dummy value
         local surv_col = l.Columns[1]
         if surv_col then
            surv_col.Value = TypeID(surv_col.Value) == TYPE_PANEL and "1" or "0"
         end
      end
   end

   dlist:SortByColumn(6)
end

function CLSCORE:AddAward(y, pw, award, dpanel)
   local nick = award.nick
   local text = award.text
   local title = string.upper(award.title)

   local titlelbl = vgui.Create("DLabel", dpanel)
   titlelbl:SetText(title)
   titlelbl:SetFont("TabLarge")
   titlelbl:SizeToContents()
   local tiw, tih = titlelbl:GetSize()

   local nicklbl = vgui.Create("DLabel", dpanel)
   nicklbl:SetText(nick)
   nicklbl:SetFont("DermaDefaultBold")
   nicklbl:SizeToContents()
   local nw, nh = nicklbl:GetSize()

   local txtlbl = vgui.Create("DLabel", dpanel)
   txtlbl:SetText(text)
   txtlbl:SetFont("DermaDefault")
   txtlbl:SizeToContents()
   local tw, th = txtlbl:GetSize()

   titlelbl:SetPos((pw - tiw) / 2, y)
   y = y + tih + 2

   local fw = nw + tw + 5
   local fx = ((pw - fw) / 2)
   nicklbl:SetPos(fx, y)
   txtlbl:SetPos(fx + nw + 5, y)

   y = y + nh

   return y
end

-- double check that we have no nils
local function ValidAward(a)
   return istable(a) and isstring(a.nick) and isstring(a.text) and isstring(a.title) and isnumber(a.priority)
end

CLSCORE.WinTypes = {
   [WIN_INNOCENT] = {
      Text = "hilite_win_innocent",
      BoxColor = Color(5, 190, 5, 255),
      TextColor = COLOR_WHITE,
      BackgroundColor = Color(50, 50, 50, 255)
   },
   [WIN_TRAITOR] = {
      Text = "hilite_win_traitors",
      BoxColor = Color(190, 5, 5, 255),
      TextColor = COLOR_WHITE,
      BackgroundColor = Color(50, 50, 50, 255)
   }
}

-- when win is due to timeout, innocents win
CLSCORE.WinTypes[WIN_TIMELIMIT] = CLSCORE.WinTypes[WIN_INNOCENT]

-- The default wintype if no EVENT_FINISH is specified
CLSCORE.WinTypes.Default = CLSCORE.WinTypes[WIN_INNOCENT]

function CLSCORE:BuildHilitePanel(dpanel, title, starttime, endtime)
   local w, h = dpanel:GetSize()

   local numply = table.Count(self.Players)
   local numtr = table.Count(self.TraitorIDs)


   local bg = vgui.Create("ColoredBox", dpanel)
   bg:SetColor(title.BackgroundColor or self.WinTypes.Default.BackgroundColor)
   bg:SetSize(w,h)
   bg:SetPos(0,0)

   local winlbl = vgui.Create("DLabel", dpanel)
   winlbl:SetFont("WinHuge")
   winlbl:SetText( T(title.Text or self.WinTypes.Default.Text) )
   winlbl:SetTextColor(title.TextColor or self.WinTypes.Default.TextColor)
   winlbl:SizeToContents()
   local xwin = (w - winlbl:GetWide())/2
   local ywin = 30
   winlbl:SetPos(xwin, ywin)

   bg.PaintOver = function()
      draw.RoundedBox(8, xwin - 15, ywin - 5, winlbl:GetWide() + 30, winlbl:GetTall() + 10, title.BoxColor or self.WinTypes.Default.BoxColor)
   end

   local ysubwin = ywin + winlbl:GetTall()
   local partlbl = vgui.Create("DLabel", dpanel)

   local plytxt = PT(numtr == 1 and "hilite_players2" or "hilite_players1",
                     {numplayers = numply, numtraitors = numtr})

   partlbl:SetText(plytxt)
   partlbl:SizeToContents()
   partlbl:SetPos(xwin, ysubwin + 8)

   local timelbl = vgui.Create("DLabel", dpanel)
   timelbl:SetText(PT("hilite_duration", {time= util.SimpleTime(endtime - starttime, "%02i:%02i")}))
   timelbl:SizeToContents()
   timelbl:SetPos(xwin + winlbl:GetWide() - timelbl:GetWide(), ysubwin + 8)

   -- Awards
   local wa = math.Round(w * 0.9)
   local ha = h - ysubwin - 40
   local xa = (w - wa) / 2
   local ya = h - ha

   local awardp = vgui.Create("DPanel", dpanel)
   awardp:SetSize(wa, ha)
   awardp:SetPos(xa, ya)
   awardp:SetPaintBackground(false)

   -- Before we pick awards, seed the rng in a way that is the same on all
   -- clients. We can do this using the round start time. To make it a bit more
   -- random, involve the round's duration too.
   math.randomseed(starttime + endtime)

   -- Attempt to generate every award, then sort the succeeded ones based on
   -- priority/interestingness
   local award_choices = {}
   for k, afn in pairs(AWARDS) do
      local a = afn(self.Events, self.Scores, self.Players, self.TraitorIDs, self.DetectiveIDs)
      if ValidAward(a) then
         table.insert(award_choices, a)
      end
   end

   local num_choices = table.Count(award_choices)
   local max_awards = 5

   -- sort descending by priority
   table.SortByMember(award_choices, "priority")

   -- put the N most interesting awards in the menu
   for i=1,max_awards do
      local a = award_choices[i]
      if a then
         self:AddAward((i - 1) * 42, wa, a, awardp)
      end
   end
end

function CLSCORE:ShowPanel()
   if IsValid(self.Panel) then
      self:ClearPanel()
   end

   local margin = 15

   local dpanel = vgui.Create("DFrame")

   local title = self.WinTypes.Default
   local starttime = self.StartTime
   local endtime = starttime
   local events = self.Events

   for i = #events, 1, -1 do
      local e = events[i]
      if e.id == EVENT_FINISH then
         endtime = e.t
         title = self.WinTypes[e.win]
         break
      end
   end

   -- size the panel based on the win text w/ 88px horizontal padding and 44px veritcal padding
   surface.SetFont("WinHuge")
   local w, h = surface.GetTextSize( T(title.Text or self.WinTypes.Default.Text) )

   -- w + DPropertySheet padding (8) + winlbl padding (30) + offset margin (margin * 2) + size margin (margin)
   w, h = math.max(700, w + 38 + margin * 3), 500

   dpanel:SetSize(w, h)
   dpanel:Center()
   dpanel:SetTitle(T("report_title"))
   dpanel:SetVisible(true)
   dpanel:ShowCloseButton(true)
   dpanel:SetMouseInputEnabled(true)
   dpanel:SetKeyboardInputEnabled(true)
   dpanel.OnKeyCodePressed = util.BasicKeyHandler

   -- keep it around so we can reopen easily
   dpanel:SetDeleteOnClose(false)
   self.Panel = dpanel

   local dbut = vgui.Create("DButton", dpanel)
   local bw, bh = 100, 25
   dbut:SetSize(bw, bh)
   dbut:SetPos(w - bw - margin, h - bh - margin/2)
   dbut:SetText(T("close"))
   dbut.DoClick = function() dpanel:Close() end

   local dsave = vgui.Create("DButton", dpanel)
   dsave:SetSize(bw,bh)
   dsave:SetPos(margin, h - bh - margin/2)
   dsave:SetText(T("report_save"))
   dsave:SetTooltip(T("report_save_tip"))
   dsave:SetConsoleCommand("ttt_save_events")

   local dtabsheet = vgui.Create("DPropertySheet", dpanel)
   dtabsheet:SetPos(margin, margin + 15)
   dtabsheet:SetSize(w - margin*2, h - margin*3 - bh)
   local padding = dtabsheet:GetPadding()


   -- Highlight tab
   local dtabhilite = vgui.Create("DPanel", dtabsheet)
   dtabhilite:SetPaintBackground(false)
   dtabhilite:StretchToParent(padding,padding,padding,padding)
   self:BuildHilitePanel(dtabhilite, title, starttime, endtime)

   dtabsheet:AddSheet(T("report_tab_hilite"), dtabhilite, "icon16/star.png", false, false, T("report_tab_hilite_tip"))

   -- Event log tab
   local dtabevents = vgui.Create("DPanel", dtabsheet)
--   dtab1:SetSize(650, 450)
   dtabevents:StretchToParent(padding, padding, padding, padding)
   self:BuildEventLogPanel(dtabevents)

   dtabsheet:AddSheet(T("report_tab_events"), dtabevents, "icon16/application_view_detail.png", false, false, T("report_tab_events_tip"))

   -- Score tab
   local dtabscores = vgui.Create("DPanel", dtabsheet)
   dtabscores:SetPaintBackground(false)
   dtabscores:StretchToParent(padding, padding, padding, padding)
   self:BuildScorePanel(dtabscores)

   dtabsheet:AddSheet(T("report_tab_scores"), dtabscores, "icon16/user.png", false, false, T("report_tab_scores_tip"))

   dpanel:MakePopup()

   -- makepopup grabs keyboard, whereas we only need mouse
   dpanel:SetKeyboardInputEnabled(false)
end

-- Replacement end-of-round screen: transparent full-screen overlay, big win
-- title, then just the MVP (highest HIDDENSCORE this round) with their
-- avatar, name, and every award they picked up -- good or bad. Supersedes
-- ShowPanel above, which is left in place (dead code, unused) rather than
-- deleted in case any of it -- the event log tab/save-to-file especially --
-- turns out to be wanted again later.
-- is_debug: when true, any fake/unresolvable player (no real SteamID, as with
-- ttt_mvp_debug's synthetic round) falls back to showing the local player's
-- own avatar instead of leaving the slot empty, so you can actually see how
-- an avatar looks in the layout. Never happens outside debug -- a genuinely
-- disconnected player in a real round still correctly shows no avatar.
function CLSCORE:ShowMVPPanel(is_debug)
   if IsValid(self.Panel) then
      self:ClearPanel()
   end

   local title = self.WinTypes.Default
   local events = self.Events

   for i = #events, 1, -1 do
      local e = events[i]
      if e.id == EVENT_FINISH then
         title = self.WinTypes[e.win]
         break
      end
   end

   -- Same determinism trick the old panel used: seed with round start/end so
   -- every client's math.random() calls inside the AWARDS generators (used
   -- for priority/tie-breaking, not for who wins an award) agree.
   local starttime, endtime = HIDDENSCORE.GetRoundTimespan(events)
   math.randomseed((starttime or 0) + (endtime or 0))

   local hidden = HIDDENSCORE.Calculate(self.Events, self.Scores, self.Players, self.TraitorIDs, self.DetectiveIDs)

   -- Everyone who scored, ranked highest first. ranked[1] is the MVP;
   -- ranked[2..9] are the smaller list shown underneath.
   local ranked = {}
   for sid, score in pairs(hidden) do
      table.insert(ranked, {sid = sid, score = score})
   end
   table.sort(ranked, function(a, b) return a.score > b.score end)

   local mvp_sid = ranked[1] and ranked[1].sid

   local function RoleString(sid)
      if table.HasValue(self.TraitorIDs, sid) then return T("traitor")
      elseif table.HasValue(self.DetectiveIDs, sid) then return T("detective")
      else return T("innocent") end
   end

   -- Same role colours used elsewhere (eg. the role-highlighted portion of
   -- the "you were killed by" chat message in cl_lang.lua).
   local function RoleColor(sid)
      if table.HasValue(self.TraitorIDs, sid) then return Color(220, 60, 60)
      elseif table.HasValue(self.DetectiveIDs, sid) then return Color(80, 140, 255)
      else return Color(80, 200, 80) end
   end

   -- Every award any player earned this round, computed once and grouped by
   -- nick, rather than re-running all 26 AWARDS generators per player shown.
   local awards_by_nick = {}
   for k, afn in pairs(AWARDS) do
      local a = afn(self.Events, self.Scores, self.Players, self.TraitorIDs, self.DetectiveIDs)
      if ValidAward(a) then
         awards_by_nick[a.nick] = awards_by_nick[a.nick] or {}
         table.insert(awards_by_nick[a.nick], a)
      end
   end
   for _, list in pairs(awards_by_nick) do
      table.SortByMember(list, "priority")
   end

   local scrw, scrh = ScrW(), ScrH()

   local dpanel = vgui.Create("DPanel")
   dpanel:SetSize(scrw, scrh)
   dpanel:SetPos(0, 0)
   dpanel:SetPaintBackground(false)
   dpanel.Paint = function(s, w, h)
      draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 140))
   end
   dpanel:SetMouseInputEnabled(true)
   dpanel:SetKeyboardInputEnabled(true)
   dpanel.OnKeyCodePressed = util.BasicKeyHandler

   -- DPanel has no Close()/DeleteOnClose (those are DFrame-only), but both
   -- util.BasicKeyHandler (ESC) and the close button below call :Close(),
   -- so give it one that just routes to the normal removal path.
   dpanel.Close = function() self:ClearPanel() end

   self.Panel = dpanel

   -- Win title, same big-box style the old panel used
   local titletext = T(title.Text or self.WinTypes.Default.Text)

   surface.SetFont("WinHuge")
   local tw, th = surface.GetTextSize(titletext)

   local winx, winy = (scrw - tw) / 2, 50

   local boxclr = title.BoxColor or self.WinTypes.Default.BoxColor
   local winbox = vgui.Create("DPanel", dpanel)
   winbox:SetPos(winx - 15, winy - 5)
   winbox:SetSize(tw + 30, th + 10)
   winbox.Paint = function(s, w, h)
      draw.RoundedBox(8, 0, 0, w, h, boxclr)
   end

   local winlbl = vgui.Create("DLabel", dpanel) -- sibling after winbox, so it paints on top
   winlbl:SetFont("WinHuge")
   winlbl:SetText(titletext)
   winlbl:SetTextColor(title.TextColor or self.WinTypes.Default.TextColor)
   winlbl:SizeToContents()
   winlbl:SetPos(winx, winy)

   local y = winy + th + 40

   if mvp_sid then
      local nick = self.Players[mvp_sid] or "???"

      local mvplbl = vgui.Create("DLabel", dpanel)
      mvplbl:SetFont("MVPTitle")
      mvplbl:SetText(T("report_mvp_title"))
      mvplbl:SetTextColor(Color(255, 210, 0))
      mvplbl:SizeToContents()
      mvplbl:SetPos((scrw - mvplbl:GetWide()) / 2, y)
      y = y + mvplbl:GetTall() + 10

      local avatar_size = 128
      local mvp_ply = player.GetBySteamID(mvp_sid)
      if not IsValid(mvp_ply) and is_debug then mvp_ply = LocalPlayer() end
      if IsValid(mvp_ply) then
         local avatar = vgui.Create("AvatarImage", dpanel)
         avatar:SetSize(avatar_size, avatar_size)
         avatar:SetPos((scrw - avatar_size) / 2, y)
         avatar:SetPlayer(mvp_ply, 184)
         y = y + avatar_size + 10
      end

      -- Two labels side by side rather than one, so the "(Role)" part can be
      -- coloured differently from the name itself.
      local namepart = nick .. " "
      local rolepart = "(" .. RoleString(mvp_sid) .. ")"

      surface.SetFont("MVPName")
      local namew, nameh = surface.GetTextSize(namepart)
      local rolew = surface.GetTextSize(rolepart)
      local namex = (scrw - (namew + rolew)) / 2

      local namelbl = vgui.Create("DLabel", dpanel)
      namelbl:SetFont("MVPName")
      namelbl:SetText(namepart)
      namelbl:SetTextColor(COLOR_WHITE)
      namelbl:SizeToContents()
      namelbl:SetPos(namex, y)

      local rolelbl = vgui.Create("DLabel", dpanel)
      rolelbl:SetFont("MVPName")
      rolelbl:SetText(rolepart)
      rolelbl:SetTextColor(RoleColor(mvp_sid))
      rolelbl:SizeToContents()
      rolelbl:SetPos(namex + namew, y)

      y = y + nameh + 20

      -- Top 5 awards only, highest priority first.
      local mvp_awards = awards_by_nick[nick] or {}

      local list_w = 780
      local shown = math.min(#mvp_awards, 5)
      local awards_h = math.max(shown, 1) * 84
      local scroll = vgui.Create("DScrollPanel", dpanel)
      scroll:SetPos((scrw - list_w) / 2, y)
      scroll:SetSize(list_w, awards_h)
      y = y + awards_h + 20

      if shown > 0 then
         local ly = 0
         for i = 1, shown do
            local a = mvp_awards[i]

            local titlelbl = vgui.Create("DLabel", scroll)
            titlelbl:SetFont("MVPAwardTitle")
            titlelbl:SetText(string.upper(a.title))
            titlelbl:SetTextColor(a.category == "bad" and Color(220, 60, 60) or COLOR_WHITE)
            titlelbl:SizeToContents()
            titlelbl:SetPos((list_w - titlelbl:GetWide()) / 2, ly)
            ly = ly + titlelbl:GetTall() + 2

            local textlbl = vgui.Create("DLabel", scroll)
            textlbl:SetFont("MVPAwardText")
            textlbl:SetText(a.text)
            textlbl:SetTextColor(Color(255, 210, 60))
            textlbl:SetContentAlignment(5)
            textlbl:SizeToContents()
            textlbl:SetPos((list_w - textlbl:GetWide()) / 2, ly)
            ly = ly + textlbl:GetTall() + 26
         end
      else
         local nonelbl = vgui.Create("DLabel", scroll)
         nonelbl:SetFont("MVPAwardText")
         nonelbl:SetText(T("report_mvp_noawards"))
         nonelbl:SetTextColor(Color(255, 210, 60))
         nonelbl:SizeToContents()
         nonelbl:SetPos((list_w - nonelbl:GetWide()) / 2, 0)
      end

      -- Ranks #2-#8: a smaller row per player -- rank, avatar, name, best
      -- (highest-priority) award, even if it's a bad one.
      local row_w = 780
      local row_h = 36
      local rows_x = (scrw - row_w) / 2

      for rank = 2, math.min(#ranked, 8) do
         local entry = ranked[rank]
         local rsid = entry.sid
         local rnick = self.Players[rsid] or "???"

         local row = vgui.Create("DPanel", dpanel)
         row:SetPos(rows_x, y)
         row:SetSize(row_w, row_h)
         row:SetPaintBackground(false)

         local ranklbl = vgui.Create("DLabel", row)
         ranklbl:SetFont("MVPRowRank")
         ranklbl:SetText("#" .. rank)
         ranklbl:SetTextColor(COLOR_WHITE)
         ranklbl:SetContentAlignment(4)
         ranklbl:SetPos(0, 0)
         ranklbl:SetSize(36, row_h)

         local rply = player.GetBySteamID(rsid)
         if not IsValid(rply) and is_debug then rply = LocalPlayer() end
         if IsValid(rply) then
            local ravatar = vgui.Create("AvatarImage", row)
            ravatar:SetSize(row_h, row_h)
            ravatar:SetPos(40, 0)
            ravatar:SetPlayer(rply, 64)
         end

         local rnamepart = rnick .. " "
         local rrolepart = "(" .. RoleString(rsid) .. ")"

         surface.SetFont("MVPRowName")
         local rnamew = surface.GetTextSize(rnamepart)

         local rnamelbl = vgui.Create("DLabel", row)
         rnamelbl:SetFont("MVPRowName")
         rnamelbl:SetText(rnamepart)
         rnamelbl:SetTextColor(COLOR_WHITE)
         rnamelbl:SetContentAlignment(4)
         rnamelbl:SetPos(40 + row_h + 10, 0)
         rnamelbl:SetSize(rnamew, row_h)

         local rrolelbl = vgui.Create("DLabel", row)
         rrolelbl:SetFont("MVPRowName")
         rrolelbl:SetText(rrolepart)
         rrolelbl:SetTextColor(RoleColor(rsid))
         rrolelbl:SetContentAlignment(4)
         rrolelbl:SetPos(40 + row_h + 10 + rnamew, 0)
         rrolelbl:SetSize(180 - rnamew, row_h)

         local best = (awards_by_nick[rnick] or {})[1]
         local award_x = 40 + row_h + 10 + 180

         if best then
            -- "Award Name - description", name white+bold, description gold.
            local awnamepart = string.upper(best.title) .. " - "

            surface.SetFont("MVPRowAwardName")
            local awnamew = surface.GetTextSize(awnamepart)

            local awnamelbl = vgui.Create("DLabel", row)
            awnamelbl:SetFont("MVPRowAwardName")
            awnamelbl:SetText(awnamepart)
            awnamelbl:SetTextColor(best.category == "bad" and Color(220, 60, 60) or COLOR_WHITE)
            awnamelbl:SetContentAlignment(4)
            awnamelbl:SetPos(award_x, 0)
            awnamelbl:SetSize(awnamew, row_h)

            local awdesclbl = vgui.Create("DLabel", row)
            awdesclbl:SetFont("MVPRowAward")
            awdesclbl:SetText(best.text)
            awdesclbl:SetTextColor(Color(255, 210, 60))
            awdesclbl:SetContentAlignment(4)
            awdesclbl:SetPos(award_x + awnamew, 0)
            awdesclbl:SetSize(row_w - (award_x + awnamew), row_h)
         else
            local rawardlbl = vgui.Create("DLabel", row)
            rawardlbl:SetFont("MVPRowAward")
            rawardlbl:SetText(T("report_mvp_noaward"))
            rawardlbl:SetTextColor(Color(160, 160, 160))
            rawardlbl:SetContentAlignment(4)
            rawardlbl:SetPos(award_x, 0)
            rawardlbl:SetSize(row_w - award_x, row_h)
         end

         y = y + row_h + 4
      end
   else
      local nonelbl = vgui.Create("DLabel", dpanel)
      nonelbl:SetFont("MVPName")
      nonelbl:SetText(T("report_mvp_none"))
      nonelbl:SetTextColor(COLOR_WHITE)
      nonelbl:SizeToContents()
      nonelbl:SetPos((scrw - nonelbl:GetWide()) / 2, y)
   end

   -- Close + full-report buttons, centered as a pair right below whatever
   -- content came before (the players list, or the "no MVP" fallback).
   local bw, bh, gap = 130, 25, 10
   local by = y + 20
   local bx = (scrw - (bw * 2 + gap)) / 2

   local dbut = vgui.Create("DButton", dpanel)
   dbut:SetSize(bw, bh)
   dbut:SetPos(bx, by)
   dbut:SetText(T("close"))
   dbut.DoClick = function() dpanel:Close() end

   local dbutold = vgui.Create("DButton", dpanel)
   dbutold:SetSize(bw, bh)
   dbutold:SetPos(bx + bw + gap, by)
   dbutold:SetText(T("report_mvp_fullreport"))
   dbutold.DoClick = function() self:ShowPanel() end

   dpanel:MakePopup()
   dpanel:SetKeyboardInputEnabled(false)
end

-- Debug preview: fabricates a full fake round event log (players, roles,
-- kills, damage, purchases, a body find, a finish) and pushes it through the
-- exact same CLSCORE:Init/ShowMVPPanel path a real round result uses, so
-- what you see is genuinely the real renderer, not a mockup. Console-only,
-- not gated behind sv_cheats since it's a purely clientside visual preview.
--
-- Fake players have no real SteamID, so player.GetBySteamID() finds nothing
-- for them -- their avatar slots are correctly just empty, same as it'd
-- gracefully handle a disconnected player in a real round.
local function BuildFakeRoundEvents()
   local names = {"Ligma", "Sugma", "Testificate", "Gnorman", "Bort",
                  "Skibbly", "Wumbo", "Deez", "Farva"}

   local sids = {}
   for i = 1, #names do
      sids[i] = "FAKE_DEBUG_" .. i
   end

   local events = {}
   local t = 0
   local function Add(e)
      e.t = t
      t = t + 1
      table.insert(events, e)
   end

   Add({id = EVENT_GAME, state = ROUND_ACTIVE})

   for i = 1, #names do
      Add({id = EVENT_SPAWN, sid = sids[i], ni = names[i]})
   end

   -- 1: traitor, big spender, gets some kills (MVP candidate)
   -- 2: traitor, does nothing all round -> Carried
   -- 3: detective, finds a body, buys a few things
   -- 4-9: innocents, mixed activity; 6 does nothing -> Slow Day
   local traitor_ids = {sids[1], sids[2]}
   local detective_ids = {sids[3]}
   Add({id = EVENT_SELECTED, traitor_ids = traitor_ids, detective_ids = detective_ids})

   for i = 4, 9 do
      Add({id = EVENT_KILL,
           att = {ni = names[1], sid = sids[1], tr = true},
           vic = {ni = names[i], sid = sids[i], tr = false},
           dmg = {t = DMG_BULLET, a = 60, h = (i % 2 == 0), g = AMMO_PISTOL}})
   end

   Add({id = EVENT_BODYFOUND, sid = sids[3], ni = names[3], b = names[4]})

   for i = 1, 4 do
      Add({id = EVENT_PURCHASE, sid = sids[1], ni = names[1]})
   end
   for i = 1, 3 do
      Add({id = EVENT_PURCHASE, sid = sids[3], ni = names[3]})
   end

   -- Round-end damage summary, normally added by SCORE:HandleDamageSummary.
   -- sids[2] and sids[6] deliberately get none -> Carried / Slow Day.
   Add({id = EVENT_DAMAGE, sid = sids[1], dealt = 240, received = 40})
   Add({id = EVENT_DAMAGE, sid = sids[3], dealt = 20, received = 60})
   Add({id = EVENT_DAMAGE, sid = sids[5], dealt = 30, received = 15})
   Add({id = EVENT_DAMAGE, sid = sids[7], dealt = 0, received = 45})
   Add({id = EVENT_DAMAGE, sid = sids[8], dealt = 10, received = 0})

   Add({id = EVENT_FINISH, win = WIN_TRAITOR})

   return events
end

concommand.Add("ttt_mvp_debug", function()
   CLSCORE:Reset()
   CLSCORE:Init(BuildFakeRoundEvents())
   CLSCORE:ShowMVPPanel(true)
end)

function CLSCORE:ClearPanel()

   if IsValid(self.Panel) then
      -- move the mouse off any tooltips and then remove the panel next tick

      -- we need this hack as opposed to just calling Remove because gmod does
      -- not offer a means of killing the tooltip, and doesn't clean it up
      -- properly on Remove
      input.SetCursorPos( ScrW()/2, ScrH()/2 )
      local pnl = self.Panel
      timer.Simple(0, function() if IsValid(pnl) then pnl:Remove() end end)
   end
end

function CLSCORE:SaveLog()
   local events = self.Events

   if events == nil or #events == 0 then
      chat.AddText(COLOR_WHITE, T("report_save_error"))
      return
   end

   local logdir = "ttt/logs"
   if not file.IsDir(logdir, "DATA") then
      file.CreateDir(logdir)
   end

   local logname = logdir .. "/ttt_events_" .. os.time() .. ".txt"
   local log = "Trouble in Terrorist Town - Round Events Log\n".. string.rep("-", 50) .."\n"

   log = log .. string.format("%s | %-25s | %s\n", " TIME", "TYPE", "WHAT HAPPENED") .. string.rep("-", 50) .."\n"

   for i = 1, #events do
      local e = events[i]
      local etxt = self:TextForEvent(e)
      local etime = self:TimeForEvent(e)
      local _, etype = self:IconForEvent(e)
      if etxt then
         log = log .. string.format("%s | %-25s | %s\n", etime, etype, etxt)
      end
   end

   file.Write(logname, log)

   chat.AddText(COLOR_WHITE, T("report_save_result"), COLOR_GREEN, " /garrysmod/data/" .. logname)
end

function CLSCORE:Reset()
   self.Events = {}
   self.TraitorIDs = {}
   self.DetectiveIDs = {}
   self.Scores = {}
   self.Players = {}
   self.RoundStarted = 0

   self:ClearPanel()
end

function CLSCORE:Init(events)
   -- Get start time, traitors, detectives, scores, and nicks
   local starttime = 0
   local traitors, detectives
   local scores, nicks = {}, {}
   
   -- Used to bail out early once one of each event type had been seen, on
   -- the assumption every EVENT_SPAWN would already be behind EVENT_SELECTED
   -- and the round's EVENT_GAME(ROUND_ACTIVE) in the log. Not reliably true
   -- -- eg. a bot/late joiner whose own spawn lands after that point would
   -- get silently dropped from self.Players/self.Scores entirely, which is
   -- why the MVP screen's ranked list could come up short. A full,
   -- unconditional scan costs nothing (round event logs are tiny) and can't
   -- miss anyone.
   for i = 1, #events do
      local e = events[i]
      if e.id == EVENT_GAME then
         if e.state == ROUND_ACTIVE then
            starttime = e.t
         end
      elseif e.id == EVENT_SELECTED then
         traitors = e.traitor_ids
         detectives = e.detective_ids
      elseif e.id == EVENT_SPAWN then
         scores[e.sid] = ScoreInit()
         nicks[e.sid] = e.ni
      end
   end

   if traitors == nil then traitors = {} end
   if detectives == nil then detectives = {} end

   scores = ScoreEventLog(events, scores, traitors, detectives)

   self.Players = nicks
   self.Scores = scores
   self.TraitorIDs = traitors
   self.DetectiveIDs = detectives
   self.StartTime = starttime
   self.Events = events
end

function CLSCORE:ReportEvents(events)
   self:Reset()

   self:Init(events)
   self:ShowMVPPanel()
end

function CLSCORE:Toggle()
   if IsValid(self.Panel) then
      self.Panel:ToggleVisible()
   end
end

local function SortEvents(a, b)
   return a.t < b.t
end

local buff = ""
net.Receive("TTT_ReportStream_Part", function()
   buff = buff .. net.ReadData(CLSCORE.MaxStreamLength)
end)

net.Receive("TTT_ReportStream", function()
   local events = util.Decompress(buff .. net.ReadData(net.ReadUInt(16)))
   buff = ""

   if events == "" then
      ErrorNoHalt("Round report decompression failed!\n")
   end

   events = util.JSONToTable(events)
   if events == nil then
      ErrorNoHalt("Round report decoding failed!\n")
   end

   table.sort(events, SortEvents)
   CLSCORE:ReportEvents(events)
end)

concommand.Add("ttt_save_events", function()
	CLSCORE:SaveLog()
end)
