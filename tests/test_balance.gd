extends SceneTree
## Balance tests: every domino's strength per energy (scripts/balance.gd) stays near the target for its rarity at
## every level, nothing is far too strong (Warlord) or too weak, and every domino at every level actually plays.
## tools/balance_report.gd prints the table behind this. Run:
##   godot --headless -s tests/test_balance.gd

const Game = preload("res://scripts/game.gd")
const Foe = preload("res://scripts/foe.gd")
const Dominoes = preload("res://scripts/dominoes.gd")
const Balance = preload("res://scripts/balance.gd")

## Dominoes that are meant to be out of the band: Garbage is worthless, Soul Tithe costs a life.
const EXEMPT := ["Garbage", "Soul Tithe"]

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
	for i in 10:
		g.stack.append(g.make_domino(Dominoes.index_of("Slash")))
	return g


func _initialize() -> void:
	test_bands()
	test_levels()
	await test_run_everything()
	print("CHECKS: ", checks, "  FAILURES: ", fails)
	quit(fails)


func test_bands() -> void:
	var g := Game.new()
	var off := []
	var by_rarity := {"c": [], "u": [], "r": []}
	var worst := {}
	for base in g.data:
		if EXEMPT.has(base.title):
			continue
		var d = g.make_domino(base.id)
		var v: float = Balance.ratio(d) / Balance.target(d.data)
		worst[base.title] = v
		if v > 1.0 + Balance.BAND or v < 1.0 - Balance.BAND:
			off.append("%s %.2f" % [base.title, v])
		if by_rarity.has(base.rarity):
			by_rarity[base.rarity].append(Balance.ratio(d))
	expect(off.is_empty(), "every domino is within %d%% of its target strength per energy %s" % [Balance.BAND * 100, str(off)])
	for r in by_rarity:
		var sum := 0.0
		for x in by_rarity[r]:
			sum += x
		var avg: float = sum / by_rarity[r].size()
		expect(abs(avg / Balance.TARGET[r] - 1.0) < 0.15, "%s dominoes average %.2f per energy (target %.1f)" % [r, avg, Balance.TARGET[r]])
	for name in ["Warlord", "Ascension", "Soul Rend", "Overwhelm", "Annihilate", "Blood Frenzy", "Sunburst", "Cutting Edge"]:
		expect(worst[name] < 1.3, "%s is no longer far too strong (%.2f of its target)" % [name, worst[name]])
	expect(Balance.score(g.make_domino(Dominoes.index_of("Slash"))) == 7.0, "Slash (1|4) is worth 7 damage points")
	var warlord = g.make_domino(Dominoes.index_of("Warlord"))
	expect(Balance.ratio(warlord) < 3.5, "Warlord gives %.1f points per energy" % Balance.ratio(warlord))


func test_levels() -> void:
	var g := Game.new()
	var bad_up := []
	var bad_down := []
	var drift := []
	for base in g.data:
		if base.max_level() <= 1 or EXEMPT.has(base.title):
			continue
		var scores := []
		for lv in range(0, base.max_level() + 1):
			var d = g.make_domino(base.id)
			d.set_level(lv)
			scores.append(Balance.score(d))
		for lv in range(2, scores.size()):
			if scores[lv] <= scores[lv - 1]:
				bad_up.append("%s L%d" % [base.title, lv])
		if scores[0] > scores[1]:
			bad_down.append(base.title)
		# a top level is never more than about double the normal one (rare 2 levels, common 4)
		if scores[scores.size() - 1] > scores[1] * 2.6 + 6.0:
			drift.append("%s %.0f -> %.0f" % [base.title, scores[1], scores[scores.size() - 1]])
	expect(bad_up.is_empty(), "every upgrade level scores higher than the one below %s" % str(bad_up.slice(0, 6)))
	expect(bad_down.is_empty(), "a downgraded domino never scores higher than the normal one %s" % str(bad_down.slice(0, 6)))
	expect(drift.is_empty(), "the top level of a domino stays reasonable %s" % str(drift.slice(0, 6)))


## Play every domino at every level once on a test board.
func test_run_everything() -> void:
	var runs := 0
	var problems := []
	var mismatch := []
	var base_g := Game.new()
	for base in base_g.data:
		for lv in range(0, base.max_level() + 1 if base.max_level() > 1 else 2):
			if base.max_level() <= 1 and lv == 0:
				continue
			var g := fresh()
			g.hand = [g.make_domino(Dominoes.index_of("Slash")), g.make_domino(Dominoes.index_of("Parry"))]
			var d = g.make_domino(base.id)
			d.set_level(lv)
			d.roll_all(g.rng)
			var foe0: int = g.foe.hp
			await g.run_fx(d)
			runs += 1
			if g.pl.hp > g.pl.max_hp or g.pl.shield < 0 or g.hand.size() > Game.MAXH or g.energy < 0 or g.foe.hp > foe0:
				problems.append("%s L%d" % [base.title, lv])
			# a plain attack deals exactly what its numbers say
			var plain := true
			var expected := 0
			for e in d.data.effects:
				if e.kind == "dmg":
					expected += e.value(e.size_for(d))
				elif e.kind == "hit":
					expected += e.value(e.size_for(d)) * e.hits
				elif ["pipdmg", "playedpips", "fury", "boost", "power", "impE", "impS"].has(e.kind):
					plain = false
			if plain and expected > 0 and foe0 - g.foe.hp != expected:
				mismatch.append("%s L%d %d vs %d" % [base.title, lv, foe0 - g.foe.hp, expected])
	expect(runs > 300, "%d dominoes (every kind at every level) were played" % runs)
	expect(problems.is_empty(), "nothing broke the game state %s" % str(problems.slice(0, 5)))
	expect(mismatch.is_empty(), "plain attacks deal exactly what they say %s" % str(mismatch.slice(0, 5)))
