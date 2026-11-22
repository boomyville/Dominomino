extends "res://scripts/conditions/condition.gd"
## You have more than 1 life (used by dominoes that cost a life).


func _init() -> void:
	id = "lives2"
	text = "you have more than 1 life"


func met(game, _i: int) -> bool:
	return game.lives > 1
