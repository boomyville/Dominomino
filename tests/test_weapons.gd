extends SceneTree
## Tests for weapon levels, the weapon upgrade in the shop, no repeated dominoes between the shop and the
## rewards, the new artifacts (Loose Grip, Stalwart, Regenerative, the artifacts that break). Run:
##   godot --headless -s tests/test_weapons.gd

const Game = preload("res://scripts/game.gd")
const Foe = preload("res://scripts/foe.gd")
const Dominoes = preload("res://scripts/dominoes.gd")
const Relics = preload("res://scripts/relics/relics.gd")
const CreatureCmd = preload("res://scripts/cmd/creature_cmd.gd")

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
	g.foe.hp = 500
	g.foe.max_hp = 500
	g.foe.intent = []
	g.hand = []
	g.stack = []
	g.discard = []
	return g


func make(g: Game, name: String):
	return g.make_domino(Dominoes.index_of(name))


func _initialize() -> void:
	test_weapon_levels()
	test_weapon_dominoes()
	test_shop_weapon_upgrade()
	test_no_repeats()
	test_loose_grip()
	test_status_artifacts()
	test_breaking_artifacts()
	await test_ui()
	print("CHECKS: ", checks, "  FAILURES: ", fails)
	quit(fails)


func test_weapon_levels() -> void:
	var common = Relics.by_id("short_sword")
	var uncommon = Relics.by_id("long_sword")
	var rare = Relics.by_id("shining_blade")
	expect(common.max_level() == 4 and uncommon.max_level() == 3 and rare.max_level() == 2, "a common weapon goes up 3 times, an uncommon 2, a rare once")
	expect(common.level == 1 and common.display_name() == "Short Sword" and common.can_upgrade() and common.can_downgrade(), "a weapon starts at level 1")
	var n := 0
	while common.upgrade():
		n += 1
	expect(n == 3 and common.level == 4 and common.display_name() == "Short Sword+++" and not common.can_upgrade(), "Short Sword: three upgrades")
	expect(rare.upgrade() and not rare.upgrade() and rare.level == 2 and rare.display_name() == "Shining Blade+", "Shining Blade: one upgrade")
	expect(uncommon.upgrade() and uncommon.upgrade() and not uncommon.upgrade(), "Long Sword: two upgrades")
	var d = Relics.by_id("duelists_blade")
	d.downgrade()
	expect(d.level == 0 and d.display_name() == "Duelist's Blade-" and not d.downgrade(), "a weapon can be downgraded to level 0")
	expect(d.level_line() == "Level 0 of 3: the dominoes it adds are level 0.", "the level line: %s" % d.level_line())
	var artifact = Relics.by_id("iron_cloak")
	expect(not artifact.upgrade() and not artifact.can_upgrade() and artifact.display_name() == "Iron Cloak", "artifacts have no levels")


func test_weapon_dominoes() -> void:
	var g := Game.new()
	g.weapon = Relics.by_id("short_sword")
	g.weapon.upgrade()
	g.weapon.upgrade()
	g.collection = [make(g, "Parry")]
	g.start_battle()
	var kinds := {}
	for d in g.stack + g.hand:
		kinds[d.data.title] = d.level()
	expect(kinds.get("Sword Slash", -1) == 3 and kinds.get("Quick Strike", -1) == 3 and kinds.get("Parry", -1) == 1, "a level 3 Short Sword adds level 3 dominoes (your own stay as they are): %s" % str(kinds))
	g.weapon = Relics.by_id("short_sword")
	g.weapon.downgrade()
	g.start_battle()
	var low := true
	var count := 0
	for d in g.stack + g.hand:
		if d.data.title == "Sword Slash" or d.data.title == "Quick Strike":
			low = low and d.level() == 0
			count += 1
	expect(low and count == 5, "a downgraded weapon adds downgraded dominoes")
	g.weapon = Relics.by_id("shining_blade")
	g.weapon.upgrade()
	g.start_battle()
	var edge = null
	for d in g.stack + g.hand:
		if d.data.title == "Cutting Edge":
			edge = d
	expect(edge != null and edge.level() == 2 and edge.display_name() == "Cutting Edge+", "the Shining Blade's Cutting Edge is upgraded with it")
	# the numbers really change: Slash at level 1 vs the Short Sword's level 4
	var g2 := Game.new()
	g2.weapon = Relics.by_id("short_sword")
	g2.collection = []
	g2.start_battle()
	var s1 = null
	for d in g2.stack + g2.hand:
		if d.data.title == "Sword Slash":
			s1 = d
	var low_damage := 0
	for e in s1.data.effects:
		if e.kind == "dmg":
			low_damage += e.value(e.size_for(s1))
	g2.weapon.upgrade()
	g2.weapon.upgrade()
	g2.weapon.upgrade()
	g2.start_battle()
	var s4 = null
	for d in g2.stack + g2.hand:
		if d.data.title == "Sword Slash":
			s4 = d
	var high_damage := 0
	for e in s4.data.effects:
		if e.kind == "dmg":
			high_damage += e.value(e.size_for(s4))
	expect(high_damage > low_damage + 4, "upgraded weapon dominoes hit harder (%d instead of %d)" % [high_damage, low_damage])
	# a weapon that adds to your hand every turn
	var g3 := fresh()
	g3.weapon = Relics.by_id("duelists_blade")
	g3.weapon.upgrade()
	g3._weapon_turn()
	expect(g3.hand.size() == 1 and g3.hand[0].data.title == "En Garde" and g3.hand[0].level() == 2, "a Rapier adds its En Garde at the Rapier's level every turn")


