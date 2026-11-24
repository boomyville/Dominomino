extends SceneTree
## Headless tests for the rules, the 80 dominoes and the battle loop. Run from the project folder:
##   godot --headless -s tests/test_rules.gd
## Exits with the number of failures.

const Game = preload("res://scripts/game.gd")
const Dominoes = preload("res://scripts/dominoes.gd")
const NullUI = preload("res://scripts/null_ui.gd")
const Domino = preload("res://scripts/domino.gd")
const Foe = preload("res://scripts/foe.gd")
const Combatant = preload("res://scripts/combatant.gd")

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


func mk(x: int, y: int, rot: int, a: int, b: int) -> Dictionary:
	return {"x": x, "y": y, "rot": rot, "a": a, "b": b}


func mki(x: int, y: int, rot: int, a: int, b: int, i: int) -> Dictionary:
	var m := mk(x, y, rot, a, b)
	m.i = i
	return m


func ti(name: String) -> int:
	for i in cat.size():
		if cat[i].title == name:
			return i
	return -1


func dom(name: String, a: int, b: int):
	return Domino.new(cat[ti(name)], a, b)


## Make the combat history say that n dominoes have been played this battle.
func set_played(g: Game, n: int) -> void:
	g.history.clear()
	for i in n:
		g.history.add("domino_played", {"a": 0, "b": 0, "cost": 0, "attack": false})


func garb():
	return Domino.new(cat[Dominoes.GARBAGE], 0, 0)


## A game set up for testing one domino: 30/50 HP, a 200 HP enemy, 4 dominoes in the stack.
func fresh() -> Game:
	var g := Game.new()
	g.pl.hp = 30
	g.foe = Foe.new(1)
	g.foe.hp = 200
	g.foe.max_hp = 200
	g.foe.intent = []
	g.hand = []
	g.stack = [dom("Slash", 1, 1), dom("Twin Fang", 2, 2), dom("Iron Guard", 3, 3), dom("Fortify", 4, 4)]
	g.discard = []
	return g


func run(g: Game, name: String, a: int, b: int) -> Dictionary:
	await g.run_fx(dom(name, a, b))
	return {"dealt": 200 - g.foe.hp, "hp": g.pl.hp, "sh": g.pl.shield, "max_sh": g.pl.max_shield, "pow": g.pl.value("power"),
			"boost": g.pl.value("boost"), "fury": g.pl.value("fury"), "efury": g.foe.value("fury"), "hand": g.hand.size(),
			"stack": g.stack.size(), "disc": g.discard.size(), "lives": g.lives}


## Find a legal spot for a domino with these pips (null if none).
func find_spot(g: Game, a: int, b: int):
	for r in 4:
		var dm := Game.dims(r)
		for x in range(0, Game.N - int(dm.x) + 1):
			for y in range(0, Game.N - int(dm.y) + 1):
				if g.check({"x": x, "y": y, "rot": r, "a": a, "b": b}).ok:
					return {"x": x, "y": y, "rot": r}
	return null


func _initialize() -> void:
	randomize()
	Game.starter_gear = false      # these tests want a plain start (no weapon, no pendant)
	await _tests()
	print("CHECKS: ", checks, "  FAILURES: ", fails)
	quit(fails)


