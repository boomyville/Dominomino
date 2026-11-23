extends "res://scripts/effects/effect.gd"
## Heal HP (up to your max).


func text(_game, s: int) -> String:
	return "Heal %d" % value(s)


func apply(game, _domino, s: int) -> void:
	CreatureCmd.heal(game, game.pl, value(s))
