---- Role variant: Rogue (neutral).
--
-- The first neutral variant: not on the traitor side or the innocent side,
-- and wins or loses independently of both of them. A Rogue looks exactly
-- like an innocent to everyone -- no disguise, no announce, nothing tips
-- anyone off that a third faction is even in play -- but shops from the
-- traitor catalogue and wins the round by being the last terror player left
-- alive, traitor or innocent.
--
-- base=ROLE_NEUTRAL draws from the innocent pool at selection time (see
-- PoolFor in roles.lua) since there's no neutral base-role selection step of
-- its own.

ROLES.Register({
   id    = "rogue",
   name  = "role_rogue",
   desc  = "role_rogue_desc",
   base  = ROLE_NEUTRAL,
   color = Color(140, 60, 160),
   -- The HUD role tab is already neutral purple, so the name goes on it in
   -- black rather than vanishing into it.
   hud_color = COLOR_BLACK,

   enabled = true,
   pct     = 0.34,  -- min/max both being 1 means this only matters if max is raised
   min     = 1,
   max     = 1,
   chance  = 1,     -- turn ttt_variant_rogue_chance down to make him occasional

   credits      = 3,            -- his entire starting credits, see SetDefaultCredits
   shop_as_role = ROLE_TRAITOR, -- same catalogue and purchase rules as a traitor

   -- Last terror player standing wins, regardless of who personally landed
   -- the final kill -- simplest reading of "kill all innocents and
   -- traitors" that doesn't need its own kill-attribution tracking. Counts
   -- other neutrals too, so raising ttt_variant_rogue_max makes them fight
   -- it out rather than both winning at once.
   win_check = function(ply)
      for _, other in ipairs(player.GetAll()) do
         if IsValid(other) and other != ply and other:Alive() and other:IsTerror() then
            return false
         end
      end

      return true
   end
})
