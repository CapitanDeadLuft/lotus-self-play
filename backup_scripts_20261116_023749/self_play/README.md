# Self Play

`Self Play.lua` runs the shared role, lane, farming, shopping, vision, recovery and combat decisions. `self_play/heroes/` contains optional hero behavior. Heroes without a registered module use the shared bot.

## Menu and modes

`Bot > Control > Bot mode` selects what the bot does:

| Mode | Behavior |
| --- | --- |
| Full game | Complete laning, farming, fighting, pushing and objectives. |
| Lane farming only | Stays in the assigned lane: last hits, denies, spacing and the first creep block. No fights, rotations, runes or jungle. Retreat and consumables stay active. |
| Creep block only | Blocks every allied wave in the assigned lane and waits on the lane path behind the front tower between waves. |
| Stack jungle camps | Any role stacks allied camps (including ancients) within 7,000 units and pre-positions for the next minute. |
| Pull lane wave | Pulls the small (or medium) camp into the allied wave at the measured crossing time. |

`Tuning` holds fight aggression (the margin the fight simulator needs before committing) and the mana kept for fights. `Behaviors` toggles each subsystem separately, including stacking, pulling, runes, joining allied fights, fight simulation, BKB/Manta use (turn off when Umbrella Dodger handles them) and build-driven selling.

## Controlling allies who left

`Bot > Control > Heroes to control` chooses My hero, My hero + departed allies, or Departed allies only. An allied hero counts as departed when no current player has it as their assigned hero (the same check Control Ally uses). Each controlled hero gets its own bot context and plays the full game (lane, farm, fight, push, items) through the local player's shared control; departed heroes never shop, sell, buy back or craft neutrals. A departed ally takes the best role still free among controlled heroes. `coordination.lua` lets controlled heroes share fight targets and stops them farming the same wave or camp, stacking the same camp, racing for the same rune or controlling each other's summons. Ordering a controlled ally yourself pauses only that hero.

## Game sense, wards and supports

`brain.lua` keeps per-game memory: each death raises caution (fading over about five minutes), repeated deaths (three within seven minutes, or two early as a core) switch on survival mode, and being behind or having many enemies missing adds caution. It also scores danger at any point from visible enemies, where fogged enemies could have walked since last seen, enemy towers, incoming teleports, recent death sites and depth into enemy territory. Caution raises the retreat threshold, demands a bigger simulated fight margin, lowers the fight score, blocks initiations while dying repeatedly, and restricts lane and jungle farming to low-danger spots.

`ward_spots.lua` chooses observer spots by what they watch (gank routes into our lane while laning, river runes, enemy jungle when ahead, our jungle entrances when behind, the area ahead of an escorted core), preferring high ground and rejecting our camp spawn boxes, trees, unsafe spots, overlap with existing wards and areas our towers already see. Sentries are moved out of camp spawn boxes.

Supports no longer shadow a core who is farming safely; they escort cores near enemies or pushing, and otherwise ward, stack camps within 4,500 units, farm empty lanes or hold a safe position. Arcane Boots, Mekansm and Guardian Greaves count allies in range, Holy Locket heals the most endangered ally and Pavise shields an ally under attack. Long trips without a ready TP walk through a Twin Gate when that saves at least ten seconds.

