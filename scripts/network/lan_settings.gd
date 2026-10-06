class_name LanSettings
extends Resource

## Inspector-editable ports, transport limits, timeouts, and compatibility versions.
## Loaded from lan_settings.tres; duration fields are seconds unless stated otherwise.


## Preferred gameplay port; automatic hosting can fall back to an available port.
@export var game_port: int = 28760
## First UDP port in the local discovery range.
@export var discovery_port: int = 28761
## Number of consecutive discovery ports tried by local listeners.
@export_range(1, 16) var discovery_slots: int = 8
## Maximum seats in a room, counting both humans and bots.
@export_range(2, 8) var max_players: int = 8
## Seconds allowed for connection and handshake responses.
@export var connect_timeout: float = 10.0
## Seconds allowed for a peer to load the match.
@export var load_timeout: float = 45.0
## Seconds before the host can extend the reconnect wait; expiration does not automatically kick the player.
@export var reconnect_grace: float = 60.0
## Seconds between guest reconnect attempts.
@export var retry_interval: float = 3.0
## Seconds between nearby-room discovery broadcasts.
@export var discovery_interval: float = 1.5
## Seconds without an announcement before a discovered room is removed.
@export var room_expiry: float = 5.0
## Maximum incoming gameplay packets processed in one frame.
@export var packets_per_frame: int = 32
## Largest accepted gameplay packet size, in bytes.
@export var max_packet_bytes: int = 1048576
## Seconds for cosmetic movement playback on networked matches.
@export_range(0.0, 1.0) var move_duration: float = 0.22
## Wire-format version checked before accepting a peer.
@export var protocol_version: int = 2
## Gameplay compatibility label; revise when rule changes require matching builds.
@export var build_version: String = "sweetspire-lan-6-turn-clock"
