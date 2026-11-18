extends "res://scripts/effects/effect.gd"
## Reroll the pips of one domino in your hand, you choose which.


func text(_game, _s: int) -> String:
	return "Reroll a domino of your choice"


func apply(game, _domino, _s: int) -> void:
	if game.hand.size() > 0:
		var c: int = await game.ui.pick("Reroll a domino", "Choose a domino from your hand to reroll.", game.hand.duplicate())
		game.reroll_card(c)
