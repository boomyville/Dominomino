extends "res://scripts/effects/effect.gd"
## Draw random attack dominoes from the stack (as many as there are, if fewer).


func text(_game, s: int) -> String:
	return "Draw %d random attack dominoes from your stack" % value(s)


func icon() -> String:
	return "draw"


func apply(game, _domino, s: int) -> void:
	for i in value(s):
		if game.draw_matching("attack"):
			game.announce_new_card()
		game.ui.refresh()
		await game.ui.pause(0.22)
