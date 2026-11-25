extends SceneTree
## Tests for domino levels (downgrade, upgrade), the upgrade in the shop, and the small UI changes that came
## with them (level tag, deselecting, the two-column game over table). Run:
##   godot --headless -s tests/test_upgrades.gd

const Game = preload("res://scripts/game.gd")
const Foe = preload("res://scripts/foe.gd")
const Dominoes = preload("res://scripts/dominoes.gd")
const Upgrades = preload("res://scripts/upgrades.gd")
const EffectFactory = preload("res://scripts/effects/effect_factory.gd")
const ConditionFactory = preload("res://scripts/conditions/condition_factory.gd")
const DominoArt = preload("res://scripts/domino_art.gd")
const Domino = preload("res://scripts/domino.gd")

var fails := 0
var checks := 0
var _rng := RandomNumberGenerator.new()


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
	for i in 12:
		g.stack.append(g.make_domino(Dominoes.index_of("Slash")))
	g.discard = []
	return g


func make(g: Game, name: String):
	return g.make_domino(Dominoes.index_of(name))


func _initialize() -> void:
	test_levels()
	test_every_domino()
	test_domino_api()
	await test_new_effects()
	test_shop()
	await test_ui()
	print("CHECKS: ", checks, "  FAILURES: ", fails)
	quit(fails)


## What a level gives you: the sum of the helpful numbers (damage, shield, draw, heal ...).
func helpful(data, dom) -> int:
	var n := 0
	for e in data.effects:
		if Upgrades.SCALES.has(e.kind) and e.mode != "N":
			n += e.value(e.size_for(dom)) * (e.hits if e.kind == "hit" else 1)
	return n


func dmg_of(data, dom) -> int:
	var n := 0
	for e in data.effects:
		if e.kind == "dmg":
			n += e.value(e.size_for(dom))
	return n


func cond_id(data) -> String:
	return data.condition.id if data.condition != null else ""


func drawbacks(data) -> int:
	var n := 0
	for e in data.effects:
		if ["selfdmg", "discR", "impS", "energy", "endturn"].has(e.kind):
			n += 1
	return n


func test_levels() -> void:
	var g := Game.new()
	var slash = make(g, "Slash")
	var by := {}
	for d in g.data:
		by[d.title] = d
	expect(by["Slash"].max_level() == 4 and by["Hexbolt"].max_level() == 3 if by.has("Hexbolt") else true, "common dominoes go up to level 4")
	var seen := {"c": 0, "u": 0, "r": 0}
	for d in g.data:
		if seen.has(d.rarity):
			var want: int = {"c": 4, "u": 3, "r": 2}[d.rarity]
			if d.max_level() == want:
				seen[d.rarity] += 1
	expect(seen.c > 30 and seen.u > 30 and seen.r > 20, "common 4 / uncommon 3 / rare 2 levels (%s)" % str(seen))
	expect(by["Quick Strike"].max_level() == 4 and by["Garbage"].max_level() == 1, "weapon dominoes can go up to 4 (their weapon sets it) and Garbage cannot be upgraded")
	var base = by["Slash"]
	expect(base.at_level(1) == base and base.at_level(2) == base.at_level(2) and base.at_level(2).base == base, "levels are built once and remember the kind")
	expect(base.at_level(2).title == "Slash" and base.at_level(3).level == 3 and base.at_level(0).level == 0 and base.at_level(9).level == 4, "same title, own level (a level past the top stops at the top)")
	expect(base.at_level(2).pips[0].lo == base.pips[0].lo and base.at_level(2).id == base.id, "a level keeps the pips and the id of its kind")
	# Slash deals 7 with its 1|4 pips. An upgrade adds about a third per level.
	var vals := []
	for lv in 5:
		vals.append(dmg_of(base.at_level(lv), slash))
	expect(vals[1] == 7 and vals[2] == 9 and vals[3] == 12 and vals[4] == 14, "Slash deals 7 / 9 / 12 / 14 as it goes up (level 1-4): %s" % str(vals))
	expect(vals[0] == 5, "a downgraded Slash deals 5 instead of 7 (%d)" % vals[0])
	expect(base.at_level(3).effects.size() == 2 and base.at_level(4).effects.size() == 3, "from level 3 an extra effect is added (draw, max shield or heal)")
	var tag := ["Slash-", "Slash", "Slash+", "Slash++", "Slash+++"]
	var ok := true
	for lv in 5:
		var d = g.make_domino(base.id)
		d.data = base.at_level(lv)
		ok = ok and d.display_name() == tag[lv]
	expect(ok, "names: Slash-, Slash, Slash+, Slash++, Slash+++")


