# LAN multiplayer implementation plan

Updated 2026-10-05. Windows LAN implementation is now present. See [LAN setup and architecture](lan-multiplayer.md) for the implemented behavior, customization and test runner. Local multi-process validation is automated; exported builds on separate computers still need manual validation.

## Agreed direction

First release: Windows players on the same Wi-Fi/local network, with no hosted service or recurring server cost. One player's running game acts as the authoritative server and also displays that player's own game. This is a listen-server architecture. Other players connect to that computer.

The browser build retains local modes initially. Godot's browser networking supports WebSockets/WebRTC rather than ENet's UDP transport. Internet room codes and browser cross-play require a separate transport/connectivity decision later.

## Player experience

1. Play → LAN → Host Game. Choose a display name, tribe, room name and capacity from 2–8; create the lobby.
2. Other players open LAN → Join Game and choose from a nearby-games list. Discovery advertises only while the host lobby is open and refreshes automatically. Offer manual local-IP entry as a fallback when network discovery is blocked.
3. Everyone chooses a tribe and presses Ready. Repeated tribes are allowed. Changing a tribe clears Ready. The host starts when all occupied seats are ready; empty capacity does not require dummy players.
4. Show loading progress per player. Start gameplay only after the roster and map have been validated and every client has acknowledged setup.
5. Each device controls its own seat, camera, Sugar display, technology UI and fog throughout the round. Show whose turn it is; no hotseat handoff cover in LAN mode.
6. Automatically attempt to reconnect a dropped client and restore its seat while the host remains available. Use a private reconnect token rather than trusting a display name or requested player ID.

Show clear messages for full lobbies, incompatible builds, failed connections and matches already in progress. Explain Windows' Private-network firewall prompt if needed. Guest Wi-Fi/client isolation can prevent devices from talking even when they use the same Wi-Fi name; manual IP entry cannot bypass isolation. No router port forwarding is needed for ordinary LAN play.

## Networking and authority

Use Godot ENet for reliable gameplay commands and state messages, plus UDP discovery on the local network. Keep discovery separate from the actual game connection. The host listens on a documented game port; discovery includes room name, occupied seats/capacity, compatibility version and game port. Manual entry remains available if broadcast discovery fails.

The host owns the match state and generates the map once. Clients submit intent: move a unit, attack a cell, buy a technology, construct a structure or end a turn. The host validates the sender's bound seat, phase, turn, ownership, visibility, prerequisites, placement and costs before applying anything. The host player's own inputs use the same validation path.

Do not send Godot Resource objects, PackedScenes, arbitrary file paths or executable data as commands. Resolve approved unit/technology/structure catalog IDs locally. Keep stable player IDs separate from network peer IDs so reconnects can restore the same seat.

Assign command IDs to prevent repeat purchases or actions after retries, and a match revision to order accepted results. Start with bounded per-player snapshots after accepted actions plus presentation events. Optimize into smaller updates only if measurements justify it. Rejoining receives a fresh snapshot instead of replaying stale clicks.

## Existing foundations and required changes

The project already has MatchManager action entry points, rule-system classes, stable generated entity IDs, and validated map manifests with a catalog signature. The LAN screen is currently presentation only.

- Extend GameSession with explicit offline/hotseat/LAN modes, stable local player identity and connection state.
- Put every mutation behind one action dispatcher. Include structure construction, which currently has UI calls directly into StructureManager. Local/Hotseat and LAN should use the same rules.
- Separate accepted rule changes from presentation timing. Combat damage currently happens through animation callbacks, and End Turn depends on local animation flags. A slow client or animation must not cause different rules or block everyone indefinitely. Let clients animate ordered accepted results.
- Separate local viewpoint from active turn. Online HUD and fog stay tied to the local player's seat while another player acts.
- Define snapshots covering players, technologies, Sugar, units/health/actions/embarkation, towns/progression, resources, territory, structures, round/turn, exploration, elimination and victory.
- Validate protocol/build/rules/catalog compatibility. Generate the biome layout on the host, send validated setup data, and never let clients independently reroll. Add a loading barrier before Main begins round one.
- Build the lobby and reusable player rows in editable Godot scenes, not runtime-created layouts.

## Fog and hidden information

The host necessarily holds the full game state; this initial design assumes a trusted friend hosting. Each guest should receive only the live entity/economy information it is allowed to see. Also filter combat events and camera targets. Hiding fully replicated enemies with visible=false does not protect their positions.

The current complete map manifest includes layout and starting assignments. Decide whether unexplored terrain/layout is intended to be private. If layout is public, distribute a layout manifest without other players' starting assignments and filter live state separately. If terrain and authored placements must remain secret too, clients must receive discovered terrain/entities rather than the full manifest. Resolve this before finalizing setup messages.

## Implemented disconnect policy

- Lobby: remove disconnected guests and update readiness. Closing the host lobby closes it for everyone with a clear message.
- Match, active guest disconnect: pause for a 60-second reconnect grace period, then let the host choose Keep Waiting or Return to Menu. No silent forfeits or invented AI turns. Eliminated guests may leave without blocking the match.
- Host disconnect/exit: the match cannot continue without its server. Show a clear disconnection screen and return-to-menu option. Host migration is deferred.
- Reconnecting to a running host is in scope; recovering a match after the host application closes requires saved-match persistence and is a separate feature.

## Implementation milestones

1. **Rules and state foundation:** command dispatcher, snapshots, seat identity, local viewpoint and animation separation. Preserve all existing Hotseat behavior.
2. **Two-player LAN proof:** Host/Join/Ready, shared map loading, movement, attacks and End Turn. Test two processes first, then two actual Windows computers on the same network.
3. **Complete existing gameplay:** recruitment, technologies, harvesting, Farms, Mining Dens, Lumber Factories, Docks/boats, captures, income, elimination and victory. Expand to 2–8 players and repeated tribes. Unimplemented technologies remain outside this networking scope.
4. **Friendly joining and recovery:** automatic LAN discovery, manual-address fallback, helpful errors, reconnect tokens, resynchronization and the agreed disconnect behavior.
5. **Exported Windows validation:** complete matches across real computers, test blocked discovery and firewall failures, mismatched builds, host/guest exits, latency and rapid duplicate clicks. Retest offline and Hotseat modes.

## Acceptance checks

- Two through eight clients finish a match with consistent shared state and correct private views.
- The host cannot accidentally apply its own command twice; guests cannot act for another seat, outside their turn, or with invalid IDs/costs.
- All map starts match the agreed tribes; mismatched builds are rejected before gameplay begins.
- Retrying a command cannot charge Sugar twice or repeat movement/combat.
- A reconnect restores seat, unit actions, Sugar, technologies, exploration and turn state.
- Slower client animation does not change rule results or the turn order.
- Every connection failure offers a recovery/exit path instead of leaving an unresponsive board.
- Hotseat retains flexible 1–8-player setup and its pass-the-device cover.

## Deferred

Internet hosting, accounts, ranked matchmaking, browser networking, spectators, chat, joining mid-match as a new participant, simultaneous turns, AI takeover, host migration and persistent save/resume. Keep the command/state protocol transport-independent so future internet support can reuse the rules.

## References

- Godot high-level networking, ENet, LAN hosting and browser limitations: https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html
- WebSockets as a possible future browser-compatible transport: https://docs.godotengine.org/en/stable/tutorials/networking/websocket.html
