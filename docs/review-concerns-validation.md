# Validation of the supplied review concerns

**Follow-up:** the territory reconstruction and local/guest fog discrepancies
described below have now been fixed. The original audit and reproductions are
retained as historical evidence. The permanent
[knowledge regression](../scripts/network/tests/knowledge_regression_test.gd)
now checks the corrected behavior; temporary pre-fix audit probes were removed
during project cleanup. See the
[LAN state/presentation notes](lan-multiplayer.md) for implementation details.

The permanent suite has 32 checks after removing unrelated audit-only checks.
Selection and caster tests also run cleanly with their deliberately detached
match fog reference: observation receives the publishing fog layer's visibility
directly. The LAN runner now rejects logged script errors and failed assertions
even if Godot exits with status zero.

Checked against the working tree on 2026-10-06. This was an audit, not a gameplay
change. Earlier documentation edits remain intact.

The requested threshold was a reproducible problem that blocks normal play,
corrupts match state, crashes, or stalls supported matches. Proposed balance
changes, hypothetical future renames, style, and unsupported modes are excluded.

## Confirmed gameplay blocker: LAN territory reconstruction

**Result: valid.** A guest can be prevented from building on a tile the host
correctly recognizes as theirs.

[TerritoryManager](../scripts/TerritoryManager.gd) preserves the first town to
claim an overlapping cell. This depends on expansion history. The
[snapshot](../scripts/network/match_snapshot.gd) sends town levels and owners,
but no cell-to-town claim mapping. On receipt it rebuilds claims from the guest's
own previous knowledge and town iteration order.

This matters when a guest first learns about towns after their territories have
already grown. Resource and existing-structure records carry their controlling
town, but empty construction tiles have no equivalent authoritative record.
[ResourceChoices.open_tile](../scripts/UI/resource_choices.gd) consults the
guest's controlling town before opening; placement validation also consults it.

The targeted runtime reproduction used actual generated towns, with seed 2468:

1. Town A at `(4,4)` belongs to seat 1. Town B at `(7,7)` belongs to seat 3.
2. B reaches level 4 before A. The existing territory rules award empty land
   `(4,6)` to B and preserve that claim when A expands.
3. Seat 2 captures B. This transfers B's existing claim and reveals neighboring
   A. The guest's earlier knowledge of these towns has no ownership claims.
4. The host's `placement_error(FARM, (4,6), 2)` returns an empty string: legal.
5. The real recipient snapshot is serialized through JSON and applied with
   guest-side claims initially empty. Both town records arrive correctly.
6. Guest reconstruction assigns `(4,6)` to A (town ID 1), whereas the host
   assigned it to B (town ID 2).
7. Guest placement returns `Build inside your territory`, and `open_tile`
   creates no action panel. The legal construction cannot be submitted through
   the normal UI.

This is a rules synchronization defect, not a proposed change to which town
should win overlapping claims. A repair should transmit authoritative claim
information appropriate to the recipient and stop independently inventing
ownership for buildable cells. No repair was applied during this audit.

## Confirmed information discrepancy, separate from match blockers

**Local fog exposes unseen ownership changes; guest snapshots remember them.**

The reproduction let seat 1 see a town owned by seat 2, removed its scout, and
confirmed that the town was explored but outside current sight. Ownership then
changed to seat 3. The local town remained visible with seat 3's live artwork,
while a snapshot for the same observer retained seat 2 as its last-seen owner.

[FogOfWar._apply_entity_visibility](../scripts/fog_of_war.gd) shows explored
towns from live state. [MatchSnapshot.capture](../scripts/network/match_snapshot.gd)
retains last-seen opponent state outside sight. The implementation therefore
gives different information depending on whether the observer is local or a
guest. The test proves town ownership/artwork divergence; it does not visually
test every resource and territory-border example in the supplied review.

This does not freeze or prevent completion of a match, so it is not counted as
a gamebreaking blocker under the requested scope. It is a real multiplayer
fairness inconsistency. Any repair should first preserve one consistent fog
policy across host, guest, and Hotseat views.

## Serious-sounding claims that did not establish a current blocker

