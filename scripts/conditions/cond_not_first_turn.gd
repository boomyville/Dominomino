extends "res://scripts/conditions/condition.gd"
## Not the first turn of the battle.


func _init() -> void:
	id = "turn2"
	text = "it is not the first turn of the battle"


func met(game, _i: int) -> bool:
	return game.history.turn > 1
