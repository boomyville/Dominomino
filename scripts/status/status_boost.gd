extends "res://scripts/status/status.gd"
## Boost adds to the next attack only. It is used up as soon as an attack finishes.


func _init() -> void:
	id = "boost"


func modify_damage_additive(_base: int, ctx: Dictionary) -> int:
	return value if is_source(ctx) else 0


func after_attack(_game, ctx: Dictionary) -> void:
	if is_source(ctx):
		value = 0


func text() -> String:
	return "Boost +%d" % value if value != 0 else ""


func label() -> String:
	return "Boost"


func number() -> String:
	return "+%d" % value
