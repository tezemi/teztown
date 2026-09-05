---- Role variant: Spy (innocent).
--
-- An innocent planted inside the traitor team's perception of itself: every
-- real traitor sees the Spy as one of their own (scoreboard colour, radar,
-- target ID, the "you were killed by" style, the round-start ally list --
-- everywhere a real traitor would normally identify an ally). While the Spy
-- is alive, the traitors' team chat and voice are jammed entirely, and none
-- of them can carry more than 1 credit.
--
-- Nobody but the Spy is ever told the Spy exists -- not even other
-- innocents -- except the traitors themselves get a vague round-start
-- warning that one is among them, without saying who. Unlike the Kingpin,
-- there's no other custom logic here: the whole variant is expressible with
-- the generic disguise_role / suppress_team_chat_for / credit_cap_role /
-- announce flags (see roles_shd.lua).

ROLES.Register({
   id    = "spy",
   name  = "role_spy",
   desc  = "role_spy_desc",
   base  = ROLE_INNOCENT,
   color = Color(90, 90, 210),

   enabled = true,
   pct     = 0.34,  -- min/max both being 1 means this only matters if max is raised
   min     = 1,
   max     = 1,
   chance  = 1,     -- turn ttt_variant_spy_chance down to make him occasional

   disguise_role          = ROLE_TRAITOR,
   suppress_team_chat_for = ROLE_TRAITOR,
   credit_cap_role        = ROLE_TRAITOR,
   credit_cap_amount      = 1,

   -- Traitors only, not detectives -- announce_role overrides announce's
   -- default "everyone off my own base role" audience. Deliberately vague:
   -- never names the Spy, or the message would defeat the disguise.
   announce      = "spy_announce",
   announce_role = ROLE_TRAITOR
})
