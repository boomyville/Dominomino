extends RefCounted
## Stateless helpers for shield, max shield, HP and max HP of a Combatant (you or the enemy).
## A Combatant only holds the numbers; every change goes through here so it is shown and counted
## the same way no matter what caused it.


static func gain_shield(game, target, n: int) -> void:
	target.shield += n
	var side: String = game.side_of(target)
	if side == "p":
		game.stats.shield += n
	game.ui.float_text(side, "+%d shield" % n)


static func gain_max_shield(game, target, n: int) -> void:
	target.max_shield += n
	game.ui.float_text(game.side_of(target), "Max shield +%d" % n)


static func gain_max_hp(game, target, n: int) -> void:
	target.max_hp += n
	target.hp += n
	game.ui.float_text(game.side_of(target), "Max HP +%d" % n)


## Heals up to max HP. Returns how much was healed.
static func heal(game, target, n: int) -> int:
	var healed: int = target.heal(n)
	var side: String = game.side_of(target)
	if side == "p":
		game.stats.healed += healed
	game.ui.float_text(side, "+%d HP" % healed)
	return healed