func shop_with_weapons(g: Game, n: int) -> int:
	var with_upgrade := 0
	for i in n:
		for it in g.generate_shop():
			if it.kind == "upgrade" and it.mode == "weapon":
				with_upgrade += 1
	return with_upgrade


func test_shop_weapon_upgrade() -> void:
	var g := fresh()
	g.weapon = Relics.by_id("short_sword")
	var n := shop_with_weapons(g, 600)
	expect(n >= 30 and n <= 100, "about one shop in ten offers a weapon upgrade (%d of 600)" % n)
	expect(Game.UPGRADE_PRICE.weapon == 6 and Game.WEAPON_UPGRADE_CHANCE == 0.1, "it costs 6 gems")
	var maxed := fresh()
	maxed.weapon = Relics.by_id("shining_blade")
	maxed.weapon.upgrade()
	expect(shop_with_weapons(maxed, 300) == 0, "no weapon upgrade is offered when every weapon is at its top level")
	# buy it
	g = fresh()
	g.weapon = Relics.by_id("short_sword")
	var stored = Relics.by_id("long_sword")
	g.stored_weapons = [stored]
	g.shop = [{"kind": "upgrade", "mode": "weapon", "item": {"text": Game.UPGRADE_TEXT.weapon}, "price": 6, "sold": false}]
	g.gems = 10
	expect(g.can_buy(0) and not g.buy(0) and g.gems == 10, "a weapon upgrade needs you to choose a weapon")
	expect(not g.buy(0, Relics.by_id("duelists_blade")) and g.gems == 10, "it must be a weapon you own")
	expect(g.upgradable_weapons().size() == 2, "the equipped weapon and the stored ones can be upgraded")
	expect(g.buy(0, stored) and g.gems == 4 and stored.level == 2 and g.weapon.level == 1 and g.shop[0].sold, "choosing a stored weapon: 6 gems, that weapon goes up a level")
	expect(g.shop_note.contains("Long Sword is now Long Sword+") and g.shop_note.contains("dominoes it adds"), "the shop says what happened: %s" % g.shop_note)
	g.shop = [{"kind": "upgrade", "mode": "weapon", "item": {"text": ""}, "price": 6, "sold": false}]
	g.weapon.upgrade()
	g.weapon.upgrade()
	g.weapon.upgrade()
	stored.upgrade()
	g.gems = 20
	expect(not g.can_buy(0) and not g.buy(0, g.weapon), "nothing to upgrade once every weapon is at its top level")


func test_no_repeats() -> void:
	var g := Game.new()
	var shop_ok := true
	for i in 150:
		var seen := {}
		for it in g.generate_shop():
			if it.kind == "domino":
				if seen.has(it.item.data.id):
					shop_ok = false
				seen[it.item.data.id] = true
	expect(shop_ok, "a shop never sells the same domino twice")
	var overlap := 0
	var repeats := 0
	var rounds := 0
	for i in 120:
		var g2 := Game.new()
		g2.battle_no = 1        # the first battle always has a shop
		var opts: Array = g2._begin_reward()
		rounds += 1
		var shop_ids := {}
		for it in g2.shop:
			if it.kind == "domino":
				shop_ids[it.item.data.id] = true
		var seen := {}
		for d in opts:
			if shop_ids.has(d.data.id):
				overlap += 1
			if seen.has(d.data.id):
				repeats += 1
			seen[d.data.id] = true
	expect(rounds == 120 and overlap == 0, "the reward screen never offers a domino the shop sells (%d overlaps)" % overlap)
	expect(repeats == 0, "the reward choices are all different too")
	var all_rare := []
	for i in Dominoes.TY.size():
		if Dominoes.TY[i].r == "r":
			all_rare.append(i)
	expect(Dominoes.rand_type_of("r", null, all_rare) in all_rare, "if everything of a rarity is excluded it still picks something")
	expect(not (Dominoes.rand_type_of("r", null, [all_rare[0]]) == all_rare[0]), "an excluded kind is not picked")