Dedicated modules: Zeus (global Thundergod's Wrath kills, Scepter Nimbus on fights, Lightning Bolt finishing and interrupts, Heavenly Jump escape), Lion (Finger of Death with kill stacks, Hex priorities, Earth Spike), Lina (Laguna kills, delay-aware Light Strike Array) and Crystal Maiden (Freezing Field only when it hits several enemies and the channel is survivable). Abilities missing from the catalog, such as Scepter and Shard grants, take their damage and disable values from the game data.

## Fight simulation

`fight_sim.lua` simulates every visible, fogged (maphack/fog memory) and teleporting enemy hero near a fight against allied heroes and controlled summons, in 0.1 s steps. Each unit has effective HP (health, shields, armor and magic resistance), physical DPS, spell burst, stun/hex/root seconds read from ability KV values, current stuns, active or ready BKB, arrival time and tower damage. Allies who are not yet fighting get a reaction delay. Results gate solo engagements, joining allied fights, teleporting into fights and per-tick retreat decisions: a fight that kills the hero is refused or abandoned, a won team fight is taken.

## Builds, skills and hero selection

`build_brain.lua` ports the build logic of [Build Brain](https://github.com/BraVoEw/Scripts-Umbrella) v2.3.0 by BraVoEw and is the default build source (`Behaviors > Item builds > Build source`). It downloads the published `build-brain-data/builds.txt` (high-rank match statistics per hero and position, with mirrors on jsDelivr), checks the version hourly and caches it as `build_brain_builds.txt` in the cheat folder, the same file the standalone Build Brain script uses. For the bot's position it takes the start kit with duplicate counts, the early and core items ordered by their typical purchase time, the situational pool, per-item buy rates and the full skill order with talents (falling back to the hero's most played position when the requested one has fewer than 100 games). Cheap items whose timing has long passed, or that sit before an item the hero already owns, are skipped. With `Add counter items` on it inserts answers the hero actually buys (buy rate of at least 3% or already in its pool): a counter to an enemy's item (BKB, Ghost, Glimmer, Satanic, Linken's Sphere, Aeon Disk and so on) right after the next unfinished item, and up to two more for the enemy lineup's tags (evasion, healing, illusions, invisibility, saves, silences, escapes, disables, magic or physical burst, tanks) and for the damage type the hero is actually taking. Sell and disassemble steps for this route come from the Draft Helper inventory simulation. Draft Helper's own route is used when Build Brain has no data for the hero or when it is selected as the source.

`draft_data.lua` ports the data layer, draft model and item planner from [Draft Helper](https://github.com/But3rflys/umbrella-work) v2.0.0-beta.21 by qfun, using its published `draft-data` statistics (cached in `configs/self_play_draft_data.dat`). The planner produces the start kit with quantities, the ordered item route for the hero's position, counter items for the actual enemy heroes and their current items, and sell, disassemble and consume steps. The shop refreshes the plan every 15 seconds and executes those steps. Build Brain supplies the skill and talent order; Dota2ProTracker is only asked when Build Brain has no skill data. Auto pick ranks available heroes with the draft model (synergy, counters, lane matchups and counter-pick risk) for the chosen rank bracket, adds the user's priority lists, and skips a few heroes the bot cannot play unless prioritized.

Talents are learned by clicking the talent tree. When the tree is not built or another unit is selected, the exact talent entity is upgraded through `Abilities.AttemptToUpgrade`; unacknowledged attempts rotate to the train-ability order.

## Strategy

`strategy.lua` tracks the game phase, enemies dead, alive and unaccounted for, and respawn times. Mid and late game farming avoids points near known enemies and deep enemy territory while several enemies are missing. Cores siege with the nearest allied wave while two or more enemies are dead, walk to unfarmed jungle camps between waves, and keep buyback gold after 30 minutes. Supports escort a core after laning instead of pushing lanes alone. Allied waves, lane paths and fogged enemy waves come from `LaneGroupsManager` (`waves.lua`).

## Retreating and defending buildings

`siege.lua` decides whether a building under creep pressure is worth a trip. For every lane it finds the next standing building the enemy wave will hit (outermost tower, then barracks, then tier-four towers and the Ancient). It reads enemy waves from `LaneGroupsManager` (visible and fogged groups, with estimated composition for fogged creeps) or from visible creeps, and simulates the fight at the building: creep damage uses attack types against structures (melee 70%, ranged 35%, siege 250%) and the building's armor, nearby allied towers focus the weakest creep, our own lane creeps between the wave and the building absorb part of it, and the hero joins from its arrival time (walking or TP). The result is the HP the building loses with and without us. That difference is turned into gold (the building's value, higher for T1/T2 during laning; a building that would fall counts in full) and compared with the trip: time away from farm at the hero's gold rate, a TP scroll, minus the creep gold the hero gets from clearing the wave. Waves that the tower handles, waves our own creeps meet first, buildings that fall before we can arrive and trips that cost more than they save are let through, and the reason is written to the debug log (`[SelfPlay siege]`). When several controlled heroes could answer, only the fastest one goes. Hero sieges still go through the fight simulator and base counterattack logic. With `Use glyph to save buildings` on, the glyph is pressed when the measured HP loss would finish a T2 or better (or a T1 with allies nearby) within 3.5 seconds.

Retreat thresholds start from the preset and move with the situation: they rise when enemies or enemy towers are close (`brain.danger`), after recent deaths, and late in the game when respawn timers are long. A chased hero with a Blink Dagger, Anti-Mage blink or Queen of Pain blink jumps toward safety, and home or defend teleports are not started when a visible enemy can reach the hero during the channel or a fogged enemy is expected nearby.

## Movement, tower dives and kill securing

`field.lua` scores standing spots: inside an enemy hero's attack reach (plus a short step), inside reach of enemy lane creeps that are not already fighting our creeps, near fogged enemies or enemy teleports, inside enemy tower range, and pressed against trees. Local repositioning moves (lane spacing, waiting at the safe edge, regeneration cover) pick the cheapest nearby spot and keep it between ticks instead of jittering. Chases, last-hit approaches, pulls, wards, fights and escapes are not rerouted.

`dive.lua` decides whether to follow a hero under its tower. It predicts where the target will be when the kill lands, finds the towers covering that strike point, and adds up the time spent in tower range (entering, the kill itself, walking back out), the tower shots taken (fewer when an allied hero or creeps are tanking), and the damage from the target and nearby enemies. A dive is taken only when the kill is likely within 4.5 seconds and the hero keeps at least 12% HP (25% unless the target is almost dead). An approved dive lets the hero inside that tower's range and ignores its aggro for the dive; a rejected one drops the target for three seconds so the bot does not walk to the tower edge, turn back and search the fog. Decisions are logged as `[SelfPlay dive]`.

Damaging spells first check every visible enemy hero in range: if the spell kills one (after magic or physical resistance, barriers and regeneration until it lands), it is cast on that hero even when the fight focus is someone else. Damage-over-time spells count their full damage (`damage_per_second` times `duration`). Disables on an already stunned or hexed hero wait until the stun is about to end and then chain into it.

WardHelper's observer spots are read from `XHelpers.GetScript("WardHelper").positions_observer` and weighted by their survivability and how often they are used in matches; `positions_sentry_camp_block` is read too for later camp-block logic.

## Umbrella damage prediction

`prediction.lua` wraps Umbrella's `LIB_DAMAGE_PREDICTION` (see `UmbrellaAPI/globals/LIB_DAMAGE_PREDICTION.md`). For a unit it runs `begin_outgoing` and the `collect_*` passes, reads `targets[unit].attacks` (`attacker`, `damage`, `max_damage`, `time_to_damage`, `is_tower`) and caches the result for 0.1 seconds; `unit_attack` tells which unit each attacker is swinging at. It is used for:

- Last hits and denies: attacks the bot's own tracker did not see (tower shots, other heroes' projectiles, ability projectiles) are merged into the creep's health timeline; an attack from the same source within 0.35 seconds of a known one is treated as the same hit.
- Creep aggro: enemy creeps that the library sees attacking our hero count as aggro immediately.
- Threat: damage already on its way to our hero in the next 1.5 seconds raises the danger estimate, and an enemy hero attacking us marks the lane as contested.
- Spell kills: allied attacks that land before a spell does are subtracted from the target's health when checking whether the spell kills.

- Base defense: creeps the library sees hitting the threatened building are cleared first, then siege and ranged creeps; the defender walks out to any safe wave within 1600 of the building instead of waiting beside it.
- Saves: Glimmer Cape, Force Staff, Lotus Orb and similar items count the damage already flying at each ally.

If the global is missing or any call fails, the bot falls back to its own estimates and logs the error in `[SelfPlay prediction]`.

## Commitment and escorting

Decisions get a little inertia so the bot does not change what it is doing every second: a task it just started keeps a 60-point bonus for 1.5 seconds, and after a detected flip-flop the current task keeps an 80-point bonus for 3 seconds; neither can lift a task above 845, so retreating (850) always wins. An allied fight is entered with strict checks but kept with looser ones, and its target is held for 3 seconds. The hero's current target is kept for 2.5 seconds unless it dies, becomes invulnerable, walks away, or another hero drops below 15% health.

Supports escorting or protecting a core take a cover spot 330-650 units behind it, on the side away from the closest enemy, at a random angle, cleaned up with the standing-spot scorer. The spot is refreshed every 1.4-3.8 seconds (0.8-1.6 while the core moves) or when the core moves away, so the escort moves with the core instead of freezing in one place.

## Pushing and fighting around enemy towers

The team push task starts on its own during a push window (enemies dead or outnumbered) when an ally is near the building, not only after allies are already hitting it. A tower with no creep cover can still be hit when no enemy hero is within 1500, an ally is near, and the hero keeps at least 55% health after the next two or three tower shots; it steps out when that budget runs out. While on an objective, an enemy hero within 1000 is hit with spells first if the fight is not outnumbered.

During fights (and while deciding whether to join one), an enemy tower that is busy shooting a healthy allied hero or our creeps does not fence off its range: the hero may stand and cast inside it, because towers switch to whoever right-clicks a hero, not to casters. Right-clicking a hero under the tower is still governed by the dive check.

Escort is only taken for a core in danger (an enemy within 1500, or within 2600 when the core is not farming), pushing, or roaming on the enemy half; a core farming its own jungle is left alone. The escort keeps its current core unless another is clearly a better fit, and cover spots whose path runs into enemies are replaced by a spot closer to home. Movement stops caused by risky paths now read `Stop short, enemies ahead` or `Stop outside enemy tower` instead of `Wait at safe edge`.

## Finishing the enemy base

When the hero stands within 1800 of an enemy Ancient, barracks, or any enemy building below 35% health, and an ally is with it (or the team push task targets that building), the bot treats the game as being finished there: base defense yields (unless our own Ancient is lower than theirs), outer tower defense is not offered, and non-lethal danger such as an ambush estimate does not trigger a retreat until health falls below 30%.

Freezing Field keeps the hero locked for the first second after the order, before the channel starts, so no other behavior can issue a move that cancels it.

## Hero modules

Register the internal hero name in `heroes/registry.lua` and return a table from the corresponding Lua file. Module tables contain immutable definitions; store match state in `ctx.heroState`. The registry resets that state on manual control, death and hero/context changes.

| Hook | Contract |
| --- | --- |
| `reserved` | Set of ability/item internal names excluded from generic casting, including toggles. The module owns their decisions. |
| `update(ctx, combat, retreat)` | Return true when an order was issued or a bounded sequence must retain control. Return false to continue shared decisions. |
| `locked(ctx)` | Whether an active sequence must finish before an ordinary attack commitment. Hard danger and manual control still take priority. |
| `skillPriority(ctx, name)` | Additional score for an otherwise legal skill upgrade. |
| `build(ctx, plan)` | Optional transformation of the provider plan. Shadow Fiend does not override his provider build. |
| `unit(ctx, combat, unit)` | Return true when the module owns this controlled unit for the tick. Otherwise shared unit control continues. |
| `duringCast(ctx, combat)` | Narrow exception for an action legal during an existing spell, such as Sleight Chains or selecting a Dissimilate exit. |
| `inventoryUnits(ctx)` / `inventory(ctx, entries)` | Extra persistent inventories and ownership-aware transfers, currently used by Lone Druid. |

Use `heroes/common.lua` for legal target checks, metadata values, facing orders and controlled-unit attack/cast timing. Hero updates run after hard threat assessment and dodge checks. Invocations, cyclone combinations and facing adjustments have deadlines to release failed sequences.

Initial modules:

- Tinker: current Laser and Deploy Turrets, predicted turret placement, contextual March, and Blink positions chosen for casting range, enemy reach and nearby trees. Rearm can run during manageable combat pressure when it refreshes a useful spell and leaves follow-up mana. Visible ready interrupts and lethal pressure prevent or cancel the channel. Blink uses its actual item cooldown; it is not assumed to refresh with Rearm.
- Invoker: prepares both setup spells before EMP/Tornado or Tornado/Meteor; confirms casts and coordinates impact times. All ten recipes remain available to the spell selector. Sun Strike requires a controlled landing with lethal damage or meaningful committed follow-up, after estimating nearby units that split its damage. Adapted from the local `invoker.lua` timing design; its UI/controller is not imported. Meteor Hammer is reserved from generic casting: it times channel plus fall against observed lift/stun duration, checks interruption risk, farms healthy predicted creep groups, and requires durable melee cover for structures. Channels are confirmed and abandoned on hard danger. Vector Ice Wall and Cataclysm are not automated here.
- Lone Druid: bear creation, leash/return, attacks, items, roar and True Form. Shopping counts bear inventory and transfers bear build items and upgrade components after courier delivery. Scepter/Shard and explicit hero groups stay on Druid. Unlabelled damage builds default to bear; ambiguous guides may still require owner tuning. A full bear inventory pauses transfers.
- Arc Warden: separate main/double enemy counts, targets, attack timing and spell attempts. Double summoning requires committed hero combat or active farming after a quiet period with a reachable lane task; nearby enemies, recent sightings, incoming teleports and team tasks reserve it from farming. This estimates current fight likelihood, not future certainty. Magnetic Field protects the caster. Flux checks its own caster's modifier, allowing the Double to apply its independent Flux. Spark predicts activation and rejects closer creep interception rather than every nearby creep. A temporary Double may spend its remaining mana on legal hero combat. Doubles farm only lane creeps and structures, choose reachable waves, and use their own teleport scroll when enough lifetime remains. Their Midas check precedes lane travel and creep spells, can approach a nearby lane creep, and shares short target reservations with the main hero. They use combat disables, defensive items and contextual Mjollnir, resume attacks after casts, and check their own tower cover. They do not follow the main hero into jungle camps. Main-hero farming can still include neutrals and reserves more mana.
- Kez: confirms Scepter stance changes and Falcon Rush before switching into aimed Echo Slash and attacks; checks actual cooldowns instead of assuming a reset. Also handles Talon Toss, close-range Impale, Raptor Dance and defensive parry.
- Rubick: recent enemy spell scoring, Spell Steal and lift landing. Stolen spells use shared metadata casting; complex stolen combinations are not separately implemented.
- Io: tether partner selection, Overcharge, Spirits and defensive Relocate. Spirit orbit radius control is not implemented.
- Shadow Fiend: facing-confirmed razes, Feast during sustained hero attacks, and timed Eul–Requiem when Eul is owned. Physical/provider builds remain available.
- Meepo: shared net timing, controlled-target Poof, injured-clone escape and defensive Dig/Megameepo.
- Techies: a bounded Tazer / predicted Blast Off / detonation / Sticky Bomb sequence, with mine spacing and pending-placement checks. Blast Off does not require an existing stun: it budgets mana, conservative self damage and landing danger, predicts through cast and flight time, and preserves the jump before follow-up actions. Tazer detonation checks nearby enemies; Sticky Bomb has a separate pending-explosion interval. Idle mine placement remains local.
- Hoodwink: checks live permanent/temporary trees, confirms Acorn trees before Bushwhack, and aims/releases Sharpshooter.
- Clinkz: active-attack Strafe, Tar Bomb attack follow-up, eligible Death Pact targets, controlled-target Barrage and vector Burning Army.
- Brewmaster: Cinder/Clap, situational Split, Earth boulders, secondary-target Storm cyclone, Storm escape and Void pulse. Stance optimization and all brewling secondary actions are not complete.
- Ember: Sleight/Chains, Flame Guard and remnant placement/confirmation/activation with an offensive charge reserve.
- Void: Aether Remnant chooses a cast origin and watch direction from predicted travel and activation time, checks beam interception by other units, and accounts for Shard. Pulse, charge-reserved Astral Step and Dissimilate exit selection remain supported.
- Earth: Rolling Boulder solves moving-target interception using actual base/stone range and speed, checks full travel and hero/stone collisions, confirms stone setup, preserves roll windup/travel and follows a successful contact with attacks. Also handles stone/Grip or Smash setup and Magnetize refresh. Enchant Remnant combos are not automated.
- Storm: Overload attacks, behavior-aware Remnant/Vortex, and Ball Lightning with engagement plus escape mana budgeting.

These are heuristic controllers, not trained policies or complete reproductions of each specialist script. Regression tests cover decision paths; actual match tuning remains necessary.

## Shared safety

Tower entry requires durable frontline cover with enough estimated tower-hit capacity for approach, attacks and escape. A dying current tank can hand off to two healthy melee successors already closer to the tower than the hero's attack position. A lone ranged creep or a wave behind the hero is insufficient. Existing structure orders are cancelled when cover disappears or the tower targets the hero.

The bot fights manageable pursuing creeps when alone, while preserving imminent last-hit windows and avoiding trades near enemy heroes. Once clearing begins, its bounded task retains the final pursuing creep even after the short aggro signal expires. Enemy heroes, unsafe damage, incoming friendly waves and expiry release the task. It still disengages from dangerous creep damage.

Talents use explicit tier and paired-choice gates because the runtime's upgrade flag also accepts locked talent tiers. Eligible talents receive priority using guide choices even when those appear at late guide levels. Only the generic attribute upgrade receives the attribute penalty. Power Treads is excluded from generic buff casting. Unit spell orders explicitly select their caster, and controlled actors keep separate attempts and busy timers.

Shared spell policy applies to generic selection and custom ability readiness. Early harassment requires an actual trade or vulnerable target, reserves follow-up mana, and limits mana spent within twenty seconds. Defensive actions, channel interrupts and conservative lethal casts can bypass that budget. Committed combinations reserve their full sequence before execution. Spark also has an independent deployment interval. These thresholds are heuristic and may need match tuning.

Unsafe lane movement clips before unplanned exposure while permitting movement that reduces existing danger. A cached wave front expires near an unsupported enemy tower. Routine same-lane travel uses walking; base returns, rotations, defense and allied fights can teleport when a safe landing saves enough time.

`creep_block.lua` finds the actual allied mid tier-three, tier-two and tier-one towers. Staging clears the tier-three collision radius toward tier two. The blocker captures the original melee group, estimates its shared path, uses short holds and latency-adjusted interception steps, continues with remaining catchable creeps if one escapes, and releases before an enemy wave enters allied tower range. It does not restart on later waves. The body-blocking and overblocking principles were checked against [Goo's original mid guide](https://thegoodota.wordpress.com/strategy-guides/goos-guide-to-mid-lane/) and [Managing Your Lane Effectively](https://www.dotafire.com/dota-2/guide/managing-your-lane-effectively-8569); old guide map coordinates are not used.

## Combat and team objectives

`recovery.lua` separates escape, nearby regeneration and fountain travel. Escaping selects a traversable local route that reduces visible and forecast danger. Local recovery budgets passive regeneration, remaining timed healing, actual Bottle charges, salves, reachable Tango trees and Clarities. It releases at useful health/mana, re-evaluates a fountain trip when healing becomes available, and backs off stalled regeneration. Healthy disengagement does not imply a trip to base. Courier delivery can continue during safe local recovery.

`deward.lua` uses nearby enemy observer/sentry entities and the Io follower's `modifier_truesight` signal. A known ward caster gives an exact target; unknown-source detection permits a bounded probe away from enemy towers. Hero-sourced detection does not invent a ward. Supply buys one sentry when needed, counts dispenser charges and courier cargo, checks existing allied detection, and promotes the needed ward out of the backpack. The task switches dispenser mode, places detection, then attacks a revealed enemy ward. Danger, expiry and failed orders release the task. Hidden or unavailable ward entities still depend on runtime detection information.

Allied heroes actively attacking a structure keep a push objective alive after the lane creeps die. Barracks can use that allied presence as cover; towers still require a healthy confirmed tank. Idle allies and illusions do not qualify. A safe allied siege cancels incoming-wave regrouping, and loses priority immediately when its cover fails.

`engagement.lua` scores reachable kills, channel interrupts, actual allied attacks, safe range advantages and opponents occupied with creeps. It compares nearby health-weighted attack strength and rejects tower danger and severe creep pressure. Urgent opportunities precede farming; ordinary trades preserve immediate last hits. This is a conservative combat heuristic rather than a complete damage/combo simulator.

`awareness.lua` estimates nearby attack and ready-spell exposure. Confirmed hero damage and active attacks break passive lane waiting; bounded spacing allows defensive abilities before movement. Routine wave movement stops before walking into an unplanned enemy trade. Offensive casts retain a brief attack commitment, while speculative trades and spells reserve the travel, windup and cooldown needed for upcoming last hits.

`lane_spacing.lua` evaluates positions around both the hero and the next creep, including staying in place. It scores predicted enemy reach, observed attack recovery, high-ground disadvantage, creep collision and aggro, access to other low-health creeps, and an escape direction. Candidate paths must fit a selected last-hit deadline. Short caching limits repeated pathfinding; due attacks suppress repositioning. Deliberate aggro pulls draw melee creeps toward the allied ranged creep, and pursuing packs can be led into a nearby allied tower.

Spacing separates safe waiting from final attack entry and retains an already useful position. Paths sample intermediate exposure rather than checking only the destination. Last-hit timing computes projectile travel from the planned attack position after approach; eligibility is rechecked before moving toward a deny. Confirmed incoming hero attacks cancel unfinished creep windups when enough windup remains to respond.

Hero commitments renew on health or distance progress rather than expiring unconditionally after three seconds. Reachable low-health targets receive a bounded finishing extension. Failed chases, tower danger, death and severe threats still release the task.

Mid and support roles buy an observer only for a nearby uncovered lane or team objective, including when a combined dispenser only contains sentries. Existing allied vision, recently confirmed placements, and observers in the backpack, stash or courier suppress purchases. Supply has a three-minute support or four-minute mid cooldown. Mid avoids redundant early vision; later wards follow the active lane. Bottle checks actual regeneration charges and stored rune type, avoids incoming damage, and spends spare charges before an uncontested rune refill. Rune contests compare observed enemy movement and arrival time. Blink and supported hero blinks can secure safe pickups; Earth Spirit additionally checks the full Roll distance, path, stones and hero collisions before committing.

`teamplay.lua` identifies actual opponents in allied fights, including a single ally fighting during the laning phase. It approaches the enemy and switches to attack commitment, using a safe time-saving teleport for distant fights. Moving groups retain formation travel. It can join a confirmed two-ally Roshan attempt or select an independent solo attempt through `roshan.lua`. Idle farmers, clones and mere proximity cannot invent a fight. Team tasks take priority over routine farming.

`roshan.lua` compares visible Roshan health and regeneration against sustained physical damage after armor, attack timing and estimated bash downtime. It budgets current Roshan attack damage, scaling Slam, burst damage, passive regeneration, conservative item lifesteal and a traversable escape route. Low-health Roshan can qualify even when a full-health attempt would fail. Nearby enemies, recent sightings, incoming teleports, an allied fight, moving Roshan and stale visibility reject solo attempts. Longer attempts require more enemies to be accounted for elsewhere. Actual damage samples can increase the estimated danger; outgoing samples can cautiously improve the damage estimate. The task checks progress, aborts stalled or unsafe attempts, and has a hard time limit and retry delay. Death records an Aegis pickup opportunity when an active inventory slot is free. It does not assume future crits, arbitrary spell combos, temporary buffs lasting indefinitely, or unavailable healing; some capable specialist heroes will therefore be underestimated. Diagnostics report the reason, estimated kill time and remaining health. This is a survival heuristic, not a guarantee of a solo kill.

Double lane travel compares the leading visible group in each lane and excludes creeps still near the allied fountain. Forward pressure and useful teleport savings affect the score. A normal scroll requires a safe allied tower; Boots of Travel allow a durable allied creep target. Arrival still needs to leave useful Double lifetime. The controller keeps the chosen destination and does not substitute a newly spawned rear group merely because it is closer. Double diagnostics show the travel decision and the runtime scroll execution result.

Double lifetime uses `modifier_kill`: live inspection showed that the permanent Double marker reports its creation time as expiry. Observed aggression permits defensive summons below the ordinary farming health threshold and before Spark. Reactive casts bypass last-hit and harassment budgets when the hero is actually being attacked. Generic defensive selection also supports point and no-target disables within their effect geometry.

`teleports.lua` adapts owned teleport-end particle tracking from the supplied `invoker.lua`. It reads destination control points, follows attached moving targets, uses visible channel expiry when available, deduplicates owners and removes cancelled/stale arrivals. Incoming enemy landings affect spacing and numerical danger before the hero appears. Unknown-owner particles are ignored; fog timing is an estimate.

Threat forecasts combine damage at teleport destinations with recent fog sightings, without double counting visible heroes. Changed maphack positions can update threat memory; an unchanged stale position cannot keep refreshing its age. Dangerous arrival forecasts interrupt farming and take the emergency branch before rune, camp and spacing tasks. Damage and reaction estimates remain heuristic.

River control discovers actual power-rune spawners. An empty power-rune spawn can trigger one bounded search of the opposite location, including distances beyond 3,200 units. Water-rune cycles are handled separately: no cross-river search after an empty or collected water rune, and completed visits are remembered.

Issuing a river pickup closes that cycle's opposite-pit search immediately, while the existing pickup task keeps bounded retries on the same rune. This does not depend on rune entity removal arriving before the hero moves away. Bounty pickups do not close power-rune cycles.

Wisdom availability uses the shrine's actual `m_bActive` field, with `m_bIsBeingGranted` identifying its countdown. These fields were checked against the [client schema](https://github.com/SteamDatabase/GameTracking-Dota2/blob/master/DumpSource2/schemas/client/C_DOTA_BaseNPC_XP_Fountain.h) and read successfully through live Umbrella MCP. Supports can travel farther; any role can collect a safe nearby shrine. An ally already collecting suppresses duplicate travel. Collection retains position inside the live 300-unit radius, waits for the shrine to become inactive, and retries failed countdowns after a short delay. Routine farming does not interrupt an active collection.

Routine lane/protection teleports reject nearby destinations, backward jumps toward home, unsupported regrouping and departures from enemy high ground. Base returns, actual fights and structure defense retain their own time-saving checks.

`jungle.lua` can choose a nearby available allied-side camp without a lane wave. Active camp travel/farming keeps its destination until danger, clearance, expiry or lack of progress. Farmed camps, waiting-to-spawn entities and repeatedly unacknowledged targets are excluded temporarily instead of pinning the bot in an empty camp.

Shopping counts hero, backpack, stash, local courier cargo and owned items on other couriers, deduplicating handles during transfers. Purchase acknowledgement also counts components already incorporated into combined items. Paid purchases wait for delivery and enter backoff if unresolved; the former twelve-second automatic rebuy is removed. Courier orders select the courier explicitly. `inventory_cleanup.lua` recycles obsolete starting items when space is needed, protects remaining build components, and uses the courier to bring junk home while delivering an upgrade through the freed slot. Full-inventory delivery is attempted once for possible assembly, then pauses until space is available. Seasonal Carnival Pie, Balloon and Firework are excluded from spell casting and levelling.

## Validation and source maintenance

`neutral_items.lua` reads the live neutral tiers, crafting costs, madstones and offered choices. It scores trinkets by hero attribute and role, and enchantments by their current level values. It selects both options, waits for server acknowledgement, limits retries and does not spend currency on rerolls. Craft/choose messages follow the [Dota client protobuf definitions](https://github.com/SteamDatabase/GameTracking-Dota2/blob/master/Protobufs/dota_clientmessages.proto). Supported neutral actives use slot 16 with healing, mana, pursuit, defense or committed-attack conditions; movement-sensitive items such as Fallen Sky and Pogo Stick are not automatically cast.

Run `python tests/run_self_play_heroes.py`, `python tests/run_self_play_actions.py`, `python tests/run_self_play_lifecycle.py`, `python tests/run_self_play_models.py`, `python tests/run_self_play_neutrals.py`, and the `self_play_planner`, `self_play_timeline`, and `self_play_policy` Luau tests. The actions runner uses `tests/fixtures/json_stub.lua` when Umbrella's `assets/JSON.lua` is not installed. The neutral runner reads the installed game metadata from `C:/Umbrella/assets/data`, or `--assets-root`. These use engine doubles and do not establish live gameplay correctness. Compile/load the production Lua files in Umbrella as well.

`tools/strip_comments.py` strips comments and comment-only lines from this bot's main script, Lua modules, Python tools and bot tests. `tools/refresh_data.py` regenerates the catalog (heroes, items, abilities) from OpenDota/dotaconstants; its notice is in `data/dotaconstants-LICENSE.txt`. Live game item recipes take precedence over external recipe metadata.
