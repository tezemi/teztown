-- SteamIDs guaranteed to become Traitor at the next role selection. Set via
-- ttt_guarantee_traitor, consumed by SelectRoles() in init.lua.
GuaranteedTraitors = GuaranteedTraitors or {}

function GetTraitors()
   local trs = {}
   for k,v in ipairs(player.GetAll()) do
      if v:GetTraitor() then table.insert(trs, v) end
   end

   return trs
end

function CountTraitors() return #GetTraitors() end

---- Role state communication

-- Send every player their role
local function SendPlayerRoles()
   for k, v in ipairs(player.GetAll()) do
      net.Start("TTT_Role")
         net.WriteUInt(v:GetRole(), 2)
      net.Send(v)
   end
end

local function SendRoleListMessage(role, role_ids, ply_or_rf)
   net.Start("TTT_RoleList")
      net.WriteUInt(role, 2)

      -- list contents
      local num_ids = #role_ids
      net.WriteUInt(num_ids, 8)
      for i=1, num_ids do
         net.WriteUInt(role_ids[i] - 1, 7)
      end

   if ply_or_rf then net.Send(ply_or_rf)
   else net.Broadcast() end
end

local function SendRoleList(role, ply_or_rf, pred)
   local role_ids = {}
   for k, v in ipairs(player.GetAll()) do
      if v:IsRole(role) then
         if not pred or (pred and pred(v)) then
            table.insert(role_ids, v:EntIndex())
         end
      end
   end

   SendRoleListMessage(role, role_ids, ply_or_rf)
end

-- Tell traitors about other traitors

function SendTraitorList(ply_or_rf, pred) SendRoleList(ROLE_TRAITOR, ply_or_rf, pred) end
function SendDetectiveList(ply_or_rf) SendRoleList(ROLE_DETECTIVE, ply_or_rf) end

-- this is purely to make sure last round's traitors/dets ALWAYS get reset
-- not happy with this, but it'll do for now
function SendInnocentList(ply_or_rf)
   -- Send innocent and detectives a list of actual innocents + traitors, while
   -- sending traitors only a list of actual innocents.
   local inno_ids = {}
   local traitor_ids = {}
   for k, v in ipairs(player.GetAll()) do
      if v:IsRole(ROLE_INNOCENT) then
         table.insert(inno_ids, v:EntIndex())
      elseif v:IsRole(ROLE_TRAITOR) then
         table.insert(traitor_ids, v:EntIndex())
      end
   end

   -- traitors get actual innocent, so they do not reset their traitor mates to
   -- innocence
   SendRoleListMessage(ROLE_INNOCENT, inno_ids, GetTraitorFilter())

   -- detectives and innocents get an expanded version of the truth so that they
   -- reset everyone who is not detective
   table.Add(inno_ids, traitor_ids)
   table.Shuffle(inno_ids)
   SendRoleListMessage(ROLE_INNOCENT, inno_ids, GetInnocentFilter())
end

function SendConfirmedTraitors(ply_or_rf)
   SendTraitorList(ply_or_rf, function(p) return p:GetNWBool("body_found") end)
end

function SendFullStateUpdate()
   SendPlayerRoles()
   SendInnocentList()
   SendTraitorList(GetTraitorFilter())
   SendDetectiveList()
   -- not useful to sync confirmed traitors here
end

