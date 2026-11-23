extends "res://scripts/effects/effect.gd"
## Gain Boost: more damage on your next attack only.


func text(_game, s: int) -> String:
	return "Gain %d Boost" % value(s)


func apply(game, _domino, s: int) -> void:
	PowerCmd.apply(game, game.pl, "boost", value(s))


func preview(_game, _domino, s: int, sim: Dictionary) -> void:
	PowerCmd.apply(null, sim.pl, "boost", value(s), true)
