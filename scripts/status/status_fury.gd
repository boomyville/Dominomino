extends "res://scripts/status/status.gd"
## Fury adds its value to the damage dealt, Impair subtracts it. This is ONE signed number:
## Impair is negative Fury, so gaining Fury cancels Impair (3 Fury + 6 Impair = 3 Impair).
## It ticks one step toward 0 after every attack.


func _init() -> void:
	id = "fury"


func modify_damage(n: int) -> int:
	return n + value


func on_attack_done() -> void:
	if value > 0:
		value -= 1
	elif value < 0:
		value += 1


func text() -> String:
	if value > 0:
		return "Fury %d" % value
	if value < 0:
		return "Impair %d" % (-value)
	return ""


func icon_id() -> String:
	return "impair" if value < 0 else "fury"


func label() -> String:
	return "Impair" if value < 0 else "Fury"


func number() -> String:
	return str(absi(value))
