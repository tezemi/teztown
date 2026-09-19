---- Role variant: Hitman (traitor).
--
-- Always has a live target -- one specific non-traitor (innocent, neutral,
-- or detective, never a fellow traitor) he's paid to kill. The target
-- rotates on a timer (ttt_hitman_target_interval, default 75s) and gets a
-- constant on-screen reminder that they're being hunted, so this is never
-- a silent assassination -- it's a race against the clock and against the
-- target noticing.
--
-- Killing the current target pays him a personal bonus and every traitor a
-- flat share (ttt_hitman_kill_bonus / ttt_hitman_team_bonus). Killing
-- anyone else earns nothing at all -- not the bonus, and not even a share
-- of the normal traitor team milestone credits (CheckCreditAward in
-- player.lua, guarded there directly since that tally isn't attributed to
-- a specific killer the way the bonus above is).

ROLES.Register({
   id    = "hitman",
   name  = "role_hitman",
   desc  = "role_hitman_desc",
   base  = ROLE_TRAITOR,
   color = Color(160, 30, 30),

   enabled = true,
   pct     = 0.34,  -- min 0 / max 1 means this only matters if max is raised
   min     = 0,
   max     = 1,
   chance  = 0.2,   -- ttt_variant_hitman_chance: odds he appears at all this round
})

if SERVER then

local target_interval = CreateConVar("ttt_hitman_target_interval", "75", FCVAR_NOTIFY)
local kill_bonus       = CreateConVar("ttt_hitman_kill_bonus", "3", FCVAR_NOTIFY)
local team_bonus       = CreateConVar("ttt_hitman_team_bonus", "1", FCVAR_NOTIFY)

local ROTATE_TIMER = "hitman_rotate"

-- CurTime() of the next scheduled rotation -- set only inside
-- RotateAllHitmen, never by a forced repick (target died/disconnected), so
-- it always reflects the real timer schedule regardless of what triggered
-- any individual target change. Networked alongside the target itself so
-- clients can show a countdown (see NetworkTarget/the HUDPaint hook below).
local next_rotation_time = 0

-- Living, non-traitor terrorists -- the only players eligible to be a
-- target. except, when given, is left out of the pool so a rotation
-- doesn't just hand the Hitman the same person back immediately.
local function EligibleTargets(except)
   local pool = {}
   for _, ply in ipairs(player.GetAll()) do
      if IsValid(ply) and ply:Alive() and ply:IsTerror() and (not ply:GetTraitor()) and ply != except then
         table.insert(pool, ply)
      end
   end

   return pool
end

-- Tells hitman and target (and, if this is a rotation rather than a first
-- assignment, whoever just stopped being the target) who's who now. All
-- three -- old target included -- get the same net message, so each
-- client's own "am I the target" check just naturally resolves to the
-- right answer without a separate clear message.
local function NetworkTarget(hitman, target, old_target)
   local recipients = {hitman}
   if IsValid(target) then table.insert(recipients, target) end
   if IsValid(old_target) and old_target != target then table.insert(recipients, old_target) end

   net.Start("TTT_HitmanTarget")
      net.WriteEntity(IsValid(target) and target or NULL)
      net.WriteFloat(next_rotation_time)
   net.Send(recipients)
end

local function SetHitmanTarget(hitman, target)
   if not IsValid(hitman) then return end

   local old_target = hitman.hitman_target
   hitman.hitman_target = target

   NetworkTarget(hitman, target, old_target)

   if IsValid(target) then
      LANG.Msg(hitman, "hitman_new_target", {player = target:Nick()})
      LANG.Msg(target, "hitman_you_are_target")
   end
end

