extends "res://scripts/conditions/condition.gd"
## No other domino in hand has an attack.


func _init() -> void:
	id = "noAtk"
	text = "you have no attack dominoes in hand"


func met(game, i: int) -> bool:
	for j in game.hand.size():
		if j != i and game.hand[j].data.has_attack():
			return false
	return true
