extends Node

## Authority-owned turn deadline. Guests only display the host's remaining time.
## An expired turn blocks new commands while committed local animations settle.
var remaining: float = 0.0
var turn_key := ""
var _last_tick: int = 0
var _sync_elapsed := 0.0
@onready var game: MatchManager = get_parent()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -100
	_last_tick = Time.get_ticks_msec()
	game.turn_started.connect(func(_seat: int, _round: int): start_turn())

func authority() -> bool:
	return not LanSession.active() or LanSession.hosting

func running() -> bool:
	return (game.current_phase in [MatchManager.Phase.PLAYER_TURN, MatchManager.Phase.TURN_TIMEOUT]
		and not get_tree().paused
		and (not LanSession.active() or (LanSession.state == "playing" and not LanSession.paused_for_disconnect)))

## Re-emitting turn_started on reconnect must preserve this turn's deadline.
func start_turn() -> void:
	if not authority() or game.current_phase != MatchManager.Phase.PLAYER_TURN:
		return
	var key := "%d:%d" % [game.current_round, game.active_player_id]
	if key != turn_key:
		turn_key = key
		remaining = GameSession.turn_duration
	_last_tick = Time.get_ticks_msec()
	if remaining <= 0.0:
		game.current_phase = MatchManager.Phase.TURN_TIMEOUT

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	var elapsed := maxf(0.0, float(now - _last_tick) / 1000.0)
	_last_tick = now
	advance(elapsed)

## Accepts elapsed wall time separately so deadline behavior can be tested without waiting minutes.
func advance(elapsed: float) -> void:
	if turn_key.is_empty() or not running():
		return
	remaining = maxf(0.0, remaining - elapsed)
	if not authority():
		return
	if remaining <= 0.0:
		game.current_phase = MatchManager.Phase.TURN_TIMEOUT
		if game.combat_resolver.attack_in_progress or game.turn_manager.any_unit_animating(game):
			return
		game.turn_manager.end_turn(game)
		if LanSession.active():
			LanSession.revision += 1
			LanSession.publish_state()
		return
	_sync_elapsed += elapsed
	if LanSession.active() and _sync_elapsed >= 1.0:
		_sync_elapsed = 0.0
		LanSession.broadcast_clock()

func capture() -> Dictionary:
	return {"remaining": remaining, "key": turn_key, "active": game.active_player_id, "round": game.current_round}

## Only LanSession's authenticated host-message path calls this on guests.
func apply_remote(data: Dictionary) -> void:
	if authority() or int(data.get("active", -1)) != game.active_player_id or int(data.get("round", -1)) != game.current_round:
		return
	turn_key = str(data.get("key", ""))
	remaining = clampf(float(data.get("remaining", 0.0)), 0.0, float(GameSession.turn_duration))
	_last_tick = Time.get_ticks_msec()
