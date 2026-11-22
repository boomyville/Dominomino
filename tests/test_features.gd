extends SceneTree
## Headless tests for the newer features: relics, pip-counting and life-cost dominoes, the damage
## previews and the icon lookup. Run from the project folder:
##   godot --headless -s tests/test_features.gd
## Exits with the number of failures. (tests/test_rules.gd covers the base rules.)

const Game = preload("res://scripts/game.gd")
const Dominoes = preload("res://scripts/dominoes.gd")
const Domino = preload("res://scripts/domino.gd")
const Foe = preload("res://scripts/foe.gd")
const Relics = preload("res://scripts/relics/relics.gd")
const Icons = preload("res://scripts/icons.gd")
const Elements = preload("res://scripts/elements.gd")
const DominoText = preload("res://scripts/domino_text.gd")

var fails := 0
var checks := 0
var cat: Array = Dominoes.build()


func expect(cond: bool, label: String) -> void:
	checks += 1
	if cond:
		print("PASS  ", label)
	else:
		fails += 1
		print("FAIL  ", label)


func ti(name: String) -> int:
	for i in cat.size():
		if cat[i].title == name:
			return i
	return -1


func dom(name: String, a: int, b: int):
	return Domino.new(cat[ti(name)], a, b)


## A game set up for testing one thing: 200 HP enemy that plans nothing, a known hand and stack.
func fresh(relic_id: String = "") -> Game:
	var g := Game.new()
	g.foe = Foe.new(1)
	g.foe.hp = 200
	g.foe.max_hp = 200
	g.foe.intent = []
	g.hand = []
	g.stack = []
	for i in 12:
		g.stack.append(dom("Slash", 1, 2))
	g.discard = []
	if relic_id != "":
		g.add_relic(Relics.by_id(relic_id))
	return g


func find_spot(g: Game, a: int, b: int):
	for r in 4:
		var dm := Game.dims(r)
		for x in range(0, Game.N - int(dm.x) + 1):
			for y in range(0, Game.N - int(dm.y) + 1):
				if g.check({"x": x, "y": y, "rot": r, "a": a, "b": b}).ok:
					return {"x": x, "y": y, "rot": r}
	return null


## Put d at the front of the hand and play it on the first legal spot. Returns the energy it cost.
## energy_left_after >= 0 sets your energy so that exactly that much is left after paying;
## otherwise your energy is left as it is.
func play(g: Game, d, energy_left_after := -1) -> int:
	g.hand.push_front(d)
	var keep: int = g.energy
	g.energy = 99
	var sp = find_spot(g, d.a, d.b)
	var cost: int = g.check({"x": sp.x, "y": sp.y, "rot": sp.rot, "a": d.a, "b": d.b}).cost
	g.energy = cost + energy_left_after if energy_left_after >= 0 else keep
	await g.play_domino({"x": sp.x, "y": sp.y, "rot": sp.rot, "a": d.a, "b": d.b, "i": 0})
	return cost


## End the current turn without an enemy action (counts as having played, so no life is lost).
func next_turn(g: Game) -> void:
	g.played_this_turn = true
	g.foe.intent = []
	await g.end_turn()


func _initialize() -> void:
	randomize()
	await _tests()
	print("CHECKS: ", checks, "  FAILURES: ", fails)
	quit(fails)


