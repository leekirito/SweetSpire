# Sweetspire codebase guide

Start here when you want to find a feature or adjust the game. Runtime scripts
now describe their responsibilities at the top. Important functions and exported
settings use Godot's `##` documentation comments, which also support editor help
and Inspector tooltips.

## How a match fits together

1. [MainMenu](../scripts/MainMenu.gd) reads the authored setup controls. Hotseat
   builds a local roster; LAN uses [LanSession](../scripts/network/lan_session.gd)
   to host or join a room and synchronize its roster.
2. [GameSession](../scripts/GameSession.gd) retains player nodes, match mode, and
   map setup across scene changes. Each [PlayerState](../scripts/player_state.gd)
   holds one seat's tribe, controller type, Sugar, research, and progress.
3. [MapBootstrap](../scripts/map/map_bootstrap.gd) assembles the map when Main
   enters the scene tree, before its children cache terrain. The host/local game
   uses a validated chunk manifest; guests use the map supplied by the host.
4. [MatchManager](../scripts/match_manager.gd) registers entities and coordinates
   the match. Its rule systems handle turns, combat, economy, research,
   construction, capture, and victory.
5. Humans select actions through [PlayerController](../scripts/player_controller.gd)
   and UI. Bots plan through [AIController](../scripts/ai/ai_controller.gd).
   [GameCommands](../scripts/systems/game_commands.gd) dispatches bot and LAN
   commands to the same gameplay requests used by local humans.
6. In LAN, the host runs the simulation and bots. Guests submit intent and apply
   their own filtered [snapshots](../scripts/network/match_snapshot.gd).
   Animations, camera, and overlays present the result.

## Where to work

| Area | Files and purpose |
| --- | --- |
| Turn timer | [TurnClock](../scripts/systems/turn_clock.gd) handles timeouts and pauses; [TurnTimer](../scenes/UI/TurnTimer.tscn) is the authored HUD. GameSession holds the selected duration. |
| Match rules | [scripts/systems](../scripts/systems): each manager owns a specific rule domain; MatchManager exposes requests and shared registries. |
| Board and movement | [BoardManager](../scripts/board_manager.gd): world/cell conversion, occupancy, terrain queries, movement/attack geometry, and highlights. |
| Entities | [Unit](../scripts/Unit.gd), [Building](../scripts/Building.gd), [Resources](../scripts/Resources.gd), and [Structure](../scripts/Structure.gd): state and presentation for placed objects. A Building is a capturable town; a Structure is an improvement such as a farm or dock. |
| Territory and visibility | [TerritoryManager](../scripts/TerritoryManager.gd), [FogOfWar](../scripts/fog_of_war.gd), [match knowledge](../scripts/systems/match_knowledge.gd), and [memory sprites](../scripts/fog_memory_view.gd): authoritative claims, per-seat observations, and last-seen presentation. [FoggedTerrain](../scripts/fogged_terrain.gd) hides unexplored terrain art. |
| Biome generation | [scripts/map](../scripts/map): painted chunk metadata, validation, seeded selection, and assembly. |
| Bots | [scripts/ai](../scripts/ai): observation, memory, navigation, scoring, decisions, and turn execution. |
| LAN | [scripts/network](../scripts/network): transport, discovery, private-room access, compatibility, ordered commands, and snapshots. |
| Interface | [scripts/UI](../scripts/UI), [network UI](../scripts/network/ui), and [recruitment UI](../scripts/recruitment_ui.gd): display state and request actions. Fixed layouts belong in scenes. |
| Effects | [scripts/effects](../scripts/effects), [water effects](../scripts/water_effects.gd), and [shaders](../assets/Shader): cosmetic feedback. |
| Camera | [CameraController](../scenes/main/CameraController.gd): zoom, panning, and local human-turn focus. |

## Settings you can customize

Open the `.tres` resource or scene in Godot and use the Inspector. The associated
script describes each setting's meaning; changing a shared resource affects all
instances that use it.

