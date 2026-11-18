extends "res://scripts/effects/effect.gd"
## Apply Impair to yourself (negative Fury: less damage dealt).


func text(_game, s: int) -> String:
	return "Apply %d Impair to yourself" % value(s)


func apply(game, _domino, s: int) -> void:
	game.pl.add("fury", -value(s))
	game.ui.float_text("p", game.pl.fury_text())
