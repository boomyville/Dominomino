extends RefCounted
## Stateless helpers for everything that costs HP. An effect or a relic says what it wants
## (DamageCmd.attack(game, game.pl, game.foe, 6)); this runs the math hooks, changes the
## Combatant, writes the event log, updates the stats, tells the UI and runs the after hooks.
## A Combatant only stores HP and shield and does the basic subtraction (take_damage, lose_hp).
##
## silent = true is for previews: only the numbers change (on copies), nothing is logged or shown.

const AbstractModel = preload("res://scripts/model.gd")


## The damage after every model has had its say. Three passes, each in a fixed order:
##   1 additive (+6 Fury)   2 multiplicative (x1.5)   3 cap / override (by priority).
## Never below 0. ctx should hold source and target.
static func calculate(models: Array, base: int, ctx: Dictionary) -> int:
	var ordered := AbstractModel.in_order(models)
	var delta := 0
	for m in ordered:
		delta += m.modify_damage_additive(base, ctx)
	var n := maxi(0, base + delta)
	var factor := 1.0
	for m in ordered:
		factor *= m.modify_damage_multiplicative(n, ctx)
	n = int(floor(n * factor))
	for m in ordered:
		n = m.modify_damage_cap(n, ctx)
	return maxi(0, n)


## What an attack of this base size does right now, source and target statuses and relics counted.
## game can be null (then only the two combatants' statuses count).
static func attack_value(game, source, target, base: int) -> int:
	var models: Array = game.active_models(source, target) if game != null \
			else source.models() + target.models()
	return calculate(models, base, {"source": source, "target": target, "base": base})


## Work out the damage of an attack and deal it. Returns {absorbed, taken}.
static func attack(game, source, target, base: int, silent: bool = false) -> Dictionary:
	var n := attack_value(game, source, target, base)
	return deal(game, source, target, n, silent, "attack")


## Deal a final amount (no modifiers). Shield soaks first. Returns {absorbed, taken}.
static func deal(game, source, target, amount: int, silent: bool = false, kind: String = "direct") -> Dictionary:
	var r: Dictionary = target.take_damage(amount)
	if silent or game == null:
		return r
	var side: String = game.side_of(target)
	if side == "c":
		game.stats.dealt += r.taken
		game.ui.float_text("c", "-%d" % r.taken if r.taken > 0 else "Blocked")
	else:
		game.stats.taken += r.taken
		game.stats.absorbed += r.absorbed
		game.ui.float_text("p", "-%d HP" % r.taken if r.taken > 0 else "Blocked")
	if side == "p" and r.taken > 0:
		game.history.add("hp_lost", {"who": "p", "amount": r.taken, "kind": kind})
	game.emit("damage", "after_damage", {"from": game.side_of(source), "to": side,
			"taken": r.taken, "absorbed": r.absorbed, "kind": kind},
			{"source": source, "target": target})
	return r


## Lose HP that ignores shield (it is not an attack, no modifiers).
static func lose_hp(game, target, amount: int, silent: bool = false) -> void:
	target.lose_hp(amount)
	if silent or game == null:
		return
	var side: String = game.side_of(target)
	if side == "p":
		game.stats.selfdmg += amount
	game.history.add("hp_lost", {"who": side, "amount": amount, "kind": "self"})
	game.ui.float_text(side, "-%d HP" % amount)


## Call once when an attack is over: Fury / Impair tick down, Boost is used up (statuses do this in
## their after_attack hook). Not an attack of its own, so nothing is dealt.
static func finish_attack(game, source, silent: bool = false) -> void:
	if silent or game == null:
		source.finish_attack()
		return
	game.emit("attack_finished", "after_attack", {"who": game.side_of(source)}, {"source": source})
