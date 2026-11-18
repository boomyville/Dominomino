extends "res://scripts/effects/effect.gd"
## Discard random dominoes from your hand.


func text(_game, s: int) -> String:
	return "Discard %d at random" % value(s)


func apply(game, _domino, s: int) -> void:
	for i in value(s):
		game.discard_random_from_hand()
