extends CanvasLayer

@export var saba_tribe: TribeData
@export var malagkit_tribe: TribeData
@export var kamote_tribe: TribeData

var selected_tribes: Dictionary[int, TribeData] = {}
const MENU_DESIGN_SIZE := Vector2(1152.0, 648.0)

@onready var design_canvas: Control = $Main/DesignCanvas
@onready var animation_player: AnimationPlayer = $Main/DesignCanvas/AnimationPlayer
@onready var menu_buttons: VBoxContainer = $Main/DesignCanvas/MenuButtons
@onready var options_panel: PanelContainer = $Main/DesignCanvas/OptionsPanel
@onready var fullscreen_button: CheckButton = $Main/DesignCanvas/OptionsPanel/Options/Fullscreen

var menu_transitioning: bool = false
var hotseat_selection_labels: Dictionary[int, Label] = {}
var hotseat_player_count: int = 2
var hotseat_kinds: Dictionary = {}
var hotseat_profiles: Dictionary = {}
var hotseat_names: Dictionary[int, String] = {}
var hotseat_tribe_buttons: Dictionary = {}
var hotseat_grid: GridContainer
var hotseat_start: Button
var hotseat_status: Label
var hotseat_count_picker: OptionButton


func _ready() -> void:
	get_viewport().size_changed.connect(_resize_main_visuals)
	_resize_main_visuals()
	animation_player.play(&"RESET")
	$Main/DesignCanvas/MenuButtons/MarginContainer/PlayButton.pressed.connect(_open_game_setup)
	$Main/DesignCanvas/MenuButtons/MarginContainer2/OptionsButton.pressed.connect(_open_options)
	$Main/DesignCanvas/MenuButtons/MarginContainer3/QuitButton.pressed.connect(_quit_game)
	$Main/DesignCanvas/OptionsPanel/Options/BackButton.pressed.connect(_close_options)
	fullscreen_button.toggled.connect(_set_fullscreen)
	$ModeSelection/Panel/Margin/Content/HotseatButton.pressed.connect(_open_hotseat)
	$ModeSelection/Panel/Margin/Content/LanButton.pressed.connect(_open_lan_setup)
	$ModeSelection/Panel/Margin/Content/BackButton.pressed.connect(_return_to_main_menu)
	$LANSetup.back_requested.connect(_back_to_mode_selection)
	fullscreen_button.set_pressed_no_signal(
		DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	)

	_setup_hotseat_layout()


## Wire the authored scene; only the number of player-card instances is dynamic.
func _setup_hotseat_layout() -> void:
	var page := $HotseatSetup/ResponsiveLayout/Page
	hotseat_grid = page.get_node("PlayersScroll/Players")
	hotseat_start = page.get_node("StartButton")
	hotseat_status = page.get_node("Status")
	hotseat_count_picker = page.get_node("CountRow/PlayerCount")
	page.get_node("Header/BackButton").pressed.connect(_back_to_mode_selection)
	hotseat_start.pressed.connect(start_game)
	hotseat_count_picker.select(hotseat_player_count - 1)
	hotseat_count_picker.item_selected.connect(func(index: int) -> void: set_hotseat_player_count(hotseat_count_picker.get_item_id(index)))
	NumericFontManager.manage_numeric_control(hotseat_count_picker)
	hotseat_count_picker.get_popup().add_theme_font_override("font", hotseat_count_picker.get_theme_font("font"))
	_rebuild_hotseat_players()


func set_hotseat_player_count(count: int) -> void:
	hotseat_player_count = clampi(count, 1, 8)
	hotseat_count_picker.select(hotseat_player_count - 1)
	_rebuild_hotseat_players()


func _rebuild_hotseat_players() -> void:
	while hotseat_grid.get_child_count() > hotseat_player_count:
		var child := hotseat_grid.get_child(hotseat_grid.get_child_count() - 1)
		hotseat_grid.remove_child(child)
		child.queue_free()
	while hotseat_grid.get_child_count() < hotseat_player_count:
		hotseat_grid.add_child(preload("res://scenes/entities/UI/HotseatPlayerCard.tscn").instantiate())
	hotseat_selection_labels.clear()
	hotseat_tribe_buttons.clear()
	for player_id in range(1, hotseat_player_count + 1):
		_configure_hotseat_player_panel(hotseat_grid.get_child(player_id - 1), player_id)
	_refresh_hotseat_selections()


