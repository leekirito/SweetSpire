# Biome chunk generation

Implemented 2026-10-05. Run `scenes/main/Main.tscn` directly or start a hotseat match through the menu. Main now assembles a complete map from painted chunk scenes before gameplay starts.

## Design and implementation plan

1. Define a finite 3×3 layout of 10×10 chunks. Sweetspire occupies the center; eight Saba, Malagkit or Kamote chunks surround it. Add a one-cell ocean border around the entire map (32×32 total).
2. Author multiple interchangeable scenes per biome, with painted terrain and placement markers. Validate them against a common seam, connectivity and resource contract.
3. Reserve a distinct matching biome chunk for each player, even if everyone chooses the same tribe. Select variants with a local seeded random generator. Prefer unused variants of a biome before repeating them.
4. Record choices, exact starting towns and stable entity IDs in a versioned manifest. Receiving peers validate and assemble that manifest without rerolling.
5. Assemble terrain and entities before child nodes build navigation, water effects or fog. Then register entities, assign starting ownership and begin play.
6. Test seed reproducibility, tribe combinations, duplicate tribes, malformed manifests, catalog constraints, JSON delivery and full match startup.

All six steps are implemented. Network transport, lobby synchronization and ongoing gameplay replication remain separate work.

## Layout and guarantees

```text
slot 0 | slot 1 | slot 2
-------+--------+-------
slot 7 | CENTER | slot 3
-------+--------+-------
slot 6 | slot 5 | slot 4
```

The center chunk is slot 8 at board cell (10,10). Its outer two rows/columns must remain water. The outermost edge may contain lake tiles (source 6) next to the surrounding mainland; the inner water ring remains ocean (source 5). The 6×6 inner island contains the original objective coordinates: (14,14), (15,14), (14,15), (15,15). These four cells must remain clear, connected land.

Both center variants contain eight empty shoreline lake tiles at local (4,0), (7,0), (9,0), (0,4), (0,7), (0,9), (3,9), and (6,9). With the starter outer variants, each borders land and lies within the maximum three-tile territory radius of an existing town. Coastal variants can extend this water into their own shore tiles, which must themselves border walkable land. These are potential dock sites, not routes across the ocean. A player must control the tile, unlock Sailing, and pay the normal dock cost. Town capture or territory expansion may be needed first.

Outer chunks normally have clear land around their perimeter. A declared **Shore Edge** permits empty lake tiles on exactly that edge and restricts the variant to the matching side of Sweetspire. Corners and the other three edges remain clear land, so outer chunks still connect safely. Every declared shore lake must border walkable land inside its chunk. Rotations remain fixed at zero to preserve directional isometric artwork.

| Shore Edge on the chunk root | Lake cells to paint | Allowed position | Slot |
| --- | --- | --- | --- |
| None | Interior lakes only; boundary stays land | Any outer position | 0–7 |
| Top (-Y) | y = 0, x = 1–8 | Below Sweetspire | 5 |
| Right (+X) | x = 9, y = 1–8 | Left of Sweetspire | 7 |
| Bottom (+Y) | y = 9, x = 1–8 | Above Sweetspire | 1 |
| Left (-X) | x = 0, y = 1–8 | Right of Sweetspire | 3 |

Directions refer to tile-grid coordinates, not screen directions in the isometric editor. A declared edge needs at least one painted lake tile; selecting a direction does not paint, rotate or move terrain. Interior lakes can still exist elsewhere and do not affect placement. Corner slots do not share a side with Sweetspire and accept only None variants. Sweetspire's own root must also use None because it has separate center-border rules.

Keep at least one None variant per playable biome to retain flexible placement for repeated tribe choices and larger lobbies. The generator filters variants and filler biomes by slot, and backtracks player assignments when a tribe needs a particular shore slot. If the catalog cannot accommodate all selected tribes or fill every slot, setup fails with an explanation instead of placing a coast facing away from Sweetspire. The same direction checks apply to received multiplayer manifests.

The generator supports 1–8 players when the catalog has compatible variants for their slots; the hotseat menu lets players choose any count from 1 to 8. It prefers opposite cardinal chunks for the first two players, then the other cardinal chunks, then corners. Shore restrictions may require a different assignment. A seeded offset varies the preference. Starts are distinct and match the selected tribes. Unselected biomes are permitted but are not mandatory. Sweetspire is neutral and is never a starting tribe. See [Hotseat setup and handoff](hotseat.md) for the menu and pass-the-device flow.

Every outer variant contains two towns and the same resource budget: three forests, three fruits, two animals, two mountains and two fish. The starting town has a forest, fruit and animal within its initial territory. Sweetspire contains one neutral town, three forests, three fruits, two animals and two mountains. These budgets and connected walkable land are checked at load time. They provide consistent starting content; competitive travel times and resource accessibility still need playtesting, especially in lobbies larger than four players.

Sweetspire's ocean ring uses the game's existing ocean movement requirements. Generation does not grant players sailing/navigation or add bridges across that ring.

## Paint a variant in Godot

Eight editable starter scenes are in `scenes/map/chunks/`:

| Biome | Variants |
| --- | --- |
| Saba | `saba_grove.tscn`, `saba_lagoon.tscn` |
| Malagkit | `malagkit_terraces.tscn`, `malagkit_pools.tscn` |
| Kamote | `kamote_ridge.tscn`, `kamote_basin.tscn` |
| Sweetspire | `sweetspire_gardens.tscn`, `sweetspire_sanctuary.tscn` |

