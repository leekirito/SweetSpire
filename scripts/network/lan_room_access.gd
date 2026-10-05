class_name LanRoomAccess
extends RefCounted
## Lobby access only. Passwords and proofs never enter shared roster/discovery data.
var private_room := false
var password := ""
var pending: Dictionary = {}

func configure(is_private: bool, secret: String = "") -> void:
	private_room = is_private
	password = secret if is_private else ""
	if private_room and password.is_empty():
		password = Crypto.new().generate_random_bytes(6).hex_encode()
	pending.clear()

func challenge(remote: int, hello: Dictionary) -> String:
	var nonce := Crypto.new().generate_random_bytes(24).hex_encode()
	pending[remote] = {"nonce": nonce, "hello": hello.duplicate(true)}
	return nonce

static func proof(secret: String, nonce: String) -> String:
	return Crypto.new().hmac_digest(HashingContext.HASH_SHA256, secret.to_utf8_buffer(), nonce.to_utf8_buffer()).hex_encode()

func authenticate(remote: int, received: String) -> Dictionary:
	if not pending.has(remote):
		return {}
	var attempt: Dictionary = pending[remote]
	pending.erase(remote)
	var expected := proof(password, attempt.nonce)
	if received.length() != expected.length() or not Crypto.new().constant_time_compare(expected.to_utf8_buffer(), received.to_utf8_buffer()):
		return {}
	return attempt.hello
