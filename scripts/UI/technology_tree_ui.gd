class_name TechnologyTreeUI
extends Control

signal closed

const TECH_PATHS := {
	"pathfinding": preload("res://scripts/data/Technologies/Primary/Pathfinding.tres"),
	"pathways": preload("res://scripts/data/Technologies/Secondary/Pathways.tres"),
	"expedition": preload("res://scripts/data/Technologies/Tertiary/Expedition.tres"),
	"fishing": preload("res://scripts/data/Technologies/Primary/Fishing.tres"),
	"sailing": preload("res://scripts/data/Technologies/Secondary/Sailing.tres"),
	"navigation": preload("res://scripts/data/Technologies/Tertiary/Navigation.tres"),
	"wilderness": preload("res://scripts/data/Technologies/Primary/Wilderness.tres"),
	"marksmanship": preload("res://scripts/data/Technologies/Secondary/Marksmanship.tres"),
	"forestry": preload("res://scripts/data/Technologies/Tertiary/Forestry.tres"),
	"harvesting": preload("res://scripts/data/Technologies/Primary/Harvesting.tres"),
	"cultivation": preload("res://scripts/data/Technologies/Secondary/Cultivation.tres"),
	"restoration": preload("res://scripts/data/Technologies/Tertiary/Restoration.tres"),
	"climbing": preload("res://scripts/data/Technologies/Primary/Climbing.tres"),
	"mining": preload("res://scripts/data/Technologies/Secondary/Mining.tres"),
	"runecraft": preload("res://scripts/data/Technologies/Tertiary/Runecraft.tres")
}

const NODE_POSITIONS := {
	"pathfinding": Vector2(0.27, 0.35), "pathways": Vector2(0.27, 0.20), "expedition": Vector2(0.27, 0.07),
	"fishing": Vector2(0.73, 0.35), "sailing": Vector2(0.73, 0.20), "navigation": Vector2(0.73, 0.07),
	"wilderness": Vector2(0.18, 0.69), "marksmanship": Vector2(0.18, 0.82), "forestry": Vector2(0.18, 0.95),
	"harvesting": Vector2(0.50, 0.69), "cultivation": Vector2(0.50, 0.82), "restoration": Vector2(0.50, 0.95),
	"climbing": Vector2(0.82, 0.69), "mining": Vector2(0.82, 0.82), "runecraft": Vector2(0.82, 0.95)
}

const CHAINS := [
	["pathfinding", "pathways", "expedition"],
	["fishing", "sailing", "navigation"],
	["wilderness", "marksmanship", "forestry"],
	["harvesting", "cultivation", "restoration"],
	["climbing", "mining", "runecraft"]
]

var active_player: PlayerState
var tech_nodes: Dictionary[String, Button] = {}
var selected_technology: TechnologyData
@onready var match_manager: MatchManager = get_tree().current_scene.get_node("MatchManager")


func _ready() -> void:
	$Close.pressed.connect(func() -> void: closed.emit())
	$TechCard/CardMargin/CardContent/CardClose.pressed.connect(_close_card)
	$TechCard/CardMargin/CardContent/Buy.pressed.connect(_purchase_selected)
	resized.connect(_layout_nodes)
	_build_nodes()


func open_for_player(player: PlayerState) -> void:
	active_player = player
	visible = true
	$TribeNode.text = (
		player.tribe.tribe_name.to_upper() + "\nTRIBE"
		if player != null and player.tribe != null
		else "TRIBE\nFLAG"
	)
	_refresh_states()
	$TechCard.hide()
	queue_redraw()


func _build_nodes() -> void:
	for technology_id: String in NODE_POSITIONS:
		var technology: TechnologyData = TECH_PATHS[technology_id]
		var button := Button.new()
		button.name = technology_id.capitalize()
		button.text = ""
		button.tooltip_text = technology.description
		button.custom_minimum_size = Vector2(64.0, 64.0)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_stylebox_override("normal", _node_style(Color("151b27"), Color("657189")))
		button.add_theme_stylebox_override("hover", _node_style(Color("24334a"), Color("72b7ff")))
		button.pressed.connect(_select_technology.bind(technology))
		$Nodes.add_child(button)
		tech_nodes[technology_id] = button
		_build_node_content(button, technology)

	_layout_nodes()


