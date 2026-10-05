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
var lan_selected_tribe_index: int = 0
var lan_tribes: Array[TribeData] = []
var lan_tribe_buttons: Array[TextureButton] = []
var hotseat_selection_labels: Dictionary[int, Label] = {}
var hotseat_player_count: int = 2
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
	$HotseatSetup/BackButton.pressed.connect(_back_to_mode_selection)
	$LANSetup/Margin/Page/Header/BackButton.pressed.connect(_back_to_mode_selection)
	$LANSetup/Margin/Page/Body/Left/SettingsPanel/Margin/Settings/Mode/HostButton.pressed.connect(_select_lan_host)
	$LANSetup/Margin/Page/Body/Left/SettingsPanel/Margin/Settings/Mode/JoinButton.pressed.connect(_select_lan_join)
	_setup_lan_tribe_selection()
	var port_input: LineEdit = $LANSetup/Margin/Page/Body/Left/SettingsPanel/Margin/Settings/Port.get_line_edit()
	NumericFontManager.manage_numeric_control(port_input)
	_select_lan_host()
	fullscreen_button.set_pressed_no_signal(
		DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	)

	_setup_hotseat_layout()


func _setup_lan_tribe_selection() -> void:
	lan_tribes = [saba_tribe, malagkit_tribe, kamote_tribe]
	var content: VBoxContainer = $LANSetup/Margin/Page/Body/Left/TribePanel/Margin/Content
	var old_dropdown: OptionButton = content.get_node_or_null("Tribe") as OptionButton
	if old_dropdown != null:
		old_dropdown.visible = false
	$LANSetup/Margin/Page/Body/Left/TribePanel.custom_minimum_size.y = 205.0

	var carousel := HBoxContainer.new()
	carousel.name = "ImageCarousel"
	carousel.alignment = BoxContainer.ALIGNMENT_CENTER
	carousel.add_theme_constant_override("separation", 12)
	content.add_child(carousel)

	var previous := Button.new()
	previous.text = "‹"
	previous.custom_minimum_size = Vector2(42.0, 88.0)
	previous.pressed.connect(_cycle_lan_tribe.bind(-1))
	carousel.add_child(previous)

	for index: int in lan_tribes.size():
		var tribe := lan_tribes[index]
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 3)
		carousel.add_child(card)

		var button := TextureButton.new()
		button.custom_minimum_size = Vector2(88.0, 88.0)
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.texture_normal = tribe.visuals.building_textures.get("base")
		button.tooltip_text = tribe.tribe_name
		button.pressed.connect(_select_lan_tribe.bind(index))
		card.add_child(button)
		lan_tribe_buttons.append(button)

		var tribe_name := Label.new()
		tribe_name.text = tribe.tribe_name
		tribe_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(tribe_name)

	var next := Button.new()
	next.text = "›"
	next.custom_minimum_size = Vector2(42.0, 88.0)
	next.pressed.connect(_cycle_lan_tribe.bind(1))
	carousel.add_child(next)

	var confirm := Button.new()
	confirm.text = "CONFIRM"
	confirm.custom_minimum_size = Vector2(116.0, 88.0)
	confirm.pressed.connect(_confirm_lan_tribe)
	carousel.add_child(confirm)
	_select_lan_tribe(0)


