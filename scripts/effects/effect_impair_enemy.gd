extends "res://scripts/effects/effect.gd"
## Apply Impair to the enemy (its attacks hit for less).


func text(_game, s: int) -> String:
	return "Apply %d Impair to the enemy" % value(s)


func apply(game, _domino, s: int) -> void:
	PowerCmd.apply(game, game.foe, "fury", -value(s))
