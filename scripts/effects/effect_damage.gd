extends "res://scripts/effects/effect.gd"
## Deal damage once.


func is_attack() -> bool:
	return true


func text(game, s: int) -> String:
	return "Deal %d damage" % game.pl.attack_damage(value(s))


func caption(game, s: int) -> String:
	return str(game.pl.attack_damage(value(s)))


func apply(game, _domino, s: int) -> void:
	game.hit_foe(game.pl.attack_damage(value(s)))
