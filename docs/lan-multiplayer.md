# Windows LAN multiplayer

One player's game hosts the match and plays as seat 1. Other Windows players on the same network join that computer. A lobby supports 2–8 occupied seats; repeated tribes are allowed. Hotseat still supports 1–8 local players with its pass-the-device cover.

## Playing

1. Open **Play → LAN**. Enter your name and select a tribe.
2. One player enters an optional room name, chooses the room capacity and **Fog of War** or **Regular**, and presses **Host Game**.
3. Friends select the room under **Nearby Games**, then press **Join Game**. If discovery is unavailable, enter the host address shown in the host's lobby.
4. Everyone presses **Ready**. Changing tribe clears that player's readiness. Changing the mode clears everyone's readiness. Only the host can change the mode, and only before the match starts. The host presses **Start Match** once everyone is ready; unused capacity does not prevent starting.
5. Each device keeps its own camera, fog, Sugar and technology view. Only the current seat may issue gameplay actions. LAN does not use Hotseat's cover.

Allow the Windows game through the **Private networks** firewall prompt. Default UDP ports are **28760** for gameplay and **28761** for nearby discovery. The lobby also accepts a custom gameplay port. Guest Wi-Fi with device isolation can block both discovery and joining; use a network that permits communication between devices.

On a guest disconnect, the match pauses and the guest automatically retries while its application remains open. The host can keep waiting after the 60-second grace period or return to the menu. An eliminated guest can leave without pausing the remaining players. Closing the host ends the session; there is no host migration. Reconnect tokens are held in memory, so closing and restarting a guest application does not restore its seat.

The browser build continues to support local play. LAN Host/Join is disabled there.

**Fog of War** is the default: exploration and vision reveal the map. **Regular** makes all terrain, units, towns and resources visible from the start for every player. Attack and movement ranges still apply, and each player's Sugar and technologies remain private. The same two modes are available in Hotseat setup; the pass-the-device cover remains enabled for both modes.

## Files and customization

| File | Responsibility |
| --- | --- |
| `scripts/network/lan_settings.tres` / `.gd` | Ports, player limit, timeouts, discovery timing, movement presentation speed, protocol and build version. Edit the resource in the Inspector. |
| `scripts/network/lan_session.gd` | ENet transport, lobby, stable seats, loading barrier, command sequencing, reconnect tokens and UDP discovery. Registered as the `LanSession` autoload. |
| `scripts/network/lan_catalog.gd` | Approved tribe, unit, technology and structure IDs; authored rule compatibility signature. |
| `scripts/network/match_commands.gd` | Checks command shape, seat and turn, then invokes the existing gameplay rule systems. |
| `scripts/network/match_snapshot.gd` | Builds recipient-specific state and applies host state on guests. |
| `scripts/network/ui/` | Lobby and connection overlay behavior. |
| `scenes/network/LanLobby.tscn` | Editable lobby layout, inputs, tribe picker, nearby rooms, roster and readiness. Instanced in MainMenu as `LANSetup`. |
| `scenes/network/LanMatchStatus.tscn` | Editable loading, reconnection and leave-game controls. |
| `scripts/network/tests/` / `scenes/network/tests/` | Automated checks; excluded from Windows and Web exports. |

The existing `MatchManager`, `CombatResolver`, economy, technology, territory, capture, victory and structure systems remain responsible for rules. LAN wraps their public requests; it does not maintain a second set of game rules. Hotseat uses the original local flow, including its animation timing and paused handoff.

When adding an action, add a catalog ID if necessary, validate the intent in `MatchCommands`, and route the UI request through `LanSession.submit`. Include any new authoritative state in snapshot capture/apply and in a test. Do not accept file paths or Resource objects from guests. Bump `build_version` for rule-script or scene-setting changes and `protocol_version` for incompatible message formats. Authored data values and biome catalogs are checked automatically during joining.

## State and presentation

The host generates the map once, sends the assembled terrain and neutral authored placements, then waits for all peers to load before starting. The current protocol treats terrain and neutral placement positions as public map data. It omits player starting assignments from guest setup messages. Unexplored terrain is still visually covered by fog.

Guests receive their own Sugar, technologies and exploration; live enemy units are included only within their vision. Towns, resources and structures retain their last known state outside vision. Loss of a previously owned town is delivered even when that capture removes its vision. The host necessarily holds the whole state and is assumed to be a trusted friend.

Commands are bound to the authenticated connection's seat. The server rejects invalid IDs, wrong turns, ownership violations, invalid placements/costs and duplicate sequence numbers. Traffic is bounded by packet size, per-frame processing and per-peer budgets. Reconnect resumes with the host's last accepted command number and a fresh snapshot.

LAN commits movement and damage immediately, then displays cosmetic movement and attack effects. Presentation never controls costs, damage or turn timing. Attack effects are sent only to recipients who can see the affected area. Hotseat keeps its existing animation-driven presentation.

## Validation

Run the complete local suite from PowerShell, supplying your Godot console executable:

```powershell
& ./scripts/network/tests/run_lan_tests.ps1 -GodotPath 'C:/path/to/Godot_console.exe' -Players 8
```

Add `-Regular` to run the multi-process gameplay and reconnect checks with the fully visible map. Without it, the runner tests Fog of War.

The runner checks discovery, version/full-room rejection, readiness changes, command validation, private snapshots, recruitment, resources, structures, combat, boats, elimination/victory, and 2–8 separate game processes taking turns and reconnecting. It also runs the Hotseat, fog, structure, caster and map-generation regressions. Logs go under `.godot/lan-tests/`. Ports 29876–29878 are reserved by these local tests; discovery uses the configured discovery port.

Local processes exercise the real ENet transport, but cannot establish that a router or Windows firewall permits two physical computers. Before distribution, export the same Windows build to two computers and verify nearby discovery, joining by address, gameplay, guest disconnect/reconnect, and host exit. Exported Windows and physical Wi-Fi validation remain manual checks.

Internet matchmaking, browser networking, account login, spectators, mid-match new players, AI takeover, host migration and persistent saved matches remain outside this version.
