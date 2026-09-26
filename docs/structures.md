# Structures and resource demo

Run `scenes/main/Main.tscn` directly for a two-player demo, or start a match from the main menu. Main scatters resources and four additional neutral towns at runtime. Existing authored placements are preserved. `MatchManager.populate_demo_map` disables this behavior; `demo_seed` changes the repeatable scatter.

## Player actions

- Select an owned forest to collect it or build a Lumber Factory. Both require Forestry. Collection gives 1 Sugar and no town EXP.
- Select owned non-ocean water next to land to build a Dock. Sailing is required. The map's lake sources are water; ocean source 5 is excluded from construction.
- Both structures cost 3 Sugar, grant 1 EXP to the controlling town immediately, and add 1 Sugar to its payout at the end of each full round. Construction does not also grant Sugar.
- A forest remains beneath its factory and cannot be collected or developed again.
- Land units may enter a friendly dock from a directly adjacent land cell. This is the sole dock exception to normal land-unit water restrictions.
- Dock entry preserves health, defence, damage, ownership, and spent actions. Boat movement is a symmetric square of radius 2; attacks use a cross of radius 1. Boats can land on ordinary reachable ground, restoring their original movement and attack configuration without healing. They cannot cross land while still moving as a boat.
- A dock and its income belong to its controlling town. Capturing that town transfers dock access and income. Enemy units cannot enter the dock.
- Forest and mountain scenes use the existing biome artwork. Mountains are resources with no collection action in this version; Mining Dens are not part of this implementation.

## Editing and extending

`scripts/data/Structures/Dock.tres` and `LumberFactory.tres` expose costs, construction EXP, round income, technology, placement, and visuals. Dock also exposes boat patterns, ranges, and art. `ResourceData` exposes collection EXP, Sugar, and collection availability.

`StructureData.behavior_script` can reference a `Structure` subclass implementing `on_unit_entered` or `on_round_end`. Register future structure definitions in `StructureManager` and present the appropriate action in `ResourceChoices`. Ground, water, forest, and mountain placement validation are supported by the data model.

## Validation

Run `scenes/structure_regression_test.tscn` for 33 integration checks covering demo setup, construction, payouts, technology/ownership/funds restrictions, ocean rejection, embarkation, landing, stat preservation, and collection. The existing `scripts/range_regression_test.gd` checks range geometry.