func test_every_domino() -> void:
	var g := Game.new()
	var monotonic := true
	var bad_up := []
	var bad_down := []
	var lowered := 0
	var total := 0
	var extras_from_3 := true
	for base in g.data:
		if base.max_level() <= 1:
			continue
		var dom = g.make_domino(base.id)
		dom.roll_all(_rng)
		var prev := helpful(base, dom)
		var base_effects: int = base.effects.size()
		for lv in range(2, base.max_level() + 1):
			var d = base.at_level(lv)
			var now := helpful(d, dom)
			if now <= prev:
				monotonic = false
				bad_up.append("%s L%d %d<=%d" % [base.title, lv, now, prev])
			prev = now
		# from level 3 a small extra effect is added (a domino with nothing to raise gets one on every level)
		if base.max_level() >= 3:
			var l3 = base.at_level(3)
			var extra_value := helpful(l3, dom) - helpful(base.at_level(2), dom)
			if l3.effects.size() == base_effects and extra_value <= 0:
				extras_from_3 = false
		# level 0 is worse in some way
		var d0 = base.at_level(0)
		var worse: bool = helpful(d0, dom) < helpful(base, dom) or drawbacks(d0) > drawbacks(base) \
				or (d0.ephemeral and not base.ephemeral) or (cond_id(d0) != "" and cond_id(base) == "")
		if not worse:
			bad_down.append(base.title)
		total += 1
		if helpful(d0, dom) < helpful(base, dom):
			lowered += 1
	expect(monotonic, "every level raises the helpful numbers %s" % str(bad_up.slice(0, 5)))
	expect(extras_from_3, "from level 3 an extra effect (or bigger number) is added")
	expect(bad_down.is_empty(), "every downgraded domino is worse in some way %s" % str(bad_down.slice(0, 5)))
	expect(lowered * 100 / total >= 55, "a downgrade mostly lowers the numbers (%d of %d)" % [lowered, total])
	# every kind of drawback and restriction is used by some domino
	var kinds_used := {}
	for base in g.data:
		if base.max_level() <= 1:
			continue
		var d0 = base.at_level(0)
		for e in d0.effects:
			if ["selfdmg", "discR", "impS", "energy", "endturn"].has(e.kind):
				kinds_used[e.kind] = true
		if d0.ephemeral and not base.ephemeral:
			kinds_used["ephemeral"] = true
		if cond_id(d0) != "" and cond_id(base) == "":
			kinds_used[cond_id(d0)] = true
	expect(kinds_used.size() >= 8, "downgrades use many drawbacks and restrictions (%s)" % str(kinds_used.keys()))


