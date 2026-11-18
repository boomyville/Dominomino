extends "res://scripts/effects/effect.gd"
## Heal HP (up to your max).


func text(_game, s: int) -> String:
	return "Heal %d" % value(s)


func apply(game, _domino, s: int) -> void:
	var healed: int = game.pl.heal(value(s))
	game.stats.healed += healed
	game.ui.float_text("p", "+%d HP" % healed)
