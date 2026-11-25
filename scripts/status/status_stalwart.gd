extends "res://scripts/status/status.gd"
## Stalwart: the shield its owner gains is doubled. It goes down by 1 each time its owner ends a turn, so
## Stalwart 1 doubles shields for one turn.


func _init() -> void:
	id = "stalwart"


func modify_shield_multiplicative(_n: int, ctx: Dictionary) -> float:
	return 2.0 if value > 0 and ctx.get("target") == owner else 1.0


func on_turn_end(_game, _ctx: Dictionary) -> void:
	value = maxi(0, value - 1)


func text() -> String:
	return "Stalwart %d" % value if value > 0 else ""


func icon_id() -> String:
	return "shield"


func label() -> String:
	return "Stalwart"


func number() -> String:
	return str(value)
