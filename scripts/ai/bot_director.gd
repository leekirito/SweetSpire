extends Node
## Only the authoritative process creates bot controllers.
func _ready() -> void:
	get_parent().match_started.connect(_attach)

func _attach() -> void:
	var game: MatchManager = get_parent()
	if LanSession.active() and not LanSession.hosting:
		return
	for player: PlayerState in game.players:
		if not player.is_bot():
			continue
		var controller: AIController = preload("res://scenes/entities/AI/ai_controller.tscn").instantiate()
		controller.controlled_player_id = player.player_id
		controller.match_manager = game
		controller.profile = BotCatalog.profile(player.bot_profile_id)
		add_child(controller)
