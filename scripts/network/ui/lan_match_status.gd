extends CanvasLayer
func _ready() -> void:
	$Overlay/Center/Panel/Content/Leave.pressed.connect(_leave)
	$Bar/Leave.pressed.connect(_leave)
	$Overlay/Center/Panel/Content/Wait.pressed.connect(func(): LanSession._disconnect_elapsed = 0.0)
	LanSession.changed.connect(_refresh)
	LanSession.notice.connect(func(message: String): $Bar/Message.text = message)
	_refresh()

func _process(_delta: float) -> void:
	if LanSession.paused_for_disconnect:
		_refresh()

func _refresh() -> void:
	visible = LanSession.active()
	if not visible:
		return
	var blocked := LanSession.state != "playing" or LanSession.paused_for_disconnect
	$Overlay.visible = blocked
	$Bar.visible = not blocked
	var label: Label = $Overlay/Center/Panel/Content/Message
	if LanSession.state == "ended":
		label.text = LanSession.error_message
	elif LanSession.state == "reconnecting":
		label.text = "Connection lost. Trying to rejoin the host…"
	elif LanSession.paused_for_disconnect:
		var remaining := maxi(0, int(LanSession.SETTINGS.reconnect_grace - LanSession._disconnect_elapsed))
		label.text = "A player disconnected. The match is paused.\nWaiting for them to reconnect… %ds" % remaining
	else:
		label.text = "Preparing the shared map…\nWaiting for all players to finish loading."
		for row: Dictionary in LanSession.seats:
			label.text += "\n%s · %s" % [row.name, "Bot ready" if row.get("kind", "human") == "bot" else ("Ready" if LanSession.loaded.get(int(row.id), false) else "Loading…")]
	$Overlay/Center/Panel/Content/Wait.visible = LanSession.hosting and LanSession.paused_for_disconnect and LanSession._disconnect_elapsed >= LanSession.SETTINGS.reconnect_grace
	NumericFontManager.manage_numeric_control(label)
	$Bar/Message.text = "LAN · " + ("Your turn" if LanSession.can_act() else "Waiting for the next action")

func _leave() -> void:
	LanSession.leave()
	GameSession.clear_players()
	get_tree().change_scene_to_file("res://scenes/entities/UI/MainMenu.tscn")
