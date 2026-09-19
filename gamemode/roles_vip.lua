---- Role variant: VIP (innocent).
--
-- The mirror image of the Deputy: instead of a secret held from everyone,
-- this is a secret the innocents keep from the traitors. Only half of them
-- are told who the VIP is by default (reveal_to_team + reveal_pct), with
-- detectives picked first, and whoever's told sees the VIP flagged with a
-- coloured ring and name tag on target ID, just like a detective
-- (target_id_tag) -- but traitors are never told, and nothing about the VIP
-- is broadcast to them.
--
-- reveal_pct is deliberately short of 1: if every innocent knew, "who's the
-- VIP?" would be a free traitor test -- an innocent always answers, a
-- traitor never can. Leaving some innocents out means "I don't know" is
-- also a perfectly normal, honest answer, so asking around no longer
-- outs anyone by itself.
--
-- While the VIP is alive, no traitor can carry more than 1 credit (the same
-- credit_cap_role/credit_cap_amount flags the Spy uses). The VIP is also
-- personally squishier than a normal innocent (damage_taken_mult), so being
-- protected is worth something even before anything happens. Once the VIP
-- is dead -- or was never among the living to begin with, if their holder
-- disconnects -- every innocent takes extra damage in a fight, on the
-- theory that losing them rattles the whole side (on_death_vulnerable_role/
-- on_death_damage_mult, applied in player.lua's PlayerTakeDamage).

ROLES.Register({
   id    = "vip",
   name  = "role_vip",
   desc  = "role_vip_desc",
   base  = ROLE_INNOCENT,
   color = Color(70, 200, 200),

   enabled = true,
   pct     = 0.25,  -- min 0 / max 1 means this only matters if max is raised
   min     = 0,
   max     = 1,
   chance  = 0.17,  -- ttt_variant_vip_chance: odds he appears at all this round

   reveal_to_team = true, -- innocents are told who the VIP is...
   reveal_pct     = 0.5,  -- ...but only half of them (ttt_variant_vip_reveal_pct), detectives first
   target_id_tag  = true, -- ...and whoever's told sees a ring/label on them, like a detective

   credit_cap_role   = ROLE_TRAITOR,
   credit_cap_amount = 1,

   damage_taken_mult = 1.2, -- the VIP themselves takes 20% more damage

   on_death_vulnerable_role = ROLE_INNOCENT,
   on_death_damage_mult     = 1.25
})
