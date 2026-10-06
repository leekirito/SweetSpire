class_name MatchCommands
extends RefCounted
## Network adapter; local bots use the same validated dispatcher.
static func execute(game: MatchManager, seat: int, command: Dictionary) -> bool:
	return GameCommands.execute(game, seat, command)