func _tests() -> void:
	# ---------- catalogue ----------
	expect(Dominoes.TY.size() == 113 and Dominoes.TY[Dominoes.GARBAGE].n == "Garbage", "112 dominoes (80 from the web build + 32 new) plus Garbage")
	var rc := {"c": 0, "u": 0, "r": 0, "w": 0, "g": 0}
	var names := {}
	for t in Dominoes.TY:
		rc[t.r] += 1
		names[t.n] = true
	expect(rc == {"c": 41, "u": 39, "r": 27, "w": 5, "g": 1}, "rarity counts 41 common / 39 uncommon / 27 rare / 5 weapon %s" % rc)
	expect(names.size() == 113, "all names are unique")
	expect(cat[Dominoes.GARBAGE].title == "Garbage" and cat[Dominoes.GARBAGE].is_garbage(), "Garbage is the last entry")
	# every effect size matches the web build exactly (fixture dumped from index.html)
	var fixture = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/domino_values.json"))
	var bad := 0
	for i in fixture.size():
		var f = fixture[i]
		# the fixture ends with Garbage, which sits after the new dominoes in the Godot catalogue
		var at: int = Dominoes.GARBAGE if f.n == "Garbage" else i
		var t = Dominoes.TY[at]
		var d = cat[at]
		var cid: String = d.condition.id if d.condition != null else ""
		if f.n != d.title or f.r != d.rarity or f.c != cid or f.fx.size() != d.effects.size():
			bad += 1
			continue
		for j in f.fx.size():
			var e = d.effects[j]
			if f.fx[j].k != e.kind or int(f.fx[j].t) != int(t.fx[j].get("t", 0)):
				bad += 1
			for s in 13:
				if int(f.fx[j].vals[s]) != e.value(s):
					bad += 1
	expect(bad == 0, "all 80 dominoes x 13 pip totals match the web build (%d mismatches)" % bad)
	var allc := true
	for d in cat:
		if d.condition != null and d.condition.text == "":
			allc = false
	expect(allc, "every play condition has text")

	# ---------- Combatant and statuses ----------
	var cb := Combatant.new(40)
	expect(cb.hp == 40 and cb.max_hp == 40 and cb.shield == 0 and cb.max_shield == 9, "a Combatant starts at full HP, no shield, max shield 9")
	cb.add("fury", 3)
	cb.add("power", 2)
	cb.add("boost", 4)
	expect(cb.attack_damage(5) == 14, "Fury, Power and Boost all add to damage (5 + 3 + 2 + 4)")
	expect(cb.status_lines() == ["Fury 3", "Power +2", "Boost +4"], "status lines in tag order %s" % [cb.status_lines()])
	cb.finish_attack()
	expect(cb.value("fury") == 2 and cb.value("power") == 2 and cb.value("boost") == 0, "after an attack: Fury ticks, Power stays, Boost is used up")
	cb.add("fury", -6)
	expect(cb.value("fury") == -4 and cb.status_lines()[0] == "Impair 4", "Impair is just negative Fury (2 - 6 = Impair 4)")
	expect(cb.attack_damage(3) == 1 and cb.attack_damage(1) == 0, "Impair lowers damage but never below 0")
	cb.finish_attack()
	expect(cb.value("fury") == -3, "Impair ticks toward 0 too")
	cb.shield = 5
	var tk := cb.take_damage(8)
	expect(tk.absorbed == 5 and tk.taken == 3 and cb.hp == 37 and cb.shield == 0, "shield soaks first, the rest hurts")
	expect(cb.heal(10) == 3 and cb.hp == 40, "healing stops at max HP")
	cb.lose_hp(100)
	expect(cb.hp == 0, "HP never goes below 0")
	expect(Foe.new(1).title == "Gruff Hare" and Foe.new(2).lv == 2 and Foe.new(7).title == "Hare Lord 7", "Foe has a level and a name")
	expect(cat[ti("Slash")].has_attack() and not cat[ti("Iron Guard")].has_attack() and cat[ti("Twin Fang")].has_attack(), "DominoData knows which dominoes are attacks")
	var orig = dom("Slash", 3, 4)
	orig.ang = 180
	var cp2 = orig.copy()
	expect(cp2.a == 3 and cp2.b == 4 and cp2.ang == 0 and cp2.data == orig.data and cp2 != orig, "a Domino copy keeps kind and pips but starts unturned")

	# ---------- board rules ----------
	var g := Game.new()
	expect(g.check(mk(5, 5, 0, 1, 1)).why == "Connect to your character", "must connect to own character")
	expect(g.check(mk(14, 8, 0, 1, 1)).why == "Space taken", "cannot overlap a character")
	var r := g.check(mk(12, 8, 0, 3, 6))
	expect(r.ok and r.cost == 9, "3|6 touching only the character costs 9")
	g.hand = [dom("Slash", 3, 6)]
	var m := mk(12, 8, 0, 3, 6)
	m.i = 0
	await g.play_domino(m)
	expect(g.energy == 1 and g.hand.size() == 0 and g.placed.size() == 1, "energy 10 -> 1, domino leaves hand and stays on the board")
	expect(g.discard.size() == 0, "a played domino does not go to the discard pile")
	expect(g.check(mk(12, 8, 0, 1, 1)).why == "Space taken", "cannot overlap a domino")
	expect(g.check(mk(11, 7, 1, 5, 2)).why == "Pips must match", "touching pips must match")
	expect(g.check(mk(12, 9, 0, 3, 6)).why == "Touches same domino twice", "touch the same domino only once")
	g.energy = 5
	r = g.check(mk(11, 8, 1, 3, 2))
	expect(r.ok and r.cost == 2, "touching half is free, other half costs its pips")
	g.energy = 1
	expect(g.check(mk(11, 8, 1, 3, 2)).why == "Needs 2 energy", "not enough energy")
	expect(g.check(mk(11, 8, 1, 3, 2), true).ok, "free flag ignores energy")

	# ---------- the original effects ----------
	g = fresh(); r = await run(g, "Slash", 3, 4);       expect(r.dealt == 9, "Slash 3|4 deals 9")
	g = fresh(); r = await run(g, "Slash", 6, 6);       expect(r.dealt == 14, "Slash 6|6 deals 14 (bigger pips, bigger effect)")
	g = fresh(); r = await run(g, "Twin Fang", 3, 4);   expect(r.dealt == 10, "Twin Fang 3|4 deals 5 + 5")
	g = fresh(); r = await run(g, "Triple Thorn", 3, 3); expect(r.dealt == 9, "Triple Thorn 3|3 deals 3 x 3")
	g = fresh(); r = await run(g, "Iron Guard", 2, 3);  expect(r.sh == 8, "Iron Guard 2|3 gains 8 shield")
	g = fresh(); r = await run(g, "Fortify", 4, 4);     expect(r.max_sh == 12 and r.sh == 5, "Fortify 4|4: max shield 12, shield 5")
	g = fresh(); r = await run(g, "Parry", 2, 3);       expect(r.sh == 6 and r.hand == 1, "Parry 2|3: shield 6 and draw 1")
	g = fresh(); r = await run(g, "Quick Study", 5, 5); expect(r.hand == 3, "Quick Study 5|5 draws 3")
	g = fresh(); g.hand = [dom("Iron Guard", 1, 1), dom("Iron Guard", 2, 2)]
	r = await run(g, "Reckless Strike", 3, 3);          expect(r.dealt == 10 and r.hand == 1 and r.disc == 1, "Reckless Strike 3|3: 10 damage + a random discard")
	g = fresh(); g.hand = [dom("Iron Guard", 1, 1), dom("Mend", 2, 2)]
	r = await run(g, "Gambit", 2, 2);                   expect(r.dealt == 9 and r.hand == 1 and r.disc == 1, "Gambit 2|2: 9 damage + a chosen discard (pick)")
	g = fresh(); r = await run(g, "Scout", 3, 3);       expect(r.hand == 1 and r.stack == 3 and r.sh == 3, "Scout 3|3: finds a domino from the stack (pick), shield 3")
	g = fresh(); r = await run(g, "War Cry", 4, 4);     expect(r.pow == 3, "War Cry 4|4 gains Power 3")
	g = fresh(); r = await run(g, "Sharpen", 3, 4);     expect(r.boost == 9, "Sharpen 3|4 gives Boost 9")
	g = fresh(); r = await run(g, "Mend", 3, 4);        expect(r.hp == 39, "Mend 3|4 heals 9")
	g = fresh(); g.pl.hp = 45; r = await run(g, "Mend", 6, 6); expect(r.hp == 50, "healing is capped at max HP")
	g = fresh(); g.hand = [dom("Slash", 1, 1), dom("Slash", 1, 1), dom("Slash", 1, 1)]
	r = await run(g, "Chaos Dice", 3, 3)
	expect(r.hand == 3 and r.sh == 5, "Chaos Dice rerolls the hand and gives shield 5")
	g = fresh(); g.hand = [dom("Slash", 1, 1)]
	r = await run(g, "Second Wind", 3, 4);              expect(r.hp == 35 and r.hand == 2, "Second Wind 3|4: heal 5 and draw 1")
	g = fresh(); r = await run(g, "Battle Trance", 3, 4); expect(r.dealt == 5 and r.pow == 1, "Battle Trance 3|4: 5 damage then +1 Power")
	g = fresh(); r = await run(g, "Shield Bash", 3, 4); expect(r.dealt == 6 and r.sh == 6, "Shield Bash 3|4: 6 damage and 6 shield")
	g = fresh(); r = await run(g, "Precision", 3, 4);   expect(r.boost == 6 and r.hand == 1, "Precision 3|4: Boost 6 and draw 1")
	g = fresh(); r = await run(g, "Lifesteal", 3, 4);   expect(r.dealt == 6 and r.hp == 33, "Lifesteal 3|4: 6 damage and heal 3")
	g = fresh(); g.hand = [dom("Slash", 1, 1)]; g.ui.picks = [0]
	await run(g, "Loaded Dice", 2, 2)
	expect(g.hand.size() == 2 and g.stats.rerolls == 1, "Loaded Dice rerolls the chosen domino (pick) and draws")

	# ---------- Fury / Impair ----------
	g = fresh(); r = await run(g, "Rage Up", 3, 3);     expect(r.fury == 4, "Rage Up 3|3 gains 4 Fury")
	g = fresh(); r = await run(g, "Sting", 3, 3);       expect(r.efury == -4, "Sting 3|3 puts 4 Impair on the enemy")
	g = fresh(); g.pl.add("fury", 3); r = await run(g, "Slash", 3, 4)
	expect(r.dealt == 12 and r.fury == 2, "Fury adds to damage (9 + 3) and ticks down after an attack")
	g = fresh(); g.pl.add("fury", -3); r = await run(g, "Slash", 3, 4)
	expect(r.dealt == 6 and r.fury == -2, "Impair subtracts (9 - 3) and ticks up toward 0")
	g = fresh(); g.pl.add("fury", -9); r = await run(g, "Slash", 0, 0);  expect(r.dealt == 0, "damage never goes below 0")
	g = fresh(); g.pl.add("fury", 3); r = await run(g, "Reckless Blow", 4, 4)
	expect(r.dealt == 21 and r.fury == -2, "3 Fury + 6 Impair on self nets 3 Impair, ticking to 2 (dealt %d, fury %d)" % [r.dealt, r.fury])
	g = fresh(); g.pl.add("fury", -2); r = await run(g, "Rage Up", 0, 0); expect(r.fury == -1, "gaining Fury cancels Impair (no attack, no tick)")
	g = fresh(); r = await run(g, "Berserker", 2, 3);   expect(r.dealt == 12 and r.fury == 5, "Berserker 2|3: Fury 6 first, then 12 damage, ticks to 5")
	g = fresh(); r = await run(g, "Blood Ward", 2, 3);  expect(r.sh == 10 and r.hp == 28, "Blood Ward 2|3: 10 shield, lose 2 HP")
	g = fresh(); r = await run(g, "Blood Rage", 2, 3);  expect(r.fury == 5 and r.hp == 28, "Blood Rage 2|3: 5 Fury, lose 2 HP")
	g = fresh(); r = await run(g, "Spare Parts", 2, 2); expect(r.stack == 5 and r.sh == 5, "Spare Parts adds a random domino to the stack")
	g = fresh(); r = await run(g, "Second Chance", 3, 3); expect(r.lives == 5 and r.stack == 6, "Second Chance: +2 lives and 2 dominoes in the stack")
	g = fresh(); r = await run(g, "Overwhelm", 3, 3);   expect(r.efury == -11 and r.boost == 10, "Overwhelm 3|3: 11 Impair on the enemy, Boost 10")
	g = fresh(); g.pl.add("boost", 9); r = await run(g, "Slash", 3, 4)
	var second := await run(g, "Slash", 3, 4)
	expect(r.dealt == 18 and r.boost == 0 and second.dealt - r.dealt == 9, "Boost is used up by the first attack: 18, then 9")
	g = fresh(); g.pl.add("boost", 9); r = await run(g, "Mend", 3, 4); expect(r.boost == 9, "Boost is kept when the domino is not an attack")
	g = fresh(); await run(g, "War Cry", 4, 4); await run(g, "Slash", 3, 4); r = await run(g, "Slash", 3, 4)
	expect(r.pow == 3, "Power stays after attacks")

	# ---------- play conditions ----------
	var cases := [
		["Clean Hands", [dom("Slash", 6, 1)], [dom("Slash", 2, 1)], "noSix"],
		["Full Grip", [dom("Slash", 1, 1)], [dom("Slash", 1, 1), dom("Slash", 1, 1), dom("Slash", 1, 1), dom("Slash", 1, 1), dom("Slash", 1, 1)], "hand6"],
		["Light Hands", [dom("Slash", 1, 1), dom("Slash", 1, 1), dom("Slash", 1, 1), dom("Slash", 1, 1), dom("Slash", 1, 1)], [], "handLe3"],
		["Steady Guard", [dom("Slash", 1, 1)], [dom("Iron Guard", 1, 1)], "noAtk"],
	]
	for c in cases:
		g = fresh()
		g.hand = [dom(c[0], 3, 3)] + c[1]
		var blocked := not g.cond_ok(0)
		g.hand = [dom(c[0], 3, 3)] + c[2]
		expect(blocked and g.cond_ok(0), "%s: blocked, then playable (%s)" % [c[0], c[3]])
	var single := [
		["Second Skin", "pl.sh", 4, 0], ["Flawless Blow", "bat", 1, 0], ["Cheap Shot", "turn", 1, 0],
		["Veteran\u2019s Edge", "played", 8, 9], ["Last Stand", "hp", 40, 25], ["Shatter", "fsh", 0, 5],
	]
	for c in single:
		g = fresh()
		g.hand = [dom(c[0], 3, 3)]
		match c[1]:
			"pl.sh":
				g.pl.shield = c[2]
			"bat":
				g.history.add("hp_lost", {"who": "p", "amount": 1, "kind": "attack"})
			"turn":
				g.played_this_turn = true
			"played":
				set_played(g, c[2])
			"hp":
				g.pl.hp = c[2]
			"fsh":
				g.foe.shield = c[2]
		var before := g.cond_ok(0)
		match c[1]:
			"pl.sh":
				g.pl.shield = c[3]
			"bat":
				g.history.clear()
			"turn":
				g.played_this_turn = false
			"played":
				set_played(g, c[3])
			"hp":
				g.pl.hp = c[3]
			"fsh":
				g.foe.shield = c[3]
		expect(not before and g.cond_ok(0), "%s: blocked, then playable" % c[0])
	g = fresh(); g.hand = [garb()]
	expect(not g.can_play(0) and g.check_p(mki(12, 8, 0, 0, 0, 0)).why == "Garbage cannot be played", "Garbage can never be played")
	g.hand = [dom("Second Skin", 3, 3)]
	g.pl.shield = 5
	expect(g.check_p(mki(12, 8, 0, 3, 3, 0)).why.begins_with("Needs:") and not g.can_play(0), "an unmet condition blocks the drop and the highlight")
	g.hand = [dom("Second Skin", 3, 3), garb(), dom("Slash", 3, 4)]
	g.pl.shield = 5
	var cp = [g.caps(0), g.caps(1), g.caps(2)]
	expect(cp[0][0].k == "x" and cp[0][0].num == "13", "caption: unmet condition shows an X and keeps the number")
	expect(cp[1][0].k == "x" and cp[1][0].num == "", "caption: Garbage shows only an X")
	expect(cp[2][0].k == "dmg" and cp[2][0].num == "9", "caption: Slash 3|4 shows damage 9")
	g.pl.shield = 0
	expect(g.caps(0)[0].k == "shield", "caption: the icon returns once the condition is met")

	# ---------- hand, stack and discard ----------
	g = fresh()
	g.hand = []
	for i in 12:
		g.hand.append(dom("Slash", 1, 1))
	g.stack = [dom("Slash", 2, 2)]
	expect(not g.draw_one() and g.hand.size() == 12 and g.stack.size() == 1, "a full hand (12) draws nothing")
	expect(g.ui.log.has("toast: Hand size is maxed"), "a 'Hand size is maxed' message is shown")
	g = fresh(); g.hand = []
	for i in 11:
		g.hand.append(dom("Slash", 1, 1))
	g.stack = [dom("Slash", 1, 2), dom("Slash", 1, 2), dom("Slash", 1, 2), dom("Slash", 1, 2)]
	r = await run(g, "Quick Study", 5, 5)
	expect(r.hand == 12 and r.stack == 3, "a draw of 3 stops at the hand limit")
	g = fresh(); g.hand = []
	for i in 12:
		g.hand.append(dom("Slash", 1, 1))
	g.ui.log.clear()
	r = await run(g, "Scout", 3, 3)
	expect(r.hand == 12 and r.stack == 4 and r.sh == 3 and not g.ui.log.has("pick: Find a domino"), "Scout with a full hand skips the search but still gives shield")
	g = fresh(); g.stack = []; g.discard = [dom("Slash", 1, 2), dom("Slash", 3, 4)]; g.hand = []
	expect(not g.draw_one() and g.discard.size() == 2 and g.hand.size() == 0, "the discard pile never goes back into the stack")

	# ---------- enemy intents ----------
	var intent_cases := [
		[[{"k": "atk", "v": 7}], 43, 0],
		[[{"k": "lifeatk", "v": 8}], 42, 1],
	]
	for c in intent_cases:
		g = Game.new(); g.played_this_turn = true; g.hand.resize(3); g.foe.intent = c[0]
		var l0 := g.lives
		await g.end_turn()
		expect(g.pl.hp == c[1] and l0 - g.lives == c[2], "%s: HP %d, lives lost %d" % [c[0][0].k, g.pl.hp, l0 - g.lives])
	g = Game.new(); g.played_this_turn = true; g.hand.resize(3); g.pl.shield = 9; g.pl.max_shield = 20; g.foe.intent = [{"k": "lifeatk", "v": 8}]
	await g.end_turn()
	expect(g.lives == 3 and g.pl.hp == 50, "life-attack fully blocked: no life lost")
	g = Game.new(); g.played_this_turn = true; g.hand.resize(3); g.foe.intent = [{"k": "discH"}]
	await g.end_turn()
	expect(g.discard.size() == 1, "enemy discards a random domino from your hand")
	g = Game.new(); g.played_this_turn = true; g.hand.resize(3); g.foe.intent = [{"k": "mill"}]
	g.stack = [dom("Slash", 1, 1), dom("Slash", 2, 2), dom("Slash", 3, 3), dom("Slash", 4, 4), dom("Slash", 5, 5), dom("Slash", 6, 6), dom("Slash", 0, 1)]
	await g.end_turn()
	var gar := 0
	for d in g.hand + g.stack + g.discard:
		if d.data.is_garbage():
			gar += 1
	expect(g.discard.size() == 1 and gar == 1, "mill: top stack domino discarded, 1 Garbage added")
	g = Game.new(); g.played_this_turn = true; g.hand.resize(3); g.foe.intent = [{"k": "junk"}]
	await g.end_turn()
	gar = 0
	for d in g.hand + g.stack + g.discard:
		if d.data.is_garbage():
			gar += 1
	expect(gar == 3, "junk: 3 Garbage shuffled into the stack")
	g = Game.new(); g.played_this_turn = true; g.hand.resize(3); g.foe.add("fury", -3); g.foe.intent = [{"k": "atk", "v": 8}]
	expect(g.intent_text(g.foe.intent[0]) == "Attack 5", "intent shows the impaired damage")
	await g.end_turn()
	expect(g.pl.hp == 45 and g.foe.value("fury") == -2, "enemy Impair reduces its attack and ticks down")
	g = Game.new(); g.played_this_turn = true; g.hand.resize(3); g.foe.add("fury", -2); g.foe.intent = [{"k": "atk", "v": 4}, {"k": "atk", "v": 4}]
	await g.end_turn()
	expect(g.pl.hp == 50 - (2 + 3) and g.foe.value("fury") == 0, "Impair ticks per attack: 4-2 then 4-1")
	var kinds := {}
	var common := 0
	var other := 0
	var counts := {1: 0, 2: 0}
	for i in 3000:
		g.history.turn = i + 1            # the plan depends on the seed, the battle and the turn
		g.new_intent()
		counts[g.foe.intent.size()] += 1
		for it in g.foe.intent:
			kinds[it.k] = true
			if it.k == "atk" or it.k == "blk":
				common += 1
			else:
				other += 1
	expect(kinds.size() == 6, "all 6 intent kinds occur %s" % [kinds.keys()])
	expect(common > other * 2, "attacks and blocks are common, the new effects uncommon")
	expect(counts[1] > 800 and counts[2] > 800 and counts.size() == 2, "the enemy plans 1 or 2 dominoes")
	g = Game.new(); g.played_this_turn = true; g.hand.resize(3); g.foe.intent = [{"k": "atk", "v": 6}, {"k": "atk", "v": 4}]
	await g.end_turn()
	expect(g.stats.cpu == 2 and g.pl.hp == 40, "two planned attacks: two enemy dominoes placed, 6 + 4 damage")
	expect(g.hand.size() == 7 and g.energy == 10 and g.history.turn == 2, "end of turn: 4 drawn, energy refilled, turn counter up")

	# ---------- lives and being stuck ----------
	g = Game.new(); g.foe.intent = [{"k": "blk", "v": 3}]
	await g.end_turn()
	expect(g.lives == 2 and g.ui.flashes >= 1, "ending a turn with no play loses a life and flashes")
	g = Game.new()
	g.hand = [garb()]
	g.stack = []
	g.foe.intent = [{"k": "blk", "v": 3}]
	await g.stuck_check()
	expect(g.ended and g.lives == 0 and g.reason == "You ran out of lives", "stuck turn after turn: lives run out, game over (%s)" % g.reason)
	g = Game.new()
	var l0 := g.lives
	await g.stuck_check()
	expect(g.lives == l0, "a playable hand does not cost a life")
	g = Game.new(); g.pl.hp = 5; g.played_this_turn = true; g.hand.resize(3); g.foe.intent = [{"k": "atk", "v": 11}]
	await g.end_turn()
	expect(g.ended and g.reason == "You were defeated", "defeat when HP reaches 0")
	g = Game.new(); g.hand.clear()
	g.hand.append(dom("Blood Ward", 6, 6))
	g.pl.hp = 2
	g.energy = 12
	var sp = find_spot(g, 6, 6)
	var pm := {"x": sp.x, "y": sp.y, "rot": sp.rot, "a": 6, "b": 6, "i": 0}
	await g.play_domino(pm)
	expect(g.ended and g.reason == "You were defeated", "losing HP to your own domino can defeat you")

	# ---------- victory, reward, next battle ----------
	g = Game.new()
	g.pl.add("fury", 3)
	g.pl.add("power", 4)
	g.pl.add("boost", 6)
	g.pl.max_shield = 14
	g.pl.shield = 11
	g.pl.hp = 12
	g.foe.hp = 1
	g.hand = [dom("Slash", 6, 6)]
	g.energy = 12
	sp = find_spot(g, 6, 6)
	pm = {"x": sp.x, "y": sp.y, "rot": sp.rot, "a": 6, "b": 6, "i": 0}
	g.relic_chance = 0.0       # no artifact choice this time: just the domino reward
	g.ui.picks = [1]
	await g.play_domino(pm)
	expect(g.battle_no == 2 and g.stats.battles == 1 and not g.ended, "victory starts battle 2")
	expect(g.pl.hp == 12 and g.pl.max_hp == 50 and g.pl.value("fury") == 0 and g.pl.value("power") == 0 and g.pl.value("boost") == 0 and g.pl.max_shield == 9 and g.pl.shield == 0, "no healing between battles (HP stays 12), every status cleared")
	expect(g.collection.size() == 21 and g.hand.size() + g.stack.size() == 21, "the chosen domino is added: 21 owned, all in the new stack and hand")
	expect(g.placed.size() == 0 and g.discard.size() == 0 and g.hand.size() == 6, "board and discard pile cleared, a fresh hand of 6")
	expect(g.foe.lv == 2 and g.foe.hp == 85, "the next enemy is stronger (HP %d)" % g.foe.hp)
	expect(g.lives == 3, "lives carry over")
	expect(Foe.new(1).hp < Foe.new(2).hp and Foe.new(2).hp < Foe.new(3).hp, "each enemy has more HP")
	g = Game.new(); g.foe.hp = 1; g.hand = [dom("Slash", 6, 6)]; g.energy = 12
	sp = find_spot(g, 6, 6)
	pm = {"x": sp.x, "y": sp.y, "rot": sp.rot, "a": 6, "b": 6, "i": 0}
	g.relic_chance = 0.0
	g.ui.picks = [-1]
	await g.play_domino(pm)
	expect(g.collection.size() == 20 and g.battle_no == 2, "Skip adds nothing and still starts the next battle")
	expect(g.ui.log.has("pick: Victory!"), "the reward screen was shown")

