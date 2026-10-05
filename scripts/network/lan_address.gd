class_name LanAddress
extends RefCounted

static func parse(text: String, fallback_port: int) -> Dictionary:
	var address := text.strip_edges()
	var port := fallback_port
	if address.count(":") == 1:
		var suffix := address.get_slice(":", 1)
		if not suffix.is_valid_int():
			return {}
		port = int(suffix)
		address = address.get_slice(":", 0).strip_edges()
	if address.is_empty() or port < 1 or port > 65535 or "/" in address or " " in address:
		return {}
	return {"address": address, "port": port}

static func local_addresses() -> PackedStringArray:
	var addresses := PackedStringArray()
	for ip: String in IP.get_local_addresses():
		if "." in ip and not ip.begins_with("127.") and not ip.begins_with("169.254."):
			addresses.append(ip)
	addresses.sort()
	return addresses
