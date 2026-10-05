extends Control
signal back_requested
const PLAYER_ROW := preload("res://scenes/network/LanPlayerRow.tscn")
@onready var page := $Margin/Page
@onready var choice := $Margin/Page/Choice
@onready var browser := $Margin/Page/Browser
@onready var room := $Margin/Page/Room
var screen := "choice"
var selected_room := ""
var room_keys: Array = []
var rows: Dictionary = {}
var updating := false
var was_guest := false

func _ready() -> void:
	page.get_node("Header/Back").pressed.connect(_back)
	choice.get_node("Content/Host").pressed.connect(_host)
	choice.get_node("Content/Join").pressed.connect(_browse)
	browser.get_node("Heading/Refresh").pressed.connect(LanSession.scan_rooms)
	browser.get_node("Rooms").item_selected.connect(_select_room)
	browser.get_node("Rooms").item_activated.connect(func(index: int): _select_room(index); _join_selected())
	browser.get_node("JoinSelected").pressed.connect(_join_selected)
	browser.get_node("Connect").pressed.connect(_join_manual)
	browser.get_node("Manual/Address").text_submitted.connect(func(_text: String): _join_manual())
	browser.get_node("Manual/Port").value = LanSession.SETTINGS.game_port
	NumericFontManager.manage_numeric_control(browser.get_node("Manual/Port").get_line_edit())
	room.get_node("Actions/Leave").pressed.connect(_leave_room)
	room.get_node("Actions/Ready").toggled.connect(_ready_changed)
	room.get_node("Actions/Start").pressed.connect(LanSession.start_match)
	room.get_node("Settings/RoomName").text_submitted.connect(func(_text: String): _apply_settings())
	room.get_node("Settings/RoomName").focus_exited.connect(_apply_settings)
	room.get_node("Settings/Capacity").value_changed.connect(func(_value: float): _apply_settings())
	room.get_node("Settings/Mode").item_selected.connect(func(_index: int): _apply_settings())
	room.get_node("Settings/Privacy").item_selected.connect(func(_index: int): _apply_settings())
	room.get_node("PasswordRow/Save").pressed.connect(_save_password)
	room.get_node("PasswordRow/Copy").pressed.connect(func(): DisplayServer.clipboard_set(LanSession.room_access.password); _status("Room password copied."))
	room.get_node("AddressRow/Copy").pressed.connect(_copy_address)
	NumericFontManager.manage_numeric_control(room.get_node("Settings/Capacity").get_line_edit())
	for preview in room.get_node("Scroll/Players").get_children():
		preview.free()
	LanSession.changed.connect(_refresh)
	LanSession.rooms_changed.connect(_refresh_rooms)
	_refresh()

func open() -> void:
	show()
	screen = "room" if LanSession.state == "lobby" else "choice"
	_refresh()

func _status(message: String) -> void:
	page.get_node("Status").text = message

func _host() -> void:
	was_guest = false
	if LanSession.host_room("", "", 8, "saba"):
		screen = "room"
	_refresh()

func _browse() -> void:
	screen = "browser"
	LanSession.error_message = ""
	if LanSession.compatibility.is_empty():
		LanSession.prepare_compatibility()
	LanSession.scan_rooms()
	_refresh()
	_refresh_rooms()

func _back() -> void:
	if LanSession.state == "connecting":
		LanSession.leave()
		_browse()
	elif screen == "room":
		_leave_room()
	elif screen == "browser":
		LanSession.leave()
		screen = "choice"
		_refresh()
	else:
		LanSession.leave()
		back_requested.emit()

func _leave_room() -> void:
	var return_to_browser := not LanSession.hosting
	LanSession.leave()
	if return_to_browser:
		_browse()
	else:
		screen = "choice"
		_refresh()

func _select_room(index: int) -> void:
	selected_room = str(room_keys[index]) if index >= 0 and index < room_keys.size() else ""
	_refresh_rooms()

