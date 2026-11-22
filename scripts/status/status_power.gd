extends "res://scripts/status/status.gd"
## Power adds to every attack for the rest of the battle (it never ticks down).


func _init() -> void:
	id = "power"


func modify_damage(n: int) -> int:
	return n + value


func text() -> String:
	return "Power +%d" % value if value != 0 else ""


func label() -> String:
	return "Power"


func number() -> String:
	return "+%d" % value