## Replaces the legacy fixed-position hotseat controls with a responsive layout.
func _setup_hotseat_layout() -> void:
	var hotseat: Control = $HotseatSetup
	for child: Node in hotseat.get_children():
		if child.name != "HotseatBackdrop":
			child.visible = false

	var margin := MarginContainer.new()
	margin.name = "ResponsiveLayout"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 42)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_right", 42)
	margin.add_theme_constant_override("margin_bottom", 30)
	hotseat.add_child(margin)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)

	var header := HBoxContainer.new()
	page.add_child(header)
	var back := Button.new()
	back.text = "‹ BACK"
	back.custom_minimum_size = Vector2(150, 50)
	back.pressed.connect(_back_to_mode_selection)
	header.add_child(back)
	var title := Label.new()
	title.text = "HOTSEAT SETUP"
	title.theme_type_variation = &"HeaderLabel"
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var count_row := HBoxContainer.new()
	count_row.add_theme_constant_override("separation", 16)
	page.add_child(count_row)
	var count_label := Label.new()
	count_label.text = "PLAYERS"
	count_row.add_child(count_label)
	hotseat_count_picker = OptionButton.new()
	hotseat_count_picker.name = "PlayerCount"
	for count in range(1, 9):
		hotseat_count_picker.add_item("1 — SOLO" if count == 1 else "%d PLAYERS" % count, count)
	hotseat_count_picker.select(hotseat_player_count - 1)
	hotseat_count_picker.item_selected.connect(func(index: int) -> void: set_hotseat_player_count(index + 1))
	count_row.add_child(hotseat_count_picker)
	NumericFontManager.manage_numeric_control(hotseat_count_picker)
	hotseat_count_picker.get_popup().add_theme_font_override("font", hotseat_count_picker.get_theme_font("font"))
	var hint := Label.new()
	hint.text = "Choose a tribe for each player. Tribes can repeat."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count_row.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.name = "PlayersScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	page.add_child(scroll)
	hotseat_grid = GridContainer.new()
	hotseat_grid.name = "Players"
	hotseat_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hotseat_grid.add_theme_constant_override("h_separation", 16)
	hotseat_grid.add_theme_constant_override("v_separation", 16)
	scroll.add_child(hotseat_grid)
	scroll.resized.connect(func() -> void: hotseat_grid.columns = 2 if scroll.size.x >= 850 else 1)
	hotseat_status = Label.new()
	hotseat_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hotseat_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(hotseat_status)
	hotseat_start = Button.new()
	hotseat_start.text = "START MATCH"
	hotseat_start.custom_minimum_size = Vector2(300, 54)
	hotseat_start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hotseat_start.pressed.connect(start_game)
	page.add_child(hotseat_start)
	_rebuild_hotseat_players()


func set_hotseat_player_count(count: int) -> void:
	hotseat_player_count = clampi(count, 1, 8)
	hotseat_count_picker.select(hotseat_player_count - 1)
	_rebuild_hotseat_players()


func _rebuild_hotseat_players() -> void:
	for child: Node in hotseat_grid.get_children():
		hotseat_grid.remove_child(child)
		child.queue_free()
	hotseat_selection_labels.clear()
	hotseat_tribe_buttons.clear()
	for player_id in range(1, hotseat_player_count + 1):
		hotseat_grid.add_child(_create_hotseat_player_panel(player_id))
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
	hotseat_start.disabled = chosen != hotseat_player_count
	hotseat_status.text = "Solo exploration — capture and hold Sweetspire to win." if hotseat_player_count == 1 and chosen == 1 else "%d / %d players ready" % [chosen, hotseat_player_count]


func _create_hotseat_player_panel(player_id: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)

	var title := Label.new()
	title.text = "PLAYER " + str(player_id)
	title.theme_type_variation = &"HeaderLabel"
	title.add_theme_font_size_override("font_size", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)

	var player_name := LineEdit.new()
	player_name.placeholder_text = "Name (optional)"
	player_name.text = hotseat_names.get(player_id, "")
	player_name.max_length = 24
	player_name.text_changed.connect(func(value: String) -> void: hotseat_names[player_id] = value)
	content.add_child(player_name)

	var choices := HBoxContainer.new()
	choices.alignment = BoxContainer.ALIGNMENT_CENTER
	choices.add_theme_constant_override("separation", 8)
	content.add_child(choices)
	hotseat_tribe_buttons[player_id] = []
	for tribe: TribeData in [saba_tribe, malagkit_tribe, kamote_tribe]:
		choices.add_child(_create_hotseat_tribe_card(player_id, tribe))

	var selected := Label.new()
	selected.text = "NO TRIBE SELECTED"
	selected.theme_type_variation = &"SubtleLabel"
	selected.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(selected)
	hotseat_selection_labels[player_id] = selected
	return panel