func _refresh_hotseat_selections() -> void:
	var chosen := 0
	for player_id in range(1, hotseat_player_count + 1):
		var selected: TribeData = selected_tribes.get(player_id)
		if selected != null:
			chosen += 1
		hotseat_selection_labels[player_id].text = selected.tribe_name + " SELECTED" if selected != null else "CHOOSE A TRIBE"
		for entry: Dictionary in hotseat_tribe_buttons[player_id]:
			entry.button.set_pressed_no_signal(entry.tribe == selected)
	var humans := 0
	for id in range(1, hotseat_player_count + 1):
		if hotseat_kinds.get(id, "human") == "human":
			humans += 1
	hotseat_start.disabled = chosen != hotseat_player_count or humans == 0
	hotseat_status.text = "Solo exploration — capture and hold Sweetspire to win." if hotseat_player_count == 1 and chosen == 1 else "%d / %d players ready" % [chosen, hotseat_player_count]
	if humans == 0:
		hotseat_status.text = "Keep at least one human player."


func _configure_hotseat_player_panel(panel: PanelContainer, player_id: int) -> void:
	panel.player_number = player_id
	var content := panel.get_node("Margin/Content")
	var player_name: LineEdit = content.get_node("PlayerName")
	player_name.text = hotseat_names.get(player_id, "")
	hotseat_selection_labels[player_id] = content.get_node("Selection")
	hotseat_tribe_buttons[player_id] = []
	var choices := content.get_node("Choices")
	var tribes: Array[TribeData] = [saba_tribe, malagkit_tribe, kamote_tribe]
	var choice_names := ["Saba", "Malagkit", "Kamote"]
	var needs_connections := not panel.has_meta("hotseat_connected")
	var controller: OptionButton = content.get_node("Controller")
	var profile_picker: OptionButton = content.get_node("Profile")
	controller.select(1 if hotseat_kinds.get(player_id, "human") == "bot" else 0)
	profile_picker.clear()
	for id: String in BotCatalog.PROFILES:
		profile_picker.add_item(BotCatalog.profile(id).display_name)
	profile_picker.select(maxi(0, BotCatalog.PROFILES.keys().find(hotseat_profiles.get(player_id, "balanced"))))
	profile_picker.visible = controller.selected == 1
	if needs_connections:
		controller.item_selected.connect(func(index: int):
			hotseat_kinds[player_id] = "bot" if index == 1 else "human"
			profile_picker.visible = index == 1
			_refresh_hotseat_selections())
		profile_picker.item_selected.connect(func(index: int): hotseat_profiles[player_id] = BotCatalog.PROFILES.keys()[index])
		player_name.text_changed.connect(func(value: String) -> void: hotseat_names[player_id] = value)
	for index in tribes.size():
		var choice := choices.get_node(choice_names[index])
		var choose: Button = choice.get_node("Choose")
		hotseat_tribe_buttons[player_id].append({"button": choose, "tribe": tribes[index]})
		if needs_connections:
			choose.pressed.connect(select_tribe.bind(player_id, tribes[index]))
			choice.get_node("Artwork").pressed.connect(select_tribe.bind(player_id, tribes[index]))
	panel.set_meta("hotseat_connected", true)


## Transitions the title artwork away and settles the animated scene into the background.
func _open_game_setup() -> void:
	if menu_transitioning:
		return
	menu_transitioning = true
	menu_buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	animation_player.play(&"main_menu_anim")
	await animation_player.animation_finished
	$Main/DesignCanvas/VideoStreamPlayer.visible = false
	$ModeSelection.visible = true
	$Main/DesignCanvas/AnimatedSprite2D.z_index = -20
	menu_transitioning = false


func _open_hotseat() -> void:
	$ModeSelection.visible = false
	$HotseatSetup.visible = true


func _open_lan_setup() -> void:
	$ModeSelection.visible = false
	$LANSetup.open()


func _back_to_mode_selection() -> void:
	$HotseatSetup.visible = false
	$LANSetup.visible = false
	$ModeSelection.visible = true


