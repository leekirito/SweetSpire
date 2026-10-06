extends MapBootstrap

## Exercises real match transitions and snapshot replication with controlled elapsed time.
var checks := 0
var failures := 0

func _enter_tree() -> void:
	GameSession.clear_players()
	GameSession.hotseat_mode = true
	GameSession.map_seed = 2468
	DemoMap.ensure_players(GameSession)
	super._enter_tree()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("TURN CLOCK: " + message)

func run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var game: MatchManager = $MatchManager
	var clock: Node = game.turn_clock
	var hud: Control = $CanvasLayer/Control/TurnTimer
	clock.set_process(false)
	check(GameSession.match_mode == GameSession.REGULAR and GameSession.turn_duration == 120, "new sessions default to Regular and two minutes")
	check(clock.remaining > 119 and clock.remaining <= 120, "first turn starts with full time")
	hud.refresh()
	check(hud.visible and "2:00" in hud.label.text, "local human gets countdown")
	clock.advance(30)
	var saved: float = clock.remaining
	game.turn_started.emit(game.active_player_id, game.current_round)
	check(clock.remaining == saved, "duplicate turn signal cannot refill clock")
	clock.advance(120)
	check(game.active_player_id == 2 and game.current_phase == MatchManager.Phase.HOTSEAT_HANDOFF, "expiry advances to privacy cover")
	hud.refresh()
	check(not hud.visible, "timer hidden during handoff")
	clock.advance(600)
	check(game.active_player_id == 2 and clock.remaining == 0, "handoff wait cannot consume next turn")
	GameSession.turn_duration = 180
	check(game.continue_hotseat_turn() and clock.remaining == 180, "Continue starts full configured three minutes")
	clock.advance(5)
	check(game.request_end_turn(), "manual end remains available")
	GameSession.turn_duration = 300
	game.continue_hotseat_turn()
	check(clock.remaining == 300, "manual advance starts full configured five minutes")
	var unit: Unit = game.units.values()[0]
	unit.is_animating = true
	clock.advance(301)
	check(game.current_phase == MatchManager.Phase.TURN_TIMEOUT and game.active_player_id == 1, "expiry waits for committed movement")
	check(not game.request_end_turn() and not game.request_purchase_technology(1, LanCatalog.TECHS.fishing), "expired turn rejects further actions")
	unit.is_animating = false
	game.combat_resolver.attack_in_progress = true
	clock.advance(1)
	check(game.active_player_id == 1, "expiry waits for committed attack")
	game.combat_resolver.attack_in_progress = false
	clock.advance(1)
	check(game.active_player_id == 2 and game.current_phase == MatchManager.Phase.HOTSEAT_HANDOFF, "settled action advances exactly once")
	game.continue_hotseat_turn()
	GameSession.hotseat_mode = false
	game.get_active_player().controller_kind = "bot"
	hud.refresh()
	check(not hud.visible, "bot countdown hidden from human")
	clock.advance(301)
	check(game.active_player_id == 1, "timeout also advances a bot turn")
	game.get_player(2).controller_kind = "human"
	LanSession.hosting = true
	LanSession.state = "loading"
	LanSession.game = game
	LanSession.local_player_id = 1
	LanSession.seats = [LanSession._seat(1, "Host", "saba"), LanSession._seat(2, "Guest", "kamote")]
	LanSession.loaded = {1: true, 2: true}
	saved = clock.remaining
	clock.advance(600)
	check(clock.remaining == saved, "LAN loading pauses countdown")
	LanSession._try_begin()
	clock.advance(20)
	saved = clock.remaining
	LanSession.paused_for_disconnect = true
	clock.advance(600)
	check(clock.remaining == saved, "disconnect pause preserves time")
	LanSession._try_begin()
	check(clock.remaining == saved, "rejoin resumes without refilling time")
	var revision: int = LanSession.revision
	clock.advance(301)
	check(game.active_player_id == 2 and LanSession.revision == revision + 1, "host timeout publishes authoritative next turn")
	hud.refresh()
	check(not hud.visible, "host cannot see guest countdown")
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(LanSession.snapshot_codec.capture(game, 2)))
	LanSession.hosting = false
	LanSession.local_player_id = 2
	MatchSnapshot.apply(game, snapshot)
	check(clock.remaining == 300, "snapshot transfers remaining time through JSON")
	hud.refresh()
	check(hud.visible, "guest sees countdown on own turn")
	clock.advance(301)
	check(game.active_player_id == 2 and game.current_phase == MatchManager.Phase.PLAYER_TURN, "guest cannot advance authority even at zero")
	LanSession._receive(1, "clock", {"active": 2, "round": game.current_round, "remaining": 42.0, "key": clock.turn_key})
	check(clock.remaining == 42, "host clock update corrects guest display")
	LanSession._receive(99, "clock", {"active": 2, "round": game.current_round, "remaining": 200.0})
	check(clock.remaining == 42, "non-host clock update ignored")
	clock.apply_remote({"active": 1, "round": game.current_round, "remaining": 200.0})
	check(clock.remaining == 42, "previous seat clock update ignored")
	game.current_phase = MatchManager.Phase.GAME_OVER
	hud.refresh()
	clock.advance(600)
	check(not hud.visible and clock.remaining == 42, "game over hides and stops timer")
	LanSession.leave()
	GameSession.turn_duration = 4
	check(GameSession.turn_duration == 120, "invalid duration falls back to two minutes")
	print("TURN CLOCK: %d checks, %d failures" % [checks, failures])
	await get_tree().create_timer(0.4).timeout
	get_tree().quit(1 if failures else 0)
