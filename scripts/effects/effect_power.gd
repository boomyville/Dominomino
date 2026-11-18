extends "res://scripts/effects/effect.gd"
## Gain Power: more damage for the rest of the battle.


func text(_game, s: int) -> String:
	return "Gain %d Power" % value(s)


func apply(game, _domino, s: int) -> void:
	var v := value(s)
	game.pl.add("power", v)
	game.ui.float_text("p", "Power +%d" % v)