## Replays the authored menu transition in reverse and restores the title screen.
func _return_to_main_menu() -> void:
	if menu_transitioning:
		return
	menu_transitioning = true
	$HotseatSetup.visible = false
	$LANSetup.visible = false
	$ModeSelection.visible = false
	$Main/DesignCanvas/AnimatedSprite2D.z_index = 0
	$Main/DesignCanvas/VideoStreamPlayer.visible = true
	animation_player.play_backwards(&"main_menu_anim")
	await animation_player.animation_finished
	menu_buttons.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_transitioning = false


func _open_options() -> void:
	menu_buttons.visible = false
	options_panel.visible = true


func _close_options() -> void:
	options_panel.visible = false
	menu_buttons.visible = true


func _set_fullscreen(enabled: bool) -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN
		if enabled
		else DisplayServer.WINDOW_MODE_WINDOWED
	)


func _quit_game() -> void:
	get_tree().quit()


## Uniformly scales the authored menu composition without distorting its artwork.
func _resize_main_visuals() -> void:
	if design_canvas == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var uniform_scale := minf(
		viewport_size.x / MENU_DESIGN_SIZE.x,
		viewport_size.y / MENU_DESIGN_SIZE.y
	)
	design_canvas.scale = Vector2.ONE * uniform_scale
	# The composition fits inside the window; the background must cover it.
	# Only resize the sprite, leaving its authored position animation intact.
	var background: AnimatedSprite2D = $Main/DesignCanvas/AnimatedSprite2D
	var texture := background.sprite_frames.get_frame_texture(background.animation, background.frame)
	if texture != null and uniform_scale > 0.0:
		var local_viewport_size := viewport_size / uniform_scale
		var texture_size := texture.get_size()
		var cover_scale := maxf(local_viewport_size.x / texture_size.x, local_viewport_size.y / texture_size.y)
		background.scale = Vector2.ONE * cover_scale

## Records a player's pending tribe choice without creating match state yet.
func select_tribe(
	player_id: int,
	tribe: TribeData
) -> void:

	selected_tribes[player_id] = tribe
	_refresh_hotseat_selections()
	
## Creates the hotseat player state and hands it to the persistent GameSession.
func start_game() -> void:
	if not prepare_hotseat_session():
		return
	get_tree().change_scene_to_file("res://scenes/main/Main.tscn")

## Validate all choices and map compatibility before leaving the setup screen.
func prepare_hotseat_session() -> bool:
	var humans := 0
	for id in range(1, hotseat_player_count + 1):
		if hotseat_kinds.get(id, "human") == "human":
			humans += 1
	if humans == 0:
		hotseat_status.text = "Keep at least one human player."
		return false
	var roster: Array = []
	for player_id in range(1, hotseat_player_count + 1):
		var tribe: TribeData = selected_tribes.get(player_id)
		if tribe == null:
			hotseat_status.text = "Choose a tribe for Player %d." % player_id
			return false
		roster.append({"player_id": player_id, "tribe_id": tribe.tribe_id})
	var generator := BiomeMapGenerator.new()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var seed_value := GameSession.map_seed if GameSession.map_seed >= 0 else int(rng.randi() & 0x7fffffff)
	var manifest := generator.generate(seed_value, roster)
	if manifest.is_empty():
		hotseat_status.text = "Map setup: " + generator.last_error
		return false
	GameSession.clear_players()
	GameSession.hotseat_mode = true
	GameSession.match_mode = GameSession.MATCH_MODES[$HotseatSetup/ResponsiveLayout/Page/ModeRow/MatchMode.selected]
	GameSession.map_manifest = manifest
	for player_id in range(1, hotseat_player_count + 1):
		var player := PlayerState.new()
		player.player_id = player_id
		player.controller_kind = hotseat_kinds.get(player_id, "human")
		player.bot_profile_id = hotseat_profiles.get(player_id, "balanced")
		player.player_name = hotseat_names.get(player_id, "").strip_edges()
		if player.player_name.is_empty():
			player.player_name = ("Bot %d" if player.is_bot() else "Player %d") % player_id
		player.tribe = selected_tribes[player_id]
		player.sugars = 20
		player.unlock_technology(player.tribe.starting_technology.technology_id)
		GameSession.add_player(player)
	return true
