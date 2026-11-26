extends SceneTree
## Tests for weapon tiers, equipment-made dominoes, attack and skill types, counters on artifacts, Berserk, and the
## dominoes that care about types (Phantom Blades, Dual Wield, Barrage, Tactician's Strike, Momentum Strike,
## Scrap Shield). Run:
##   godot --headless -s tests/test_equipment.gd

const Game = preload("res://scripts/game.gd")
const Foe = preload("res://scripts/foe.gd")
const Dominoes = preload("res://scripts/dominoes.gd")
const Relics = preload("res://scripts/relics/relics.gd")
const Balance = preload("res://scripts/balance.gd")

var fails := 0
var checks := 0


func expect(cond: bool, label: String) -> void:
	checks += 1
	if cond:
		print("PASS  ", label)
	else:
		fails += 1
		print("FAIL  ", label)


func fresh() -> Game:
	var g := Game.new()
	g.foe = Foe.new(1)
	g.foe.hp = 1000
	g.foe.max_hp = 1000
	g.foe.intent = []
	g.hand = []
	g.stack = []
	g.discard = []
	return g


func make(g: Game, name: String):
	return g.make_domino(Dominoes.index_of(name))


func equip(g: Game, name: String):
	var d = make(g, name)
	d.origin = "equipment"
	d.roll_all(g.rng)
	return d


func _initialize() -> void:
	test_tiers()
	test_equipment_tag()
	test_types()
	test_down_counters()
	test_up_counters()
	await test_new_dominoes()
	test_berserk()
	await test_ui()
	print("CHECKS: ", checks, "  FAILURES: ", fails)
	quit(fails)


func test_tiers() -> void:
	var g := Game.new()
	var by := {}
	for d in g.data:
		by[d.title] = d
	expect(by["Quick Strike"].tier == "c" and by["Heavy Blade"].tier == "u" and by["Cutting Edge"].tier == "r" and by["Sword Slash"].tier == "c",
			"a weapon domino has the tier of its weapon (Quick Strike common, Heavy Blade uncommon, Cutting Edge rare)")
	expect(by["Quick Strike"].max_level() == 4 and by["Heavy Blade"].max_level() == 3 and by["Cutting Edge"].max_level() == 2,
			"so it goes up as far as its weapon: common 4, uncommon 3, rare 2")
	expect(by["Quick Strike"].rarity_name() == "Common weapon" and by["Cutting Edge"].rarity_name() == "Rare weapon", "and is named after it")
	expect(by["Slash"].tier == "c" and by["Phantom Shiv"].max_level() == 1, "regular dominoes keep their rarity as their tier; a token has one level")
	var ok := true
	for w in Relics.build_weapons():
		for add in w.adds:
			var kind = by[add.t]
			if kind.rarity == "w":
				ok = ok and kind.tier == w.rarity and kind.max_level() == w.max_level()
	expect(ok, "every weapon domino matches its weapon's rarity and number of levels")
	# weapon dominoes are better than regular ones of the same rarity
	var better := true
	for name in ["Sword Slash", "Quick Strike", "Heavy Blade", "En Garde", "Rip and Shred", "Cutting Edge"]:
		var d = g.make_domino(by[name].id)
		better = better and Balance.ratio(d) >= Balance.TARGET[by[name].tier]
	expect(better, "weapon dominoes give at least as much per energy as the average regular domino of their rarity")
	var slash = make(g, "Slash")
	var sword = make(g, "Sword Slash")
	expect(sword.total() == slash.total() and Balance.score(sword) > Balance.score(slash), "a Sword Slash costs the same as a Slash and hits harder")
	expect(Balance.target(by["Quick Strike"]) > Balance.target(by["Slash"]) and Balance.WEAPON_BONUS == 1.2, "the balance target for weapon dominoes is 20% higher")
	var w = Relics.by_id("short_sword")
	expect(w.rarity == "c" and w.max_level() == 4, "a common weapon has 3 upgrades")


