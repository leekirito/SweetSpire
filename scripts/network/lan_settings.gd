class_name LanSettings
extends Resource

@export var game_port: int = 28760
@export var discovery_port: int = 28761
@export_range(1, 16) var discovery_slots: int = 8
@export_range(2, 8) var max_players: int = 8
@export var connect_timeout: float = 10.0
@export var load_timeout: float = 45.0
@export var reconnect_grace: float = 60.0
@export var retry_interval: float = 3.0
@export var discovery_interval: float = 1.5
@export var room_expiry: float = 5.0
@export var packets_per_frame: int = 32
@export var max_packet_bytes: int = 1048576
@export_range(0.0, 1.0) var move_duration: float = 0.22
@export var protocol_version: int = 1
@export var build_version: String = "sweetspire-lan-4-bots"
