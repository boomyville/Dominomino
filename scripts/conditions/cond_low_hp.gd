extends "res://scripts/conditions/condition.gd"
## Your HP is half or less.


func _init() -> void:
	id = "lowHp"
	text = "your HP is half or less"


func met(game, i: int) -> bool:
	return game.pl.hp * 2 <= game.pl.max_hp
