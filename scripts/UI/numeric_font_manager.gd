extends Node

## Cocogoose trial fonts replace digits with trial-watermark glyphs.
## This manager keeps Cocogoose for normal copy and restores Godot's original
## fallback font on controls whose current text contains a number.

const CHECK_INTERVAL := 0.1
const MANAGED_META := &"sweetspire_numeric_font"

var _tracked_controls: Array[Control] = []
var _elapsed: float = 0.0
var _numeric_font: SystemFont


func _ready() -> void:
	_numeric_font = SystemFont.new()
	_numeric_font.font_names = PackedStringArray([
		"Noto Sans",
		"Arial",
		"Segoe UI"
	])
	_numeric_font.allow_system_fallback = true
	get_tree().node_added.connect(_register_node)
	_register_branch(get_tree().root)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < CHECK_INTERVAL:
		return
	_elapsed = 0.0

	for index: int in range(_tracked_controls.size() - 1, -1, -1):
		var control := _tracked_controls[index]
		if not is_instance_valid(control):
			_tracked_controls.remove_at(index)
			continue
		_update_control_font(control)


func _register_branch(node: Node) -> void:
	_register_node(node)
	for child: Node in node.get_children():
		_register_branch(child)


func _register_node(node: Node) -> void:
	if node is SpinBox:
		_register_spinbox_input.call_deferred(node as SpinBox)
		return
	if not node is Label and not node is Button and not node is LineEdit:
		return
	var control := node as Control
	if not _tracked_controls.has(control):
		_tracked_controls.append(control)
	_update_control_font(control)


func _register_spinbox_input(spin_box: SpinBox) -> void:
	if not is_instance_valid(spin_box):
		return
	_register_node(spin_box.get_line_edit())


## Explicit hook for engine controls whose text editor is an internal child.
func manage_numeric_control(control: Control) -> void:
	if not is_instance_valid(control):
		return
	if not _tracked_controls.has(control):
		_tracked_controls.append(control)
	_update_control_font(control)


func _update_control_font(control: Control) -> void:
	var text_value := str(control.get("text"))
	var needs_numeric_font := _contains_digit(text_value)
	var is_managed := control.has_meta(MANAGED_META)

	if needs_numeric_font and not is_managed:
		# Preserve a deliberate per-node override so it can be restored later.
		if control.has_theme_font_override("font"):
			control.set_meta(
				&"sweetspire_previous_font",
				control.get_theme_font("font")
			)
		control.add_theme_font_override("font", _numeric_font)
		control.set_meta(MANAGED_META, true)
	elif not needs_numeric_font and is_managed:
		control.remove_theme_font_override("font")
		if control.has_meta(&"sweetspire_previous_font"):
			control.add_theme_font_override(
				"font",
				control.get_meta(&"sweetspire_previous_font") as Font
			)
			control.remove_meta(&"sweetspire_previous_font")
		control.remove_meta(MANAGED_META)


func _contains_digit(value: String) -> bool:
	for index: int in value.length():
		var character_code := value.unicode_at(index)
		if character_code >= 48 and character_code <= 57:
			return true
	return false
