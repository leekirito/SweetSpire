# Windows LAN multiplayer

One player's game hosts the match and plays as seat 1. Other Windows players on the same network join that computer. A lobby supports 2–8 occupied seats; repeated tribes are allowed. Hotseat still supports 1–8 local players with its pass-the-device cover.

## Playing

1. Open **Play → LAN**, then choose **Host Game** or **Join Game**.
2. **Host Game** opens the lobby immediately. The host can change the room name, capacity, **Fog of War / Regular**, **Turn Time** (2, 3, or 5 minutes), and **Public / Private**. The game chooses an available gameplay port and displays the complete host address; **Copy Address** copies it for sharing. With multiple network adapters, select the address on your friends' network.
3. **Join Game** opens **Nearby Games**. Select a public room and press **Join Selected Room**, or enter a host address and port below. Pasting a complete `address:port` fills both fields. Full rooms and rooms running a different version are shown but cannot be selected for joining.
4. Choose your name and tribe in your own lobby row, then press **Ready**. Changing tribe clears that player's readiness. Changing capacity, mode, turn time or privacy clears everyone's readiness. Only the host can change room settings before the match starts. The host presses **Start Match** once everyone is ready; unused capacity does not prevent starting.
5. Each device keeps its own camera, fog, Sugar and technology view. Only the current seat may issue gameplay actions. LAN does not use Hotseat's cover.

**Public** means discoverable on the same local network. **Private** hides the room from nearby discovery and requires an address and password to join. Switching to Private generates a password; the host can copy it or enter a replacement and press **Set Password**. Guests enter it under Join by Address. Changing privacy or the password does not remove players already admitted. Previously discovered entries expire within five seconds after a room becomes private or closes.

The host can **Kick** another player from the lobby before the match begins. The player returns to Join with an explanation, and the old seat and reconnect token are removed. This is removal, not a permanent ban; they may join again if they have the current access details.

Allow the Windows game through the **Private networks** firewall prompt. Gameplay prefers UDP **28760**, falling back to an operating-system-assigned port if occupied. Nearby discovery tries UDP **28761–28768**, allowing multiple hosts on one computer. These defaults are configurable in `lan_settings.tres`. Discovery failure still permits joining by address. Guest Wi-Fi with device isolation can block both discovery and joining; use a network that permits communication between devices.

On a guest disconnect, the match pauses and the guest automatically retries while its application remains open. The host can keep waiting after the 60-second grace period or return to the menu. An eliminated guest can leave without pausing the remaining players. Closing the host ends the session; there is no host migration. Reconnect tokens are held in memory, so closing and restarting a guest application does not restore its seat.

The browser build continues to support local play. LAN Host/Join is disabled there.

**Regular** is the default. **Fog of War** uses exploration and vision to reveal the map. **Regular** makes all terrain, units, towns and resources visible from the start for every player. Attack and movement ranges still apply, and each player's Sugar and technologies remain private. The same two modes are available in Hotseat setup; the pass-the-device cover remains enabled for both modes.

Each human and bot turn has a **2-minute** limit by default. Hotseat setup and the host's LAN lobby offer **2, 3, or 5 minutes**. A countdown appears below the player/round header only on your human turn; it turns red for the final 15 seconds. At zero, new actions stop and the turn advances automatically after any already-committed local movement or attack finishes. Loading, LAN disconnect pauses, and the Hotseat handoff cover consume no turn time. Pressing Continue starts the next human's full allowance. Reconnection resumes the remaining time instead of resetting it.

The clock is authoritative on the host, with small clock updates sent each second and remaining time included in match snapshots. Clients display the countdown but cannot advance turns themselves. This requires matching `sweetspire-lan-6-turn-clock` builds.

## Files and customization

| File | Responsibility |
| --- | --- |
| `scripts/network/lan_settings.tres` / `.gd` | Ports, player limit, timeouts, discovery timing, movement presentation speed, protocol and build version. Edit the resource in the Inspector. |
| `scripts/network/lan_session.gd` | ENet transport, lobby, stable seats, loading barrier, command sequencing, reconnect tokens and UDP discovery. Registered as the `LanSession` autoload. |
| `scripts/network/lan_room_access.gd` | Private-room password generation and one-use challenge authentication. Secrets stay out of discovery and roster messages. |
| `scripts/network/lan_address.gd` | Parses pasted endpoints and lists local IPv4 addresses. |
| `scripts/network/lan_catalog.gd` | Approved tribe, unit, technology and structure IDs; authored rule compatibility signature. |
| `scripts/systems/game_commands.gd` | Shared human LAN/bot dispatcher: checks command shape, seat and turn, then invokes the existing gameplay rule systems. |
| `scripts/network/match_snapshot.gd` | Builds recipient-specific state and applies host state on guests. |
| `scripts/network/ui/` | Lobby and connection overlay behavior. |
| `scenes/network/LanLobby.tscn` | Screen shell, navigation and status. Instanced in MainMenu as `LANSetup`. |
| `scenes/network/LanChoice.tscn` / `LanBrowser.tscn` | Editable Host/Join choice and nearby/manual joining screens. |
| `scenes/network/LanRoom.tscn` / `LanPlayerRow.tscn` | Editable room settings, address/password controls, scrollable player rows and readiness. Preview rows are replaced with live players at runtime. |
| `scenes/network/LanMatchStatus.tscn` | Editable loading, reconnection and leave-game controls. |
| `scripts/network/tests/` / `scenes/network/tests/` | Automated checks; excluded from Windows and Web exports. |

