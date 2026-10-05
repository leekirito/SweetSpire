extends HBoxContainer
const TRIBES := ["saba", "malagkit", "kamote"]
var seat := -1
var local := false

func _ready() -> void:
	$PlayerName.text_submitted.connect(func(_text: String): _save_name(); $PlayerName.release_focus())
	$PlayerName.focus_exited.connect(_save_name)
	$Tribe.item_selected.connect(func(index: int): LanSession.choose(TRIBES[index], false))
	$Kick.pressed.connect(func(): LanSession.kick_player(seat))

func _save_name() -> void:
	if local:
		LanSession.rename_player($PlayerName.text)

func configure(row: Dictionary) -> void:
	seat = int(row.id)
	local = seat == LanSession.local_player_id
	$Badge.text = "HOST" if seat == 1 else "PLAYER %d" % seat
	NumericFontManager.manage_numeric_control($Badge)
	if not $PlayerName.has_focus():
		$PlayerName.text = row.name
	$PlayerName.editable = local
	$Tribe.disabled = not local
	$Tribe.select(TRIBES.find(row.tribe))
	$Status.text = "READY" if row.ready else "CHOOSING"
	$Kick.visible = LanSession.hosting and not local and LanSession.state == "lobby"
