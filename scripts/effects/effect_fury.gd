extends "res://scripts/effects/effect.gd"
## Gain Fury: more damage on your attacks (it ticks down after each attack).


func text(_game, s: int) -> String:
	return "Gain %d Fury" % value(s)


func apply(game, _domino, s: int) -> void:
	game.pl.add("fury", value(s))
	game.ui.float_text("p", game.pl.fury_text())