| Change | Start here |
| --- | --- |
| Unit health, damage, movement, cost, and research requirements | [Unit resources](../scripts/data/Units) and [UnitData](../scripts/UnitData.gd). |
| Movement, attack, or blast shapes | [Range resources](../scripts/data/RangePatterns) and [RangePattern](../scripts/RangePattern.gd). Terrain and occupancy checks still apply. |
| Tribe starting research/unit and ownership colors | [Tribe resources](../scripts/data/Tribe) and [TribeData](../scripts/TribeData.gd). |
| Resource collection rewards and upgrade requirements | [Resource definitions](../scripts/data/Resources) and [ResourceData](../scripts/ResourceData.gd). |
| Research prices, prerequisites, and displayed explanations | [Technology resources](../scripts/data/Technologies) and [TechnologyData](../scripts/TechnologyData.gd). Description text alone does not implement an unlock. |
| Improvement costs, income, placement, and boat configuration | [Structure resources](../scripts/data/Structures) and [StructureData](../scripts/StructureData.gd). |
| Bot capabilities and believable mistakes | [balanced.tres](../scripts/ai/profiles/balanced.tres) and [BotProfile](../scripts/ai/bot_profile.gd). The descriptions cover priorities, savings, risk, bounded mistakes, commitment, pacing, and safety limits. |
| LAN ports, timeouts, discovery, and compatibility versions | [lan_settings.tres](../scripts/network/lan_settings.tres) and [LanSettings](../scripts/network/lan_settings.gd). |
| Biome varieties and inward-facing lake edges | Paint chunk scenes registered by [ChunkCatalog](../scripts/map/chunk_catalog.gd); follow the [authoring guide](biome-map-generation.md). |
| Center-control victory target and territory/fog appearance | Inspector settings on MatchManager, TerritoryManager, and FogOfWar in Main. |
| Menu, Hotseat cards, and LAN screens | Authored UI scenes described in the [UI authoring guide](ui-authoring.md). Runtime rows depend on roster/discovery data. |

For custom bot profiles, duplicate Balanced and register the new resource in
[BotCatalog](../scripts/ai/bot_catalog.gd). To make opponents more forgiving,
adjust bounded mistakes and priorities while retaining the abilities you want
them to use. Profiles do not force a loss or grant hidden bonuses. See the
[bot guide](bot-implementation-plan.md) for tuning and current limitations.

## Important distinctions

- **Cell coordinates and screen directions:** gameplay uses tile-grid cells.
  In an isometric view, grid Top/Right/Bottom/Left differ from screen directions.
  Chunk shoreline settings use grid directions and constrain placement; they do
  not rotate artwork or paint water automatically.
- **Seat and peer IDs:** a player ID identifies a match seat. A peer ID identifies
  a network connection. Bots occupy seats without remote connections. Do not use
  one kind of ID in place of the other.
- **Active player and viewing player:** the active seat owns the turn. The viewer
  is the human perspective shown on this device. They can differ during bot or
  remote turns, so fog, camera, and private UI must use the appropriate identity.
- **Shared data and live state:** resources hold authored defaults; entities and
  PlayerState hold mutable match state. Bot profiles are copied before use.
- **Commands and rules:** UI and planners propose actions; rule systems validate
  ownership, costs, turn limits, and terrain. A displayed button or a positive
  bot score does not authorize an action by itself.
- **Knowledge and authority:** the host has full state. BotObservation restricts
  planners to allowed knowledge; snapshots restrict what guests receive about
  units, economies, and static-entity changes. Exploration and current sight
  are separate. Terrain setup is sent to guests even when visually fogged.
- **Simulation and presentation:** board occupancy is updated independently of
  sprite movement. Local combat applies damage at its impact callback; LAN
  resolves authoritative damage separately from cosmetic attack playback.

## Extending the game

When adding an action, implement its rules in the relevant system and expose it
through MatchManager. Add its command shape to GameCommands if bots or LAN will
use it. Register new approved content in the relevant catalogs, include new
replicated state in snapshots, and let bots score it through their observations.
This keeps Hotseat, LAN humans, and bots using the same costs and restrictions.

Update compatibility versions when gameplay or network formats require matching
builds. Catalogs fingerprint authored rule data and bot profiles. Keep fixed UI
controls in scenes; populate only content that depends on live data.

Use `##` before public functions and exported properties for editor-facing
descriptions. Use ordinary `#` comments for a local reason or invariant that is
not obvious from the code. Keep descriptions accurate when behavior changes.

## Existing guides and checks

- [Biome generation and chunk authoring](biome-map-generation.md)
- [Hotseat setup and handoff](hotseat.md)
- [LAN rooms, reconnection, and synchronization](lan-multiplayer.md)
- [Bots and profile tuning](bot-implementation-plan.md)
- [UI authoring](ui-authoring.md)
- [Original structures implementation notes](structures.md) — describes the
  earlier demo-map stage; the current structure catalog and scripts include
  subsequent additions.

Regression scenes live under `scenes` and the `scenes/ai/tests` and
`scenes/network/tests` folders. Run the relevant existing checks after behavior
changes. The [bot runner](../scripts/ai/tests/run_bot_tests.ps1) and
[LAN runner](../scripts/network/tests/run_lan_tests.ps1) accept a `-GodotPath`
pointing to the Godot console executable; their feature guides show usage.

The LAN runner also executes the standalone range, territory, shoreline, and
mountain-movement scenes. Run `scenes/range_regression_test.tscn` rather than
launching its script directly, so the normal project autoloads are initialized.
All regression scripts and scenes stay in source control and are excluded from
Windows and Web exports. Temporary runner output lives under `.godot/lan-tests`.
