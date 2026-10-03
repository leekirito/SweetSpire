# LAN multiplayer and biome map assembly review

Reviewed 2026-10-02. This is an architecture review, not multiplayer implementation or a two-computer test.

## Agreed scope

- First multiplayer release: host/join with friends on LAN or direct IP.
- Map: preserve the handcrafted center. Assemble the surrounding sides from three biomes, each with multiple handcrafted variations for balance. Randomness determines placement, rather than generating terrain from scratch.
- Build the complete finite map before a match starts. Streaming and an infinite world are outside this scope.

## Readiness

The project is a reasonable starting point, but is not network-ready yet. It does not require a complete rewrite. MatchManager already delegates combat, capture, economy, technology, turns, units, structures, and victory to separate systems. Its request methods and existing legality checks provide useful entry points for host-controlled commands.

The LAN menu is currently presentation only: MainMenu confirms tribe selection with NETWORKING NOT CONNECTED. GameSession stores local player nodes. No transport, RPC command protocol, lobby synchronization, or match snapshot system is implemented in the gameplay scripts.

## Multiplayer work

1. Add an ENet host/client connection and lobby, with peer-to-player assignment, tribe selection, ready states, and a shared start signal. Only the host starts and owns the match.
2. Route gameplay requests through the host. Validate the sending peer's identity, ownership, turn, legality, and costs. In particular, request_end_turn currently has no player identity argument.
3. Use stable host-assigned IDs for entities and catalog IDs for unit/technology types. Current recruitment and technology APIs accept PackedScene and TechnologyData objects; these should remain local lookups rather than network messages.
4. Define match snapshots and ordered authoritative updates for movement, damage, deaths, recruitment, resources, territory claims, structures, technologies, income, turn changes, elimination, and victory. Do not independently simulate setup on every client.
5. Separate local controls and presentation from shared match state. MatchManager currently references HUD nodes directly, while rules also trigger scene animations. Turn completion currently depends on local unit animation flags.
6. Preserve a local player's fog viewpoint during other players' turns; keep active-player switching for hotseat mode. Host visibility should determine which enemy information is sent to a client. Hiding fully replicated enemies with visible=false is not fog privacy.
7. Define disconnect behavior for the first release. Host migration and reconnect can be later features, but disconnects must not silently leave an unusable match.
8. Verify with two game processes and two computers: rejected out-of-turn/spoofed commands, identical public state, private fog, turn order, entity creation/removal, lobby failures, and disconnect handling.

Godot provides the transport and RPC layer; it does not automatically synchronize these rules. Reference: https://docs.godotengine.org/en/4.7/tutorials/networking/high_level_multiplayer.html

Direct IP across the internet is separate from LAN usability: host firewall/router configuration or a future relay may be needed. A friends-on-LAN prototype does not prove internet connectivity.

## Handcrafted biome assembly work

The existing DemoMap scatters towns/resources on an already authored Ground map. It does not assemble terrain chunks.

Create a reusable chunk definition containing biome ID, variant ID, dimensions, ground cells, decorative/obstacle layers, resource/building placements, allowed orientations, compatible edges, routes to the center, and balance metadata. The exact slot layout, chunk sizes, biome placement constraints, and allowed rotations remain design decisions.

Use the center as a fixed anchor. Select compatible handcrafted variants for surrounding slots with a seeded random generator. Validate seams, accessible starting towns, routes toward the center, resource budgets, and no overlapping entity placement. Choose variants within agreed balance bands; handwritten chunks alone do not guarantee fair combinations.

The host should send the chosen map manifest: center/version, slot coordinates, biome/variant IDs, permitted orientations, and authoritative starting placements. Clients assemble that exact result. A seed is useful for reproduction, but is not the complete synchronization contract. Current starting-base selection uses global pick_random(), separately from DemoMap's seeded generator.

Initialization must become explicit:

1. Assemble all terrain and authored entities.
2. Build board/navigation and terrain caches.
3. Register entities with stable IDs; establish starting ownership and first resource claims.
4. Build water overlays and fog cells from the completed map.
5. Apply player state and begin the match.

BoardManager, WaterEffects, and FogOfWar currently build from existing Ground cells during startup. Generating terrain after that would leave incomplete navigation, water, or fog unless refreshed. First-resource ownership must also be consistent across all peers, including overlapping town ranges.

For the requested finite map, existing whole-map fog and navigation can be retained initially. Profile representative final map sizes before deciding whether chunk-specific performance work is necessary.

## Suggested sequence and effort

1. Define shared entity IDs, command/state formats, and explicit map initialization.
2. Prove two-player LAN movement, attack, and end turn on the current map.
3. Add the center-and-biome manifest and handcrafted chunk assembler.
4. Extend synchronization to the rest of the game and validate generated map combinations.

Rough focused developer-time estimates, not delivery guarantees:

| Deliverable | Difficulty | Estimated effort |
| --- | --- | --- |
| Two-player LAN proof on the existing map | Moderate | 3–5 days |
| Playable LAN version covering current systems | Moderate to high | 2–4 weeks total |
| Finite biome chunk assembler, with prepared compatible chunks | Moderate | 4–8 days |

Chunk authoring, art, balance iteration, and further playtesting are additional. LAN estimates exclude matchmaking, relay services, host migration, and robust reconnect. Shared preparation overlaps between the two features; estimates should not be added mechanically.
