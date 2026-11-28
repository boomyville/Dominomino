extends "res://scripts/effects/effect.gd"
## Damage that is doubled while the enemy has no shield (Machete Chop).


func is_attack() -> bool:
	return true


func icon() -> String:
	return "dmg"


func _base(game, s: int) -> int:
	return value(s) * (2 if game.foe.shield == 0 else 1)


func text_for(game, _domino, s: int) -> String:
	return "Deal %d damage, double if the enemy has no shield (%d now)" % [attack_value(game, value(s)), attack_value(game, _base(game, s))]


func caption_for(game, _domino, s: int) -> String:
	return str(attack_value(game, _base(game, s)))


func apply(game, _domino, s: int) -> void:
	attack(game, _base(game, s))


func preview(game, _domino, s: int, sim: Dictionary) -> void:
	sim_attack(game, sim, value(s) * (2 if sim.foe.shield == 0 else 1))