func test_equipment_tag() -> void:
	var g := Game.new()
	g.weapon = Relics.by_id("short_sword")
	g.collection = [make(g, "Parry")]
	g.start_battle()
	var mine := 0
	var theirs := 0
	for d in g.stack + g.hand:
		if d.origin == "equipment":
			theirs += 1
			expect_silent(d.is_equipment() and d.data.rarity == "w" or d.data.title == "Sword Slash")
		else:
			mine += 1
	expect(theirs == 5 and mine == 1, "the dominoes a weapon adds are tagged as equipment (%d), yours are not (%d)" % [theirs, mine])
	expect(g.collection[0].origin == "collection" and g.collection.size() == 1, "and they never enter your collection")
	var first = (g.hand + g.stack)[0]
	var copy = first.copy()
	expect(copy.origin == first.origin, "a copy keeps the tag")
	g.collection.append(equip(g, "Quick Strike"))
	g.collection.append(make(g, "Slash"))
	var created = make(g, "Slash")
	created.origin = "created"
	g.collection.append(created)
	g._strip_temporary_dominoes()
	expect(g.collection.size() == 2 and g.collection[1].data.title == "Slash", "at the end of a battle equipment and created dominoes are removed from the collection")
	g.collection.append(equip(g, "Heavy Blade"))
	g.start_battle()
	expect(g.collection.size() == 2, "and a new battle starts clean too")
	var rt := RichTextLabel.new()
	var DominoText = load("res://scripts/domino_text.gd")
	DominoText.setup(rt)
	var shown = null
	for d in g.hand + g.stack:
		if d.origin == "equipment":
			shown = d
	DominoText.fill(rt, g, shown, -1)
	expect(rt.get_parsed_text().contains("Made by your equipment"), "its card says it belongs to your equipment")
	rt.free()


func expect_silent(cond: bool) -> void:
	if not cond:
		fails += 1
		checks += 1
		print("FAIL  (silent check)")


func test_types() -> void:
	var g := Game.new()
	expect(make(g, "Slash").type() == "attack" and make(g, "Sword Slash").type() == "attack" and make(g, "Sunburst").type() == "attack", "damage dominoes are attacks (regular, weapon, element)")
	expect(make(g, "Parry").type() == "skill" and make(g, "Phantom Blades").type() == "skill" and make(g, "Scrap Shield").type() == "skill" and make(g, "Uptick").type() == "skill", "everything without an attack is a skill")
	expect(make(g, "Phantom Shiv").type() == "attack" and make(g, "Berserk").type() == "attack" and make(g, "Tactician's Strike").type() == "attack", "created dominoes, Berserk and the type strikes are attacks")
	var d = make(g, "Parry")
	d.downgrade()
	expect(d.type() == "skill", "a level does not change the type")
	var rt := RichTextLabel.new()
	var DominoText = load("res://scripts/domino_text.gd")
	DominoText.setup(rt)
	DominoText.fill(rt, g, make(g, "Slash"), -1)
	expect(rt.get_parsed_text().contains("Common attack"), "the card says attack: %s" % rt.get_parsed_text().substr(0, 60).replace("\n", " "))
	rt.clear()
	DominoText.fill(rt, g, make(g, "Parry"), -1)
	expect(rt.get_parsed_text().contains("Common skill"), "or skill")
	rt.free()


func test_down_counters() -> void:
	var g := fresh()
	g.add_relic(Relics.by_id("dwindling_flame"))
	var r = g.relics[g.relics.size() - 1]
	expect(r.counter == 4 and r.counter_text() == "4" and r.counter_line().begins_with("Counter: 4"), "Dwindling Flame starts at 4")
	var furies := []
	for i in 4:
		g.pl.statuses.clear()
		g.dispatch("on_battle_start")
		furies.append(g.pl.value("fury"))
	expect(furies == [4, 3, 2, 1] and not g.has_relic("dwindling_flame"), "Fury 4, 3, 2, 1 at the start of four battles, then it breaks %s" % str(furies))
	var h := fresh()
	h.add_relic(Relics.by_id("waning_phial"))
	var heals := []
	for i in 3:
		h.pl.hp = 10
		h.dispatch("on_battle_start")
		heals.append(h.pl.hp - 10)
	expect(heals == [9, 6, 3] and not h.has_relic("waning_phial"), "Waning Phial heals 9, 6, 3 and breaks %s" % str(heals))
	var t = Relics.by_id("fragile_gauntlet")
	expect(t.tooltip().contains("Counter: 3") and t.counter_mode == "down", "the tooltip shows the counter")
	var plain = Relics.by_id("iron_cloak")
	expect(plain.counter_text() == "" and plain.counter_line() == "", "artifacts without a counter show nothing")


