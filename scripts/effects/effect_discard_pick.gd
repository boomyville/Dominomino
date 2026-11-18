extends "res://scripts/effects/effect.gd"
## Discard dominoes from your hand, you choose which.


func text(_game, s: int) -> String:
	return "Discard %d of your choice" % value(s)


func apply(game, _domino, s: int) -> void:
	for i in value(s):
		if game.hand.size() > 0:
			var c: int = await game.ui.pick("Discard a domino", "Choose a domino from your hand to discard.", game.hand.duplicate())
			game.discard_hand_card(c)
