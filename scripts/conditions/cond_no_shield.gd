extends "res://scripts/conditions/condition.gd"
## You have no shield.


func _init() -> void:
	id = "noShield"
	text = "you have no shield"


func met(game, i: int) -> bool:
	return game.pl.shield == 0
