extends RefCounted
## Stateless helpers for shield, max shield, HP and max HP of a Combatant (you or the enemy).
## A Combatant only holds the numbers; every change goes through here so it is shown and counted
## the same way no matter what caused it.


## The shield or healing after every model has had its say (Stalwart and Regenerative double it).
static func scaled(game, target, n: int, shield: bool) -> int:
	var factor := 1.0
	for m in game.active_models():
		factor *= m.modify_shield_multiplicative(n, {"target": target}) if shield \
				else m.modify_heal_multiplicative(n, {"target": target})
	return int(floor(n * factor))


static func gain_shield(game, target, n: int) -> void:
	n = scaled(game, target, n, true)
	target.shield += n
	var side: String = game.side_of(target)
	if side == "p":
		game.stats.shield += n
	game.ui.float_text(side, "+%d shield" % n)


## Remove all of a creature's shield. silent = true is for previews on copies.
static func break_shield(game, target, silent: bool = false) -> void:
	if target.shield <= 0:
		return
	target.shield = 0
	if not silent and game != null:
		game.ui.float_text(game.side_of(target), "Shield broken")


static func gain_max_shield(game, target, n: int) -> void:
	target.max_shield += n
	game.ui.float_text(game.side_of(target), "Max shield +%d" % n)


static func gain_max_hp(game, target, n: int) -> void:
	target.max_hp += n
	target.hp += n
	game.ui.float_text(game.side_of(target), "Max HP +%d" % n)


## Heals up to max HP. Returns how much was healed.
static func heal(game, target, n: int) -> int:
	var healed: int = target.heal(scaled(game, target, n, false))
	var side: String = game.side_of(target)
	if side == "p":
		game.stats.healed += healed
	game.ui.float_text(side, "+%d HP" % healed)
	return healed