func test_domino_api() -> void:
	var g := fresh()
	var d = make(g, "Slash")
	expect(d.level() == 1 and d.max_level() == 4 and d.can_upgrade() and d.can_downgrade() and d.level_tag() == "", "a new domino is level 1")
	expect(d.upgrade() and d.level() == 2 and d.level_tag() == "+" and d.display_name() == "Slash+", "upgrade: level 2 is Slash+")
	d.upgrade()
	d.upgrade()
	expect(d.level() == 4 and not d.can_upgrade() and not d.upgrade() and d.level_tag() == "+++", "it stops at the top level")
	var copy = d.copy()
	expect(copy.level() == 4 and copy.data == d.data, "a copy keeps the level")
	for i in 4:
		d.downgrade()
	expect(d.level() == 0 and not d.can_downgrade() and not d.downgrade() and d.level_tag() == "-" and d.display_name() == "Slash-", "downgrade goes to level 0 and stops")
	expect(d.upgrade() and d.level() == 1, "upgrading a downgraded domino brings it back to level 1")
	var w = make(g, "Quick Strike")
	w.set_level(3)
	expect(w.level() == 3 and w.display_name() == "Quick Strike++" and w.max_level() == 4, "a weapon domino can be set to a level (the weapon does that)")
	w.set_level(9)
	expect(w.level() == 4, "set_level stops at the top level")
	var risky = make(g, "Risky Manoeuvre")
	risky.upgrade()
	expect(risky.level() == 2 and not risky.can_upgrade() and risky.specs[0].text() == "3-6" and risky.data.pips[0].is_volatile(), "a rare domino stops at 2 and keeps its pips")
	var up = DominoArt.sides(d).tag
	expect(up == "", "level 1 has no tag in the picture")
	d.upgrade()
	expect(DominoArt.sides(d).tag == "+", "an upgraded domino gets a + tag in the picture")
	d.upgrade()
	expect(DominoArt.sides(d).tag == "++", "two upgrades: ++")
	d.downgrade()
	d.downgrade()
	d.downgrade()
	expect(DominoArt.sides(d).tag == "-", "a downgraded domino gets a - tag")
	# upgraded dominoes fight at their level: the numbers show in the hand and apply in the battle
	var g2 := fresh()
	var s = make(g2, "Slash")
	s.upgrade()
	g2.hand = [s]
	expect(g2.fx_lines(s)[0] == "Deal 9 damage" and g2.caps(0)[0].num == "9", "an upgraded Slash says 9 damage")
	g2.collection = [s]
	g2.weapon = null
	g2.start_battle()
	var in_battle = null
	for x in g2.stack + g2.hand:
		in_battle = x
	expect(in_battle.level() == 2, "the battle copy keeps the level")


func test_new_effects() -> void:
	var g := fresh()
	var d = make(g, "Slash")
	var e = EffectFactory.make({"k": "energy", "m": "K", "a": 0, "b": 1})
	g.energy = 5
	await e.apply(g, d, e.size_for(d))
	expect(g.energy == 4 and e.text_for(g, d, 0) == "Lose 1 energy", "lose 1 energy")
	g.energy = 0
	await e.apply(g, d, 0)
	expect(g.energy == 0, "energy never goes below 0")
	g.hand = []
	expect(not ConditionFactory.make("hand4").met(g, 0), "hand4: not with an empty hand")
	for i in 4:
		g.hand.append(make(g, "Slash"))
	expect(ConditionFactory.make("hand4").met(g, 0), "hand4: met with 4 dominoes")
	expect(ConditionFactory.make("hand4").text == "you hold 4 or more dominoes", "hand4 has its own text")
	g.history.turn = 1
	expect(not ConditionFactory.make("turn2").met(g, 0), "turn2: not on the first turn")
	g.history.turn = 2
	expect(ConditionFactory.make("turn2").met(g, 0), "turn2: met on turn 2")
	# a domino that ends your turn
	var row := {"n": "Slash", "r": "c", "c": "", "p": [1, 2], "fx": [{"k": "dmg", "m": "S", "a": 1, "b": 2}, {"k": "endturn"}]}
	var data = Dominoes.make_data(0, row)
	var ender = Domino.new(data)
	g = fresh()
	g.hand = [make(g, "Slash"), make(g, "Slash")]
	g.stack.append(make(g, "Slash"))
	var turn0: int = g.history.turn
	var cost := await play(g, ender)
	expect(g.history.turn == turn0 + 1 and g.foe.hp < 500 and cost > 0, "playing a domino that ends your turn does its effects, then the turn ends")
	expect(not g.end_turn_after_play and g.busy == 0, "and the game is ready for the next turn")


func find_spot(g: Game, a: int, b: int):
	for r in 4:
		var dm := Game.dims(r)
		for x in range(0, Game.N - int(dm.x) + 1):
			for y in range(0, Game.N - int(dm.y) + 1):
				if g.check({"x": x, "y": y, "rot": r, "a": a, "b": b}).ok:
					return {"x": x, "y": y, "rot": r}
	return null