func _join_selected() -> void:
	if not LanSession.rooms.has(selected_room):
		_status("That room is no longer available. Refresh the list.")
		return
	var found: Dictionary = LanSession.rooms[selected_room]
	_connect_to(found.address, int(found.port), "")

func _join_manual() -> void:
	var endpoint := LanAddress.parse(browser.get_node("Manual/Address").text, int(browser.get_node("Manual/Port").value))
	if endpoint.is_empty():
		_status("Enter a host address and a port between 1 and 65535.")
		return
	browser.get_node("Manual/Address").text = endpoint.address
	browser.get_node("Manual/Port").value = endpoint.port
	_connect_to(endpoint.address, int(endpoint.port), browser.get_node("Password").text)

func _connect_to(address: String, port: int, password: String) -> void:
	if LanSession.state == "connecting":
		return
	was_guest = true
	LanSession.join_room(address, "", "saba", port, password)
	_refresh()

func _apply_settings() -> void:
	if updating or not LanSession.hosting or LanSession.state != "lobby":
		return
	var settings := room.get_node("Settings")
	if not LanSession.configure_room(settings.get_node("RoomName").text, int(settings.get_node("Capacity").value), GameSession.MATCH_MODES[settings.get_node("Mode").selected], settings.get_node("Privacy").selected == 1, LanSession.room_access.password):
		_refresh()
		_status("Capacity cannot be smaller than the number of players already here.")

func _save_password() -> void:
	if not LanSession.hosting:
		return
	var secret: String = room.get_node("PasswordRow/Password").text
	if secret.strip_edges().is_empty():
		_status("Enter a password, or keep the generated password.")
		return
	LanSession.configure_room(LanSession.room_name, LanSession.capacity, LanSession.match_mode, true, secret)
	_status("Room password updated. Share it with invited players.")

func _ready_changed(ready: bool) -> void:
	if updating:
		return
	room.get_node("Actions/Ready").text = "CANCEL READY" if ready else "READY"
	for row: Dictionary in LanSession.seats:
		if int(row.id) == LanSession.local_player_id:
			LanSession.choose(row.tribe, ready)

func _copy_address() -> void:
	var addresses: OptionButton = room.get_node("AddressRow/Addresses")
	if addresses.selected >= 0:
		DisplayServer.clipboard_set(addresses.get_item_text(addresses.selected))
		_status("Host address copied.")

func _refresh_rooms() -> void:
	var list: ItemList = browser.get_node("Rooms")
	list.clear()
	room_keys = LanSession.rooms.keys()
	room_keys.sort()
	var can_join := false
	for key in room_keys:
		var found: Dictionary = LanSession.rooms[key]
		var compatible: bool = found.get("version", "") == LanSession.compatibility
		var full := int(found.count) >= int(found.capacity)
		var mode := "Regular" if found.get("mode") == GameSession.REGULAR else "Fog of War"
		var suffix := " · Different version" if not compatible else (" · Full" if full else "")
		var index := list.add_item("%s · %d/%d · %s%s" % [str(found.room).left(32), int(found.count), int(found.capacity), mode, suffix])
		list.set_item_disabled(index, not compatible or full)
		if str(key) == selected_room:
			list.select(index)
			can_join = compatible and not full
	browser.get_node("JoinSelected").disabled = not can_join or LanSession.state == "connecting"
	browser.get_node("Empty").visible = room_keys.is_empty()

