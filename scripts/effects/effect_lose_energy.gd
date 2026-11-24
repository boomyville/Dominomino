extends "res://scripts/effects/effect.gd"
## Lose energy (never below 0). Mostly a drawback of downgraded dominoes.


func text(_game, s: int) -> String:
	return "Lose %d energy" % value(s)


func apply(game, _domino, s: int) -> void:
	game.lose_energy(value(s))