-- Picks a fresh target for this Hitman. Tries to avoid repeating whoever
-- he's already after; only falls back to allowing a repeat if they're
-- genuinely the only eligible player left alive.
local function PickHitmanTarget(hitman)
   if not IsValid(hitman) or not hitman:Alive() then return end

   local pool = EligibleTargets(hitman.hitman_target)
   if #pool == 0 then
      pool = EligibleTargets(nil)
   end

   SetHitmanTarget(hitman, #pool > 0 and pool[math.random(#pool)] or nil)
end

local function RotateAllHitmen()
   if GetRoundState() != ROUND_ACTIVE then return end

   next_rotation_time = CurTime() + target_interval:GetFloat()

   for _, ply in ipairs(player.GetAll()) do
      if IsValid(ply) and ply:Alive() and ply:IsTerror() and ply:HasRoleVariant("hitman") then
         PickHitmanTarget(ply)
      end
   end
end

hook.Add("TTTBeginRound", "RoleVariants_HitmanStart", function()
   -- Assign first targets immediately rather than leaving every Hitman
   -- idle for the first interval, then keep rotating on schedule.
   RotateAllHitmen()

   timer.Create(ROTATE_TIMER, target_interval:GetFloat(), 0, RotateAllHitmen)
end)

hook.Add("TTTEndRound", "RoleVariants_HitmanStop", function()
   timer.Remove(ROTATE_TIMER)
end)

local function AwardHitmanBonus(hitman)
   local personal = kill_bonus:GetInt()
   if personal > 0 then
      hitman:AddCredits(personal)
      LANG.Msg(hitman, "hitman_target_killed_you", {num = personal})
   end

   local team = team_bonus:GetInt()
   if team > 0 then
      local traitors = GetTraitorFilter(true)
      for _, ply in ipairs(traitors) do
         ply:AddCredits(team)
      end

      if #traitors > 0 then
         LANG.Msg(traitors, "hitman_target_killed_team", {player = hitman:Nick(), num = team})
      end
   end
end

-- Fires on every death, not just a Hitman's own kills -- whoever's target
-- just died (by anyone's hand, or the Hitman's own) needs a new one.
hook.Add("DoPlayerDeath", "RoleVariants_HitmanCheck", function(victim, attacker)
   if GetRoundState() != ROUND_ACTIVE then return end
   if not IsValid(victim) or not victim:IsPlayer() then return end

   for _, ply in ipairs(player.GetAll()) do
      if IsValid(ply) and ply:Alive() and ply:IsTerror() and ply:HasRoleVariant("hitman")
         and ply.hitman_target == victim then

         if IsValid(attacker) and attacker == ply then
            AwardHitmanBonus(ply)
         end

         -- Deferred a tick: CheckCreditAward (player.lua) still needs to
         -- read this same, still-stale ply.hitman_target for its own
         -- off-target suppression check, and that runs later in this same
         -- death event -- hook.Call only reaches GM:DoPlayerDeath (which
         -- calls CheckCreditAward) after every hook.Add handler, this one
         -- included, has already returned. Overwriting the target here,
         -- synchronously, would make every kill look off-target to it.
         local hitman = ply
         timer.Simple(0, function() PickHitmanTarget(hitman) end)
      end
   end
end)

-- A target who disconnects needs replacing immediately too, same as one
-- who dies -- otherwise the Hitman is stuck pointed at someone who can
-- never come back.
hook.Add("PlayerDisconnected", "RoleVariants_HitmanTargetLeft", function(ply)
   if not IsValid(ply) then return end

   for _, hitman in ipairs(player.GetAll()) do
      if IsValid(hitman) and hitman:Alive() and hitman:IsTerror() and hitman:HasRoleVariant("hitman")
         and hitman.hitman_target == ply then
         PickHitmanTarget(hitman)
      end
   end
end)

-- Cleared every round so a stale target from a previous round (players and
-- their fields persist as entities) can never leak into a new one, both
-- server-side and on whichever clients still think they're involved.
hook.Add("TTTPrepareRound", "RoleVariants_HitmanReset", function()
   timer.Remove(ROTATE_TIMER)
   next_rotation_time = 0

   for _, ply in ipairs(player.GetAll()) do
      if IsValid(ply) then ply.hitman_target = nil end
   end

   net.Start("TTT_HitmanTarget")
      net.WriteEntity(NULL)
      net.WriteFloat(0)
   net.Broadcast()
end)

end -- SERVER

if CLIENT then

surface.CreateFont("HitmanTargetHUD", {font = "Trebuchet24", size = 46, weight = 900, shadow = true})
surface.CreateFont("HitmanOwnHUD",    {font = "Trebuchet24", size = 26, weight = 800, shadow = true})

net.Receive("TTT_HitmanTarget", function()
   local target = net.ReadEntity()
   local next_rotate = net.ReadFloat()

   GAMEMODE.HitmanTarget = IsValid(target) and target or nil
   GAMEMODE.HitmanNextRotate = next_rotate
end)

-- MM:SS until the next rotation, same formatting the round timer itself
-- uses. Never negative even a frame or two after the server's own timer
-- has actually fired, since the new assignment's net message hasn't
-- necessarily arrived yet.
local function RotationCountdown()
   return util.SimpleTime(math.max(0, (GAMEMODE.HitmanNextRotate or 0) - CurTime()), "%02i:%02i")
end

-- Backed by a solid/pulsing box rather than bare text, and low on the
-- screen (just above the standard health/ammo HUD) so it's impossible to
-- lose in the middle of a firefight -- these two are meant to be alarming,
-- not subtle.
local function DrawHitmanBanner(text, font, y, box_color, text_color)
   surface.SetFont(font)
   local tw, th = surface.GetTextSize(text)

   local pad_x, pad_y = 26, 12
   local box_w, box_h = tw + pad_x * 2, th + pad_y * 2
   local box_x = ScrW() / 2 - box_w / 2

   draw.RoundedBox(6, box_x, y, box_w, box_h, box_color)
   draw.SimpleText(text, font, ScrW() / 2, y + box_h / 2, text_color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

   return box_h
end

hook.Add("HUDPaint", "RoleVariants_HitmanHUD", function()
   local client = LocalPlayer()
   if not IsValid(client) or not client:Alive() or GetRoundState() != ROUND_ACTIVE then return end

   local target = GAMEMODE.HitmanTarget

   -- The target's own constant, impossible-to-miss reminder -- a pulsing
   -- red banner, not just red text. Only this client ever receives a
   -- TTT_HitmanTarget naming them, so nobody else's screen shows this.
   if target == client then
      local pulse = math.abs(math.sin(RealTime() * 3))

      DrawHitmanBanner(LANG.GetParamTranslation("hitman_hud_target", {time = RotationCountdown()}),
         "HitmanTargetHUD", ScrH() - 190, Color(140, 0, 0, 165 + pulse * 90), Color(255, 255, 255, 255))
   end

   -- The Hitman's own reminder of who he's after -- only sent to him.
   if IsValid(target) and client:HasRoleVariant("hitman") then
      DrawHitmanBanner(LANG.GetParamTranslation("hitman_hud_your_target", {player = target:Nick(), time = RotationCountdown()}),
         "HitmanOwnHUD", ScrH() - 130, Color(20, 20, 20, 210), Color(255, 210, 210, 255))
   end
end)

-- Overhead icon on the current target, so the Hitman can spot them in a
-- crowd instead of relying on the name alone -- same billboard technique
-- as cl_targetid.lua's "T" over fellow traitors' heads (and the tester
-- part icon in cl_testerparts.lua), just a different, dedicated texture so
-- it doesn't read as either of those. Ignores the depth buffer, same as
-- the tester part icon, so it reads through walls -- only ever visible to
-- the Hitman himself, since GAMEMODE.HitmanTarget is nil on every other
-- client's own machine.
local target_icon_mat = Material("vgui/ttt/custom_marker")
local target_icon_col = Color(255, 255, 255, 220)

local function DrawHitmanTargetIcon()
   local client = LocalPlayer()
   if not IsValid(client) or not client:HasRoleVariant("hitman") then return end

   local target = GAMEMODE.HitmanTarget
   if not IsValid(target) or not target:Alive() then return end

   local pos = target:GetPos()
   pos.z = pos.z + 74

   render.SetMaterial(target_icon_mat)

   cam.IgnoreZ(true)
   render.DrawQuadEasy(pos, client:GetForward() * -1, 10, 10, target_icon_col, 180)
   cam.IgnoreZ(false)
end
hook.Add("PostDrawTranslucentRenderables", "RoleVariants_HitmanTargetIcon", DrawHitmanTargetIcon)

end -- CLIENT
