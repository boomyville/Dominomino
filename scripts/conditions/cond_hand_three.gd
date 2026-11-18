extends "res://scripts/conditions/condition.gd"
## Hold 3 or fewer dominoes.


func _init() -> void:
	id = "handLe3"
	text = "you hold 3 or fewer dominoes"


func met(game, i: int) -> bool:
	return game.hand.size() <= 3