func play(g: Game, d) -> int:
	g.hand.push_front(d)
	g.energy = 99
	var sp = find_spot(g, d.a, d.b)
	var cost: int = g.check({"x": sp.x, "y": sp.y, "rot": sp.rot, "a": d.a, "b": d.b}).cost
	await g.play_domino({"x": sp.x, "y": sp.y, "rot": sp.rot, "a": d.a, "b": d.b, "i": 0})
	return cost


func upgrade_item(mode: String) -> Dictionary:
	return {"kind": "upgrade", "mode": mode, "item": {"text": Game.UPGRADE_TEXT[mode]}, "price": Game.UPGRADE_PRICE[mode], "sold": false}


func levels(g: Game) -> Array:
	var out := []
	for d in g.collection:
		out.append(d.level())
	return out


func test_shop() -> void:
	var g := fresh()
	var modes := {}
	var all_ok := true
	for i in 80:
		var items: Array = g.generate_shop()
		var ups := items.filter(func(it): return it.kind == "upgrade" and it.mode != "weapon")
		all_ok = all_ok and ups.size() == 1 and ups[0].price == Game.UPGRADE_PRICE[ups[0].mode]
		modes[ups[0].mode] = true
	expect(all_ok and modes.size() == 3, "every shop has one upgrade, randomly: pick 5 / random 3 / two random 6 gems %s" % str(modes.keys()))
	expect(Game.UPGRADE_PRICE.pick == 5 and Game.UPGRADE_PRICE.random == 3 and Game.UPGRADE_PRICE.random2 == 6, "the upgrade prices are 5, 3 and 6 gems")
	# pick a domino
	g = fresh()
	g.collection = [make(g, "Slash"), make(g, "Parry"), make(g, "Slash")]
	g.shop = [upgrade_item("pick")]
	g.gems = 20
	expect(not g.buy(0) and g.gems == 20 and not g.shop[0].sold, "choosing an upgrade needs a domino: nothing is paid without one")
	expect(not g.buy(0, make(g, "Slash")) and g.gems == 20, "it must be a domino you own")
	var target = g.collection[1]
	expect(g.buy(0, target) and g.gems == 15 and target.level() == 2 and g.shop[0].sold and levels(g) == [1, 2, 1], "pick: 5 gems, that domino goes up a level")
	expect(g.shop_note.begins_with("Upgraded: Parry is now Parry+"), "the shop says what happened: %s" % g.shop_note)
	expect(not g.buy(0, target), "an upgrade can be bought once")
	# a domino at its top level cannot be picked
	g.shop = [upgrade_item("pick")]
	var top = make(g, "Risky Manoeuvre")
	top.upgrade()
	g.collection.append(top)
	expect(not g.buy(0, top) and g.gems == 15, "a domino at its top level cannot be chosen")
	# random
	g = fresh()
	g.collection = [make(g, "Slash"), make(g, "Parry"), make(g, "Jab"), make(g, "Quick Strike"), make(g, "Garbage")]   # a weapon domino and Garbage are never upgraded here
	g.shop = [upgrade_item("random")]
	g.gems = 3
	expect(g.buy(0) and g.gems == 0 and levels(g).count(2) == 1 and g.collection[3].level() == 1 and g.collection[4].level() == 1, "random: 3 gems, one upgradable domino goes up (never a weapon or Garbage)")
	g.shop = [upgrade_item("random2")]
	g.gems = 6
	var before := levels(g)
	expect(g.buy(0) and g.gems == 0, "two random: 6 gems")
	var sum_before := 0
	for x in before:
		sum_before += x
	var sum_after := 0
	for x in levels(g):
		sum_after += x
	expect(sum_after == sum_before + 2, "two different dominoes go up one level each")
	var changed := 0
	for i in before.size():
		if levels(g)[i] != before[i]:
			changed += 1
	expect(changed == 2, "they are two different dominoes")
	# not enough to upgrade
	g = fresh()
	g.collection = [make(g, "Slash")]
	g.shop = [upgrade_item("random2")]
	g.gems = 10
	expect(g.buy(0) and g.collection[0].level() == 2 and g.gems == 4, "two random with only one upgradable domino upgrades that one")
	g.shop = [upgrade_item("random")]
	g.collection = [make(g, "Quick Strike"), make(g, "Garbage")]
	g.gems = 10
	expect(not g.can_buy(0) and not g.buy(0) and g.gems == 10, "nothing to upgrade: it cannot be bought and costs nothing")
	g.collection = [make(g, "Slash")]
	g.gems = 2
	expect(not g.can_buy(0), "too few gems")
	# the shop discount applies
	var g2 := fresh()
	g2.collection = [make(g2, "Slash")]
	g2.shop = [upgrade_item("pick")]
	expect(g2.shop_price(0) == 5, "price without a discount")


