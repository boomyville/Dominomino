extends "res://scripts/effects/effect.gd"
## Gain shield.


func text(_game, s: int) -> String:
	return "Gain %d shield" % value(s)


func apply(game, _domino, s: int) -> void:
	var v := value(s)
	game.pl.shield += v
	game.stats.shield += v
	game.ui.float_text("p", "+%d shield" % v)
