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


func _ready() -> void:
	get_viewport().size_changed.connect(_resize_main_visuals)
	_resize_main_visuals()
	animation_player.play(&"RESET")
	$Main/DesignCanvas/MenuButtons/PlayButton.pressed.connect(_open_game_setup)
	$Main/DesignCanvas/MenuButtons/OptionsButton.pressed.connect(_open_options)
	$Main/DesignCanvas/MenuButtons/QuitButton.pressed.connect(_quit_game)
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

	$HotseatSetup/Button2.pressed.connect(
		select_tribe.bind(
			1,
			saba_tribe
		)
	)

	$HotseatSetup/Button3.pressed.connect(
		select_tribe.bind(
			1,
			malagkit_tribe
		)
	)

	$HotseatSetup/Button4.pressed.connect(
		select_tribe.bind(
			1,
			kamote_tribe
		)
	)

	$HotseatSetup/Button5.pressed.connect(
		select_tribe.bind(
			2,
			saba_tribe
		)
	)

	$HotseatSetup/Button6.pressed.connect(
		select_tribe.bind(
			2,
			malagkit_tribe
		)
	)

	$HotseatSetup/Button7.pressed.connect(
		select_tribe.bind(
			2,
			kamote_tribe
		)
	)
	
	$HotseatSetup/Button.pressed.connect(
		start_game
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
	page.add_theme_constant_override("separation", 22)
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
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var header_spacer := Control.new()
	header_spacer.custom_minimum_size = Vector2(150, 0)
	header.add_child(header_spacer)

	var player_columns := HBoxContainer.new()
	player_columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	player_columns.add_theme_constant_override("separation", 24)
	page.add_child(player_columns)
	player_columns.add_child(_create_hotseat_player_panel(1))
	player_columns.add_child(_create_hotseat_player_panel(2))

	var start := Button.new()
	start.text = "START MATCH"
	start.custom_minimum_size = Vector2(360, 66)
	start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start.add_theme_font_size_override("font_size", 27)
	start.pressed.connect(start_game)
	page.add_child(start)


func _create_hotseat_player_panel(player_id: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 26)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	margin.add_child(content)

	var title := Label.new()
	title.text = "PLAYER " + str(player_id)
	title.theme_type_variation = &"HeaderLabel"
	title.add_theme_font_size_override("font_size", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)

	var hint := Label.new()
	hint.text = "Choose a tribe"
	hint.theme_type_variation = &"BodyLabel"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(hint)

	var choices := HBoxContainer.new()
	choices.alignment = BoxContainer.ALIGNMENT_CENTER
	choices.add_theme_constant_override("separation", 18)
	content.add_child(choices)
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
	image.custom_minimum_size = Vector2(128, 128)
	image.ignore_texture_size = true
	image.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	image.texture_normal = tribe.visuals.building_textures.get("base")
	image.tooltip_text = tribe.tribe_name
	image.pressed.connect(select_tribe.bind(player_id, tribe))
	card.add_child(image)
	var tribe_name := Label.new()
	tribe_name.text = tribe.tribe_name
	tribe_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(tribe_name)
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
## Records a player's pending tribe choice without creating match state yet.
func select_tribe(
	player_id: int,
	tribe: TribeData
) -> void:

	selected_tribes[player_id] = tribe
	if hotseat_selection_labels.has(player_id):
		hotseat_selection_labels[player_id].text = tribe.tribe_name + " SELECTED"

	print(
		"Player ",
		player_id,
		" selected ",
		tribe.tribe_name
	)
	
## Creates the hotseat player state and hands it to the persistent GameSession.
func start_game() -> void:
	if not selected_tribes.has(1):
		print("Player 1 has not selected a tribe.")
		return

	if not selected_tribes.has(2):
		print("Player 2 has not selected a tribe.")
		return

	GameSession.clear_players()

	var player_1 := PlayerState.new()
	player_1.player_id = 1
	player_1.player_name = "Player 1"
	player_1.tribe = selected_tribes[1]
	player_1.sugars = 5

	player_1.unlocked_technologies.append(
		player_1.tribe.starting_technology.technology_id
	)

	GameSession.add_player(
		player_1
	)


	var player_2 := PlayerState.new()
	player_2.player_id = 2
	player_2.player_name = "Player 2"
	player_2.tribe = selected_tribes[2]
	player_2.sugars = 5

	player_2.unlocked_technologies.append(
		player_2.tribe.starting_technology.technology_id
	)

	GameSession.add_player(
		player_2
	)


	get_tree().change_scene_to_file(
		"res://scenes/main/Main.tscn"
	)
