extends RefCounted
## AbstractModel: the one base class for everything that can react to combat.
## Relics, statuses and dominoes all extend it. game.gd keeps ONE list of live models
## (Game.active_models) and calls a hook on each of them when something happens, without caring
## whether the effect comes from a relic, a status or a domino.
##
## Event hooks: Game.dispatch(hook, ctx) calls them. Override only what you need.
## Math hooks:  DamageCmd.calculate runs them in three passes (additive, multiplicative, cap).
##
## `game` is null when a model is asked to take part in a simulation (damage previews). A hook that
## changes game state must do nothing in that case (statuses only touch their own value).
##
## ctx always holds what happened. For damage: source and target (Combatants).

var id := ""
## Lower runs first. Equal priority keeps the order models were listed in (see in_order).
var priority := 0
## The Combatant this model sits on (statuses), or null (relics, dominoes). Held weakly so a
## Combatant and its statuses do not keep each other alive.
var _owner_ref: WeakRef = null
var owner:
	get:
		return _owner_ref.get_ref() if _owner_ref != null else null
	set(value):
		_owner_ref = weakref(value) if value != null else null

const HOOKS := ["on_battle_start", "on_turn_start", "on_turn_end", "on_domino_played", "on_victory",
		"after_attack", "after_card_drawn", "after_damage"]


# ---- event hooks (all empty; override what you need) -----------------------

func on_battle_start(_game, _ctx: Dictionary) -> void:
	pass


func on_turn_start(_game, _ctx: Dictionary) -> void:
	pass


## You pressed End turn (before the enemy acts). ctx: hand_empty.
func on_turn_end(_game, _ctx: Dictionary) -> void:
	pass


## A domino was played, before its effects. ctx: a, b, cost, attack, domino.
func on_domino_played(_game, _ctx: Dictionary) -> void:
	pass


## You won the battle (before the rewards).
func on_victory(_game, _ctx: Dictionary) -> void:
	pass


## A combatant finished an attack (a domino with an attack in it, or an enemy attack). ctx: source.
func after_attack(_game, _ctx: Dictionary) -> void:
	pass


## ctx: card (the Domino that was drawn).
func after_card_drawn(_game, _ctx: Dictionary) -> void:
	pass


## Damage was dealt. ctx: source, target, taken (HP lost), absorbed (soaked by shield), kind.
func after_damage(_game, _ctx: Dictionary) -> void:
	pass


# ---- damage math hooks (ordered passes, see DamageCmd.calculate) -----------

## Pass 1. Return how much to ADD (can be negative). Deltas are summed, so order never matters.
func modify_damage_additive(_base: int, _ctx: Dictionary) -> int:
	return 0


## Pass 2. Return a factor (1.0 = no change). Factors are multiplied, so order never matters.
func modify_damage_multiplicative(_n: int, _ctx: Dictionary) -> float:
	return 1.0


## Pass 3. Return the new value (clamp it, or replace it). This is the only pass where order
## matters, so it runs by priority.
func modify_damage_cap(n: int, _ctx: Dictionary) -> int:
	return n


## Models sorted by priority, then by their place in the list. (Godot's sort is not stable, so the
## place in the list is part of the key.)
static func in_order(models: Array) -> Array:
	var keyed := []
	for i in models.size():
		keyed.append([models[i].priority, i, models[i]])
	keyed.sort_custom(func(p, q): return p[0] < q[0] or (p[0] == q[0] and p[1] < q[1]))
	var out := []
	for k in keyed:
		out.append(k[2])
	return out
