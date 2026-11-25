extends "res://scripts/status/status.gd"
## Regenerative: the healing its owner gets is doubled. It goes down by 1 each time its owner ends a turn.


func _init() -> void:
	id = "regenerative"


func modify_heal_multiplicative(_n: int, ctx: Dictionary) -> float:
	return 2.0 if value > 0 and ctx.get("target") == owner else 1.0


func on_turn_end(_game, _ctx: Dictionary) -> void:
	value = maxi(0, value - 1)


func text() -> String:
	return "Regenerative %d" % value if value > 0 else ""


func icon_id() -> String:
	return "heal"


func label() -> String:
	return "Regenerative"


func number() -> String:
	return str(value)
