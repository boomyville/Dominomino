extends "res://scripts/effects/effect.gd"
## Draw dominoes from the stack (nothing is drawn if the hand is full or the stack is empty).


func text(_game, s: int) -> String:
	return "Draw %d" % value(s)


func apply(game, _domino, s: int) -> void:
	for i in value(s):
		if game.draw_one():
			game.announce_new_card()
		game.ui.refresh()
		await game.ui.pause(0.22)
	game.ui.fresh(-1)
