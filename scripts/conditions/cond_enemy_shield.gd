extends "res://scripts/conditions/condition.gd"
## The enemy has shield.


func _init() -> void:
	id = "enShield"
	text = "the enemy has shield"


func met(game, i: int) -> bool:
	return game.foe.shield > 0
