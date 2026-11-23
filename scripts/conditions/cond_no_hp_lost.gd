extends "res://scripts/conditions/condition.gd"
## You have not lost HP this battle.


func _init() -> void:
	id = "noHpLost"
	text = "you have not lost HP this battle"


func met(game, i: int) -> bool:
	return not game.history.has("hp_lost", {"who": "p"})
