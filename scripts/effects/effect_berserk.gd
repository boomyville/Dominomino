extends "res://scripts/effects/effect.gd"
## Apply Berserk to yourself: until the start of your next turn you can only play attack dominoes.


func text(_game, s: int) -> String:
	return "Apply %d Berserk to yourself (only attack dominoes can be played)" % value(s)


func icon() -> String:
	return "fury"


func apply(game, _domino, s: int) -> void:
	PowerCmd.apply(game, game.pl, "berserk", value(s))
