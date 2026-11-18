extends "res://scripts/effects/effect.gd"
## Apply Impair to the enemy (its attacks hit for less).


func text(_game, s: int) -> String:
	return "Apply %d Impair to the enemy" % value(s)


func apply(game, _domino, s: int) -> void:
	game.foe.add("fury", -value(s))
	game.ui.float_text("c", game.foe.fury_text())
