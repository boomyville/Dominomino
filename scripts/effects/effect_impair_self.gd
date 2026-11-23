extends "res://scripts/effects/effect.gd"
## Apply Impair to yourself (negative Fury: less damage dealt).


func text(_game, s: int) -> String:
	return "Apply %d Impair to yourself" % value(s)


func apply(game, _domino, s: int) -> void:
	PowerCmd.apply(game, game.pl, "fury", -value(s))
