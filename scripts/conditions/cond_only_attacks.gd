extends "res://scripts/conditions/condition.gd"
## You have played only attack dominoes this turn.


func _init() -> void:
	id = "onlyAttacks"
	text = "you have played only attack dominoes this turn"


func met(game, _i: int) -> bool:
	return game.history.count("domino_played", {"turn": game.history.turn, "attack": false}) == 0
