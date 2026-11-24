extends SceneTree
## Tests for pip stability (stable / unstable / volatile pips), core versus current pips, the pip-based effects
## and the pips of the catalogue. Run:
##   godot --headless -s tests/test_pips.gd

const Game = preload("res://scripts/game.gd")
const Foe = preload("res://scripts/foe.gd")
const Dominoes = preload("res://scripts/dominoes.gd")
const PipSpec = preload("res://scripts/pip_spec.gd")
const PipMetric = preload("res://scripts/pip_metric.gd")
const DominoArt = preload("res://scripts/domino_art.gd")

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


func kind(g: Game, name: String) -> int:
	return Dominoes.index_of(name)


func make(g: Game, name: String):
	return g.make_domino(Dominoes.index_of(name))


func _initialize() -> void:
	test_specs()
	test_catalogue()
	test_balance()
	await test_battle_rolls()
	test_core_and_current()
	test_uptick_and_permanent()
	await test_pip_effects()
	test_text_and_art()
	test_rewind_states()
	print("CHECKS: ", checks, "  FAILURES: ", fails)
	quit(fails)


func test_specs() -> void:
	var s = PipSpec.parse(4)
	expect(s.stability == "stable" and s.lo == 4 and s.hi == 4 and not s.ranged() and s.text() == "4", "a number is a stable pip")
	var u = PipSpec.parse([1, 6, "u"])
	expect(u.stability == "unstable" and u.ranged() and not u.is_volatile() and u.text() == "1-6", "[1, 6, u] is an unstable pip written 1-6")
	var v = PipSpec.parse([3, 6, "v"])
	expect(v.stability == "volatile" and v.is_volatile() and v.contains(3) and not v.contains(2), "[3, 6, v] is a volatile pip: 2 is not in 3-6")
	expect(PipSpec.parse([4, 4, "u"]).stability == "stable", "a range of one value is just stable")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var seen := {}
	var ok := true
	for i in 300:
		var x: int = v.roll(rng)
		seen[x] = true
		ok = ok and x >= 3 and x <= 6
	expect(ok and seen.size() == 4, "rolling a 3-6 pip gives 3, 4, 5 and 6 and nothing else")
	var c = u.copy()
	c.shift(-2)
	expect(u.lo == 1 and u.hi == 6 and c.lo == 0 and c.hi == 5, "a copy is separate; shifting keeps the width and stays between 0 and 6")
	var w = PipSpec.parse([2, 4, "u"])
	w.shift(5)
	expect(w.lo == 4 and w.hi == 6, "shifting a range up stops at 6")
	expect(PipMetric.of("sum", 3, 5) == 8 and PipMetric.of("max", 3, 5) == 5 and PipMetric.of("min", 3, 5) == 3
			and PipMetric.of("diff", 3, 5) == 2 and PipMetric.of("diff", 5, 3) == 2 and PipMetric.of("prod", 3, 5) == 15,
			"sum, max, min, diff and prod of two pips")


func test_catalogue() -> void:
	var cat := Dominoes.build()
	var bad := []
	var stable := 0
	var unstable := 0
	var volatile := 0
	for d in cat:
		if d.pips.size() != 2:
			bad.append(d.title)
			continue
		for p in d.pips:
			if p.lo < 0 or p.hi > 6 or p.lo > p.hi:
				bad.append(d.title)
			match p.stability:
				"stable":
					stable += 1
				"unstable":
					unstable += 1
				"volatile":
					volatile += 1
	expect(bad.is_empty(), "every domino has two valid pips %s" % str(bad))
	expect(volatile > 0 and volatile <= 8 and unstable > volatile and stable > 10 * (unstable + volatile),
			"almost every pip is stable, a few are unstable, extremely few are volatile (%d / %d / %d)" % [stable, unstable, volatile])
	var by := {}
	for d in cat:
		by[d.title] = d
	expect(by["Chaos Force"].pip_stability() == ["unstable", "stable"] and by["Chaos Force"].pips[0].text() == "1-6" and by["Chaos Force"].pips[1].text() == "6",
			"Chaos Force: one unstable 1-6 pip and a stable 6")
	expect(by["Risky Manoeuvre"].pip_stability() == ["volatile", "volatile"] and by["Risky Manoeuvre"].pips[0].text() == "3-6" and by["Risky Manoeuvre"].pips[1].text() == "3-6",
			"Risky Manoeuvre: volatile 3-6 and 3-6")
	expect(by["Flakey Shield"].pips[0].text() == "1-6" and by["Flakey Shield"].pips[1].text() == "1-6" and by["Flakey Shield"].pips[0].is_volatile(),
			"Flakey Shield: volatile 1-6 and 1-6")
	expect(by["Product Smash"].pips[0].text() == "4-6" and by["Product Smash"].pips[1].text() == "3-6" and by["Product Smash"].pips[1].is_volatile(),
			"Product Smash: volatile 4-6 and 3-6")
	expect(by["Uptick"].pips[0].text() == "1" and by["Uptick"].pips[1].text() == "1" and not by["Uptick"].has_ranged_pips(), "Uptick is a stable 1|1")
	var noSix := true
	for d in cat:
		if d.condition != null and d.condition.id == "noSix":
			for p in d.pips:
				noSix = noSix and p.hi < 6
	expect(noSix, "a domino that needs a hand without 6s has no 6 itself")


