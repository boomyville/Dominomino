extends "res://scripts/effects/effect.gd"
## Lose HP (it ignores shield).


func text(_game, s: int) -> String:
	return "Lose %d HP" % value(s)


func apply(game, _domino, s: int) -> void:
	DamageCmd.lose_hp(game, game.pl, value(s))
