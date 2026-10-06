class_name LanRoomAccess
extends RefCounted

## Private-lobby password challenges kept separate from shared roster data.
## Each peer's pending challenge is consumed when authentication is attempted.

## Lobby access only. Passwords and proofs never enter shared roster/discovery data.
var private_room := false
var password := ""
var pending: Dictionary = {}

## Sets privacy/password and clears challenges; an empty private-room password is generated.
func configure(is_private: bool, secret: String = "") -> void:
	private_room = is_private
	password = secret if is_private else ""
	if private_room and password.is_empty():
		password = Crypto.new().generate_random_bytes(6).hex_encode()
	pending.clear()

## Stores join data with a fresh nonce for this peer and returns the nonce.
func challenge(remote: int, hello: Dictionary) -> String:
	var nonce := Crypto.new().generate_random_bytes(24).hex_encode()
	pending[remote] = {"nonce": nonce, "hello": hello.duplicate(true)}
	return nonce

## Computes the password challenge's HMAC response without sending the password itself.
static func proof(secret: String, nonce: String) -> String:
	return Crypto.new().hmac_digest(HashingContext.HASH_SHA256, secret.to_utf8_buffer(), nonce.to_utf8_buffer()).hex_encode()

## Consumes the pending challenge; only a valid response receives the stored join data.
func authenticate(remote: int, received: String) -> Dictionary:
	if not pending.has(remote):
		return {}
	var attempt: Dictionary = pending[remote]
	pending.erase(remote)
	var expected := proof(password, attempt.nonce)
	if received.length() != expected.length() or not Crypto.new().constant_time_compare(expected.to_utf8_buffer(), received.to_utf8_buffer()):
		return {}
	return attempt.hello
