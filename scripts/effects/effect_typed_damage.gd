extends "res://scripts/effects/effect.gd"
## Deal damage for every domino of one type ("ty": attack or skill) in your hand (this domino does not count).

var ty := "skill"


func setup(row: Dictionary) -> void:
	super.setup(row)
	ty = row.get("ty", "skill")


func is_attack() -> bool:
	return true


func icon() -> String:
	return "dmg"


func _count(game, domino) -> int:
	var n := 0
	for d in game.hand:
		if d != domino and d.type() == ty:
			n += 1
	return n


func text_for(game, domino, s: int) -> String:
	var n := _count(game, domino)
	return "Deal %d damage for every %s in your hand (%d now)" % [value(s), ty, attack_value(game, value(s) * n)]


func caption_for(game, domino, s: int) -> String:
	return str(attack_value(game, value(s) * _count(game, domino)))


func apply(game, domino, s: int) -> void:
	attack(game, value(s) * _count(game, domino))


func preview(game, domino, s: int, sim: Dictionary) -> void:
	sim_attack(game, sim, value(s) * _count(game, domino))
