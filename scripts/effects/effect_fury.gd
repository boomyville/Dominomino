extends "res://scripts/effects/effect.gd"
## Gain Fury: more damage on your attacks (it ticks down after each attack).


func text(_game, s: int) -> String:
	return "Gain %d Fury" % value(s)


func apply(game, _domino, s: int) -> void:
	PowerCmd.apply(game, game.pl, "fury", value(s))


func preview(_game, _domino, s: int, sim: Dictionary) -> void:
	PowerCmd.apply(null, sim.pl, "fury", value(s), true)