func test_up_counters() -> void:
	var g := fresh()
	g.add_relic(Relics.by_id("spiked_buckler"))
	var r = g.relics[g.relics.size() - 1]
	expect(r.counter_text() == "0/3", "Spiked Buckler counts attacks: 0/3")
	g.dispatch("on_domino_played", {"attack": true})
	g.dispatch("on_domino_played", {"attack": false})
	expect(r.counter == 1 and g.pl.shield == 0, "a skill does not count")
	g.dispatch("on_domino_played", {"attack": true})
	expect(r.counter == 2 and r.counter_text() == "2/3", "2 attacks: 2/3")
	g.dispatch("on_domino_played", {"attack": true})
	expect(g.pl.shield == 3 and r.counter == 0, "the third attack gives 3 shield and the counter starts again")
	for i in 3:
		g.dispatch("on_domino_played", {"attack": true})
	expect(g.pl.shield == 6, "every 3 attacks, so 6 attacks give it twice")
	g.dispatch("on_domino_played", {"attack": true})
	g.dispatch("on_domino_played", {"attack": true})
	expect(r.counter == 2, "two more attacks wait on the counter")
	g.dispatch("on_turn_start")
	expect(r.counter == 0, "the counter resets to 0 at the start of every turn")
	g.pl.shield = 0
	g.dispatch("on_domino_played", {"attack": true})
	g.dispatch("on_domino_played", {"attack": true})
	expect(g.pl.shield == 0 and g.has_relic("spiked_buckler"), "and it never breaks")
	r.counter = 2
	g._reset_counters()
	expect(r.counter == 0, "restarting a turn resets it too")
	# skills draw, plays give energy
	var s := fresh()
	s.stack = [make(s, "Slash"), make(s, "Slash"), make(s, "Slash")]
	s.add_relic(Relics.by_id("scribes_quill"))
	for i in 3:
		s.dispatch("on_domino_played", {"attack": false})
	expect(s.hand.size() == 1, "Scribe's Quill: 3 skills draw a domino")
	var e := fresh()
	e.add_relic(Relics.by_id("tally_stick"))
	e.energy = 0
	for i in 3:
		e.dispatch("on_domino_played", {"attack": i % 2 == 0})
	expect(e.energy == 0, "Tally Stick: 3 dominoes give nothing yet")
	e.dispatch("on_domino_played", {"attack": true})
	expect(e.energy == 1, "the 4th gives 1 energy")
	expect(e.relics[e.relics.size() - 1].counter_line().contains("this turn"), "its text says the counter resets every turn")


