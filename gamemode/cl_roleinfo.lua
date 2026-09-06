---- Role reference: the first tab of the F1 menu.
--
-- Opens on whatever the local player currently is, variant included, and
-- lets them read up on every other role from the same screen. The base roles
-- are listed here; variants come straight out of the ROLES registry and slot
-- in under whichever base role they sit on, so a newly registered variant
-- appears in this list on its own. To give one a body, add the language keys
-- help_role_<id>_tag, help_role_<id>_mech and help_role_<id>_psych -- the
-- two list keys are newline-separated, one bullet per line.

ROLEINFO = {}

local T = LANG.GetTranslation
local TryT = LANG.TryTranslation
local GetRaw = LANG.GetRawTranslation

surface.CreateFont("HelpRoleTitle",   {font = "Trebuchet24", size = 28, weight = 900, shadow = true, extended = true})
surface.CreateFont("HelpRoleSub",     {font = "Trebuchet24", size = 15, weight = 500, shadow = true, extended = true})
surface.CreateFont("HelpRoleTag",     {font = "Trebuchet24", size = 16, weight = 600, shadow = true, extended = true})
surface.CreateFont("HelpRoleSection", {font = "Trebuchet24", size = 17, weight = 900, shadow = true, extended = true})
surface.CreateFont("HelpRoleBody",    {font = "Trebuchet24", size = 15, weight = 400, shadow = true, extended = true})
surface.CreateFont("HelpRoleList",    {font = "Trebuchet24", size = 16, weight = 700, shadow = true, extended = true})
surface.CreateFont("HelpRoleListSub", {font = "Trebuchet24", size = 15, weight = 500, shadow = true, extended = true})

-- The F1 frame's default skin gives DScrollPanel/DPanel a light background,
-- which is why the light text below used to wash out -- everything here
-- paints its own dark background explicitly rather than trusting the skin.
local col_bg      = Color(26, 26, 30)   -- page background (sidebar + content)
local col_header  = Color(42, 42, 48)   -- header card, elevated over col_bg
local col_sel     = Color(58, 58, 66)   -- selected sidebar row
local col_hover   = Color(46, 46, 52)   -- hovered sidebar row
local col_body    = Color(214, 214, 222)
local col_dim     = Color(160, 160, 170)

-- Same role colours the round report and chat already use, so a role looks
-- like itself everywhere.
local base_roles = {
   {id = "innocent",  role = ROLE_INNOCENT,  color = Color(80, 200, 80)},
   {id = "detective", role = ROLE_DETECTIVE, color = Color(80, 140, 255)},
   {id = "traitor",   role = ROLE_TRAITOR,   color = Color(220, 60, 60)},
   -- No plain-neutral page: neutral only ever exists as a variant, so this
   -- one contributes a group label and its variants, nothing clickable.
   {id = "neutral",   role = ROLE_NEUTRAL,   color = Color(175, 105, 215), group_only = true}
}

-- Flat top-to-bottom list of what the sidebar shows: base role pages, each
-- followed by the variants sitting on it.
local function BuildPages()
   local pages = {}
   local variants = ROLES.GetAll()

   for _, base in ipairs(base_roles) do
      if base.group_only then
         table.insert(pages, {group = true, title = TryT(base.id), color = base.color})
      else
         table.insert(pages, {
            key   = base.id,
            title = TryT(base.id),
            color = base.color
         })
      end

      for _, v in ipairs(variants) do
         if v.base == base.role then
            table.insert(pages, {
               key     = v.id,
               title   = TryT(v.name),
               color   = v.color,
               variant = true
            })
         end
      end
   end

   return pages
end

-- Which page to open on. A variant beats its base role, so a Kingpin lands
-- on the Kingpin page rather than the generic Traitor one.
local function CurrentKey()
   local ply = LocalPlayer()
   if not IsValid(ply) or not ply.GetRoleVariant then return "innocent" end

   local vid = ply:GetRoleVariant()
   if vid and ROLES.Get(vid) then return vid end

   return ply:GetRoleStringRaw() or "innocent"
end

---- Content

local function AddSection(parent, title, color)
   local lbl = vgui.Create("DLabel", parent)
   lbl:SetFont("HelpRoleSection")
   lbl:SetTextColor(color)
   lbl:SetText(string.upper(title))
   lbl:SizeToContents()
   lbl:Dock(TOP)
   lbl:DockMargin(0, 10, 0, 6)
end

-- One bullet, hanging-indented so wrapped lines line up under the text
-- rather than under the dot. The label sizes itself to the wrapped text, so
-- the row has to take its height from the label after it has laid out.
local function AddBullet(parent, text, color)
   local row = vgui.Create("DPanel", parent)
   row:SetPaintBackground(false)
   row:Dock(TOP)
   row:DockMargin(4, 0, 0, 7)

   local dot = vgui.Create("DLabel", row)
   dot:SetFont("HelpRoleBody")
   dot:SetTextColor(color)
   dot:SetText("•")
   dot:SizeToContents()

   local lbl = vgui.Create("DLabel", row)
   lbl:SetFont("HelpRoleBody")
   lbl:SetTextColor(col_body)
   lbl:SetWrap(true)
   lbl:SetAutoStretchVertical(true)
   lbl:SetText(text)

   row.PerformLayout = function(s)
      dot:SetPos(0, 0)

      lbl:SetPos(14, 0)
      lbl:SetWide(math.max(1, s:GetWide() - 14))
      lbl:InvalidateLayout(true) -- settle the wrap now, not next frame

      s:SetTall(math.max(lbl:GetTall(), 16))
   end