The existing `MatchManager`, `CombatResolver`, economy, technology, territory, capture, victory and structure systems remain responsible for rules. LAN wraps their public requests; it does not maintain a second set of game rules. Hotseat uses the original local flow, including its animation timing and paused handoff.

When adding an action, add a catalog ID if necessary, validate the intent in `GameCommands`, and route the UI request through `LanSession.submit`. Include any new authoritative state in snapshot capture/apply and in a test. Do not accept file paths or Resource objects from guests. Bump `build_version` for rule-script or scene-setting changes and `protocol_version` for incompatible message formats. Authored data values and biome catalogs are checked automatically during joining.

## State and presentation

Territory cells are now included in each recipient's remembered state. Guests
install the host's known cell-to-town claims directly, including cleared claims,
instead of rebuilding overlap priority from town order. This preserves the
original claimant when expanded towns overlap and keeps legal construction
available after discovering or capturing previously unseen towns.

`scripts/systems/match_knowledge.gd` owns static observations for every seat.
Local/host fog and LAN snapshots share this history. Towns, resources, structures,
and territory colors retain their last observed state outside current sight;
own holdings and loss of previously owned holdings are updated. Hotseat views
have separate memories. `scripts/fog_memory_view.gd` renders remembered sprites
without collision, gameplay scripts, or registry entries. Live entities and
their status controls are shown in current sight; remembered sprites supply the
explored view. Regular mode continues to show current state everywhere.

The snapshot format now requires `claims`; protocol version 2 and build
`sweetspire-lan-6-turn-clock` reject older builds during the compatibility
handshake. Re-export every LAN participant together. The regression runner
includes `KnowledgeRegressionTest`, covering overlapping territory, Hotseat
memory, unseen captures/collection/construction, JSON delivery, and claim removal.

The host generates the map once, sends the assembled terrain and neutral authored placements, then waits for all peers to load before starting. The current protocol treats terrain and neutral placement positions as public map data. It omits player starting assignments from guest setup messages. Unexplored terrain is still visually covered by fog.

Guests receive their own Sugar, technologies and exploration; live enemy units are included only within their vision. Towns, resources and structures retain their last known state outside vision. Loss of a previously owned town is delivered even when that capture removes its vision. The host necessarily holds the whole state and is assumed to be a trusted friend.

Commands are bound to the authenticated connection's seat. The server rejects invalid IDs, wrong turns, ownership violations, invalid placements/costs and duplicate sequence numbers. Traffic is bounded by packet size, per-frame processing and per-peer budgets. Reconnect resumes with the host's last accepted command number and a fresh snapshot.

LAN commits movement and damage immediately, then displays cosmetic movement and attack effects. Presentation never controls costs, damage or turn timing. Attack effects are sent only to recipients who can see the affected area. Hotseat keeps its existing animation-driven presentation.

## Validation

Run the complete local suite from PowerShell, supplying your Godot console executable:

```powershell
& ./scripts/network/tests/run_lan_tests.ps1 -GodotPath 'C:/path/to/Godot_console.exe' -Players 8
```

Add `-Regular` to run the multi-process gameplay and reconnect checks with the fully visible map. Without it, the runner tests Fog of War. Add `-Private` to require password authentication for all joining processes.

The runner checks screen navigation, discovery, automatic port fallback, password rejection/admission, kicks, version/full-room rejection, readiness changes, command validation, private snapshots, recruitment, resources, structures, combat, boats, elimination/victory, and 2–8 separate game processes taking turns and reconnecting. It also runs the Hotseat, fog, structure, caster and map-generation regressions. Logs and per-run completion markers go under `.godot/lan-tests/`. Processes stay connected until every peer observes the final round, avoiding test teardown races. Ports 29876–29879 and the preferred gameplay/discovery ports must be free before running the suite.

Local processes exercise the real ENet transport, but cannot establish that a router or Windows firewall permits two physical computers. Before distribution, export the same Windows build to two computers and verify nearby discovery, joining by address, gameplay, guest disconnect/reconnect, and host exit. Exported Windows and physical Wi-Fi validation remain manual checks.

Internet matchmaking, browser networking, account login, spectators, mid-match new players, AI takeover, host migration and persistent saved matches remain outside this version.
