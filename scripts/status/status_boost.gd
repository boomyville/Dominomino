extends "res://scripts/status/status.gd"
## Boost adds to the next attack only. It is used up as soon as an attack finishes.


func _init() -> void:
	id = "boost"


func modify_damage(n: int) -> int:
	return n + value


func on_attack_done() -> void:
	value = 0


func text() -> String:
	return "Boost +%d" % value if value != 0 else ""
