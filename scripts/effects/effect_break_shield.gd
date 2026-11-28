extends "res://scripts/effects/effect.gd"
## Remove all of the enemy's shield (Rapier Thrust).


func text(_game, _s: int) -> String:
	return "Remove all of the enemy's shield"


func icon() -> String:
	return "shield"


func apply(game, _domino, _s: int) -> void:
	CreatureCmd.break_shield(game, game.foe)


func preview(game, _domino, _s: int, sim: Dictionary) -> void:
	CreatureCmd.break_shield(game, sim.foe, true)
