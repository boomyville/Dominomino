extends "res://scripts/effects/effect.gd"
## Add random dominoes to your stack (they only exist for this battle).


func text(_game, s: int) -> String:
	var v := value(s)
	return "Add %d random domino%s to your stack" % [v, "es" if v > 1 else ""]


func apply(game, _domino, s: int) -> void:
	var v := value(s)
	game.generate_into_stack(v)
	game.ui.float_text("p", "+%d in stack" % v)
