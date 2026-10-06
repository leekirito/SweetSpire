# Bot players

Status: implemented. The original AI controller scene and state machine now run
player bots through the shared game command dispatcher.

## Playing

- Hotseat: choose 1–8 total seats. Each player card offers Human or Bot, tribe,
  name, and a bot profile. At least one seat must remain human.
- LAN: the host uses **Add Bot**, then edits its name, tribe, and profile.
  **Remove** frees the seat. Humans and bots share the eight-seat limit.
  A ready host can start with bots and no other connected computer.
- Both Fog of War and Regular are supported.
- Bot turns run automatically. Human actions are disabled during their turn.
  Single-human Hotseat keeps that human's camera and fog. Multiple-human
  Hotseat covers bot turns without pausing simulation, then prompts the next
  human to continue. LAN always keeps each device's own view.
- A disconnected LAN human pauses bot decisions with the rest of the match.
  Rejoining resumes the existing controller rather than restarting its turn.

## Tune the bots

Edit `scripts/ai/profiles/balanced.tres` in Godot's Inspector. Its exported
properties are defined in `scripts/ai/bot_profile.gd`. Profiles are copied and
validated per controller, so runtime changes do not mutate the source resource.

| Settings | Effect |
| --- | --- |
| Economy, expansion, defense, research, Sweetspire, recruitment weights | Relative action and destination priorities |
| Lookahead depth | How far visible enemy attack threats influence movement; this is a threat horizon, not a full game-tree search |
| Candidate limit | Maximum movement candidates retained per unit |
| Coordination limit | Soft penalty for assigning too many units to one destination; also influences desired army size |
| Risk tolerance, retreat health ratio, retaliation weight | Exposure penalties and retreat preference |
| Friendly fire penalty | Avoids area attacks that hurt allies more than enemies |
| Reserve Sugar, investment horizon | Savings and income-building preference |
| Mistake chance, alternative count, max score loss | Occasional selection of a nearby lower-scoring legal option |
| Mistake cooldown | Minimum intervening decisions before another deliberate imperfection |
| Goal commitment turns, threat response threshold | Persistence versus switching goals under visible threat |
| Capability switches | Research, recruitment, construction, naval travel, and area attacks |
| Action delay, turn intro delay | Presentation pacing |
| Work per frame, max actions, max failed retries | Planning work and turn safety limits |
| Debug decisions | Prints action reason, score, and whether a bounded mistake was chosen |

For a more forgiving opponent, increase mistake chance slightly, lower
coordination and lookahead, and adjust its priorities or savings. Keep all
capabilities enabled to preserve believable play. Avoid very large score losses:
those produce obviously bad decisions. No hidden income, information advantage,
or forced losing is applied. Difficulty still needs human playtesting.

To add a profile, duplicate Balanced, change its ID/name/settings, and register
it in `BotCatalog.PROFILES`. Both setup screens populate from this catalog.
Profile values contribute to LAN compatibility; all participants need the same
build and profiles.

## Code organization

| File under scripts/ai | Responsibility |
| --- | --- |
| bot_director.gd | Attaches controllers only on the authoritative machine |
| ai_controller.gd and existing state scripts | Turn lifecycle, frame pacing, execution, bounded failures |
| bot_profile.gd, profiles/balanced.tres, bot_catalog.gd | Editable behavior and approved profile catalog |
| bot_observation.gd | Copies only visible or legitimately remembered player information |
| bot_memory.gd | Known terrain/static entities, goals, previous moves, rejected commands, seeded RNG |
| bot_navigation.gd | Known-map movement, line-of-sight, dock/boat/landing routes |
| bot_actions.gd | Economy, resource collection/upgrades, prerequisite research, recruitment, construction |
| bot_strategy.gd | Combat, friendly fire, defense, exploration, town capture, naval/center goals |
| bot_decision.gd | Deterministic ranking and bounded imperfect choices |

`scripts/systems/game_commands.gd` dispatches validated commands to the existing
game rules. LAN calls this same dispatcher directly.
Bot LAN commands use the same ordered execution and snapshot publication as
human commands. Guests cannot create controllers or submit actions for bot seats.

The former `scripts/AI` folder was normalized to `scripts/ai`, preserving its
script UIDs. The existing controller scene stays at
`scenes/entities/AI/ai_controller.tscn`.

Setup controls and the bot-turn overlay are authored in scenes. Only
roster-dependent rows/cards and profile choices are populated at runtime.

## Current capabilities and boundaries

Bots collect and upgrade resources, research useful prerequisite chains, recruit
available unit types, build farms/lumber factories/mines/docks, move, attack
(including area attacks), explore, capture towns, embark, sail, land, contest and
hold Sweetspire, and end their turns. Costs, ownership, action limits and
technology gates are checked by the normal game rules.

Navigation is heuristic and only uses known terrain. Profiles tune imperfect
choices; they do not guarantee a specific win rate. Work is spread across units
per frame, but route evaluation for one unit is synchronous. Very large custom
maps may need an incremental pathfinder.

No mid-match seat replacement, automatic disconnected-player takeover, host
migration, or persistent save/load of bot memory is included. Bots only use
currently implemented technologies/actions, not promised effects in descriptions.

## Validation

Run with the installed Godot console executable:

```powershell
./scripts/ai/tests/run_bot_tests.ps1 -GodotPath "<Godot console executable>"
./scripts/network/tests/run_lan_tests.ps1 -GodotPath "<Godot console executable>" -Players 8 -Regular
```

The bot suite covers profile isolation/clamping/signatures, bounded mistakes,
fog information, combat and friendly fire, legal naval paths, setup and seat
limits, actual bot development/exploration/dock use across multiple turns,
mixed-human Hotseat privacy, host-only execution, and host/guest reconnection
during bot turns in both map modes. The existing suite covers human-only LAN,
Hotseat, selection, fog, structures, combat, and map generation.
