extends SceneTree
## Tests for the combat architecture: one model list with ordered hooks, phased damage math, the
## combat history, commands as the only way to change HP / shield / statuses. Run:
##   godot --headless -s tests/test_architecture.gd

const Game = preload("res://scripts/game.gd")
const Foe = preload("res://scripts/foe.gd")
const Model = preload("res://scripts/model.gd")
const CombatLog = preload("res://scripts/combat_log.gd")
const DamageCmd = preload("res://scripts/cmd/damage_cmd.gd")
const PowerCmd = preload("res://scripts/cmd/power_cmd.gd")
const CreatureCmd = preload("res://scripts/cmd/creature_cmd.gd")

var fails := 0
var checks := 0


## A stand-in model: records the hooks it gets, and can add / multiply / cap / replace damage.
class Probe extends "res://scripts/model.gd":
	var tag := ""
	var seen: Array = []
	var log_to: Array = []
	var add := 0
	var factor := 1.0
	var cap_mode := ""      # "max" (clamp to val) or "set" (replace with val)
	var val := 0

	func _init(t: String = "", prio: int = 0) -> void:
		tag = t
		priority = prio

	func on_turn_start(_game, _ctx: Dictionary) -> void:
		log_to.append(tag)

	func after_damage(_game, ctx: Dictionary) -> void:
		seen.append(ctx)

	func modify_damage_additive(_base: int, _ctx: Dictionary) -> int:
		return add

	func modify_damage_multiplicative(_n: int, _ctx: Dictionary) -> float:
		return factor

	func modify_damage_cap(n: int, _ctx: Dictionary) -> int:
		match cap_mode:
			"max":
				return mini(n, val)
			"set":
				return val
		return n


func expect(cond: bool, label: String) -> void:
	checks += 1
	if cond:
		print("PASS  ", label)
	else:
		fails += 1
		print("FAIL  ", label)


func fresh() -> Game:
	var g := Game.new()
	g.pl.hp = 30
	g.foe = Foe.new(1)
	g.foe.hp = 200
	g.foe.max_hp = 200
	g.foe.intent = []
	g.hand = []
	g.relics.clear()
	g.history.clear()
	return g


func _initialize() -> void:
	test_hook_order()
	test_damage_phases()
	test_history()
	test_commands()
	test_no_direct_mutation()
	print("CHECKS: ", checks, "  FAILURES: ", fails)
	quit(fails)


func test_hook_order() -> void:
	var g := fresh()
	var order := []
	var a := Probe.new("A", 0)
	var b := Probe.new("B", -1)
	var c := Probe.new("C", 0)
	for p in [a, b, c]:
		p.log_to = order
	g.relics.append_array([a, b, c])
	g.dispatch("on_turn_start")
	expect(order == ["B", "A", "C"], "hooks run by priority, then list order")
	order.clear()
	g.relics.clear()
	g.relics.append_array([c, a, b])
	g.dispatch("on_turn_start")
	expect(order == ["B", "C", "A"], "same priority keeps the list order; priority still wins")
	# one list for every kind of model: a relic, a status and a hand domino all get listed
	g = fresh()
	g.relics.append(Probe.new("relic"))
	PowerCmd.apply(g, g.pl, "power", 1)
	g.hand = [g.make_domino(0, 1, 2)]
	var kinds := g.active_models().size()
	expect(kinds == 3, "active_models lists relics, statuses and hand dominoes together (%d)" % kinds)


func test_damage_phases() -> void:
	var plus := Probe.new("+6"); plus.add = 6
	var times := Probe.new("x1.5"); times.factor = 1.5
	var cap := Probe.new("cap12"); cap.cap_mode = "max"; cap.val = 12
	var all := [plus, times, cap]
	expect(DamageCmd.calculate(all, 4, {}) == 12, "additive, then multiplicative, then cap: (4 + 6) x 1.5 = 15 -> 12")
	var shuffled := [cap, times, plus]
	expect(DamageCmd.calculate(shuffled, 4, {}) == 12, "list order does not change additive / multiplicative results")
	var minus := Probe.new("-20"); minus.add = -20
	expect(DamageCmd.calculate([minus, times], 4, {}) == 0, "damage is never below 0 (clamped before multiplying)")
	var low := Probe.new("max3", 0); low.cap_mode = "max"; low.val = 3
	var over := Probe.new("set5", 1); over.cap_mode = "set"; over.val = 5
	expect(DamageCmd.calculate([over, low], 9, {}) == 5, "cap pass runs by priority: max 3, then override to 5")
	low.priority = 1
	over.priority = 0
	expect(DamageCmd.calculate([low, over], 9, {}) == 3, "change the priorities and the cap result changes")