## The stronger a domino, the higher its pips (and so the more energy it costs).
func test_balance() -> void:
	var g := Game.new()
	var sums := {"c": [], "u": [], "r": []}
	var worst_cost := 0
	var cheap := true
	var checked := 0
	for d in g.data:
		if not sums.has(d.rarity) or d.has_ranged_pips():
			continue
		var dom = g.make_domino(d.id)
		sums[d.rarity].append(dom.total())
		worst_cost = maxi(worst_cost, dom.total())
		if d.rarity == "c" and dom.total() > 6:
			cheap = false
		# damage per energy of the attack dominoes with no condition
		var dmg := 0
		for e in d.effects:
			if e.kind == "dmg":
				dmg += e.value(e.size_for(dom))
			elif e.kind == "hit":
				dmg += e.value(e.size_for(dom)) * e.hits
		if dmg > 0 and d.condition != null and d.condition.id == "":
			checked += 1
	var avg := func(a: Array) -> float:
		var t := 0.0
		for x in a:
			t += x
		return t / maxf(1.0, a.size())
	var ac: float = avg.call(sums.c)
	var au: float = avg.call(sums.u)
	var ar: float = avg.call(sums.r)
	expect(ac < au and au < ar, "rarer dominoes have higher pips on average (%.1f, %.1f, %.1f)" % [ac, au, ar])
	expect(worst_cost <= 9 and cheap, "no stable domino costs more than 9 energy, no common more than 6")
	# within one effect formula, more pips means more damage: Slash's number grows with the pips
	var slash = make(g, "Slash")
	var pricey = g.make_domino(Dominoes.index_of("Slash"), 6, 6)
	var e = slash.data.effects[0]
	expect(e.value(e.size_for(pricey)) > e.value(e.size_for(slash)), "bigger pips give a bigger effect")
	var strong := 0.0
	var weak := 0.0
	for name in ["Annihilate", "Overpower", "Last Gasp"]:
		var s = make(g, name)
		strong += s.total()
	for name in ["Jab", "Slash", "Sting"]:
		var s = make(g, name)
		weak += s.total()
	expect(strong > weak, "the big attacks have higher pips than the small ones")
	expect(make(g, "Quick Strike").total() == 2 and make(g, "Heavy Blade").total() == 7 and make(g, "Cutting Edge").total() == 1,
			"weapon dominoes keep their old pips")


func test_battle_rolls() -> void:
	var g := Game.new()
	g.collection = [make(g, "Chaos Force"), make(g, "Risky Manoeuvre"), make(g, "Slash"), make(g, "Wild Swing")]
	g.weapon = null
	g.start_battle()
	var all: Array = g.stack + g.hand
	expect(all.size() == 4, "the battle has the four dominoes")
	var settled := true
	var inrange := true
	for d in all:
		settled = settled and d.rolled
		for i in 2:
			inrange = inrange and d.specs[i].contains(d.current(i))
	expect(settled and inrange, "at the start of a battle every pip has a value inside its range")
	expect(g.collection[0].unsettled() and g.collection[0].pips_text() == "1-6|6", "your collection keeps ranges, not values (%s)" % g.collection[0].pips_text())
	var chaos = null
	var risky = null
	for d in all:
		if d.data.title == "Chaos Force":
			chaos = d
		if d.data.title == "Risky Manoeuvre":
			risky = d
	expect(chaos.b == 6 and chaos.a >= 1 and chaos.a <= 6, "Chaos Force: the stable pip is 6, the other is 1-6 (%d|%d)" % [chaos.a, chaos.b])
	# unstable pips stay for the whole battle, volatile ones are rolled every turn (in any pile)
	var first_a: int = chaos.a
	var seen := {}
	var always_in := true
	var unstable_kept := true
	for t in 40:
		g._new_turn_state()
		unstable_kept = unstable_kept and chaos.a == first_a
		seen["%d|%d" % [risky.a, risky.b]] = true
		always_in = always_in and risky.a >= 3 and risky.a <= 6 and risky.b >= 3 and risky.b <= 6
	expect(unstable_kept, "an unstable pip keeps its value turn after turn")
	expect(always_in and seen.size() > 3, "a volatile domino gets new values every turn, always inside 3-6 (%d different)" % seen.size())
	for pile_name in ["stack", "hand", "discard"]:
		var g2 := fresh()
		var v = make(g2, "Product Smash")
		v.roll_all(g2.rng)
		g2.get(pile_name).append(v)
		var vals := {}
		for t in 30:
			g2._roll_volatile_pips()
			vals[v.total()] = true
		expect(vals.size() > 2, "volatile pips are rerolled in the %s too" % pile_name)
	# on the board the pips never change
	var g3 := fresh()
	var played = make(g3, "Risky Manoeuvre")
	played.roll_all(g3.rng)
	g3.placed.append({"owner": "p", "a": played.a, "b": played.b})
	var pa: int = played.a
	var pb: int = played.b
	for t in 20:
		g3._roll_volatile_pips()
	expect(g3.placed[0].a == pa and g3.placed[0].b == pb, "once played on the board a volatile domino keeps its pips")
	# a battle starts again from the same seed with the same pips
	var g4 := Game.new()
	g4.collection = [make(g4, "Risky Manoeuvre"), make(g4, "Chaos Force")]
	g4.weapon = null
	g4.start_battle()
	var before := []
	for d in g4.stack + g4.hand:
		before.append(d.pips_text() + d.data.title)
	g4.start_battle()
	var after := []
	for d in g4.stack + g4.hand:
		after.append(d.pips_text() + d.data.title)
	before.sort()
	after.sort()
	expect(before == after, "restarting a battle rolls the same pips (the seed)")
	var g5 := fresh()
	g5.collection = [make(g5, "Slash")]
	g5.generate_into_stack(0)
	var n0: int = g5.stack.size()
	g5.generate_into_stack(5)
	var new_ok := g5.stack.size() == n0 + 5
	for d in g5.stack:
		new_ok = new_ok and (d.rolled or not d.has_ranged())
	expect(new_ok, "dominoes added to the stack in a battle are rolled")


