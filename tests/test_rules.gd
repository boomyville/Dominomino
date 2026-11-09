extends SceneTree
## Headless rule tests. Run from the project folder:
##   godot --headless -s tests/test_rules.gd
## Exits with the number of failures.

const Game = preload("res://scripts/game.gd")
const Skills = preload("res://scripts/skills.gd")

var fails := 0


func expect(cond: bool, label: String) -> void:
	if cond:
		print("PASS  ", label)
	else:
		fails += 1
		print("FAIL  ", label)


func mk(x: int, y: int, rot: int, a: int, b: int) -> Dictionary:
	return {"x": x, "y": y, "rot": rot, "a": a, "b": b}


func _init() -> void:
	randomize()
	var g := Game.new()

	# not touching the player's character
	expect(g.check(mk(5, 5, 0, 1, 1)).why == "Connect to your character", "must connect to own character")
	# player footprint is x 14..16, y 8..10
	expect(g.check(mk(14, 8, 0, 1, 1)).why == "Space taken", "cannot overlap a character")
	var r := g.check(mk(12, 8, 0, 3, 6))
	expect(r.ok and r.cost == 9, "3|6 touching only the character costs 9")
	g.hand = [{"a": 3, "b": 6, "ang": 0}]
	var m := mk(12, 8, 0, 3, 6)
	m.i = 0
	expect(g.commit_player(m), "commit 3|6")
	expect(g.energy == 1 and g.hand.size() == 0, "energy 10 -> 1, domino leaves hand")
	expect(g.check(mk(12, 8, 0, 1, 1)).why == "Space taken", "cannot overlap a domino")
	expect(g.check(mk(11, 7, 1, 5, 2)).why == "Pips must match", "touching pips must match")
	expect(g.check(mk(12, 9, 0, 3, 6)).why == "Touches same domino twice", "touch the same domino only once")
	g.energy = 5
	r = g.check(mk(11, 8, 1, 3, 2))
	expect(r.ok and r.cost == 2, "touching half is free, other half costs its pips")
	g.energy = 1
	expect(g.check(mk(11, 8, 1, 3, 2)).why == "Needs 2 energy", "not enough energy")
	expect(g.check(mk(11, 8, 1, 3, 2), true).ok, "free flag ignores energy")

	# can_play
	g.reset()
	g.energy = 0
	expect(not g.can_play({"a": 6, "b": 6}), "6|6 unplayable with 0 energy")
	g.energy = 12
	g._cache.clear()
	expect(g.can_play({"a": 6, "b": 6}), "6|6 playable with 12 energy")

	# CPU only builds legal dominoes from its own side
	g.reset()
	var played := 0
	for i in 12:
		if g.cpu_play():
			played += 1
	expect(played > 0 and g.stats.cpu == played, "cpu plays dominoes (%d)" % played)
	var all_cpu := true
	for p in g.placed:
		if p.owner != "c":
			all_cpu = false
	expect(all_cpu, "cpu dominoes are owned by the computer")

	# turn flow
	g.reset()
	expect(g.begin_end_turn() == true and g.lives == 2, "no play -> lose a life")
	g.start_new_turn()
	expect(g.energy == Game.MAXE and g.turn == 2, "new turn resets energy")

	# skills
	var names := {}
	for lo in 7:
		for hi in range(lo, 7):
			var sk := Skills.skill(lo, hi)
			names[sk.name] = true
			print("SKILL ", lo, "|", hi, " ", sk.name, " | ", sk.desc, " | ", sk.power)
	expect(names.size() == 28, "28 unique skill names")
	expect(Skills.skill(6, 3).name == Skills.skill(3, 6).name, "skill name ignores pip order")

	print("FAILURES: ", fails)
	quit(fails)
