---- Clientside half of the Traitor Tester Parts objective.
--
-- Jobs: outline the parts for traitors (through walls, and boosted at range
-- -- see below), a much weaker normal-vision outline for everyone else,
-- show progress on everyone's HUD, and reflect confirmed scan results as an
-- auto-tag on the scanned player (scoreboard + target ID both read sb_tag).

local PART_CLASS = "weapon_ttt_tester_part"

local traitor_color  = Color(255, 60, 60)
local innocent_color = Color(80, 220, 80)

-- Passes, not blur size: blur widens the outline (reads as a bigger halo up
-- close), passes stack it additively and just make it brighter, which is
-- what actually carries at distance. No distance falloff for traitors --
-- parts are meant to be visible to them anywhere, always.
local TRAITOR_PASSES = 6

-- How close (and, since ignorez is off here, how unoccluded) a part needs to
-- be before non-traitors get any visual cue on it at all.
local INNO_DIST = 600

-- Only parts nobody is carrying. A halo on a carried part would out its
-- holder to every traitor on the map.
local function LooseParts()
   local out = {}
   for _, wep in ipairs(ents.FindByClass(PART_CLASS)) do
      if IsValid(wep) and not IsValid(wep:GetOwner()) then
         table.insert(out, wep)
      end
   end

   return out
end

local function DrawPartHalos()
   local client = LocalPlayer()
   if not IsValid(client) then return end

   local parts = LooseParts()
   if #parts == 0 then return end

   if client:IsActiveTraitor() then
      -- ignorez (last arg) is what makes these visible through walls
      halo.Add(parts, traitor_color, 2, 2, TRAITOR_PASSES, true, true)
   else
      -- Weak cue only: normal occlusion (no ignorez) and only up close, so
      -- this never becomes a way to find parts you can't already see.
      local cpos = client:GetPos()
      local nearby = {}

      for _, part in ipairs(parts) do
         if cpos:DistToSqr(part:GetPos()) <= (INNO_DIST * INNO_DIST) then
            table.insert(nearby, part)
         end
      end

      if #nearby > 0 then halo.Add(nearby, innocent_color, 2, 2, 1, true, false) end
   end
end
hook.Add("PreDrawHalos", "TesterParts_Halos", DrawPartHalos)

-- Overhead icon for traitors, on top of the halo -- same billboard technique
-- cl_targetid.lua uses for the "T" over fellow traitors' heads, reusing the
-- part's own inventory icon so it reads unambiguously as "a part is here."
local part_icon_mat = Material("vgui/ttt/icon_cse")
local part_icon_col = Color(255, 255, 255, 220)

local function DrawPartIcons()
   local client = LocalPlayer()
   if not IsValid(client) or not client:IsActiveTraitor() then return end

   local parts = LooseParts()
   if #parts == 0 then return end

   local dir = client:GetForward() * -1

   render.SetMaterial(part_icon_mat)

   -- Ignore the depth buffer so this reads through walls, matching the halo.
   cam.IgnoreZ(true)

   for _, part in ipairs(parts) do
      local pos = part:GetPos()
      pos.z = pos.z + 20

      render.DrawQuadEasy(pos, dir, 10, 10, part_icon_col, 180)
   end

   cam.IgnoreZ(false)
end
hook.Add("PostDrawTranslucentRenderables", "TesterParts_Icon", DrawPartIcons)

-- Confirmed scan result: public knowledge, so auto-tag the scanned player
-- for every client (scoreboard label + target ID both read ply.sb_tag).
net.Receive("TTT_TesterScanResult", function()
   local target = net.ReadEntity()
   local is_traitor = net.ReadBit() == 1

   if not IsValid(target) or not target:IsPlayer() then return end

   target.sb_tag = SB_TAGS[is_traitor and "sb_tag_kill" or "sb_tag_innocent"]
end)

surface.CreateFont("TesterPartsHUD", {font = "Trebuchet24",
                                      size = 18,
                                      weight = 900})

local T = LANG.GetTranslation

local function DrawProgress()
   local total = GetGlobalInt("ttt_tester_parts_total", 0)
   if total <= 0 then return end

   local client = LocalPlayer()
   if not IsValid(client) then return end

   local held = GetGlobalInt("ttt_tester_parts_held", 0)
   local all_held = held >= total

   local text = T("tester_parts_hud") .. ": " .. held .. " / " .. total
   local clr = all_held and Color(80, 220, 80) or Color(255, 210, 0)

   draw.SimpleText(text, "TesterPartsHUD", ScrW() / 2, 8, clr,
                   TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
end
hook.Add("HUDPaint", "TesterParts_Progress", DrawProgress)