func _tests() -> void:
	# ---------- catalogue ----------
	var all := Relics.build()
	var rc := {"c": 0, "u": 0, "r": 0}
	var ids := {}
	for r in all:
		rc[r.rarity] += 1
		ids[r.id] = true
	expect(all.size() == 30 and ids.size() == 30, "30 relics with unique ids")
	expect(rc == {"c": 13, "u": 14, "r": 3}, "relic rarities 13 common / 14 uncommon / 3 rare %s" % rc)
	expect(Relics.by_id("gamblers_purse") != null and Relics.by_id("gamblers_purse").title == "Gambler's Purse", "ids drop apostrophes and spaces")
	var owned := ids.keys().slice(2)
	var left := Relics.roll(owned, 3)
	expect(left.size() == 2 and not owned.has(left[0].id) and not owned.has(left[1].id), "an offer never includes relics you own (and shrinks when few are left)")
	var distinct := true
	for i in 100:
		var offer := Relics.roll([], 3)
		if offer.size() != 3 or offer[0].id == offer[1].id or offer[1].id == offer[2].id or offer[0].id == offer[2].id:
			distinct = false
	expect(distinct, "an offer is 3 different relics")

	# ---------- new dominoes: counting pips ----------
	var g := fresh()
	expect(cat[ti("Inferno")].effects[0].icon() == "fire" and cat[ti("Eclipse")].effects[0].icon() == "darkness", "pip dominoes use their element icon")
	for c in [[1, 0], [2, 0], [3, 1], [4, 0], [5, 0], [6, 2]]:
		g.occ[Vector2(c[0] * 2, c[1] * 3)] = {"id": c[0], "owner": "c", "pip": c[0]}
	g.occ[Vector2(0, 10)] = {"id": 9, "owner": "p", "pip": 4}
	g.occ[Vector2(1, 10)] = {"id": 9, "owner": "p", "pip": 4}
	expect(g.count_pips(4, "board") == 3 and g.count_pips(1, "board") == 1, "count_pips counts every pip on the board, yours and the enemy's")
	await g.run_fx(dom("Inferno", 0, 0))
	expect(200 - g.foe.hp == 9, "Inferno: 3 damage x 3 fire pips on the board = 9")
	g = fresh()
	g.occ[Vector2(0, 0)] = {"id": 1, "owner": "c", "pip": 4}
	g.occ[Vector2(0, 2)] = {"id": 2, "owner": "c", "pip": 4}
	await g.run_fx(dom("Fireball", 0, 0))
	expect(200 - g.foe.hp == 8, "Fireball: 4 damage per fire pip")
	g.pl.add("fury", 2)
	g.pl.add("power", 1)
	await g.run_fx(dom("Fireball", 0, 0))
	expect(200 - g.foe.hp == 8 + 8 + 3, "pip damage takes Fury and Power like any attack")
	g = fresh()
	g.hand = [dom("Slash", 5, 5), dom("Slash", 5, 1), dom("Slash", 2, 2)]
	await g.run_fx(dom("Thunderclap", 5, 5))
	expect(200 - g.foe.hp == 9, "Thunderclap: 3 damage x 3 lightning pips in hand")
	g = fresh()
	g.hand = [dom("Eclipse", 6, 6), dom("Slash", 6, 0), dom("Slash", 2, 2)]
	var lines: Array = g.fx_lines(g.hand[0])
	expect(lines[0].contains("1 now") and lines[0].contains("Deal 3 damage"), "in hand, a domino does not count its own pips (%s)" % lines[0])
	expect(g.caps(0)[0].k == "darkness" and g.caps(0)[0].num == "3", "caption: element icon and the damage if played now")
	g.hand = [dom("Inferno", 4, 4)]
	g.occ[Vector2(0, 0)] = {"id": 1, "owner": "c", "pip": 4}
	expect(g.caps(0)[0].num == "9", "on the board a domino counts its own pips (3 x (1 + 2) = 9)")
	g = fresh()
	g.foe.hp = 200
	await play(g, dom("Inferno", 4, 4))
	expect(200 - g.foe.hp == 6 and g.placed.size() == 1, "playing Inferno 4|4 on an empty board hits for its own two fire pips (6)")

	# ---------- new dominoes: pay a life ----------
	g = fresh()
	g.hand = [dom("Blood Pact", 3, 3)]
	expect(g.cond_ok(0) and g.fx_lines(g.hand[0])[0] == "Lose 1 life", "Blood Pact is playable with 3 lives and says what it costs")
	await g.run_fx(dom("Blood Pact", 3, 3))
	expect(g.lives == 2 and g.ui.flashes == 1 and 200 - g.foe.hp == 21, "paying a life: lives 3 -> 2, damage 2.4 x 6 + 7 = 21")
	g.lives = 1
	expect(not g.cond_ok(0) and not g.can_play(0), "cannot be played with only 1 life")
	expect(g.check_p({"x": 12, "y": 8, "rot": 0, "a": 3, "b": 3, "i": 0}).why == "Needs: you have more than 1 life", "the message says why")
	expect(g.caps(0)[0].k == "x", "the caption shows the red X")
	for n in ["Soul Tithe", "Hex of Ruin", "Crimson Ritual", "Sacrificial Blade"]:
		g = fresh()
		g.hand = [dom(n, 3, 3)]
		expect(g.cond_ok(0), "%s playable with 3 lives" % n)
		g.lives = 1
		expect(not g.cond_ok(0), "%s blocked with 1 life" % n)
	g = fresh()
	g.stack = [dom("Slash", 1, 1), dom("Slash", 1, 1), dom("Slash", 1, 1), dom("Slash", 1, 1), dom("Slash", 1, 1)]
	await g.run_fx(dom("Soul Tithe", 4, 4))
	expect(g.lives == 2 and g.hand.size() == 5, "Soul Tithe: lose a life, draw 5 (0.25 x 8 + 3)")
	g = fresh()
	await g.run_fx(dom("Hex of Ruin", 5, 5))
	expect(g.lives == 2 and g.foe.value("fury") == -(12 + 4), "Hex of Ruin: Impair 1.2 x 10 + 4")
	g = fresh()
	await g.run_fx(dom("Crimson Ritual", 5, 5))
	expect(g.lives == 2 and g.pl.value("fury") == 17 and g.pl.value("power") == 4, "Crimson Ritual: Fury and Power")
	g = fresh()
	await g.run_fx(dom("Sacrificial Blade", 5, 5))
	expect(g.lives == 2 and 200 - g.foe.hp == 3 * 15, "Sacrificial Blade: 3 hits of 15")

	# ---------- the damage preview on the enemy ----------
	g = fresh()
	g.hand = [dom("Slash", 3, 4), dom("Iron Guard", 3, 3), dom("Second Skin", 3, 3), dom("Berserker", 2, 2), dom("Twin Fang", 4, 4)]
	var pv: Dictionary = g.preview_player_attack(0)
	expect(pv.attack and pv.hp == 9 and pv.absorbed == 0, "Slash 3|4 would take 9 HP")
	g.pl.add("fury", 2)
	expect(g.preview_player_attack(0).hp == 11, "the preview includes your Fury")
	g.foe.shield = 5
	pv = g.preview_player_attack(0)
	expect(pv.hp == 6 and pv.absorbed == 5, "enemy shield soaks first: 11 - 5 = 6 HP, 5 absorbed")
	g.foe.shield = 50
	pv = g.preview_player_attack(0)
	expect(pv.attack and pv.hp == 0 and pv.absorbed == 11, "a fully absorbed attack takes no HP")
	expect(not g.preview_player_attack(1).attack, "a shield domino has no attack preview")
	g.pl.shield = 5
	expect(not g.preview_player_attack(2).attack, "a domino whose condition is not met shows no preview")
	expect(g.foe.hp == 200 and g.foe.shield == 50 and g.pl.value("fury") == 2, "previewing changes nothing")
	g.foe.shield = 0
	expect(g.preview_player_attack(3).hp == 5 + (2 + 5), "Berserker 2|2: it gives 5 Fury first, then hits for 5 plus the Fury it now has (12)")
	expect(g.preview_player_attack(4).hp == 2 * (5 + 2), "multi-hit: every hit counts (Twin Fang 4|4 = 2 hits of 5, plus Fury 2 each)")
	# the preview must equal what really happens, for every attack domino at several pip totals
	var mismatch := 0
	var tested := 0
	for t in cat.size():
		if not cat[t].has_attack():
			continue
		for pips in [[0, 0], [1, 2], [3, 3], [6, 5], [6, 6]]:
			var d := Domino.new(cat[t], pips[0], pips[1])
			var a := fresh()
			a.pl.add("fury", 2)
			a.pl.add("power", 1)
			a.pl.add("boost", 3)
			a.foe.shield = 4
			a.hand = [d, dom("Slash", 5, 5), dom("Slash", 4, 1)]
			a.occ[Vector2(0, 0)] = {"id": 1, "owner": "c", "pip": 4}
			a.occ[Vector2(0, 2)] = {"id": 2, "owner": "c", "pip": 5}
			var sim := {"pl": a.pl.snapshot(), "foe": a.foe.snapshot()}
			for e in d.data.effects:
				e.preview(a, d, d.total(), sim)
			var predicted: int = a.foe.hp - sim.foe.hp
			# now really play it: it leaves the hand and lands on the board
			a.hand.remove_at(0)
			a.occ[Vector2(8, 8)] = {"id": 7, "owner": "p", "pip": d.a}
			a.occ[Vector2(9, 8)] = {"id": 7, "owner": "p", "pip": d.b}
			var before: int = a.foe.hp
			await a.run_fx(d)
			tested += 1
			if before - a.foe.hp != predicted:
				mismatch += 1
				print("   preview mismatch: ", d.data.title, " ", pips, " predicted ", predicted, " got ", before - a.foe.hp)
	expect(mismatch == 0 and tested > 100, "the preview equals the real damage for every attack domino (%d checked, %d off)" % [tested, mismatch])

	# ---------- the preview of the enemy's attacks ----------
	g = fresh()
	g.foe.intent = [{"k": "atk", "v": 8}, {"k": "atk", "v": 6}, {"k": "blk", "v": 4}]
	g.pl.shield = 5
	var plan: Dictionary = g.preview_intents()
	expect(plan.entries[0].text == "Attack 8: -3 HP" and plan.entries[1].text == "Attack 6: -6 HP", "the shield soaks the first attack, then the second one (%s)" % [plan.entries])
	expect(plan.loss == 9 and plan.attacks == 2 and plan.absorbed == 5, "total loss 9 HP")
	expect(plan.entries[2].text == "Block 4", "other intents keep their text")
	g.pl.shield = 30
	plan = g.preview_intents()
	expect(plan.loss == 0 and plan.entries[0].text == "Attack 8: blocked" and plan.entries[1].text == "Attack 6: blocked", "an attack the shield stops shows blocked")
	g.pl.shield = 0
	g.foe.intent = [{"k": "lifeatk", "v": 7}]
	expect(g.preview_intents().entries[0].text == "Attack 7: -7 HP and a life", "a life attack that gets through says so")
	g.foe.intent = [{"k": "atk", "v": 4}]
	g.foe.add("fury", -9)
	expect(g.preview_intents().entries[0].text == "Attack 0: no damage", "an Impaired attack shows no damage")
	g.foe.fury_text()
	g = Game.new()
	g.foe.intent = [{"k": "atk", "v": 4}, {"k": "atk", "v": 4}]
	g.foe.add("fury", -2)
	g.pl.shield = 1
	plan = g.preview_intents()
	var hp0: int = g.pl.hp
	g.played_this_turn = true
	g.hand.resize(3)
	await g.end_turn()
	expect(plan.loss == hp0 - g.pl.hp and plan.entries[1].text == "Attack 3: -3 HP", "the preview equals what the enemy really does (Impair ticking, shield soaking: %d HP)" % plan.loss)

	# ---------- relics: energy ----------
	g = fresh("overcharged_core")
	await next_turn(g)
	expect(g.energy == 11, "Overcharged Core: 11 energy next turn")
	g = fresh("deep_well")
	expect(g.energy_cap() == 12, "Deep Well: energy cap 12")
	await next_turn(g)
	expect(g.energy == 12, "Deep Well: start the next turn with 12")
	g = fresh()
	g.add_relic(Relics.by_id("starter_spark"))
	g.start_battle()
	expect(g.energy == 13, "Starter Spark: 3 extra energy on turn 1")
	await next_turn(g)
	expect(g.energy == 10, "Starter Spark: only on turn 1")
	g = fresh("reserve_tank")
	g.hand = [dom("Slash", 1, 1)]
	await play(g, dom("Slash", 1, 1), 0)
	expect(g.energy == 2, "Reserve Tank: spending all your energy gives 2 back")
	var e1: int = g.energy
	await play(g, dom("Slash", 1, 1), 0)
	expect(g.energy == 0 and e1 == 2, "Reserve Tank: only once per turn")
	await next_turn(g)
	await play(g, dom("Slash", 1, 1), 0)
	expect(g.energy == 2, "Reserve Tank: works again next turn")
	g = fresh("reserve_tank")
	await play(g, dom("Slash", 1, 1))
	expect(g.energy == 10 - 2, "Reserve Tank: nothing when energy is left over")
	g = fresh("quiet_mind")
	await next_turn(g)
	expect(g.energy == 12, "Quiet Mind: no attacks last turn gives 2 energy")
	g = fresh("quiet_mind")
	await play(g, dom("Slash", 1, 1))
	await next_turn(g)
	expect(g.energy == 10, "Quiet Mind: nothing after an attack")
	g = fresh("quiet_mind")
	expect(g.energy == 10, "Quiet Mind: nothing on the very first turn")
	g = fresh("open_palm")
	g.hand = []
	await next_turn(g)
	expect(g.energy == 13, "Open Palm: ended the turn with an empty hand gives 3 energy")
	g = fresh("open_palm")
	g.hand = [dom("Slash", 1, 1)]
	await next_turn(g)
	expect(g.energy == 10, "Open Palm: nothing with dominoes in hand")

	# ---------- relics: shield ----------
	g = fresh("banked_charge")
	g.foe.intent = [{"k": "atk", "v": 8}]
	g.played_this_turn = true
	g.energy = 4
	await g.end_turn()
	expect(g.pl.hp == 50 and g.pl.shield == 2, "Banked Charge: 4 energy left gives 10 shield (an 8 attack is blocked)")
	g = fresh("banked_charge")
	g.foe.intent = [{"k": "atk", "v": 8}]
	g.played_this_turn = true
	g.energy = 3
	await g.end_turn()
	expect(g.pl.hp == 42, "Banked Charge: nothing with 3 energy left")
	g = fresh()
	g.add_relic(Relics.by_id("iron_cloak"))
	g.start_battle()
	expect(g.pl.shield == 6, "Iron Cloak: 6 shield at the start of a battle")
	g = fresh("safety_net")
	g.foe.intent = [{"k": "atk", "v": 4}]
	g.played_this_turn = true
	await g.end_turn()
	expect(g.pl.hp == 50, "Safety Net: no shield at end of turn gives 4 shield")
	g = fresh("safety_net")
	g.foe.intent = [{"k": "atk", "v": 4}]
	g.played_this_turn = true
	g.pl.shield = 1
	await g.end_turn()
	expect(g.pl.hp == 47, "Safety Net: nothing when you still have shield")
	g = fresh("brimming_cup")
	g.hand = [dom("Slash", 1, 1)]
	g.pl.shield = g.pl.max_shield
	await next_turn(g)
	expect(g.hand.size() == 1 + 4 + 1, "Brimming Cup: shield == max shield draws an extra domino")
	g = fresh("brimming_cup")
	g.hand = [dom("Slash", 1, 1)]
	g.pl.shield = 3
	await next_turn(g)
	expect(g.hand.size() == 5, "Brimming Cup: nothing otherwise")
	g = fresh()
	g.add_relic(Relics.by_id("bulwark_seed"))
	g.start_battle()
	expect(g.pl.max_shield == 17, "Bulwark Seed: +8 max shield at the start of a battle")
	g = fresh("seedling_plate")
	await next_turn(g)
	expect(g.pl.max_shield == 10, "Seedling Plate: +1 max shield when you have no shield")
	g = fresh("seedling_plate")
	g.pl.shield = 2
	await next_turn(g)
	expect(g.pl.max_shield == 9, "Seedling Plate: nothing with shield")
	g = fresh("overflow_valve")
	g.hand = [dom("Slash", 1, 1)]
	g.pl.shield = 12
	await next_turn(g)
	expect(g.hand.size() == 6 and g.pl.shield == 9, "Overflow Valve: excess shield draws an extra domino (and is still cut to max)")
	g = fresh("overflow_valve")
	g.hand = [dom("Slash", 1, 1)]
	g.pl.shield = 9
	await next_turn(g)
	expect(g.hand.size() == 5, "Overflow Valve: shield equal to max is not excess")

	# ---------- relics: start of battle ----------
	var battle_cases := [
		["ember_heart", "fury", 3], ["war_drum", "power", 1], ["whetstone", "boost", 2],
	]
	for c in battle_cases:
		g = fresh()
		g.add_relic(Relics.by_id(c[0]))
		g.start_battle()
		expect(g.pl.value(c[1]) == c[2], "%s: %d %s at the start of a battle" % [c[0], c[2], c[1]])
	g = fresh()
	g.add_relic(Relics.by_id("venom_fang"))
	g.start_battle()
	expect(g.foe.value("fury") == -3 and g.foe.status_lines()[0] == "Impair 3", "Venom Fang: 3 Impair on the enemy")
	g = fresh()
	g.add_relic(Relics.by_id("heartwood"))
	g.start_battle()
	expect(g.pl.max_hp == 55 and g.pl.hp == 55, "Heartwood: +5 max HP")
	g = fresh()
	g.lives = 2
	g.add_relic(Relics.by_id("phoenix_feather"))
	g.start_battle()
	expect(g.lives == 3, "Phoenix Feather: a life back when you have lost one")
	g.start_battle()
	expect(g.lives == 3, "Phoenix Feather: nothing at full lives")
	g = fresh("gamblers_purse")
	expect(g._begin_reward().size() == 4, "Gambler's Purse: 4 dominoes on the reward screen")
	expect(fresh()._begin_reward().size() == 3, "3 dominoes without it")

	# ---------- relics: when you play a domino ----------
	g = fresh("tile_armor")
	await play(g, dom("Slash", 1, 1))
	expect(g.pl.shield == 1, "Tile Armor: 1 shield for every domino")
	g = fresh("pebble_sling")
	await play(g, dom("Iron Guard", 2, 5))
	expect(g.foe.hp == 199, "Pebble Sling: a 2 pip deals 1 damage")
	g = fresh("pebble_sling")
	await play(g, dom("Iron Guard", 3, 5))
	expect(g.foe.hp == 200, "Pebble Sling: nothing without a 2 pip")
	g = fresh("frost_shard")
	await play(g, dom("Slash", 3, 1))
	expect(g.pl.shield == 1, "Frost Shard: a 3 pip gives 1 shield")
	g = fresh("kindling")
	var cost := await play(g, dom("Iron Guard", 4, 0))
	expect(g.energy == 10 - cost + 1, "Kindling: a 4 pip gives 1 energy back")
	g = fresh("storm_charm")
	await play(g, dom("Iron Guard", 5, 0))
	expect(g.pl.value("fury") == 1, "Storm Charm: a 5 pip gives 1 Fury")
	g = fresh("midnight_vial")
	g.pl.hp = 30
	await play(g, dom("Iron Guard", 6, 0))
	expect(g.pl.hp == 31, "Midnight Vial: a 6 pip heals 1")
	g = fresh("midnight_vial")
	g.pl.hp = 30
	await play(g, dom("Iron Guard", 6, 6), 0)
	expect(g.pl.hp == 31, "Midnight Vial: 6|6 still heals only 1")
	g = fresh("hollow_bone")
	await play(g, dom("Iron Guard", 0, 3))
	expect(g.pl.shield == 6 + 2, "Hollow Bone: a blank half gives 2 shield")
	g = fresh("dawn_lantern")
	g.discard = [dom("Slash", 2, 2), dom("Slash", 2, 2)]
	var stack0: int = g.stack.size()
	await play(g, dom("Iron Guard", 1, 3))
	expect(g.discard.size() == 1 and g.stack.size() == stack0 + 1, "Dawn Lantern: a 1 pip shuffles a discarded domino into the stack")
	g = fresh("dawn_lantern")
	await play(g, dom("Iron Guard", 1, 3))
	expect(g.stack.size() == 12, "Dawn Lantern: nothing happens with an empty discard pile")
	g = fresh("double_vision")
	await play(g, dom("Iron Guard", 2, 2))
	expect(g.hand.size() == 1, "Double Vision: a double draws a domino")
	g = fresh("double_vision")
	await play(g, dom("Iron Guard", 2, 3))
	expect(g.hand.size() == 0, "Double Vision: not for other dominoes")
	g = fresh("tile_armor")
	g.foe.hp = 1
	g.ui.picks = [-1, -1]
	g.relics.clear()
	g.add_relic(Relics.by_id("pebble_sling"))
	g.foe.hp = 1
	await play(g, dom("Iron Guard", 2, 5))
	expect(g.battle_no == 2, "a relic that finishes the enemy wins the battle")

	# ---------- relics: end of turn ----------
	g = fresh("bandage_roll")
	g.pl.hp = 20
	await next_turn(g)
	expect(g.pl.hp == 24, "Bandage Roll: half HP or less heals 4")
	g = fresh("bandage_roll")
	g.pl.hp = 40
	await next_turn(g)
	expect(g.pl.hp == 40, "Bandage Roll: nothing above half HP")

	# ---------- relics: getting them ----------
	g = Game.new()
	g.foe.hp = 1
	g.hand = [dom("Slash", 6, 6)]
	g.energy = 12
	g.ui.picks = [0, 1]
	await play(g, dom("Slash", 6, 6), 0)
	expect(g.relics.size() == 1 and g.ui.log.has("pick: Choose a relic") and g.relic_offer.is_empty(), "a relic is offered after battle 1 and the choice is kept")
	expect(g.relics[0].id != "" and g.battle_no == 2, "the next battle starts")
	var first_id: String = g.relics[0].id
	g.foe.hp = 1
	g.ui.picks = [-1]
	g.ui.log.clear()
	await play(g, dom("Slash", 6, 6), 0)
	expect(g.battle_no == 3 and not g.ui.log.has("pick: Choose a relic"), "no relic after battle 2")
	g.foe.hp = 1
	g.ui.picks = [-1, 0]
	await play(g, dom("Slash", 6, 6), 0)
	expect(g.battle_no == 4 and g.relics.size() == 2 and g.relics[1].id != first_id, "a relic after battle 3 (a different one)")
	g.new_game()
	expect(g.relics.is_empty(), "a new game starts without relics")
	g = Game.new()
	g.foe.hp = 1
	g.ui.picks = [-1, -1]
	await play(g, dom("Slash", 6, 6), 0)
	expect(g.relics.is_empty() and g.battle_no == 2, "Skip takes no relic")

	# ---------- icons ----------
	expect(Icons.name_of("dmg") == "damage" and Icons.name_of("impS") == "impair" and Icons.name_of("impE") == "impair" and Icons.name_of("fire") == "fire", "kinds map to icon names; a name stays as it is")
	expect(Icons.slug("Veteran's Edge") == "veterans_edge" and Icons.slug("Max Shield") == "max_shield", "names are lowercase with underscores")
	var missing := []
	for t in cat:
		for e in t.effects:
			if not Icons.exists(e.icon()):
				missing.append(e.icon())
	for k in ["atk", "lifeatk", "blk", "discH", "mill", "junk", "x", "fury", "impair", "power", "boost", "shield", "energy"]:
		if not Icons.exists(k):
			missing.append(k)
	for p in Elements.NAMES:
		if not Icons.exists(Elements.icon(p)):
			missing.append(Elements.icon(p))
	expect(missing.is_empty(), "every effect, intent, status and element has an icon %s" % [missing])
	expect(Icons.texture("dmg").get_width() == Icons.SIZE, "built-in icons are SIZE pixels wide")
	var dir := ProjectSettings.globalize_path(Icons.DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color.RED)
	img.save_png(dir + "heal.png")
	img.save_png(dir + "tile_armor.png")
	Icons.clear_cache()
	expect(Icons.texture("heal").get_width() == 16 and Icons.texture("heal", Color.BLUE).get_width() == 16, "img/icons/heal.png replaces the built-in icon")
	expect(Icons.relic_texture(Relics.by_id("tile_armor")).get_width() == 16 and Icons.relic_texture(Relics.by_id("war_drum")).get_width() == Icons.SIZE, "a relic's PNG is found by its name, otherwise a gem is drawn")
	DirAccess.remove_absolute(dir + "heal.png")
	DirAccess.remove_absolute(dir + "tile_armor.png")
	Icons.clear_cache()
	expect(Icons.texture("heal").get_width() == Icons.SIZE, "without the file the built-in icon comes back")
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	DominoText.append_rich(rt, "Gain 2 :fury: and :nonsense: now")
	expect(rt.get_parsed_text().contains(":nonsense:") and not rt.get_parsed_text().contains(":fury:"), ":name: becomes an icon, an unknown :word: stays text")
	rt.free()