function SendRoleReset(ply_or_rf)
   local plys = player.GetAll()

   net.Start("TTT_RoleList")
      net.WriteUInt(ROLE_INNOCENT, 2)

      net.WriteUInt(#plys, 8)
      for k, v in ipairs(plys) do
         net.WriteUInt(v:EntIndex() - 1, 7)
      end

   if ply_or_rf then net.Send(ply_or_rf)
   else net.Broadcast() end
end

---- Console commands

local function request_rolelist(ply)
   -- Client requested a state update. Note that the client can only use this
   -- information after entities have been initialised (e.g. in InitPostEntity).
   if GetRoundState() != ROUND_WAIT then

      SendRoleReset(ply)
      SendDetectiveList(ply)

      if ply:IsTraitor() then
         SendTraitorList(ply)
      else
         SendConfirmedTraitors(ply)
      end
   end
end
concommand.Add("_ttt_request_rolelist", request_rolelist)

local function force_terror(ply)
   ply:SetRole(ROLE_INNOCENT)
   ply:UnSpectate()
   ply:SetTeam(TEAM_TERROR)

   ply:StripAll()

   ply:Spawn()
   ply:PrintMessage(HUD_PRINTTALK, "You are now on the terrorist team.")

   SendFullStateUpdate()
end
concommand.Add("ttt_force_terror", force_terror, nil, nil, FCVAR_CHEAT)

local function force_traitor(ply)
   ply:SetRole(ROLE_TRAITOR)

   SendFullStateUpdate()
end
concommand.Add("ttt_force_traitor", force_traitor, nil, nil, FCVAR_CHEAT)

local function force_detective(ply)
   ply:SetRole(ROLE_DETECTIVE)

   SendFullStateUpdate()
end
concommand.Add("ttt_force_detective", force_detective, nil, nil, FCVAR_CHEAT)


-- Case-insensitive substring match on nick, or an exact userid. Returns nil
-- (with an explanation via out()) if there isn't exactly one match.
local function FindTargetPlayer(str, out)
   local byid = tonumber(str) and player.GetByID(tonumber(str))
   if IsValid(byid) then return byid end

   local matches = {}
   local needle = string.lower(str)
   for _, p in ipairs(player.GetAll()) do
      if IsValid(p) and string.find(string.lower(p:Nick()), needle, 1, true) then
         table.insert(matches, p)
      end
   end

   if #matches == 1 then
      return matches[1]
   elseif #matches == 0 then
      out("No player found matching '" .. str .. "'.")
   else
      out("'" .. str .. "' matches more than one player, be more specific.")
   end

   return nil
end

-- Admin-only, silent (server console feedback to the caller only, no
-- broadcast). Guarantees a player will be picked as Traitor at the next role
-- selection; see SelectRoles() in init.lua for where this is consumed.
--   ttt_guarantee_traitor            guarantee yourself
--   ttt_guarantee_traitor <target>   guarantee <target>
--   ttt_guarantee_traitor <target> 0 clear <target>'s guarantee (use your
--                                    own name to clear your own)
local function guarantee_traitor(ply, cmd, args)
   if IsValid(ply) and (not ply:IsSuperAdmin()) then return end

   local out = IsValid(ply) and function(msg) ply:PrintMessage(HUD_PRINTCONSOLE, msg) end or print

   local target = ply
   if args[1] then
      target = FindTargetPlayer(args[1], out)
   end

   if not IsValid(target) then
      if not args[1] then out("Console must specify a target player.") end
      return
   end

   if args[2] == "0" then
      GuaranteedTraitors[target:SteamID()] = nil
      out(target:Nick() .. " is no longer guaranteed Traitor next round.")
   else
      GuaranteedTraitors[target:SteamID()] = true
      out(target:Nick() .. " is now guaranteed Traitor next round.")
   end
end
concommand.Add("ttt_guarantee_traitor", guarantee_traitor)


local function force_spectate(ply, cmd, arg)
   if IsValid(ply) then
      if #arg == 1 and tonumber(arg[1]) == 0 then
         ply:SetForceSpec(false)
      else
         if not ply:IsSpec() then
            ply:Kill()
         end

         GAMEMODE:PlayerSpawnAsSpectator(ply)
         ply:SetTeam(TEAM_SPEC)
         ply:SetForceSpec(true)
         ply:Spawn()

         ply:SetRagdollSpec(false) -- dying will enable this, we don't want it here
      end
   end
end
concommand.Add("ttt_spectate", force_spectate)
net.Receive("TTT_Spectate", function(l, pl)
   force_spectate(pl, nil, { net.ReadBool() and 1 or 0 })
end)
