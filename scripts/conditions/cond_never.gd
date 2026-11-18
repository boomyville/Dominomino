extends "res://scripts/conditions/condition.gd"
## Garbage can never be played.


func _init() -> void:
	id = "never"
	text = "cannot be played"


func met(game, i: int) -> bool:
	return false
