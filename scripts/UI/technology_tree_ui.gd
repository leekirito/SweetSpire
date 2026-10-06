@tool
class_name TechnologyTreeUI
extends Control

## Displays research nodes, prerequisite connections, and purchase details.
## Refreshes the viewing player's state and requests purchases through MatchManager.


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
@onready var match_manager: MatchManager = null if Engine.is_editor_hint() else get_tree().current_scene.get_node("MatchManager")


func _ready() -> void:
	_bind_nodes()
	resized.connect(queue_redraw)
	$TribeNode.item_rect_changed.connect(queue_redraw)
	$Nodes.item_rect_changed.connect(queue_redraw)
	if Engine.is_editor_hint():
		return
	$Close.pressed.connect(func() -> void: closed.emit())
	$TechCard/CardMargin/CardContent/CardClose.pressed.connect(_close_card)
	$TechCard/CardMargin/CardContent/Buy.pressed.connect(_purchase_selected)
	LanSession.changed.connect(_network_refresh)

func _network_refresh() -> void:
	if visible and active_player != null:
		_refresh_states()


## Displays research for the viewer and refreshes affordability/unlock states.
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


## Positions and child controls are authored in TurnNavbar/TechnologyTree.
func _bind_nodes() -> void:
	for button: Button in $Nodes.get_children():
		var technology: TechnologyData = button.technology
		if technology == null:
			continue
		tech_nodes[technology.technology_id] = button
		button.item_rect_changed.connect(queue_redraw)
		if not Engine.is_editor_hint():
			button.pressed.connect(_select_technology.bind(technology))
	queue_redraw()


## Updates authored buttons from the player's research, prerequisites, and Sugar.
func _refresh_states() -> void:
	for technology_id: String in tech_nodes:
		var button: Button = tech_nodes[technology_id]
		var technology: TechnologyData = TECH_PATHS[technology_id]
		var unlocked := active_player != null and active_player.has_technology(technology_id)
		var prerequisite_owned := (
			technology.prerequisite_technology == null
			or (active_player != null and active_player.has_technology(technology.prerequisite_technology.technology_id))
		)
		var affordable := active_player != null and active_player.sugars >= technology.cost
		button.modulate = Color.WHITE if unlocked else Color(1, 1, 1, 0.5)
		var border := Color("ffd166") if unlocked else Color("72b7ff") if prerequisite_owned and affordable else Color("657189")
		button.add_theme_stylebox_override("normal", _node_style(Color("151b27"), border))

	if selected_technology != null and $TechCard.visible:
		_update_card(selected_technology)


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
	buy.disabled = owned or not prerequisite_owned or not affordable or not LanSession.can_act()

	if owned:
		buy.text = "TECHNOLOGY OWNED"
	elif not prerequisite_owned:
		buy.text = "REQUIRES " + prerequisite_name.to_upper()
	elif not affordable:
		buy.text = "NEED %d SUGAR" % technology.cost
	else:
		buy.text = "BUY FOR %d SUGAR" % technology.cost


## Requests the chosen technology through MatchManager rather than granting it in UI code.
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

	var center: Vector2 = _node_center($TribeNode)
	var line_color := Color("526075")
	var root_ids := ["pathfinding", "fishing", "wilderness", "harvesting", "climbing"]

	for root_id: String in root_ids:
		var root: Button = tech_nodes[root_id]
		draw_line(center, _node_center(root), line_color, 3.0, true)

	for chain: Array in CHAINS:
		for index: int in range(chain.size() - 1):
			var from: Button = tech_nodes[chain[index]]
			var to: Button = tech_nodes[chain[index + 1]]
			draw_line(_node_center(from), _node_center(to), line_color, 3.0, true)


func _node_center(control: Control) -> Vector2:
	return get_global_transform().affine_inverse() * (control.get_global_transform() * (control.size * 0.5))


func _node_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(32)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 5
	return style
