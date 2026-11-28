extends "res://scripts/conditions/condition.gd"
## Only on the first turn of the battle.


func _init() -> void:
	id = "turn1"
	text = "it is the first turn of the battle"


func met(game, _i: int) -> bool:
	return game.history.turn == 1
