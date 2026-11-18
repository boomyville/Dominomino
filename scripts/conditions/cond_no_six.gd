extends "res://scripts/conditions/condition.gd"
## No other domino in hand has a 6 pip.


func _init() -> void:
	id = "noSix"
	text = "you have no 6 pips in hand"


func met(game, i: int) -> bool:
	for j in game.hand.size():
		if j != i and (game.hand[j].a == 6 or game.hand[j].b == 6):
			return false
	return true
