extends "res://scripts/effects/effect.gd"
## Lose HP (it ignores shield).


func text(_game, s: int) -> String:
	return "Lose %d HP" % value(s)


func apply(game, _domino, s: int) -> void:
	var v := value(s)
	game.pl.lose_hp(v)
	game.stats.selfdmg += v
	game.bat.hp_lost = true
	game.ui.float_text("p", "-%d HP" % v)