func test_history() -> void:
	var h := CombatLog.new()
	h.add("domino_played", {"attack": true, "cost": 3})
	h.add("domino_played", {"attack": false, "cost": 4})
	h.next_turn()
	h.add("domino_played", {"attack": true, "cost": 5})
	h.add("hp_lost", {"who": "p", "amount": 6})
	expect(h.count("domino_played") == 3, "history: count by type")
	expect(h.count("domino_played", {"attack": true}) == 2, "history: count with a filter")
	expect(h.count("domino_played", {"turn": h.prev()}) == 2, "history: the turn before this one")
	expect(h.has("hp_lost", {"who": "p"}) and not h.has("hp_lost", {"who": "c"}), "history: has")
	expect(h.sum("domino_played", "cost") == 12, "history: sum a field")
	expect(h.last("domino_played").cost == 5 and h.last("nothing").is_empty(), "history: last event, or {} when none")
	var g := fresh()
	g.hand = [g.make_domino(0, 2, 3), g.make_domino(0, 1, 1)]
	g.draw(0)
	g.stack = [g.make_domino(1, 1, 2), g.make_domino(1, 3, 3)]
	g.draw(2)
	expect(g.history.count("card_drawn") == 2, "drawing cards writes card_drawn events")
	g.discard_hand_card(0)
	expect(g.history.count("card_discarded") == 1, "discarding writes a card_discarded event")
	g.start_battle()
	expect(g.history.count("battle_started") == 1 and g.history.turn == 1, "a new battle starts a fresh history")


func test_commands() -> void:
	var g := fresh()
	var probe := Probe.new("listener")
	g.relics.append(probe)
	var r := DamageCmd.attack(g, g.pl, g.foe, 5)
	expect(r.taken == 5 and g.foe.hp == 195, "DamageCmd.attack hurts the target")
	expect(g.history.count("damage", {"from": "p", "to": "c", "taken": 5}) == 1, "the hit is in the history")
	expect(probe.seen.size() == 1 and probe.seen[0].taken == 5 and probe.seen[0].target == g.foe,
			"a listening model gets after_damage with source and target")
	PowerCmd.apply(g, g.pl, "fury", 3)
	PowerCmd.apply(g, g.foe, "fury", 2)
	expect(DamageCmd.attack_value(g, g.pl, g.foe, 5) == 8, "your Fury counts for your attacks (5 + 3)")
	expect(DamageCmd.attack_value(g, g.foe, g.pl, 5) == 7, "the enemy's Fury counts for its attacks, yours does not (5 + 2)")
	DamageCmd.finish_attack(g, g.pl)
	expect(g.pl.value("fury") == 2 and g.foe.value("fury") == 2, "after_attack ticks the attacker's Fury only")
	g.pl.shield = 3
	g.history.clear()
	DamageCmd.attack(g, g.foe, g.pl, 7)       # enemy Fury 2 -> 9, shield soaks 3
	expect(g.pl.hp == 24 and g.pl.shield == 0, "shield soaks first (9 damage: 3 soaked, 6 taken)")
	expect(g.history.sum("hp_lost", "amount", {"who": "p"}) == 6, "HP you lose is a history query")
	g.history.clear()
	var sim := {"pl": g.pl.snapshot(), "foe": g.foe.snapshot()}
	DamageCmd.attack(g, sim.pl, sim.foe, 5, true)
	PowerCmd.apply(null, sim.pl, "power", 4, true)
	expect(g.history.events.is_empty() and g.foe.hp == 195 and g.pl.value("power") == 0,
			"silent commands change only the copies and write nothing")
	expect(sim.foe.hp == 195 - 7 and sim.pl.value("power") == 4, "the copies did change (5 + 2 Fury = 7)")
	g.history.clear()
	g.history.next_turn()
	g.history.add("domino_played", {"attack": false})
	g.history.next_turn()
	g.history.add("turn_ended", {"hand_empty": true})
	CreatureCmd.gain_shield(g, g.pl, 4)
	expect(g.pl.shield == 4 and g.stats.shield == 4, "CreatureCmd.gain_shield changes the shield and the stats")


## A cheap lint: effects, relics and conditions must change HP, shield and statuses through the
## commands in scripts/cmd/, not by writing to a Combatant.
func test_no_direct_mutation() -> void:
	var files := []
	for dir in ["res://scripts/effects/", "res://scripts/conditions/"]:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd"):
				files.append(dir + f)
	files.append("res://scripts/relics/relic.gd")
	var write := RegEx.new()
	write.compile("\\.(hp|shield|max_shield|max_hp|lives)\\s*[-+*]?=([^=]|$)")
	var call_ := RegEx.new()
	call_.compile("(?<!Cmd)(?<!history)\\.(add|lose_hp|take_damage|heal|finish_attack)\\(")
	var bat := RegEx.new()
	bat.compile("\\.bat\\.(?!extra_draw)")
	var bad := []
	for path in files:
		var n := 0
		for line in FileAccess.get_file_as_string(path).split("\n"):
			n += 1
			var code := line.split("##")[0]
			if write.search(code) or call_.search(code) or bat.search(code):
				bad.append("%s:%d" % [path, n])
	expect(bad.is_empty(), "effects, conditions and relics use commands, not direct writes %s" % str(bad))
