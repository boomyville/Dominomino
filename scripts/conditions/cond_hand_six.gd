extends "res://scripts/conditions/condition.gd"
## Hold 6 or more dominoes.


func _init() -> void:
	id = "hand6"
	text = "you hold 6 or more dominoes"
	hand_size = true


func met(game, i: int) -> bool:
	return game.hand.size() >= 6