func _create_hotseat_tribe_card(player_id: int, tribe: TribeData) -> VBoxContainer:
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 6)
	var image := TextureButton.new()
	image.custom_minimum_size = Vector2(88, 72)
	image.ignore_texture_size = true
	image.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	var texture: Texture2D = tribe.visuals.building_textures.get("base")
	var cropped := AtlasTexture.new()
	cropped.atlas = texture
	cropped.region = texture.get_image().get_used_rect()
	image.texture_normal = cropped
	image.tooltip_text = tribe.tribe_name
	image.pressed.connect(select_tribe.bind(player_id, tribe))
	card.add_child(image)
	var choose := Button.new()
	choose.text = tribe.tribe_name
	choose.add_theme_font_size_override("font_size", 14)
	choose.toggle_mode = true
	choose.pressed.connect(select_tribe.bind(player_id, tribe))
	card.add_child(choose)
	hotseat_tribe_buttons[player_id].append({"button": choose, "tribe": tribe})
	return card


func _select_lan_tribe(index: int) -> void:
	lan_selected_tribe_index = wrapi(index, 0, lan_tribes.size())
	for button_index: int in lan_tribe_buttons.size():
		var selected := button_index == lan_selected_tribe_index
		lan_tribe_buttons[button_index].modulate = (
			Color.WHITE if selected else Color(0.45, 0.45, 0.45, 0.72)
		)
		lan_tribe_buttons[button_index].scale = (
			Vector2(1.08, 1.08) if selected else Vector2.ONE
		)


func _cycle_lan_tribe(direction: int) -> void:
	_select_lan_tribe(lan_selected_tribe_index + direction)


func _confirm_lan_tribe() -> void:
	var tribe := lan_tribes[lan_selected_tribe_index]
	$LANSetup/Margin/Page/Body/PlayersPanel/Margin/Content/Status.text = (
		tribe.tribe_name + " SELECTED — NETWORKING NOT CONNECTED"
	)


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
	$LANSetup.visible = true


func _back_to_mode_selection() -> void:
	$HotseatSetup.visible = false
	$LANSetup.visible = false
	$ModeSelection.visible = true


func _select_lan_host() -> void:
	var address: LineEdit = $LANSetup/Margin/Page/Body/Left/SettingsPanel/Margin/Settings/Address
	address.editable = false
	address.text = "127.0.0.1"
	$LANSetup/Margin/Page/Body/Left/SettingsPanel/Margin/Settings/Mode/HostButton.disabled = true
	$LANSetup/Margin/Page/Body/Left/SettingsPanel/Margin/Settings/Mode/JoinButton.disabled = false


func _select_lan_join() -> void:
	var address: LineEdit = $LANSetup/Margin/Page/Body/Left/SettingsPanel/Margin/Settings/Address
	address.editable = true
	address.select_all()
	address.grab_focus()
	$LANSetup/Margin/Page/Body/Left/SettingsPanel/Margin/Settings/Mode/HostButton.disabled = false
	$LANSetup/Margin/Page/Body/Left/SettingsPanel/Margin/Settings/Mode/JoinButton.disabled = true


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
	GameSession.map_manifest = manifest
	for player_id in range(1, hotseat_player_count + 1):
		var player := PlayerState.new()
		player.player_id = player_id
		player.player_name = hotseat_names.get(player_id, "").strip_edges()
		if player.player_name.is_empty():
			player.player_name = "Player %d" % player_id
		player.tribe = selected_tribes[player_id]
		player.sugars = 20
		player.unlock_technology(player.tribe.starting_technology.technology_id)
		GameSession.add_player(player)
	return true