func test_loose_grip() -> void:
	var g := fresh()
	var d = null
	var kind := -1
	for i in Dominoes.TY.size():
		if Dominoes.TY[i].c == "hand6":
			kind = i
			break
	expect(kind >= 0, "there is a domino that needs 6 dominoes in hand")
	d = g.make_domino(kind)
	g.hand = [d]
	expect(not g.cond_ok(0), "with one domino in hand it cannot be played")
	g.add_relic(Relics.by_id("loose_grip"))
	expect(g.cond_ok(0), "Loose Grip: the hand size no longer matters")
	var shielded = null
	for i in Dominoes.TY.size():
		if Dominoes.TY[i].c == "noShield":
			shielded = g.make_domino(i)
			break
	g.hand = [shielded]
	g.pl.shield = 5
	expect(not g.cond_ok(0), "other conditions still apply")
	var fewer = null
	for i in Dominoes.TY.size():
		if Dominoes.TY[i].c == "handLe3":
			fewer = g.make_domino(i)
			break
	g.hand = [fewer, fewer, fewer, fewer, fewer]
	expect(g.cond_ok(0), "'3 or fewer dominoes' is ignored too")
	g.hand = [make(g, "Slash")]
	var four = g.make_domino(Dominoes.index_of("Slash"))
	four.data = four.data.at_level(0)
	expect(g.cond_ok(0), "ordinary dominoes are not affected")


func test_status_artifacts() -> void:
	var g := fresh()
	g.add_relic(Relics.by_id("stalwart_charm"))
	g.dispatch("on_battle_start")
	expect(g.pl.value("stalwart") == 1, "Stalwart Charm starts the battle with 1 Stalwart")
	g.pl.shield = 0
	g.gain_shield(4)
	expect(g.pl.shield == 8, "Stalwart doubles the shield you gain (4 becomes 8)")
	g.dispatch("on_turn_end")
	expect(g.pl.value("stalwart") == 0, "it goes down by 1 when you end the turn")
	g.pl.shield = 0
	g.gain_shield(4)
	expect(g.pl.shield == 4, "so turn 2 is normal again")
	expect(g.pl.status_entries().size() == 0, "an empty Stalwart is not shown")
	g.pl.add("stalwart", 2)
	expect(g.pl.status_entries()[0].name == "Stalwart" and g.pl.status_lines() == ["Stalwart 2"], "Stalwart shows on the tag")
	g.dispatch("on_turn_end")
	expect(g.pl.value("stalwart") == 1, "Stalwart 2 lasts two turns")
	# the enemy's shield is not doubled by your Stalwart
	g.foe.shield = 0
	CreatureCmd.gain_shield(g, g.foe, 5)
	expect(g.foe.shield == 5, "it only doubles your own shield")
	var h := fresh()
	h.add_relic(Relics.by_id("phial_of_renewal"))
	h.dispatch("on_battle_start")
	h.pl.hp = 10
	CreatureCmd.heal(h, h.pl, 4)
	expect(h.pl.value("regenerative") == 1 and h.pl.hp == 18, "Regenerative doubles healing (4 heals 8)")
	h.dispatch("on_turn_end")
	CreatureCmd.heal(h, h.pl, 4)
	expect(h.pl.hp == 22, "and ends after the first turn")
	var sim = h.pl.snapshot()
	expect(sim.value("regenerative") == 0, "a copy keeps the statuses that are on (none left here)")
	# the game knows them in its glossary
	expect(load("res://scripts/glossary.gd").ENTRIES.has("stalwart") and load("res://scripts/glossary.gd").ENTRIES.has("regenerative"), "both are explained in the glossary")