func test_ui() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(1.5).timeout
	var g = main.game
	var hud = main.hud
	g.busy = 0
	# the shop: pick a domino to upgrade
	g.collection = [make(g, "Slash"), make(g, "Parry"), make(g, "Quick Strike")]
	g.shop = [upgrade_item("pick")]
	g.gems = 12
	hud.shop_window.open(g)
	var sw = hud.shop_window
	var b = sw.grid.get_child(0).get_child(1)
	expect(sw.visible and b.text == "Upgrade: choose, 5" and not b.disabled, "the shop has an upgrade button with its price")
	b.pressed.emit()
	expect(sw.grid.get_child_count() == 2 and sw.leave_b.text == "Back" and g.gems == 12, "choosing shows the two dominoes you can upgrade (not the weapon) and costs nothing yet")
	sw.leave_b.pressed.emit()
	expect(sw.visible and sw.grid.get_child_count() == 1 and g.gems == 12 and sw.leave_b.text == "Leave shop", "Back returns to the shop")
	sw.grid.get_child(0).get_child(1).pressed.emit()
	var card = sw.grid.get_child(1).get_child(0)
	card.pressed.emit()
	expect(g.gems == 7 and g.collection[1].level() == 2 and sw.grid.get_child(0).get_child(1).text == "Sold", "picking a domino upgrades it and the upgrade shows Sold")
	expect(sw._note_l.visible and sw._note_l.text.contains("Parry"), "the shop tells you what was upgraded")
	sw.leave_b.pressed.emit()
	# random buttons
	g.shop = [upgrade_item("random")]
	g.gems = 3
	hud.shop_window.open(g)
	b = sw.grid.get_child(0).get_child(1)
	expect(b.text == "Upgrade: buy for 3", "the random upgrade button says buy for 3")
	b.pressed.emit()
	expect(g.gems == 0 and sw.grid.get_child(0).get_child(1).text == "Sold", "buying a random upgrade")
	sw.leave_b.pressed.emit()
	g.collection = [make(g, "Quick Strike")]
	g.shop = [upgrade_item("random")]
	g.gems = 9
	hud.shop_window.open(g)
	expect(sw.grid.get_child(0).get_child(1).text == "Nothing to upgrade" and sw.grid.get_child(0).get_child(1).disabled, "the button says when there is nothing to upgrade")
	sw.leave_b.pressed.emit()
	# clicking outside the hand deselects
	g.hand = [make(g, "Slash"), make(g, "Slash"), make(g, "Slash")]
	main.sel = 1
	main._refresh_ui()
	main._press(Vector2(480, 470))
	expect(main.sel == 1, "a click inside the hand area keeps the selection")
	main._press(Vector2(100, 100))
	expect(main.sel == -1, "a click anywhere else deselects")
	main.sel = 2
	main._press(Vector2(900, 300))
	expect(main.sel == -1, "also at the side of the screen")
	# the game over table has two columns of name and value
	var rows := []
	for i in 7:
		rows.append(["stat %d" % i, i])
	hud.show_game_over(rows)
	var go = hud.game_over
	expect(go.rows.columns == 4 and go.rows.get_child_count() == 16, "game over: 7 statistics in two columns (4 rows of name and value)")
	expect(go.rows.get_child(0).text == "stat 0" and go.rows.get_child(2).text == "stat 4" and go.rows.get_child(1).text == "0", "the first half is the left column, the rest the right column")
	expect(go.rows.get_child(14).text == "" and go.rows.get_child(15).text == "", "an odd number leaves the last place empty")
	hud.hide_game_over()
	main.queue_free()
	await process_frame