end

-- Newline-separated language string -> one bullet per line.
local function AddBulletList(parent, raw, color)
   for _, line in ipairs(string.Explode("\n", raw)) do
      line = string.Trim(line)
      if line != "" then
         AddBullet(parent, line, color)
      end
   end
end

function ROLEINFO:BuildPage(content, page)
   content:Clear()

   local is_current = (page.key == CurrentKey())

   -- Header: colour stripe, role name, and what kind of role it is. Sized
   -- from the actual text height plus fixed top/bottom padding, so the text
   -- is always truly centered rather than eyeballed against a fixed height.
   local header = vgui.Create("DPanel", content)
   header:Dock(TOP)
   header:DockMargin(0, 0, 0, 4)
   header.Paint = function(s, w, h)
      draw.RoundedBox(4, 0, 0, w, h, col_header)

      surface.SetDrawColor(page.color)
      surface.DrawRect(0, 0, 4, h)
   end

   local pad_v = 8
   local cur = nil

   if is_current then
      cur = vgui.Create("DLabel", header)
      cur:SetFont("HelpRoleSub")
      cur:SetTextColor(page.color)
      cur:SetText(string.upper(T("help_role_current")))
      cur:SizeToContents()
   end

   local title = vgui.Create("DLabel", header)
   title:SetFont("HelpRoleTitle")
   title:SetTextColor(page.color)
   title:SetText(page.title)
   title:SizeToContents()

   if cur then
      local gap = 2
      header:SetTall(pad_v * 2 + cur:GetTall() + gap + title:GetTall())

      cur:SetPos(16, pad_v)
      title:SetPos(16, pad_v + cur:GetTall() + gap)
   else
      header:SetTall(pad_v * 2 + title:GetTall())

      title:SetPos(16, pad_v)
   end

   -- Tagline: the one-line pitch for the role
   local tag = GetRaw("help_role_" .. page.key .. "_tag")
   if tag then
      local lbl = vgui.Create("DLabel", content)
      lbl:SetFont("HelpRoleTag")
      lbl:SetTextColor(col_dim)
      lbl:SetWrap(true)
      lbl:SetAutoStretchVertical(true)
      lbl:Dock(TOP)
      lbl:DockMargin(8, 12, 12, 14)
      lbl:SetText(tag)
   end

   local mech = GetRaw("help_role_" .. page.key .. "_mech")
   if mech then
      AddSection(content, T("help_role_mech"), page.color)
      AddBulletList(content, mech, page.color)
   end

   local psych = GetRaw("help_role_" .. page.key .. "_psych")
   if psych then
      AddSection(content, T("help_role_psych"), page.color)
      AddBulletList(content, psych, page.color)
   end
end

---- Panel

function ROLEINFO:CreatePanel(parent)
   local pages = BuildPages()
   local current = CurrentKey()

   local list = vgui.Create("DScrollPanel", parent)
   list:Dock(LEFT)
   list:SetWide(150)
   list.Paint = function(s, w, h) draw.RoundedBox(0, 0, 0, w, h, col_bg) end

   local content = vgui.Create("DScrollPanel", parent)
   content:Dock(FILL)
   content:DockMargin(10, 0, 0, 0)
   content.Paint = function(s, w, h) draw.RoundedBox(0, 0, 0, w, h, col_bg) end

   local buttons = {}
   local selected = nil

   local function Select(page)
      selected = page.key

      for _, b in pairs(buttons) do
         b.is_selected = (b.page_key == page.key)
      end

      self:BuildPage(content, page)
   end

   for _, page in ipairs(pages) do
      if page.group then
         local lbl = vgui.Create("DLabel", list)
         lbl:SetFont("HelpRoleList")
         lbl:SetTextColor(page.color)
         lbl:SetText(page.title)
         lbl:SizeToContents()
         lbl:Dock(TOP)
         lbl:DockMargin(6, 6, 0, 2)
      else
         local btn = vgui.Create("DButton", list)
         btn:Dock(TOP)
         btn:DockMargin(page.variant and 12 or 0, 1, 4, 1)
         btn:SetTall(24)
         btn:SetFont(page.variant and "HelpRoleListSub" or "HelpRoleList")
         btn:SetText((page.key == current and "> " or "") .. page.title)
         btn:SetContentAlignment(4) -- left
         btn:SetTextInset(8, 0)
         btn:SetTextColor(page.variant and col_body or page.color)

         btn.page_key = page.key
         btn.is_selected = false

         btn.Paint = function(s, w, h)
            if s.is_selected then
               draw.RoundedBox(3, 0, 0, w, h, col_sel)
               surface.SetDrawColor(page.color)
               surface.DrawRect(0, 0, 3, h)
            elseif s:IsHovered() then
               draw.RoundedBox(3, 0, 0, w, h, col_hover)
            end
         end

         btn.DoClick = function() Select(page) end

         table.insert(buttons, btn)

         if page.key == current then Select(page) end
      end
   end

   -- Nothing matched the local player's role -- spectating before roles are
   -- handed out, say -- so fall back to the first real page.
   if not selected then
      for _, page in ipairs(pages) do
         if not page.group then
            Select(page)
            break
         end
      end
   end
end
