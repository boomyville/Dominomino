extends "res://scripts/effects/effect.gd"
## Gain extra lives.


func text(_game, s: int) -> String:
	return "Gain %d lives" % value(s)


func apply(game, _domino, s: int) -> void:
	var v := value(s)
	game.lives += v
	game.ui.float_text("p", "+%d lives" % v)
