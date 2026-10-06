extends HBoxContainer
const TRIBES := ["saba", "malagkit", "kamote"]
var seat := -1
var local := false
var bot := false
var bot_editable := false

func _ready() -> void:
	$PlayerName.text_submitted.connect(func(_text: String): _save_name(); $PlayerName.release_focus())
	$PlayerName.focus_exited.connect(_save_name)
	$Tribe.item_selected.connect(func(index: int):
		if bot_editable: _save_bot()
		elif local: LanSession.choose(TRIBES[index], false))
	$Profile.item_selected.connect(func(_index: int): _save_bot())
	$Kick.pressed.connect(func():
		if bot_editable: LanSession.remove_bot(seat)
		else: LanSession.kick_player(seat))

func _save_name() -> void:
	if bot_editable:
		_save_bot()
	elif local:
		LanSession.rename_player($PlayerName.text)

func _save_bot() -> void:
	if bot_editable:
		LanSession.edit_bot(seat, $PlayerName.text, TRIBES[$Tribe.selected], BotCatalog.PROFILES.keys()[$Profile.selected])

func configure(row: Dictionary) -> void:
	seat = int(row.id)
	local = seat == LanSession.local_player_id
	bot = row.get("kind", "human") == "bot"
	bot_editable = bot and LanSession.hosting and LanSession.state == "lobby"
	$Profile.visible = bot
	$Profile.disabled = not bot_editable
	$Profile.clear()
	for id: String in BotCatalog.PROFILES:
		$Profile.add_item(BotCatalog.profile(id).display_name)
	$Profile.select(maxi(0, BotCatalog.PROFILES.keys().find(row.get("profile", "balanced"))))
	$Badge.text = "BOT %d" % seat if bot else ("HOST" if seat == 1 else "PLAYER %d" % seat)
	NumericFontManager.manage_numeric_control($Badge)
	if not $PlayerName.has_focus():
		$PlayerName.text = row.name
	$PlayerName.editable = local or bot_editable
	$Tribe.disabled = not (local or bot_editable)
	$Tribe.select(TRIBES.find(row.tribe))
	$Status.text = "BOT" if bot else ("READY" if row.ready else "CHOOSING")
	$Kick.text = "REMOVE" if bot else "KICK"
	$Kick.visible = LanSession.hosting and not local and LanSession.state == "lobby"