1. Open a starter scene in the 2D editor. Duplicate it with Save As to create another variety.
2. On the root, set `biome_id`, a unique `variant_id`, and increment `revision` when changing a released variant. Add new scene paths to `ChunkCatalog.SCENES` in `scripts/map/chunk_catalog.gd`.
3. Paint **Ground** cells (0,0) through (9,9) using the existing Dungeon TileSet. Fill every cell. Use the matching land sources: Saba 39, Malagkit 3/24, Kamote 4/23, Sweetspire 26. Water sources are 5 (ocean) and 6 (lake).
4. Paint optional **Decoration** and **Obstacles** layers. All three layers must use the same TileSet and have unchanged transforms. Any occupied Obstacles cell blocks movement. Keep perimeter seams, placements and routes open. Decoration is visual only.
5. Under **Placements**, duplicate a `ChunkPlacement` marker and place it at a tile center. Select its `kind` in the Inspector: town, forest, mountain, fruit, animal or fish. Gold markers indicate starting towns; cyan markers indicate other placements. Markers become normal game entities during assembly; they are not themselves gameplay objects.
6. Each outer chunk needs exactly one `starting_town` marker, on local cell (4,4). Its other town stays neutral. Center town markers must not have `starting_town` enabled. Fish belong on water; all other placements belong on land. Do not overlap placements or put them on obstacles.
7. Keep the resource counts described above. Place forest, fruit and animal markers within one tile of the starting town. Keep all non-mountain walkable land connected to local (4,4), including the neutral town and the outside seams.
8. Save, then run `scenes/map_generation_regression_test.tscn`. Invalid catalogs stop map setup with an explanation rather than silently substituting another map.

To author a coast that faces Sweetspire, set **Shore Edge** on the variant's root using the table above. For example, select **Bottom (+Y)** and paint a lake at (7,9): the generator will use that variant only above Sweetspire. Keep lake tiles on that edge empty of markers and obstacles, and retain adjacent land. Keep or move the neutral town close enough to claim the intended dock tile (town territory reaches at most three cells); the starting town remains at (4,4). Duplicate the scene for another direction and give it a unique variant ID. Existing starter scenes default to None until you choose a direction and paint its shore.

For Sweetspire, keep local x/y 0–1 and 8–9 as unobstructed water. Lake tiles are allowed only on the outermost edge (x or y equal to 0 or 9); leave those tiles free of resource markers so docks can be built. The inner ring must stay ocean. Keep local objective cells (4,4), (5,4), (4,5), (5,5) free of placements and obstacles.

## Startup and multiplayer handoff

`MapBootstrap` is the script on Main's root. Its `_enter_tree` validates and assembles everything before children enter the tree. The original authored terrain/entities remain in Main for legacy test fixtures, but the runtime assembler replaces them. Existing tests that override Main's root script retain their original fixed-map behavior.

`GameSession.map_seed` defaults to -1 (fresh seed). Set a nonnegative 32-bit value before loading Main to reproduce a map. `GameSession.map_manifest` stores the accepted result. Starting a new match through `clear_players()` clears the old manifest. A nonempty manifest is an explicit replay and takes precedence over the seed.

The manifest contains:

- Generator version (currently 2) and a SHA-256 signature of the compiled catalog's tiles, placements, shore edges and revisions.
- Seed for diagnostics, sorted player IDs and tribe IDs.
- Ordered chunk slots, origins, biome/variant IDs, shore edges, zero rotation and assigned player IDs.
- Exact starting town IDs and cells. Other entity positions and stable IDs derive from the validated catalog and canonical slot/placement order.

The payload uses only dictionaries, arrays, strings, booleans and numbers. JSON round trips are covered by tests. Changed catalog content is rejected instead of allowing peers to silently construct different worlds. Ship the same game build/TileSet and rule data to every peer; the catalog signature is not a fingerprint of the entire game.

For future lobby integration:

1. The host finalizes player IDs and tribe selections, generates the manifest and sends it to peers.
2. Each joining peer populates `GameSession.players`, sets `require_map_manifest = true`, and installs the received manifest before loading Main. Missing, incompatible or invalid manifests halt setup; there is no local random fallback.
3. The lobby should wait for every peer's setup acknowledgement before starting synchronized gameplay. Current Main begins locally after successful setup; this network start barrier is not implemented.
4. Host-authenticated commands, authoritative state updates, local fog viewpoints, disconnect handling and save snapshots remain on the multiplayer roadmap. A reproducible setup is not a complete multiplayer implementation.

## Verification

Run with the Godot console executable:

```text
godot --headless --path . res://scenes/map_generation_regression_test.tscn
godot --headless --path . res://scenes/map_generation_regression_test.tscn -- --replay
godot --headless --path . res://scenes/shore_edge_regression_test.tscn
```

The first command exercises local generation; the second exercises startup from a JSON-received manifest with local generation disabled. Each passes 1,686 checks, including 40 seeds across all nine two-player tribe combinations, 1–8 identical-tribe rosters, shoreline lake adjacency and town reach, actual dock construction, and preservation of the inner ocean ring. The shore-edge suite passes 466 checks covering all four directions, invalid edge painting, assembled coast adjacency, constrained player assignment, impossible catalogs, deterministic replay, and tampered manifests. Live rendering of the original generated layout was also inspected.

Existing territory (19), mountain movement (21) and caster (70) checks pass. Four fog checks and one structure fish-income check fail identically on an isolated HEAD baseline and on the updated project; those pre-existing failures were left outside this map change.
