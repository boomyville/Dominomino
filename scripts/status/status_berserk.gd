extends "res://scripts/status/status.gd"
## Berserk: while it is on you only attack dominoes can be played (Game.cond_ok). It goes down by 1 at the start of
## each of your turns, so Berserk 1 lasts the rest of the turn you got it in.


func _init() -> void:
	id = "berserk"


func on_turn_start(_game, _ctx: Dictionary) -> void:
	value = maxi(0, value - 1)


func text() -> String:
	return "Berserk %d" % value if value > 0 else ""


func icon_id() -> String:
	return "fury"


func label() -> String:
	return "Berserk"


func number() -> String:
	return str(value)
