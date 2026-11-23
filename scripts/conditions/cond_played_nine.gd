extends "res://scripts/conditions/condition.gd"
## At least 9 dominoes played this battle.


func _init() -> void:
	id = "played9"
	text = "you have played 9 or more dominoes this battle"


func met(game, i: int) -> bool:
	return game.history.count("domino_played") >= 9
