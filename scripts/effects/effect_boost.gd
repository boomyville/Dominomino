extends "res://scripts/effects/effect.gd"
## Gain Boost: more damage on your next attack only.


func text(_game, s: int) -> String:
	return "Gain %d Boost" % value(s)


func apply(game, _domino, s: int) -> void:
	var v := value(s)
	game.pl.add("boost", v)
	game.ui.float_text("p", "Boost +%d" % v)


func preview(_game, _domino, s: int, sim: Dictionary) -> void:
	sim.pl.add("boost", value(s))