| Concern | Verdict and evidence |
| --- | --- |
| Fog refresh recursively re-enters through `fog_updated` | False for the stated path. The signal is emitted **before** `_refreshing` is cleared. A runtime listener attempted `refresh(true)` from that signal: the guard held and only one callback ran. The repeated assignment is redundant, not the claimed recursion. |
| `request_recruitment` submits twice | False. Its LAN branch returns immediately; host execution also runs with `LanSession.executing`. The public-wrapper probe recorded exactly one new command, one new unit, and one unit cost charged. |
| LAN movement prevents End Turn | False for current network movement. Its tween does not set `is_animating`. The probe successfully ended the turn while the tween was running. Local animation waiting is an existing gameplay/presentation rule. |
| EXP segments leak on refresh | Not reproduced. After 12 immediate refreshes the container held one correct segment set; the original segment objects were invalid after the next frame. Temporary deferred deletion is not a permanent leak. |
| Resources show through structures on guests | The claimed missing behavior is already handled elsewhere. Snapshot application calls fog refresh, whose resource visibility expression explicitly excludes cells containing structures. |
| Disconnected players freeze the match with no recovery UI | Overstated. Pausing is intentional; the grace timer enables the host's Wait control, and Leave remains available. Reconnection tests passed. Continuing without a permanently absent player would be a new forfeit/takeover policy, not a correction to the current pause policy. |
| Debug grid renders in ordinary matches | False for Main: its scene overrides both debug flags to false. Runtime probe verified both values. |
| Flying units disappear into holes | A conditional edge case in the terrain-ignoring path, but no registered unit enables it. The generated supported map is a filled rectangle. No current playable-unit blocker was established. |
| Bot prerequisite loop freezes current matches | Cycles would be a robustness problem, but every registered technology chain was traversed and found acyclic. No current freeze was reproduced. |
| Bots act during setup if the `playing` string changes | The claimed direction is wrong: equality would fail and block them. Current execution also requires a bot seat, its active turn, player-turn phase, host authority, and no disconnect pause. |
| Old menu scenes lack LAN screens or bot selectors | Current scene files and the 35-check LAN UI suite agree. This does not establish whether an old, unsaved tab existed during the other review. |
| Startup silently fails for missing starting data | Valid robustness concern for malformed or custom setups, not reproduced with current content. Generated-map validation reports map failures through an overlay; map and Hotseat suites passed. All towns instantiated by the targeted generated-map fixture had BuildingData. |
| Unguarded `_end_turn()` bypasses rules | The wrapper exists, but the code/scene search found no caller using it to drive gameplay. Actual UI, commands, and bots use guarded requests. |
| Recruitment popups accumulate permanently | No gamebreaking reproduction. Existing UI dismisses popups on outside clicks and turn changes; the selection suite verifies outside-click dismissal. Calling the factory repeatedly from arbitrary code is not proof of a normal-input leak. |
| Case-only AI folder rename breaks referenced paths | No remaining `scripts/AI/` references were found in the gameplay scripts/scenes searched. This audit did not perform a new Linux or browser export. |
| Malformed host packets or missing authored nodes crash guests | These are defensive-programming concerns. The supplied review did not give a valid host-generated packet or supported scene producing the alleged crash; current host/guest tests passed. Arbitrarily corrupted content or a malicious host is outside this audit's normal-play threshold. |
| Fog polling, scene instantiation, lookup costs, and EXP redraw churn are gamebreaking | Some repeated work exists. Eight-seat runs completed, and no hang was established by these claims. This is not a performance certification on slower hardware; frame-time profiling would be needed to establish severity. |

Cumulative center control, retained town progression after capture, and waiting
for disconnected players were not treated as bugs merely because another design
could work differently. All-bot spectator play is outside current setup options.
Naming, refactors, enum/shadowing warnings, debug prints, line endings, and
future rename hazards were excluded from the gamebreaking verdict.

## Verification and limits

- Existing LAN runner passed with eight processes in Fog of War, including
  lobby/UI/rules, reconnection, Hotseat, selection, fog, structures, caster, and
  map-generation suites.
- Existing bot runner passed: rules, setup UI, eight-seat games, host with bots,
  host/guest games and reconnection, in both Fog of War and Regular, plus local
  bot regression.
- The targeted probe completed 20 checks with zero harness failures. Checks
  labelled `REPRODUCED` assert the presence of the two inconsistencies above;
  a passing harness does not mean those defects are fixed.
- These were headless runs on this computer. They do not certify cross-device
  firewall behavior, rendering appearance, exported builds, or all possible
  gameplay sequences. Godot also printed its certificate-store warning, and
  the targeted harness printed shutdown object/resource cleanup warnings;
  neither was counted as proof of a gameplay crash.

Temporary audit artifacts were removed after the reproductions became permanent
regression checks. Current suite logs are under `.godot/lan-tests/` and can be
regenerated by the test runners; they are not exported gameplay files.

To rerun the permanent regression with the Godot console executable:

```text
--headless --path <project-directory> --quit-after 600 res://scenes/network/tests/KnowledgeRegressionTest.tscn
```

The reproduction directly sets up reachable town ownership/level histories and
uses the real snapshot serializer and applier. It does not automate a full
three-player campaign from opening moves through those captures.
