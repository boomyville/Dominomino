extends "res://scripts/effects/effect.gd"
## Pay with a life (not HP). Put it first in a domino's effects. Pair it with the play condition
## "lives2" so the domino cannot be played when you only have 1 life left.


func text(_game, s: int) -> String:
	var v := value(s)
	return "Lose %d li%s" % [v, "ves" if v > 1 else "fe"]


func apply(game, _domino, s: int) -> void:
	for i in value(s):
		game.lose_life()