func test_breaking_artifacts() -> void:
	var g := fresh()
	var tail = Relics.by_id("lizard_tail")
	g.add_relic(tail)
	expect(g._death_reason() == "", "alive: nothing happens")
	expect(g.has_relic("lizard_tail"), "the Lizard Tail does nothing by itself")
	g.pl.hp = 0
	var lives0: int = g.lives
	expect(g._death_reason() == "", "the Lizard Tail saves you from dying")
	expect(g.lives == lives0 + 3 and g.pl.hp == 25, "3 lives and half your HP (%d lives, %d HP)" % [g.lives, g.pl.hp])
	expect(not g.has_relic("lizard_tail") and g.history.has("relic_broken", {"relic": "lizard_tail"}), "then it breaks and is gone")
	g.pl.hp = 0
	expect(g._death_reason() == "You were defeated", "the second time you die")
	var g2 := fresh()
	g2.add_relic(Relics.by_id("lizard_tail"))
	g2.lives = 0
	expect(g2._death_reason() == "" and g2.lives == 3 and g2.pl.hp == 50, "it also saves you when you run out of lives")
	var g3 := fresh()
	g3.lives = 0
	expect(g3._death_reason() == "You ran out of lives", "without it: out of lives")
	g3.stored_relics.append(Relics.by_id("lizard_tail"))
	g3.lives = 0
	expect(g3._death_reason() == "You ran out of lives", "an artifact in your inventory (not equipped) does nothing")
	# Last Meal
	var m := fresh()
	m.add_relic(Relics.by_id("last_meal"))
	m.pl.hp = 40
	m.dispatch("on_turn_start")
	expect(m.has_relic("last_meal") and m.pl.hp == 40, "Last Meal waits until you are at half HP")
	m.pl.hp = 20
	m.dispatch("on_turn_start")
	expect(m.pl.hp == 28 and not m.has_relic("last_meal"), "then it heals 8 and is gone")
	# Emergency Bulwark and Fragile Gauntlet work on the battle start, once
	var b := fresh()
	b.add_relic(Relics.by_id("emergency_bulwark"))
	b.add_relic(Relics.by_id("fragile_gauntlet"))
	b.dispatch("on_battle_start")
	expect(b.pl.shield == 15 and b.pl.value("power") == 3 and b.has_relic("emergency_bulwark") and b.has_relic("fragile_gauntlet"), "Emergency Bulwark (15 shield) and Fragile Gauntlet (3 power) work at the start of a battle")
	b.pl.shield = 0
	b.pl.add("power", -3)
	b.dispatch("on_battle_start")
	expect(b.pl.shield == 10 and b.pl.value("power") == 2, "and again, weaker: their counters went down (10 shield, 2 power)")
	b.pl.shield = 0
	b.pl.add("power", -2)
	b.dispatch("on_battle_start")
	expect(b.pl.shield == 5 and b.pl.value("power") == 1 and not b.has_relic("emergency_bulwark") and not b.has_relic("fragile_gauntlet"), "the third time (5 shield, 1 power) the counters reach 0 and both break")
	b.pl.shield = 0
	b.dispatch("on_battle_start")
	expect(b.pl.shield == 0, "and do not come back")
	# a broken one can be offered again in later shops
	expect(not b.relic_ids().has("lizard_tail"), "a broken artifact is no longer owned")


func test_ui() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(1.5).timeout
	var g = main.game
	var hud = main.hud
	g.busy = 0
	g.weapon = Relics.by_id("short_sword")
	g.stored_weapons = [Relics.by_id("long_sword")]
	g.shop = [{"kind": "upgrade", "mode": "weapon", "item": {"text": Game.UPGRADE_TEXT.weapon}, "price": 6, "sold": false}]
	g.gems = 12
	hud.shop_window.open(g)
	var sw = hud.shop_window
	var b = sw.grid.get_child(0).get_child(1)
	expect(b.text == "Upgrade: choose, 6" and not b.disabled, "the weapon upgrade has a button with its price")
	b.pressed.emit()
	expect(sw.grid.get_child_count() == 2 and sw.gems_l.text.begins_with("Choose a weapon"), "choosing shows your two weapons")
	sw.grid.get_child(1).get_child(0).pressed.emit()
	expect(g.gems == 6 and g.stored_weapons[0].level == 2 and sw.grid.get_child(0).get_child(1).text == "Sold", "picking one upgrades it")
	sw.leave_b.pressed.emit()
	# weapon cards show the level
	var rt := RichTextLabel.new()
	var DominoText = load("res://scripts/domino_text.gd")
	DominoText.setup(rt)
	DominoText.fill_relic(rt, g.stored_weapons[0])
	expect(rt.get_parsed_text().contains("Long Sword+") and rt.get_parsed_text().contains("Level 2 of 3"), "the weapon card shows its name with + and its level")
	rt.free()
	main.queue_free()
	await process_frame
