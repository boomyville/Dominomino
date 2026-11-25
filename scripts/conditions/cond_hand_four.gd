extends "res://scripts/conditions/condition.gd"
## Hold 4 or more dominoes (this one counts).


func _init() -> void:
	id = "hand4"
	text = "you hold 4 or more dominoes"
	hand_size = true


func met(game, _i: int) -> bool:
	return game.hand.size() >= 4