func test_new_dominoes() -> void:
	# Phantom Blades
	var g := fresh()
	var pb = make(g, "Phantom Blades")
	pb.roll_all(g.rng)
	await g.run_fx(pb)
	var shivs := 0
	for d in g.hand:
		if d.data.title == "Phantom Shiv":
			shivs += 1
			expect_silent(d.origin == "created" and d.data.ephemeral and d.total() == 2 and d.type() == "attack")
	expect(shivs == 3 and g.ui.entered.size() >= 3 and g.ui.entered[g.ui.entered.size() - 1].source == "top", "Phantom Blades adds 3 ephemeral Phantom Shivs (1|1) to your hand, from the top of the screen")
	var shiv = g.hand[0]
	g.hand = [shiv]
	var foe0: int = g.foe.hp
	await g.run_fx(shiv)
	expect(foe0 - g.foe.hp == 4, "a Phantom Shiv deals 4")
	# Dual Wield
	g = fresh()
	var dw = make(g, "Dual Wield")
	dw.roll_all(g.rng)
	var sword = equip(g, "Sword Slash")
	var regular = make(g, "Slash")
	regular.roll_all(g.rng)
	g.hand = [regular, sword, make(g, "Parry")]
	foe0 = g.foe.hp
	await g.run_fx(dw)
	expect(foe0 - g.foe.hp == 16 and not g.hand.has(sword) and g.discard.has(sword), "Dual Wield: the chosen weapon domino hits twice (2 x 8), then it is discarded")
	expect(g.hand.has(regular) and g.hand.size() == 2, "your own dominoes were not offered: the Slash stays in your hand")
	expect(g.history.count("domino_replayed") == 2 and g.placed.is_empty(), "it was played from the hand: it did not go on the board")
	g.pl.add("fury", 2)
	var sw2 = equip(g, "Sword Slash")
	g.hand = [sw2]
	foe0 = g.foe.hp
	await g.run_fx(dw)
	expect(foe0 - g.foe.hp == 10 + 9, "each play ticks Fury down: 8+2 then 8+1")
	g.hand = [make(g, "Slash")]
	foe0 = g.foe.hp
	await g.run_fx(dw)
	expect(foe0 == g.foe.hp and g.hand.size() == 1, "with no weapon domino in hand it does nothing")
	# Barrage
	g = fresh()
	var bar = make(g, "Barrage")
	var a1 = make(g, "Slash")
	var a2 = make(g, "Slash")
	var a3 = make(g, "Slash")
	for d in [a1, a2, a3]:
		d.roll_all(g.rng)
	g.hand = [a1, a2, a3, make(g, "Parry")]
	foe0 = g.foe.hp
	await g.run_fx(bar)
	expect(foe0 - g.foe.hp == 14 and g.hand.size() == 2 and g.discard.size() == 2, "Barrage plays 2 random attack dominoes from your hand once each (2 x 7), then discards them")
	var skill_left := false
	for d in g.hand:
		if d.data.title == "Parry":
			skill_left = true
	expect(skill_left, "skills are never chosen")
	g.hand = [make(g, "Slash")]
	g.hand[0].roll_all(g.rng)
	foe0 = g.foe.hp
	await g.run_fx(bar)
	expect(foe0 - g.foe.hp == 7 and g.hand.is_empty(), "with one attack it plays that one")
	# Tactician's Strike
	g = fresh()
	var ts = make(g, "Tactician's Strike")
	ts.roll_all(g.rng)
	g.hand = [make(g, "Parry"), make(g, "Parry"), make(g, "Phantom Blades"), make(g, "Slash"), ts]
	foe0 = g.foe.hp
	await g.run_fx(ts)
	expect(foe0 - g.foe.hp == 6, "Tactician's Strike: 2 damage for each of the 3 skills in hand")
	expect(g.fx_lines(ts)[0].contains("(6 now)") and g.caps(4)[0].num == "6", "its text and its number under the domino show the 6")
	# Momentum Strike
	g = fresh()
	var ms = make(g, "Momentum Strike")
	ms.roll_all(g.rng)
	g.history.add("domino_played", {"attack": true})
	g.history.add("domino_played", {"attack": false})
	g.history.add("domino_played", {"attack": true})     # this one
	foe0 = g.foe.hp
	await g.run_fx(ms)
	expect(foe0 - g.foe.hp == 6, "Momentum Strike: 3 damage for each attack played this turn, itself included (2 -> 6)")
	# Scrap Shield
	g = fresh()
	var ss = make(g, "Scrap Shield")
	g.hand = [make(g, "Slash"), make(g, "Parry"), make(g, "Slash"), make(g, "Slash"), make(g, "Fortify")]
	g.pl.shield = 0
	await g.run_fx(ss)
	expect(g.pl.shield == 21 and g.hand.size() == 2 and g.discard.size() == 3, "Scrap Shield discards all 3 attacks and gains 7 shield for each (21)")
	for d in g.hand:
		expect_silent(d.type() == "skill")
	# every upgrade level of the new ones works
	var lv_ok := true
	for name in ["Phantom Blades", "Dual Wield", "Barrage", "Tactician's Strike", "Momentum Strike", "Scrap Shield"]:
		var base = null
		for d in g.data:
			if d.title == name:
				base = d
		for lv in range(0, base.max_level() + 1):
			var d2 = make(g, name)
			d2.set_level(lv)
			lv_ok = lv_ok and d2.level() == lv
	expect(lv_ok, "all levels of the new dominoes exist")


