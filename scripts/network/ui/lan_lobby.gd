extends Control
signal back_requested
@onready var page := $Margin/Page
@onready var name_input: LineEdit = $Margin/Page/Identity/PlayerName
@onready var tribe: OptionButton = $Margin/Page/Identity/Tribe
@onready var address_input: LineEdit = $Margin/Page/Connection/Address
@onready var port_input: SpinBox = $Margin/Page/Connection/Port
@onready var nearby: ItemList = $Margin/Page/Lists/Nearby/Rooms
@onready var roster: ItemList = $Margin/Page/Lists/Lobby/Players
@onready var mode_picker: OptionButton = $Margin/Page/ModeRow/MatchMode
var room_keys: Array = []
var updating := false

func _ready() -> void:
	page.get_node("Header/Back").pressed.connect(_back)
	page.get_node("Hosting/Host").pressed.connect(_host)
	page.get_node("Connection/Join").pressed.connect(_join)
	page.get_node("Actions/Ready").toggled.connect(_ready_changed)
	page.get_node("Actions/Start").pressed.connect(LanSession.start_match)
	page.get_node("Actions/Leave").pressed.connect(func(): LanSession.leave(); LanSession.scan_rooms())
	tribe.item_selected.connect(func(_index: int): LanSession.choose(_tribe(), false))
	mode_picker.item_selected.connect(func(index: int): LanSession.choose_mode(GameSession.MATCH_MODES[index]))
	nearby.item_selected.connect(_room_selected)
	LanSession.changed.connect(_refresh)
	LanSession.rooms_changed.connect(_refresh_rooms)
	LanSession.notice.connect(func(message: String): page.get_node("Status").text = message)
	port_input.value = LanSession.SETTINGS.game_port
	NumericFontManager.manage_numeric_control(port_input.get_line_edit())
	_refresh()

func open() -> void:
	show()
	if OS.has_feature("web"):
		page.get_node("Status").text = "LAN multiplayer is available in the Windows download."
		return
	if not LanSession.hosting:
		LanSession.scan_rooms()
	_refresh()

func _tribe() -> String:
	return ["saba", "malagkit", "kamote"][tribe.selected]

func _host() -> void:
	LanSession.host_room(name_input.text, page.get_node("Hosting/RoomName").text, int(page.get_node("Hosting/Capacity").value), _tribe(), int(port_input.value), GameSession.MATCH_MODES[mode_picker.selected])

func _join() -> void:
	LanSession.join_room(address_input.text, name_input.text, _tribe(), int(port_input.value))

func _back() -> void:
	LanSession.leave()
	back_requested.emit()

func _ready_changed(value: bool) -> void:
	if not updating:
		LanSession.choose(_tribe(), value)

func _room_selected(index: int) -> void:
	if index >= room_keys.size() or not LanSession.rooms.has(room_keys[index]):
		return
	var room: Dictionary = LanSession.rooms[room_keys[index]]
	address_input.text = room.address
	port_input.value = room.port

func _refresh_rooms() -> void:
	nearby.clear()
	room_keys = LanSession.rooms.keys()
	for key in room_keys:
		var room: Dictionary = LanSession.rooms[key]
		nearby.add_item("%s — %d/%d" % [str(room.room).left(32), int(room.get("count", 0)), int(room.get("capacity", 8))])

func _refresh() -> void:
	updating = true
	roster.clear()
	var ready: CheckButton = page.get_node("Actions/Ready")
	ready.set_pressed_no_signal(false)
	for row: Dictionary in LanSession.seats:
		var status := "READY" if row.ready else "Choosing tribe"
		if not row.connected:
			status = "Disconnected"
		roster.add_item("%d  %s  ·  %s  ·  %s" % [int(row.id), row.name, str(row.tribe).to_upper(), status])
		if int(row.id) == LanSession.local_player_id:
			ready.set_pressed_no_signal(row.ready)
	var idle := LanSession.state in ["offline", "ended"]
	mode_picker.disabled = not idle and not (LanSession.hosting and LanSession.state == "lobby")
	if not idle:
		mode_picker.select(GameSession.MATCH_MODES.find(LanSession.match_mode))
	page.get_node("Hosting/Host").disabled = not idle or OS.has_feature("web")
	page.get_node("Connection/Join").disabled = not idle or OS.has_feature("web")
	name_input.editable = idle
	ready.disabled = LanSession.state != "lobby"
	page.get_node("Actions/Start").disabled = not LanSession.can_start()
	page.get_node("Actions/Leave").disabled = idle
	if not LanSession.error_message.is_empty():
		page.get_node("Status").text = LanSession.error_message
	elif LanSession.state == "lobby":
		var addresses: Array = []
		for ip in IP.get_local_addresses():
			if "." in ip and not ip.begins_with("127.") and not ip.begins_with("169.254."):
				addresses.append(ip)
		page.get_node("Status").text = "Choose your tribe and mark Ready." + (" Host address: " + ", ".join(addresses) + " · port %d" % LanSession.port if LanSession.hosting else "")
	elif LanSession.state == "connecting":
		page.get_node("Status").text = "Connecting to the host…"
	else:
		page.get_node("Status").text = "Same Wi-Fi · Windows · Choose a nearby game, or enter the host's address."
	updating = false