func _layout_nodes() -> void:
	if not is_node_ready():
		return

	var content_rect := Rect2(Vector2(50.0, 70.0), size - Vector2(100.0, 115.0))
	for technology_id: String in tech_nodes:
		var normalized: Vector2 = NODE_POSITIONS[technology_id]
		var button: Button = tech_nodes[technology_id]
		button.position = content_rect.position + content_rect.size * normalized - button.custom_minimum_size * 0.5

	$TribeNode.position = content_rect.position + content_rect.size * Vector2(0.5, 0.52) - $TribeNode.size * 0.5
	queue_redraw()


func _refresh_states() -> void:
	for technology_id: String in tech_nodes:
		var button: Button = tech_nodes[technology_id]
		var technology: TechnologyData = TECH_PATHS[technology_id]
		var unlocked := active_player != null and active_player.has_technology(technology_id)
		var prerequisite_owned := (
			technology.prerequisite_technology == null
			or active_player.has_technology(technology.prerequisite_technology.technology_id)
		)
		var affordable := active_player != null and active_player.sugars >= technology.cost
		button.modulate = Color.WHITE if unlocked else Color(1, 1, 1, 0.5)
		var border := Color("ffd166") if unlocked else Color("72b7ff") if prerequisite_owned and affordable else Color("657189")
		button.add_theme_stylebox_override("normal", _node_style(Color("151b27"), border))

	if selected_technology != null and $TechCard.visible:
		_update_card(selected_technology)


func _build_node_content(button: Button, technology: TechnologyData) -> void:
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.position = Vector2(12.0, 8.0)
	icon.size = Vector2(40.0, 40.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = technology.icon
	button.add_child(icon)

	var cost := Label.new()
	cost.position = Vector2(7.0, 44.0)
	cost.size = Vector2(50.0, 18.0)
	cost.text = str(technology.cost) + " S"
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost.add_theme_font_size_override("font_size", 11)
	cost.add_theme_color_override("font_color", Color("ffd166"))
	cost.add_theme_color_override("font_outline_color", Color("151b27"))
	cost.add_theme_constant_override("outline_size", 4)
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(cost)


func _select_technology(technology: TechnologyData) -> void:
	selected_technology = technology
	_update_card(technology)
	$TechCard.show()


func _update_card(technology: TechnologyData) -> void:
	var content := $TechCard/CardMargin/CardContent
	content.get_node("Header/Icon").texture = technology.icon
	content.get_node("Header/Identity/Name").text = technology.technology_name.to_upper()
	content.get_node("Header/Identity/Description").text = technology.description

	var effects_text := ""
	for effect: String in technology.unlock_effects:
		effects_text += "• " + effect + "\n"
	content.get_node("Effects").text = effects_text.strip_edges()

	var prerequisite_name := "None"
	var prerequisite_owned := true
	if technology.prerequisite_technology != null:
		prerequisite_name = technology.prerequisite_technology.technology_name
		prerequisite_owned = active_player.has_technology(technology.prerequisite_technology.technology_id)
	content.get_node("Requirement").text = "REQUIRES  " + prerequisite_name

	var owned := active_player.has_technology(technology.technology_id)
	var affordable := active_player.sugars >= technology.cost
	var buy: Button = content.get_node("Buy")
	buy.disabled = owned or not prerequisite_owned or not affordable

	if owned:
		buy.text = "TECHNOLOGY OWNED"
	elif not prerequisite_owned:
		buy.text = "REQUIRES " + prerequisite_name.to_upper()
	elif not affordable:
		buy.text = "NEED %d SUGAR" % technology.cost
	else:
		buy.text = "BUY FOR %d SUGAR" % technology.cost


func _purchase_selected() -> void:
	if selected_technology == null or active_player == null:
		return

	if match_manager.request_purchase_technology(active_player.player_id, selected_technology):
		_refresh_states()


func _close_card() -> void:
	$TechCard.hide()


func _draw() -> void:
	if tech_nodes.is_empty():
		return

	var center: Vector2 = $TribeNode.position + $TribeNode.size * 0.5
	var line_color := Color("526075")
	var root_ids := ["pathfinding", "fishing", "wilderness", "harvesting", "climbing"]

	for root_id: String in root_ids:
		var root: Button = tech_nodes[root_id]
		draw_line(center, root.position + root.size * 0.5, line_color, 3.0, true)

	for chain: Array in CHAINS:
		for index: int in range(chain.size() - 1):
			var from: Button = tech_nodes[chain[index]]
			var to: Button = tech_nodes[chain[index + 1]]
			draw_line(from.position + from.size * 0.5, to.position + to.size * 0.5, line_color, 3.0, true)


func _node_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(32)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 5
	return style
