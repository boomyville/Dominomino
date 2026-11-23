extends "res://scripts/effects/effect.gd"
## Gain shield.


func text(_game, s: int) -> String:
	return "Gain %d shield" % value(s)


func apply(game, _domino, s: int) -> void:
	CreatureCmd.gain_shield(game, game.pl, value(s))
