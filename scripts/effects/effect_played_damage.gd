extends "res://scripts/effects/effect.gd"
## Deal damage for every domino of one type ("ty": attack or skill) you have played this turn (this one counts).

var ty := "attack"


func setup(row: Dictionary) -> void:
	super.setup(row)
	ty = row.get("ty", "attack")


func is_attack() -> bool:
	return true


func icon() -> String:
	return "dmg"


func _count(game, _domino) -> int:
	return game.history.count("domino_played", {"turn": game.history.turn, "attack": ty == "attack"})


func text_for(game, domino, s: int) -> String:
	return "Deal %d damage for every %s you played this turn, this one included (%d now)" % [value(s), ty, attack_value(game, value(s) * maxi(1, _count(game, domino)))]


func caption_for(game, domino, s: int) -> String:
	return str(attack_value(game, value(s) * maxi(1, _count(game, domino))))


func apply(game, domino, s: int) -> void:
	attack(game, value(s) * maxi(1, _count(game, domino)))


func preview(game, domino, s: int, sim: Dictionary) -> void:
	sim_attack(game, sim, value(s) * maxi(1, _count(game, domino)))
