extends "res://scripts/effects/effect.gd"
## Gain Power: more damage for the rest of the battle.


func text(_game, s: int) -> String:
	return "Gain %d Power" % value(s)


func apply(game, _domino, s: int) -> void:
	PowerCmd.apply(game, game.pl, "power", value(s))


func preview(_game, _domino, s: int, sim: Dictionary) -> void:
	PowerCmd.apply(null, sim.pl, "power", value(s), true)