func test_core_and_current() -> void:
	var g := fresh()
	var slash = make(g, "Slash")
	expect(slash.a == 1 and slash.b == 4 and slash.core(0) == 1 and slash.core(1) == 4, "Slash has its kind's pips: 1|4")
	var copy = slash.copy()
	copy.specs[0].shift(3)
	expect(slash.specs[0].lo == 1 and g.data[Dominoes.index_of("Slash")].pips[0].lo == 1, "a copy has its own core pips; the kind is not changed")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var risky = make(g, "Risky Manoeuvre")
	risky.roll_all(rng)
	var moved := false
	for i in 40:
		risky.reroll(rng)
		moved = moved or risky.a != risky.core(0)
		expect_silent(risky.a >= 3 and risky.b >= 3)
	expect(risky.specs[0].text() == "3-6", "a reroll keeps the core pips")
	var stable_seen := {}
	for i in 80:
		slash.reroll(rng)
		stable_seen[slash.a] = true
	expect(stable_seen.size() > 3 and slash.core(0) == 1 and slash.core(1) == 4, "a reroll can give a stable pip any value but the core pips stay")
	var inside := true
	for i in 80:
		risky.reroll(rng)
		inside = inside and risky.a >= 3 and risky.a <= 6 and risky.b >= 3 and risky.b <= 6
	expect(inside, "a reroll of a ranged pip stays inside its range")
	# rerolls in a battle end with the battle
	g.collection = [make(g, "Slash")]
	g.weapon = null
	g.start_battle()
	var in_battle = g.hand[0] if g.hand.size() > 0 else g.stack[0]
	g.hand = [in_battle]
	g.reroll_hand()
	g.reroll_card(0)
	expect(g.collection[0].a == 1 and g.collection[0].b == 4, "rerolled pips never change the domino in your collection")
	g.start_battle()
	var again = g.hand[0] if g.hand.size() > 0 else g.stack[0]
	expect(again.a == 1 and again.b == 4, "the next battle starts from the core pips again")
	slash.reset_to_core()
	expect(slash.a == 1 and slash.b == 4, "reset_to_core puts the core pips back")


func expect_silent(cond: bool) -> void:
	if not cond:
		fails += 1
		checks += 1
		print("FAIL  (silent check)")


func test_uptick_and_permanent() -> void:
	var g := fresh()
	var d = g.make_domino(Dominoes.index_of("Slash"), 3, 6)
	g.hand = [d]
	g.uptick_card(0)
	expect(d.a == 4 and d.b == 6, "Uptick adds 1 to both pips and never goes past 6")
	expect(d.core(0) == 3 and d.core(1) == 6, "an Uptick is temporary: the core pips stay")
	d.shift_core(0, -2)
	expect(d.core(0) == 1 and d.a == 1, "a permanent change moves the core pip (cheaper to play)")
	d.shift_core(1, -9)
	expect(d.core(1) == 0 and d.b == 0, "pips never go below 0")
	var r = make(g, "Risky Manoeuvre")
	r.shift_core(0, -1)
	expect(r.specs[0].text() == "2-5" and r.specs[1].text() == "3-6", "a permanent change moves a whole range")