func _refresh() -> void:
	if not is_node_ready():
		return
	updating = true
	if LanSession.state == "lobby":
		screen = "room"
	elif LanSession.state == "ended" and was_guest:
		screen = "browser"
		if LanSession.discovery == null:
			LanSession.scan_rooms()
	choice.visible = screen == "choice"
	browser.visible = screen == "browser"
	room.visible = screen == "room"
	page.get_node("Header/Title").text = {"choice": "LAN MULTIPLAYER", "browser": "JOIN A GAME", "room": "GAME LOBBY"}[screen]
	page.get_node("Header/Back").text = "CANCEL" if LanSession.state == "connecting" else "BACK"
	choice.get_node("Content/Host").disabled = OS.has_feature("web")
	choice.get_node("Content/Join").disabled = OS.has_feature("web")
	browser.get_node("Connect").disabled = LanSession.state == "connecting"
	browser.get_node("Heading/Refresh").disabled = LanSession.state == "connecting"
	if screen == "room":
		_refresh_room()
	_refresh_rooms()
	if OS.has_feature("web"):
		_status("LAN multiplayer is available in the Windows download.")
	elif not LanSession.error_message.is_empty():
		_status(LanSession.error_message)
	elif LanSession.state == "connecting":
		_status("Connecting… Use Cancel to return to nearby games.")
	elif screen == "room":
		_status("Choose your name and tribe, then mark Ready." if not LanSession.hosting or LanSession.discovery_available or LanSession.private_room else "Nearby discovery is unavailable. Friends can still join using your address.")
	else:
		_status("Play with friends on the same network." if screen == "choice" else "Select a public room, or enter a friend's address and password.")
	updating = false

func _refresh_room() -> void:
	var settings := room.get_node("Settings")
	var host := LanSession.hosting
	settings.get_node("RoomName").editable = host
	if not settings.get_node("RoomName").has_focus():
		settings.get_node("RoomName").text = LanSession.room_name
	settings.get_node("Capacity").editable = host
	settings.get_node("Capacity").set_value_no_signal(LanSession.capacity)
	settings.get_node("Mode").disabled = not host
	settings.get_node("Mode").select(GameSession.MATCH_MODES.find(LanSession.match_mode))
	settings.get_node("Privacy").disabled = not host
	settings.get_node("Privacy").select(1 if LanSession.private_room else 0)
	room.get_node("PasswordRow").visible = host and LanSession.private_room
	if host and not room.get_node("PasswordRow/Password").has_focus():
		room.get_node("PasswordRow/Password").text = LanSession.room_access.password
	room.get_node("PrivacyHint").text = "Private · Hidden from nearby games. Share the address and password." if LanSession.private_room else "Public · Listed in nearby games on this network."
	var addresses: OptionButton = room.get_node("AddressRow/Addresses")
	var previous := addresses.get_item_text(addresses.selected) if addresses.selected >= 0 else ""
	addresses.clear()
	var ips := LanAddress.local_addresses() if host else PackedStringArray([LanSession.address])
	for ip in ips:
		var text := "%s:%d" % [ip, LanSession.port]
		addresses.add_item(text)
		if text == previous:
			addresses.select(addresses.item_count - 1)
	room.get_node("AddressRow/Copy").disabled = ips.is_empty()
	if ips.is_empty():
		addresses.add_item("No LAN address found — connect to Wi-Fi")
	NumericFontManager.manage_numeric_control(addresses)
	addresses.get_popup().add_theme_font_override("font", addresses.get_theme_font("font"))
	var keep: Array = []
	room.get_node("Actions/Ready").set_pressed_no_signal(false)
	for data: Dictionary in LanSession.seats:
		var id := int(data.id)
		keep.append(id)
		if not rows.has(id):
			rows[id] = PLAYER_ROW.instantiate()
			room.get_node("Scroll/Players").add_child(rows[id])
		rows[id].configure(data)
		if id == LanSession.local_player_id:
			room.get_node("Actions/Ready").set_pressed_no_signal(data.ready)
	for id in rows.keys():
		if id not in keep:
			room.get_node("Scroll/Players").remove_child(rows[id])
			rows[id].queue_free()
			rows.erase(id)
	room.get_node("Actions/Start").visible = host
	room.get_node("Actions/Start").disabled = not LanSession.can_start()
	var ready_button: Button = room.get_node("Actions/Ready")
	ready_button.text = "CANCEL READY" if ready_button.button_pressed else "READY"
