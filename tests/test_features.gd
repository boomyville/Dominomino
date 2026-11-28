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


func _game_with_gear() -> Game:
	Game.starter_gear = true
	var g := Game.new()
	Game.starter_gear = false
	return g


func _hand_titles(g: Game) -> Array:
	var out := []
	for d in g.hand:
		out.append("%s %d|%d" % [d.data.title, d.a, d.b])
	return out


func _stack_titles(g: Game) -> Array:
	var out := []
	for d in g.stack:
		out.append("%s %d|%d" % [d.data.title, d.a, d.b])
	return out


func DominoText_has_ephemeral(g: Game, d) -> bool:
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	g.hand = [d]
	DominoText.fill(rt, g, d, 0)
	var ok := rt.get_parsed_text().contains("Ephemeral")
	rt.free()
	return ok


## Damage a domino of this kind and these pips deals on a fresh game with nothing else going on.
func _dmg_of(_g: Game, title: String, a: int, b: int) -> int:
	var t := fresh()
	await t.run_fx(dom(title, a, b))
	return 200 - t.foe.hp


func _initialize() -> void:
	randomize()
	Game.starter_gear = false      # plain start; the starter gear is tested near the end
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
	expect(all.size() == 48 and ids.size() == 48, "48 artifacts (43 + 5 new) with unique ids")
	expect(rc == {"c": 18, "u": 22, "r": 8}, "artifact rarities 18 common / 22 uncommon / 8 rare %s" % rc)
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
	expect(200 - g.foe.hp == 12, "Fireball: 6 damage per fire pip")
	g.pl.add("fury", 2)
	g.pl.add("power", 1)
	await g.run_fx(dom("Fireball", 0, 0))
	expect(200 - g.foe.hp == 12 + 12 + 3, "pip damage takes Fury and Power like any attack")
	g = fresh()
	g.hand = [dom("Slash", 5, 5), dom("Slash", 5, 1), dom("Slash", 2, 2)]
	await g.run_fx(dom("Thunderclap", 5, 5))
	expect(200 - g.foe.hp == 12, "Thunderclap: 4 damage x 3 lightning pips in hand")
	g = fresh()
	g.hand = [dom("Eclipse", 6, 6), dom("Slash", 6, 0), dom("Slash", 2, 2)]
	var lines: Array = g.fx_lines(g.hand[0])
	expect(lines[0].contains("1 now") and lines[0].contains("Deal 4 damage"), "in hand, a domino does not count its own pips (%s)" % lines[0])
	expect(g.caps(0)[0].k == "darkness" and g.caps(0)[0].num == "4", "caption: element icon and the damage if played now")
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
	expect(g.lives == 2 and g.foe.value("fury") == -24, "Hex of Ruin: Impair 1.75 x 10 + 6")
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
	expect(g.preview_player_attack(3).hp == 4 + (2 + 4), "Berserker 2|2: it gives 4 Fury first, then hits for 4 plus the Fury it now has (10)")
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
				e.preview(a, d, e.size_for(d), sim)
			var predicted: int = a.foe.hp - sim.foe.hp
			# now really play it: it leaves the hand and lands on the board
			a.hand.remove_at(0)
			a.occ[Vector2(8, 8)] = {"id": 7, "owner": "p", "pip": d.a}
			a.occ[Vector2(9, 8)] = {"id": 7, "owner": "p", "pip": d.b}
			a.placed.append({"owner": "p", "a": d.a, "b": d.b})
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
	g = fresh("heartwood")
	g.pl.hp = 40
	g.pl = g.fresh_player()
	expect(g.pl.max_hp == 55 and g.pl.hp == 40, "Heartwood: +5 max HP, and it does not heal you")
	g.pl.hp = 55
	g.unequip_relic(g.relics[0])
	g.pl = g.fresh_player()
	expect(g.pl.max_hp == 50 and g.pl.hp == 50, "unequipped, the max HP bonus is gone (HP is cut to the new max)")
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

	# ---------- relics: slots and the inventory ----------
	g = fresh()
	var filler := ["war_drum", "iron_cloak", "tile_armor", "kindling", "frost_shard", "storm_charm", "pebble_sling", "hollow_bone"]
	for id in filler:
		expect(g.add_relic(Relics.by_id(id)), "%s goes into a free slot" % id)
	expect(g.relics.size() == 8 and g.EQUIP_SLOTS == 8, "8 equip slots")
	var extra = Relics.by_id("overcharged_core")
	expect(not g.add_relic(extra) and g.relics.size() == 8 and g.stored_relics == [extra], "the 9th artifact waits unequipped")
	await next_turn(g)
	expect(g.energy == 10, "an unequipped artifact does nothing (Overcharged Core gives no energy)")
	expect(not g.equip_relic(extra), "cannot equip with all slots full")
	g.unequip_relic(g.relics[0])
	expect(g.relics.size() == 7 and g.stored_relics.size() == 2, "unequip moves it to the inventory")
	expect(g.equip_relic(extra) and g.relics.has(extra) and g.stored_relics.size() == 1, "equip when a slot is free")
	await next_turn(g)
	expect(g.energy == 11, "once equipped it works (11 energy)")
	expect(g.relic_ids().size() == 9, "relic_ids lists equipped and unequipped")
	expect(Relics.roll(g.relic_ids(), 60).size() == 38, "an offer never repeats any relic you own, equipped or not, nor the starter Time Pendant")

	# ---------- rewards: domino, or 20% a choice of domino / artifact ----------
	expect(Game.RELIC_CHANCE == 0.2, "20% chance of the artifact choice")
	g = Game.new()
	g.relic_chance = 0.0
	g.foe.hp = 1
	g.ui.picks = [0]
	await play(g, dom("Slash", 6, 6), 0)
	expect(g.relics.is_empty() and g.stored_relics.is_empty() and g.battle_no == 2 and g.collection.size() == 21, "no artifact choice: just a domino")
	expect(g.ui.log.has("intermission") and g.reward_note.begins_with("New domino"), "the screen between battles is shown with a note")
	g = Game.new()
	g.relic_chance = 1.0
	g.foe.hp = 1
	g.ui.picks = [1]
	await play(g, dom("Slash", 6, 6), 0)
	expect(g.relics.size() == 1 and g.collection.size() == 20 and g.battle_no == 2, "choosing the artifact gives one random artifact and no domino")
	expect(g.reward_note.begins_with("New artifact:") and g.reward_note.ends_with("(equipped)"), "the note says it was equipped (%s)" % g.reward_note)
	g = Game.new()
	g.relic_chance = 1.0
	g.foe.hp = 1
	g.ui.picks = [0, 2]
	await play(g, dom("Slash", 6, 6), 0)
	expect(g.relics.is_empty() and g.collection.size() == 21, "choosing the domino then lets you pick one of the 3")
	g = Game.new()
	g.relic_chance = 1.0
	g.foe.hp = 1
	g.ui.picks = [-1]
	await play(g, dom("Slash", 6, 6), 0)
	expect(g.relics.is_empty() and g.collection.size() == 20 and g.battle_no == 2, "Skip takes neither")
	g = Game.new()
	g.relic_chance = 1.0
	for id in filler:
		g.add_relic(Relics.by_id(id))
	g.foe.hp = 1
	g.ui.picks = [1]
	await play(g, dom("Slash", 6, 6), 0)
	expect(g.relics.size() == 8 and g.stored_relics.size() == 1 and g.reward_note.contains("unequipped"), "a new artifact with full slots goes to the inventory")
	g = Game.new()
	g.relic_chance = 1.0
	for r in Relics.build():
		g.add_relic(r)
	g.foe.hp = 1
	g._begin_reward()
	expect(not g.artifact_offered, "no artifact choice when you already own every artifact")
	g.new_game()
	expect(g.relics.is_empty() and g.stored_relics.is_empty(), "a new game starts without artifacts")

	# ---------- no healing between battles ----------
	g = Game.new()
	g.relic_chance = 0.0
	g.pl.hp = 23
	g.pl.shield = 5
	g.pl.add("fury", 4)
	g.foe.hp = 1
	g.ui.picks = [-1]
	await play(g, dom("Slash", 6, 6), 0)
	expect(g.pl.hp == 23 and g.pl.shield == 0 and g.pl.value("fury") == 0, "HP stays at 23 for the next battle, shield and statuses are cleared")

	# ---------- the deck lists (stack window) ----------
	g = Game.new()
	g.hand = [g.hand[0], g.hand[1]]
	var hand_ids: Array = g.hand.duplicate()
	var entries: Array = g.battle_deck_entries()
	var n_hand := 0
	var n_stack := 0
	var sorted_ok := true
	for i in entries.size():
		if entries[i].state == "hand":
			n_hand += 1
		elif entries[i].state == "stack":
			n_stack += 1
		if i > 0 and entries[i - 1].d.data.title.to_lower() > entries[i].d.data.title.to_lower():
			sorted_ok = false
	expect(entries.size() >= 20 and n_hand == 2 and n_stack == g.stack.size() and sorted_ok, "battle deck entries: alphabetical, 2 in hand, the rest of the stack undrawn")
	var drawn_one = g.stack.pop_back()
	g.discard.append(drawn_one)
	var states := {}
	for e in g.battle_deck_entries():
		if e.d == drawn_one:
			states = e
	expect(states.state == "drawn", "a discarded domino counts as drawn")
	g.stack.append(drawn_one)
	g.discard.erase(drawn_one)
	var back := {}
	for e in g.battle_deck_entries():
		if e.d == drawn_one:
			back = e
	expect(back.state == "stack", "shuffled back into the stack it is undrawn again")
	var coll: Array = g.collection_entries()
	var all_stack := true
	for e in coll:
		if e.state != "stack":
			all_stack = false
	expect(coll.size() == 20 and all_stack, "between battles the whole collection is listed at full opacity")
	var played_d = hand_ids[0]
	g.hand.erase(played_d)
	var after := {}
	for e in g.battle_deck_entries():
		if e.d == played_d:
			after = e
	expect(after.state == "drawn", "a played domino counts as drawn")

	# ---------- settings and glossary ----------
	var Settings = load("res://scripts/settings.gd")
	var Glossary = load("res://scripts/glossary.gd")
	expect(Settings.show_damage_taken and not Settings.show_status_names and not Settings.show_status_info, "defaults: damage estimate on, names off, status info off")
	g = fresh()
	g.foe.intent = [{"k": "atk", "v": 8}]
	g.pl.shield = 5
	expect(g.preview_intents(false).entries[0].text == "Attack 8" and g.preview_intents(true).entries[0].text == "Attack 8: -3 HP", "without the estimate the intent only says how hard it hits")
	g.foe.intent = [{"k": "lifeatk", "v": 8}]
	expect(g.preview_intents(false).entries[0].text == "Attack 8 (lose a life if unblocked)", "a life attack still explains itself")
	g.pl.add("fury", 2)
	g.pl.add("power", 1)
	var ents: Array = g.pl.status_entries()
	expect(ents[0].name == "Fury" and ents[0].num == "2" and ents[1].name == "Power" and ents[1].num == "+1", "status entries carry a name and a number")
	g.pl.add("fury", -5)
	expect(g.pl.status_entries()[0].name == "Impair" and g.pl.status_entries()[0].num == "3" and g.pl.status_entries()[0].k == "impair", "Impair is its own name and icon")
	expect(Glossary.for_domino(dom("Crimson Ritual", 1, 1)) == ["life", "fury", "power"], "glossary ids for a domino, in order")
	expect(Glossary.for_domino(dom("Slash", 1, 1)) == [] and Glossary.for_domino(dom("Hex of Ruin", 1, 1)) == ["life", "impair"], "no cards for plain damage; Impair for Hex of Ruin")
	for id in Glossary.ENTRIES:
		expect(Icons.exists(Glossary.ENTRIES[id].icon), "glossary icon exists: %s" % id)

	# ---------- seed: same stack, same plans ----------
	g = Game.new()
	expect(g.seed_value >= 100000000 and g.seed_value < 1000000000, "a new game gets a 9 digit seed (%d)" % g.seed_value)
	var h1 := _hand_titles(g)
	var intents1: Array = g.foe.intent.duplicate(true)
	var stack1 := _stack_titles(g)
	g.start_battle()
	expect(_hand_titles(g) == h1 and _stack_titles(g) == stack1 and g.foe.intent == intents1, "starting the battle again gives the same hand, stack order and enemy plans")
	var g2 := Game.new()
	g2.new_game(g.seed_value)
	expect(_stack_titles(g2) == stack1 and g2.foe.intent == intents1, "the same seed gives the same battle in a new game")
	var g3 := Game.new()
	g3.new_game(g.seed_value + 1)
	expect(_stack_titles(g3) != stack1 or g3.foe.intent != intents1, "another seed gives another battle")
	# the plan for later turns depends on the seed, the battle and the turn only
	g.history.turn = 5
	g.new_intent()
	var turn5: Array = g.foe.intent.duplicate(true)
	g.rng.randi()
	g.rng.randi()
	g.new_intent()
	expect(g.foe.intent == turn5, "the enemy plan of a turn does not depend on what random numbers were used before")
	g.start_battle()
	g.hand[0] = g.hand[0]
	g.hand.pop_front()
	g.energy = 3
	g.pl.shield = 4
	g.restart_battle()
	expect(_hand_titles(g) == h1 and g.energy == 10 and g.pl.shield == 0 and g.foe.intent == intents1, "Restart battle: same hand again, fresh energy and shield")
	g = Game.new()
	var hp_start: int = g.pl.hp
	g.pl.hp = 11
	g.lives = 1
	g.ended = true
	g.restart_battle()
	expect(not g.ended and g.pl.hp == hp_start and g.lives == 3, "Restart battle after a defeat gives back your HP and lives from the start of the battle")
	g = Game.new()
	g.foe.hp = 5
	g.hand = [dom("Slash", 1, 1)]
	g.busy = 2
	expect(not g.restart_battle() and g.busy == 2, "cannot restart in the middle of an animation")
	g.busy = 0

	# ---------- ephemeral dominoes ----------
	g = fresh()
	g.hand = [dom("Lunge", 1, 1), dom("Slash", 1, 1), dom("Flash Guard", 1, 1)]
	g.foe.intent = []
	g.played_this_turn = true
	await g.end_turn()
	var still := []
	for d in g.hand:
		still.append(d.data.title)
	expect(not still.has("Lunge") and not still.has("Flash Guard") and still.has("Slash"), "ephemeral dominoes left in hand go to the discard pile at the end of the turn")
	expect(g.discard.size() == 2 and g.discard[0].data.ephemeral, "they are in the discard pile")
	expect(cat[ti("Lunge")].ephemeral and cat[ti("Quick Strike")].ephemeral and not cat[ti("Slash")].ephemeral, "the ephemeral flag comes from the catalogue")
	expect(DominoText_has_ephemeral(g, dom("Lunge", 1, 1)), "the info text says Ephemeral")
	# stronger than the normal counterpart for the same pips
	var lunge_dmg: int = await _dmg_of(g, "Lunge", 3, 3)
	var slash_dmg: int = await _dmg_of(g, "Slash", 3, 3)
	expect(lunge_dmg > slash_dmg, "Lunge hits harder than Slash for the same pips (%d vs %d)" % [lunge_dmg, slash_dmg])
	g = fresh()
	g.hand = [dom("Quick Strike", 1, 1), dom("Slash", 1, 1)]
	expect(g.cond_ok(0), "Quick Strike can be the first domino of the turn")
	g.played_this_turn = true
	expect(not g.cond_ok(0), "Quick Strike cannot be played after another domino")
	var Dom := Dominoes
	var counts := {"c": 0, "u": 0, "r": 0}
	for i in 600:
		counts[cat[Dom.rand_type(g.rng)].rarity] += 1
	expect(counts.c > 0 and counts.u > 0 and counts.r > 0, "random dominoes never include weapon dominoes (only c, u and r come out)")

	# ---------- rip and shred ----------
	g = fresh()
	g.placed = [{"owner": "p", "a": 2, "b": 3}, {"owner": "c", "a": 6, "b": 6}, {"owner": "p", "a": 1, "b": 1}]
	g.hand = [dom("Rip and Shred", 2, 1)]
	var shred = cat[ti("Rip and Shred")].effects[0]
	expect(shred.count(g, g.hand[0]) == 7 + 3, "Rip and Shred counts the pips of every domino YOU played, plus itself")
	expect(g.fx_lines(g.hand[0])[0].contains("10 now"), "its text shows the current total")
	g.pl.add("fury", 2)
	expect(g.preview_player_attack(0).hp == 12, "the preview includes Fury")
	g.pl.statuses.clear()
	g.placed.append({"owner": "p", "a": 2, "b": 1})        # now it is on the board
	await g.run_fx(g.hand[0])
	expect(200 - g.foe.hp == 10, "it deals that much damage")

	# ---------- weapons ----------
	Game.starter_gear = true
	g = Game.new()
	Game.starter_gear = false
	expect(g.weapon != null and g.weapon.title == "Short Sword" and g.has_relic("time_pendant"), "a new game starts with the Short Sword and the Time Pendant")
	expect(g.relics.size() == 1 and g.relics[0].id == "time_pendant" and g.has_rewind(), "the Time Pendant takes an artifact slot")
	var deck := g.battle_deck_entries()
	var by := {}
	for e in deck:
		by[e.d.data.title] = by.get(e.d.data.title, 0) + 1
	expect(deck.size() == 25 and by["Quick Strike"] == 2 and by["Sword Slash"] == 3, "the Short Sword adds 3 Sword Slash and 2 Quick Strike to the 20 dominoes (25 in all)")
	expect(g.collection.size() == 20, "weapon dominoes are not added to your collection")
	var qs: Array = []
	for e in deck:
		if e.d.data.title == "Quick Strike":
			qs.append(e.d)
	expect(qs[0].total() == 2 and qs[0].data.ephemeral, "Quick Strike has small pips (2 energy) and is ephemeral")
	g = fresh()
	g.add_relic(Relics.by_id("time_pendant"))
	expect(Relics.by_id("short_sword").weapon and Relics.build_weapons().size() == 8, "8 weapons")
	var cases := [["long_sword", "Heavy Blade", 2, "bottom"], ["shining_blade", "Cutting Edge", 1, "top"], ["sawtooth_blade", "Rip and Shred", 2, "any"]]
	for c in cases:
		g = Game.new()
		g.weapon = Relics.by_id(c[0])
		g.start_battle()
		var idx: Array = []
		for i in g.stack.size():
			if g.stack[i].data.title == c[1]:
				idx.append(i)
		for d in g.hand:
			if d.data.title == c[1]:
				idx.append(-1)
		expect(idx.size() == c[2], "%s adds %d %s" % [c[0], c[2], c[1]])
		if c[3] == "bottom":
			expect(idx == [0, 1], "Heavy Blade sits at the very bottom of the stack (drawn last)")
		if c[3] == "top":
			var in_hand := false
			for d in g.hand:
				if d.data.title == "Cutting Edge":
					in_hand = true
			expect(in_hand, "Cutting Edge is on top of the stack, so it is in your first hand")
	g = Game.new()
	g.weapon = Relics.by_id("shining_blade")
	g.start_battle()
	var ce = null
	for d in g.hand:
		if d.data.title == "Cutting Edge":
			ce = d
	expect(ce != null and ce.total() == 4, "Cutting Edge costs 4 energy")
	g.foe.hp = 200
	g.foe.max_hp = 200
	g.foe.shield = 0
	await g.run_fx(ce)
	expect(200 - g.foe.hp == 12, "Cutting Edge: 3 hits of 4 = 12 damage")
	# rapier: En Garde at the start of EVERY turn, and it is ephemeral
	g = Game.new()
	g.weapon = Relics.by_id("duelists_blade")
	g.start_battle()
	var eg := 0
	for d in g.hand:
		if d.data.title == "En Garde":
			eg += 1
	expect(eg == 1, "Rapier: an En Garde in your first hand")
	g.foe.intent = []
	g.played_this_turn = true
	await g.end_turn()
	eg = 0
	for d in g.hand:
		if d.data.title == "En Garde":
			eg += 1
	expect(eg == 1 and g.discard.size() >= 1, "Rapier: the unplayed one was discarded and a new En Garde arrives each turn (still just 1)")
	expect(g.battle_deck.size() == 20 + 2, "the added En Garde cards are part of this battle's deck list")
	# only one weapon, never unequipped, replaced
	g = fresh()
	g.weapon = Relics.by_id("short_sword")
	var lw = Relics.by_id("long_sword")
	g.stored_weapons.append(lw)
	expect(g.equip_weapon(lw) and g.weapon == lw and g.stored_weapons.size() == 1 and g.stored_weapons[0].title == "Short Sword", "equipping a weapon swaps it with the old one")
	expect(not g.equip_weapon(Relics.by_id("duelists_blade")), "you can only equip a weapon you own")
	expect(g.relic_ids().has("long_sword") and g.relic_ids().has("short_sword"), "owned weapons count as owned")

	# ---------- the Time Pendant ----------
	g = _game_with_gear()
	g.relic_chance = 0.0
	expect(g.can_rewind_turn() and g.has_rewind(), "with the pendant you can rewind (3 lives)")
	var hand0 := _hand_titles(g)
	var stack_before := _stack_titles(g)
	var e0: int = g.energy
	var foe_intent: Array = g.foe.intent.duplicate(true)
	await play(g, dom("Iron Guard", 1, 1))
	g.pl.shield = 7
	g.pl.add("fury", 3)
	g.foe.hp -= 20
	g.hand.pop_back()
	expect(g.restart_turn(), "Rewind turn works")
	expect(g.lives == 2 and g.energy == e0 and _hand_titles(g) == hand0 and _stack_titles(g) == stack_before, "back at the start of the turn for 1 life: same hand, same stack, same energy")
	expect(g.pl.shield == 0 and g.pl.value("fury") == 0 and g.foe.hp == g.foe.max_hp and g.foe.intent == foe_intent and g.placed.is_empty() and g.occ.is_empty(), "the board, both fighters and the enemy plan are restored")
	expect(not g.played_this_turn and g.stats.lost == 1, "no domino played yet this turn; the life is counted as lost")
	expect(g.history.count("domino_played") == 0 and g.history.count("damage") == 0, "the combat history is rewound too")
	g.lives = 1
	expect(not g.can_rewind_turn() and not g.restart_turn(), "cannot rewind with only 1 life left")
	g.lives = 3
	g.unequip_relic(g.relics[0])
	expect(not g.has_rewind() and not g.can_rewind_turn(), "unequipped, the pendant does nothing (no button)")
	g.equip_relic(g.stored_relics[0])
	g.busy = 1
	expect(not g.can_rewind_turn(), "cannot rewind while something is happening")
	g.busy = 0
	# the same random numbers come out again after a rewind
	g = _game_with_gear()
	g.hand = []
	g.discard = [dom("Slash", 2, 2), dom("Slash", 3, 3), dom("Slash", 4, 4)]
	g.snapshot_turn()
	var first: Array = []
	for i in 3:
		g.restack_random(1)
		first.append(g.stack.size())
	var order1 := _stack_titles(g)
	g.restart_turn()
	for i in 3:
		g.restack_random(1)
	expect(_stack_titles(g) == order1 and g.discard.size() == 0 , "after a rewind the same random choices happen again")
	# next turn: the rewind goes to the start of THAT turn
	g = _game_with_gear()
	g.foe.intent = []
	g.played_this_turn = true
	await g.end_turn()
	expect(g.turn_snap.history.turn == 2 and g.turn_snap.lives == 3, "a new snapshot is taken at the start of every turn")

	# ---------- gems, victory and the shop ----------
	g = fresh()
	expect(g.gems == 9, "you start with 9 gems")
	g = Game.new()
	g.relic_chance = 0.0
	g.pl.hp = 40
	g.foe.hp = 1
	g.hand = [dom("Slash", 6, 6)]
	g.ui.picks = [-1]
	await play(g, dom("Slash", 6, 6), 0)
	var vs: Dictionary = g.victory_summary
	expect(g.ui.log.has("victory") and vs.gems >= 2 and vs.gems <= 3 and g.gems == 9 + vs.gems, "victory: 2-3 gems (+%d, now %d)" % [vs.gems, g.gems])
	expect(vs.dealt > 0 and vs.lost == 0 and vs.battle == 1, "the victory summary has the damage dealt and the HP lost (%s)" % [vs])
	expect(g.shop_pending and g.shop.size() >= 9, "after the first battle there is always a shop with 9 things (10 with a weapon upgrade)")
	var kinds := {"domino": 0, "relic": 0, "weapon": 0, "upgrade": 0}
	var rare_domino := 0
	for it in g.shop:
		kinds[it.kind] += 1
		if it.kind == "domino" and it.item.data.rarity == "r":
			rare_domino += 1
	expect(kinds.domino == 5 and kinds.relic == 2 and kinds.weapon == 1 and (kinds.upgrade == 1 or kinds.upgrade == 2) and rare_domino >= 1,
			"the shop sells 5 dominoes (at least 1 rare), 2 artifacts, 1 weapon and 1 upgrade (2 if it also offers a weapon upgrade)")
	var price_ok := true
	for it in g.shop:
		if it.kind == "upgrade":
			continue
		var r: String = it.item.data.rarity if it.kind == "domino" else it.item.rarity
		var lo := 0
		var hi := 0
		match r:
			"c":
				lo = 2
				hi = 3
			"u":
				lo = 4
				hi = 5
			"r":
				lo = 6
				hi = 8
		if it.kind == "relic":
			lo *= 2
			hi *= 2
		if it.kind == "weapon":
			lo = roundi(1.5 * lo)
			hi = roundi(1.5 * hi)
		if it.price < lo or it.price > hi:
			price_ok = false
			print("   bad price ", it.kind, " ", r, " ", it.price)
	expect(price_ok, "prices: domino c 2-3, u 4-5, r 6-8; artifacts double; weapons 1.5x")
	var wpn = null
	for it in g.shop:
		if it.kind == "weapon":
			wpn = it.item
	expect(wpn != null and wpn.weapon and wpn.title != "Short Sword", "the weapon on sale is one you do not own")
	var shop_owned := true
	for it in g.shop:
		if it.kind == "relic" and g.relic_ids().has(it.item.id):
			shop_owned = false
	expect(shop_owned, "artifacts on sale are ones you do not own")
	# buying
	g.gems = 100
	var di := -1
	var ri := -1
	var wi := -1
	for i in g.shop.size():
		match g.shop[i].kind:
			"domino":
				di = i
			"relic":
				ri = i
			"weapon":
				wi = i
	var gems_before: int = g.gems
	var price_d: int = g.shop_price(di)
	expect(g.buy(di) and g.gems == gems_before - price_d and g.collection.has(g.shop[di].item) and g.shop[di].sold, "buying a domino takes gems and adds it to your collection")
	expect(not g.buy(di), "it cannot be bought twice")
	var rl = g.shop[ri].item
	expect(g.buy(ri) and g.relics.has(rl), "buying an artifact equips it when there is a free slot")
	g.weapon = Relics.by_id("short_sword")
	var wp = g.shop[wi].item
	expect(g.buy(wi) and g.stored_weapons.has(wp) and g.weapon.title == "Short Sword", "a bought weapon waits in the inventory (equip it yourself)")
	g.gems = 0
	g.shop[0].sold = false
	expect(not g.buy(0), "cannot buy without enough gems")
	g.gems = 100
	g.add_relic(Relics.by_id("hagglers_tongue"))
	var cheap := 99
	for i in g.shop.size():
		if not g.shop[i].sold:
			cheap = mini(cheap, g.shop_price(i) - g.shop[i].price)
	expect(cheap == -1, "Haggler's Tongue: everything costs 1 gem less")
	g.shop[0].price = 1
	expect(g.shop_price(0) == 1, "never below 1 gem")
	# the shop is a 30% chance after the first battle
	var shops := 0
	for i in 400:
		g = Game.new()
		g.relic_chance = 0.0
		g.new_game(1000 + i)
		g.battle_no = 2
		g._begin_reward()
		if g.shop_pending:
			shops += 1
	expect(shops > 80 and shops < 160, "about 30%% of later victories offer the shop (%d of 400)" % shops)
	g = Game.new()
	g.relic_chance = 0.0
	g.battle_no = 2
	g._begin_reward()
	expect(g.shop.is_empty() == not g.shop_pending, "no shop stock when there is no shop")
	# gems artifact, extra life artifacts, extra draw
	g = fresh("jewelers_loupe")
	g.battle_no = 2
	g.gems = 0
	g._begin_reward()
	expect(g.gems >= 3 and g.gems <= 4, "Jeweler's Loupe: 1 more gem after a battle (%d)" % g.gems)
	g = fresh("spare_heart")
	g.battle_no = 3
	g._begin_reward()
	expect(g.lives == 4, "Spare Heart: a life after the 3rd battle")
	g = fresh("spare_heart")
	g.battle_no = 2
	g._begin_reward()
	expect(g.lives == 3, "Spare Heart: nothing after the 2nd battle")
	g = fresh("warm_hearth")
	g.lives = 1
	g.battle_no = 2
	g._begin_reward()
	expect(g.lives == 2, "Warm Hearth: a life if you win with only 1 life")
	g = fresh("warm_hearth")
	g.battle_no = 2
	g._begin_reward()
	expect(g.lives == 3, "Warm Hearth: nothing with more lives")
	g = fresh("bottomless_satchel")
	g.hand = [dom("Slash", 1, 1)]
	await next_turn(g)
	expect(g.hand.size() == 1 + 4 + 1 and Relics.by_id("bottomless_satchel").rarity == "r", "Bottomless Satchel (rare): 1 extra domino every turn")
	expect(Relics.by_id("jewelers_loupe").rarity == "r" and Relics.by_id("time_pendant").starter, "Jeweler's Loupe is rare; the Time Pendant is a starter")
	var ro := Relics.roll([], 200)
	var seen_pendant := false
	var cnt := {"c": 0, "u": 0, "r": 0}
	for r in ro:
		cnt[r.rarity] += 1
		if r.id == "time_pendant":
			seen_pendant = true
	expect(not seen_pendant and cnt.c > cnt.u * 0 and cnt.r <= cnt.c, "starter artifacts are never offered; rare ones are the least common")

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
