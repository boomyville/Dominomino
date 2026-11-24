extends "res://scripts/effects/effect.gd"
## Playing this domino ends your turn once all its effects are done.


func text(_game, _s: int) -> String:
	return "Ends your turn"


func icon() -> String:
	return "end_turn"


func apply(game, _domino, _s: int) -> void:
	game.end_turn_after_play = true
