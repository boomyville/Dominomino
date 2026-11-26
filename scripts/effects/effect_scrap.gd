extends "res://scripts/effects/effect.gd"
## Discard every domino of one type ("ty") from your hand and gain shield for each one.

var ty := "attack"


func setup(row: Dictionary) -> void:
	super.setup(row)
	ty = row.get("ty", "attack")


func text_for(game, domino, s: int) -> String:
	var n := 0
	for d in game.hand:
		if d != domino and d.type() == ty:
			n += 1
	return "Discard every %s in your hand and gain %d shield for each (%d now)" % [ty, value(s), n]


func icon() -> String:
	return "shield"


func apply(game, _domino, s: int) -> void:
	var gone := 0
	for i in range(game.hand.size() - 1, -1, -1):
		if game.hand[i].type() == ty:
			game.discard_hand_card(i)
			gone += 1
	if gone > 0:
		CreatureCmd.gain_shield(game, game.pl, value(s) * gone)
	game.ui.refresh()
	await game.ui.pause(0.3)
