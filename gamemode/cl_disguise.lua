
DISGUISE = {}

local trans = LANG.GetTranslation

function DISGUISE.CreateMenu(parent)
   
   local dform = vgui.Create("DForm", parent)
   dform:SetName(trans("disg_menutitle"))
   dform:StretchToParent(0,0,0,0)
   dform:SetAutoSize(false)

   local owned = LocalPlayer():HasEquipmentItem(EQUIP_DISGUISE)

   if not owned then
      dform:Help(trans("disg_not_owned"))
      return dform
   end

   for i, v in ipairs(LocalPlayer().disg_players) do

      local dbutton = vgui.Create("DButton", dform);

      local bStr = v:Nick();

      if (v == LocalPlayer()) then

         bStr = bStr .. " (Remove Disguise)";

      end

      dbutton:SetText(bStr);
      dbutton:Dock(TOP)
      dbutton:DockMargin(4, 0, 0, 0)

      function dbutton:DoClick()

         net.Start("TTT_Disguise")
         net.WriteString(v:Nick());
         net.WriteString(v:GetModel())
         net.SendToServer();

         parent:GetParent():Close();

      end

   end
   
   --
   -- This is the original behavior
   --
   --[[
   local dcheck = vgui.Create("DCheckBoxLabel", dform)
   dcheck:SetText(trans("disg_enable"))
   dcheck:SetIndent(5)
   dcheck:SetValue(LocalPlayer():GetNWBool("disguised", false))
   dcheck.OnChange = function(s, val)
                        RunConsoleCommand("ttt_set_disguise", val and "1" or "0")
                     end
   dform:AddItem(dcheck)

   dform:Help(trans("disg_help1"))

   dform:Help(trans("disg_help2"))

   dform:SetVisible(true)
   --]]

   return dform
end

function DISGUISE.Draw(client)
   if (not client) or (not client:IsActiveTraitor()) then return end
   
   if (IsValid(client) and client:GetNWString("disguised_player", "nil") ~= "nil") then

      surface.SetFont("TabLarge")
      surface.SetTextColor(255, 0, 0, 230)

      local text = "Disguised As " .. client:GetNWString("disguised_player", "nil");
      local w, h = surface.GetTextSize(text);

      surface.SetTextPos(36, ScrH() - 160 - h)
      surface.DrawText(text)

   end

   --
   -- Original Behavior
   --
   --[[
   if not client:GetNWBool("disguised", false) then return end

   surface.SetFont("TabLarge")
   surface.SetTextColor(255, 0, 0, 230)

   local text = trans("disg_hud")
   local w, h = surface.GetTextSize(text)

   surface.SetTextPos(36, ScrH() - 160 - h)
   surface.DrawText(text)
   ]]
end

concommand.Add("ttt_toggle_disguise", WEPS.DisguiseToggle)
