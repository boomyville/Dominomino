extends "res://scripts/effects/effect.gd"
## Deal damage once.


func is_attack() -> bool:
	return true


func text(game, s: int) -> String:
	return "Deal %d damage" % attack_value(game, value(s))


func caption(game, s: int) -> String:
	return str(attack_value(game, value(s)))


func apply(game, _domino, s: int) -> void:
	attack(game, value(s))


func preview(game, _domino, s: int, sim: Dictionary) -> void:
	sim_attack(game, sim, value(s))
