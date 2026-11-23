extends "res://scripts/effects/effect.gd"
## Deal damage several times (twice or three times).


func is_attack() -> bool:
	return true


func text(game, s: int) -> String:
	return "Deal %d damage x%d" % [attack_value(game, value(s)), hits]


func caption(game, s: int) -> String:
	return "%dx%d" % [attack_value(game, value(s)), hits]


func apply(game, _domino, s: int) -> void:
	for i in hits:
		if game.foe.hp <= 0:
			break
		attack(game, value(s))
		game.ui.refresh()
		await game.ui.pause(0.26)


func preview(game, _domino, s: int, sim: Dictionary) -> void:
	for i in hits:
		sim_attack(game, sim, value(s))
