---- Role variant: Deputy (detective).
--
-- A full detective who nobody knows is a detective -- not innocents, not
-- traitors, not even a second real detective if the round happens to have
-- one. hide_role (see roles_shd.lua) does all the heavy lifting: it keeps
-- them off the public detective broadcast, off radar, off the death-hat,
-- and off their own corpse's search results, so every system that would
-- normally out a detective reads them as a plain innocent instead. Their own
-- client still sees their real role, so their shop, credits, and equipment
-- all work exactly like a normal detective's.
--
-- no_team_chat closes the one gap hide_role can't: if a second real
-- detective exists, the built-in detective team-chat channel would still
-- print the Deputy's name under a "DETECTIVE" tag the moment they used it.
--
-- The result is a pure trade-off rather than a power spike: full detective
-- tools, but no credibility to back them up. Convincing anyone a search
-- result is real is on the Deputy alone -- and nothing stops a traitor
-- caught red-handed from claiming to be the Deputy right back.

ROLES.Register({
   id    = "deputy",
   name  = "role_deputy",
   desc  = "role_deputy_desc",
   base  = ROLE_DETECTIVE,
   -- Plainclothes silver-grey -- reads clearly against the blue detective
   -- HUD panel (unlike a colour close to the panel's own blue or purple).
   color = Color(190, 190, 200),

   enabled = true,
   pct     = 0.34,  -- min 0 / max 1 means this only matters if max is raised
   min     = 0,
   max     = 1,
   chance  = 0.33,  -- ttt_variant_deputy_chance: odds he appears at all this round

   hide_role    = true, -- never revealed as a detective, by anyone, ever
   no_team_chat = true  -- closes the detective-team-chat leak to a 2nd detective
})
