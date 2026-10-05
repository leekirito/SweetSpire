extends Node
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("LAN UI: " + message)

func _ready() -> void:
	get_tree().root.size = Vector2i(1152, 648)
	call_deferred("run")

func run() -> void:
	var menu: Node = load("res://scenes/entities/UI/MainMenu.tscn").instantiate()
	get_tree().root.add_child(menu)
	menu._open_lan_setup()
	var ui: Control = menu.get_node("LANSetup")
	check(ui.choice.visible and not ui.browser.visible and not ui.room.visible, "LAN opens at Host or Join")
	ui.choice.get_node("Content/Host").pressed.emit()
	await get_tree().process_frame
	check(LanSession.hosting and ui.room.visible and not ui.choice.visible, "Host opens lobby immediately")
	check(LanSession.port > 0 and not ui.room.has_node("Port"), "host does not enter a port")
	check(ui.rows.size() == 1 and not ui.rows[1].get_node("Kick").visible, "host row cannot kick itself")
	ui.rows[1].get_node("PlayerName").text = "Mika"
	ui.rows[1].get_node("PlayerName").text_submitted.emit("Mika")
	check(LanSession.seats[0].name == "Mika", "player name editable in lobby")
	ui.rows[1].get_node("Tribe").item_selected.emit(2)
	check(LanSession.seats[0].tribe == "kamote", "player selects tribe in lobby")
	ui.room.get_node("Settings/Privacy").select(1)
	ui.room.get_node("Settings/Privacy").item_selected.emit(1)
	check(LanSession.private_room and ui.room.get_node("PasswordRow").visible, "private choice generates password controls")
	check(not LanSession.room_access.password.is_empty(), "private room immediately has a generated password")
	ui.room.get_node("PasswordRow/Password").text = "new-secret"
	ui.room.get_node("PasswordRow/Save").pressed.emit()
	check(LanSession.room_access.password == "new-secret", "host can replace room password")
	ui.room.get_node("Settings/Mode").select(1)
	ui.room.get_node("Settings/Mode").item_selected.emit(1)
	check(LanSession.match_mode == GameSession.REGULAR, "mode selector remains functional")
	ui.room.get_node("Actions/Leave").pressed.emit()
	check(not LanSession.hosting and ui.choice.visible, "host leave returns to choice")
	ui.choice.get_node("Content/Join").pressed.emit()
	check(ui.browser.visible and LanSession.discovery != null, "Join opens discovery browser")
	var key := "127.0.0.1:29879"
	LanSession.rooms[key] = {"address": "127.0.0.1", "port": 29879, "room": "Nearby", "count": 1, "capacity": 8, "mode": GameSession.REGULAR, "version": LanSession.compatibility, "seen": Time.get_ticks_msec()}
	ui._refresh_rooms()
	ui._select_room(0)
	check(not ui.browser.get_node("JoinSelected").disabled, "nearby room can be selected")
	ui._refresh_rooms()
	check(ui.selected_room == key and not ui.browser.get_node("JoinSelected").disabled, "discovery refresh preserves selection")
	LanSession.rooms[key].count = 8
	ui._refresh_rooms()
	check(ui.browser.get_node("JoinSelected").disabled, "full room cannot be selected to join")
	ui.browser.get_node("Manual/Address").text = "127.0.0.1:29879"
	ui.browser.get_node("Connect").pressed.emit()
	check(LanSession.state == "connecting" and LanSession.port == 29879, "manual pasted endpoint connects")
	ui.page.get_node("Header/Back").pressed.emit()
	check(LanSession.state == "offline" and ui.browser.visible, "connecting can be cancelled")
	# Exercise the actual client rejection handler and UI transition.
	ui.was_guest = true
	ui.screen = "room"
	LanSession.reconnect_token = "expired"
	LanSession._receive(1, "kicked", {"message": "You were removed by the host."})
	check(ui.browser.visible and "removed" in ui.page.get_node("Status").text, "kicked player returns to Join with reason")
	check(LanSession.reconnect_token.is_empty(), "kicked client cannot automatically resume old seat")
	ui._back()
	check(ui.choice.visible, "browser back returns to choice")
	menu.queue_free()
	await get_tree().process_frame
	LanSession.leave()
	print("LAN UI: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