func test_pip_effects() -> void:
	var g := fresh()
	var d = make(g, "Risky Manoeuvre")
	d.roll_all(g.rng)
	d.a = 4
	d.b = 6
	g.hand = [d]
	await g.run_fx(d)
	expect(g.foe.hp == 500 - 24, "Risky Manoeuvre deals the product of its pips (4 x 6 = 24)")
	g = fresh()
	d = make(g, "Product Smash")
	d.roll_all(g.rng)
	d.a = 5
	d.b = 3
	g.hand = [d]
	await g.run_fx(d)
	expect(g.foe.hp == 500 - 15, "Product Smash: 5 x 3 = 15")
	g = fresh()
	d = make(g, "Flakey Shield")
	d.roll_all(g.rng)
	d.a = 2
	d.b = 6
	g.hand = [d]
	var max0: int = g.pl.max_shield
	await g.run_fx(d)
	expect(g.pl.shield == 4 and g.pl.max_shield == max0 + 2, "Flakey Shield: shield = difference (4), max shield + lowest pip (2)")
	g = fresh()
	d = make(g, "Chaos Force")
	d.roll_all(g.rng)
	d.a = 3
	d.b = 6
	g.hand = [d]
	await g.run_fx(d)
	expect(g.pl.value("power") == 3, "Chaos Force grants Power equal to the lowest pip")
	g = fresh()
	d = make(g, "Wild Swing")
	d.roll_all(g.rng)
	d.a = 4
	d.b = 2
	g.hand = [d]
	await g.run_fx(d)
	expect(g.foe.hp == 500 - 9, "Wild Swing: highest pip x 2 + 1 = 9")
	g = fresh()
	d = make(g, "Skew Strike")
	d.roll_all(g.rng)
	d.a = 1
	d.b = 6
	g.hand = [d]
	await g.run_fx(d)
	expect(g.foe.hp == 500 - 18, "Skew Strike: difference x 3 + 3 = 18")
	g = fresh()
	var up = make(g, "Uptick")
	var target = g.make_domino(Dominoes.index_of("Slash"), 2, 5)
	g.hand = [target]
	await g.run_fx(up)
	expect(target.a == 3 and target.b == 6, "the Uptick domino raises both pips of the domino you pick")
	# the preview agrees with the real damage for a pip-based attack
	g = fresh()
	d = make(g, "Risky Manoeuvre")
	d.roll_all(g.rng)
	d.a = 5
	d.b = 4
	g.hand = [d]
	expect(g.preview_player_attack(0).hp == 20, "the damage preview uses the product too")


func test_text_and_art() -> void:
	var g := fresh()
	var d = make(g, "Risky Manoeuvre")
	expect(d.unsettled() and d.pips_text() == "3-6|3-6", "before a battle the pips read as ranges")
	var lines: Array = g.fx_lines(d)
	expect(lines[0] == "Deal 9-36 damage (the product of the pips)", "so does the text: '%s'" % lines[0])
	var look: Array = DominoArt.sides(d)
	expect(look[0].label == "3-6" and look[0].mark == "v" and look[1].mark == "v", "the picture shows the ranges and a volatile mark")
	d.roll_all(g.rng)
	d.a = 4
	d.b = 5
	expect(not d.unsettled() and d.pips_text() == "4|5" and g.fx_lines(d)[0] == "Deal 20 damage (the product of the pips)", "once rolled the real numbers show")
	look = DominoArt.sides(d)
	expect(look[0].label == "" and look[0].mark == "v", "a rolled volatile half shows pips and keeps its mark")
	var chaos = make(g, "Chaos Force")
	expect(DominoArt.sides(chaos)[0].mark == "u" and DominoArt.sides(chaos)[1].mark == "", "unstable halves get a different mark; stable halves none")
	g.hand = [make(g, "Wild Swing")]
	expect(g.caps(0)[0].num == "3-11", "the number under a hand domino is a range too while unrolled (%s)" % g.caps(0)[0].num)
	var slash = make(g, "Slash")
	expect(g.fx_lines(slash)[0] == "Deal 7 damage", "a stable domino reads as before")
	var span: Vector2i = chaos.total_span()
	expect(span.x == 7 and span.y == 12, "the total of Chaos Force is 7 to 12 until the battle")


func test_rewind_states() -> void:
	var g := fresh()
	var d = make(g, "Risky Manoeuvre")
	d.roll_all(g.rng)
	var states: Array = g._states([d])
	var a0: int = d.a
	var b0: int = d.b
	d.a = 3
	d.b = 3
	d.rolled = false
	g._restore_pile(states)
	expect(d.a == a0 and d.b == b0 and d.rolled, "rewinding a turn puts the pips back")
