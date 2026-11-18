extends "res://scripts/conditions/condition.gd"
## Nothing has been played yet this turn.


func _init() -> void:
	id = "first"
	text = "no domino has been played yet this turn"


func met(game, i: int) -> bool:
	return not game.played_this_turn
