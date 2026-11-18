extends "res://scripts/effects/effect.gd"
## Reroll the pips of every domino in your hand.


func text(_game, _s: int) -> String:
	return "Reroll all dominoes in hand"


func apply(game, _domino, _s: int) -> void:
	game.reroll_hand()
