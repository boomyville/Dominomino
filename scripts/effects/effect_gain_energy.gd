extends "res://scripts/effects/effect.gd"
## Gain energy this turn (Beginner's Luck).


func text(_game, s: int) -> String:
	return "Gain %d energy" % value(s)


func icon() -> String:
	return "energy"


func apply(game, _domino, s: int) -> void:
	game.gain_energy(value(s))
