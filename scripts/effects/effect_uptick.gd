extends "res://scripts/effects/effect.gd"
## Uptick: choose a domino in your hand. Both of its pips go up by 1 (never past 6) until the battle ends.


func text(_game, _s: int) -> String:
	return "Add 1 to both pips of a domino in your hand (max 6)"


func icon() -> String:
	return "uptick"


func apply(game, _domino, _s: int) -> void:
	if game.hand.size() > 0:
		var c: int = await game.ui.pick("Uptick", "Choose a domino from your hand: both its pips go up by 1 (at most 6).", game.hand.duplicate())
		game.uptick_card(c)