func test_berserk() -> void:
	var g := fresh()
	var parry = make(g, "Parry")
	var slash = make(g, "Slash")
	g.hand = [parry, slash]
	expect(g.cond_ok(0) and g.cond_ok(1), "before Berserk everything can be played")
	g.pl.add("berserk", 1)
	expect(not g.cond_ok(0) and g.cond_ok(1), "Berserk: only attack dominoes can be played")
	expect(g.pl.status_lines().has("Berserk 1"), "it shows on your tag")
	g.dispatch("on_turn_start")
	expect(g.pl.value("berserk") == 0 and g.cond_ok(0), "it goes down by 1 at the start of the next turn and skills are playable again")
	# the Berserk domino and its levels
	var base = null
	for d in g.data:
		if d.title == "Berserk":
			base = d
	expect(base.max_level() == 3 and base.row.has("levels"), "Berserk is uncommon: levels 0 to 3, spelled out")
	var l0 = base.at_level(0)
	var l1 = base
	var l2 = base.at_level(2)
	var l3 = base.at_level(3)
	expect(l0.condition.id == "first" and l1.condition.id == "onlyAttacks" and l2.condition.id == "onlyAttacks" and l3.condition.id == "onlyAttacks",
			"level 0: only if no other domino was played; level 1 and up: only if you played no skills this turn")
	var fury := []
	for lv in 4:
		var x = make(g, "Berserk")
		x.set_level(lv)
		var f := 0
		for e in x.data.effects:
			if e.kind == "fury":
				f = e.value(e.size_for(x))
		fury.append(f)
	expect(fury == [5, 5, 7, 7], "Fury 5 (level 0 and 1), 7 at level 2 and 3 %s" % str(fury))
	expect(not l2.has_effect("drawattack") and l3.has_effect("drawattack") and l1.has_effect("berserk") and l3.has_effect("berserk"), "level 3 also draws 2 random attack dominoes")
	# playing it: Fury 5 and Berserk 1, attack type
	var g2 := fresh()
	g2.history.turn = 1
	g2.hand = [make(g2, "Berserk"), make(g2, "Parry")]
	expect(g2.cond_ok(0), "Berserk (level 1) can be played when only attacks were played")
	g2.history.add("domino_played", {"attack": false})
	expect(not g2.cond_ok(0), "but not after a skill this turn")
	var g3 := fresh()
	g3.hand = [make(g3, "Berserk")]
	g3.hand[0].set_level(0)
	expect(g3.cond_ok(0), "level 0 can be the first domino of the turn")
	g3.played_this_turn = true
	expect(not g3.cond_ok(0), "but not after anything else was played")
	# drawing attacks
	var g4 := fresh()
	g4.stack = [make(g4, "Parry"), make(g4, "Slash"), make(g4, "Parry"), make(g4, "Slash"), make(g4, "Slash"), make(g4, "Fortify")]
	var b3 = make(g4, "Berserk")
	b3.set_level(3)
	b3.roll_all(g4.rng)
	await g4.run_fx(b3)
	var drawn_attacks := 0
	for d in g4.hand:
		if d.type() == "attack":
			drawn_attacks += 1
	expect(g4.hand.size() == 2 and drawn_attacks == 2 and g4.pl.value("berserk") == 1 and g4.pl.value("fury") == 6,
			"level 3 draws exactly 2 attacks (no skills), gives 7 Fury (6 after its own attack) and applies Berserk")
	var g5 := fresh()
	g5.stack = [make(g5, "Parry"), make(g5, "Slash")]
	expect(g5.draw_matching("attack") and not g5.draw_matching("attack") and g5.hand.size() == 1 and g5.stack.size() == 1, "drawing attacks stops when the stack has none left")


func test_ui() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(1.5).timeout
	var g = main.game
	var hud = main.hud
	g.busy = 0
	g.add_relic(Relics.by_id("spiked_buckler"))
	g.add_relic(Relics.by_id("fragile_gauntlet"))
	main._refresh_ui()
	var badges := []
	for icon in hud.relic_bar.get_children():
		for c in icon.get_children():
			if c is Label:
				badges.append(c.text)
	expect(badges.has("0/3") and badges.has("3"), "artifacts with a counter show it on their icon %s" % str(badges))
	g.dispatch("on_domino_played", {"attack": true})
	main._refresh_ui()
	badges = []
	for icon in hud.relic_bar.get_children():
		for c in icon.get_children():
			if c is Label:
				badges.append(c.text)
	expect(badges.has("1/3"), "and it follows the counter (1/3)")
	main.queue_free()
	await process_frame
