extends "res://scripts/effects/effect.gd"
## Raise the shield cap (shield above the cap is lost at the start of your turn).


func text(_game, s: int) -> String:
	return "Max shield +%d" % value(s)


func apply(game, _domino, s: int) -> void:
	CreatureCmd.gain_max_shield(game, game.pl, value(s))
