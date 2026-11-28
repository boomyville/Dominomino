extends SceneTree
## Tests for the title screen, the library numbers, saving and loading, the boons and the new run flow, the new common
## weapons, Beginner's Luck, and the pause before the victory screen. Run:
##   godot --headless -s tests/test_title.gd

const Game = preload("res://scripts/game.gd")
const Foe = preload("res://scripts/foe.gd")
const Dominoes = preload("res://scripts/dominoes.gd")
const Relics = preload("res://scripts/relics/relics.gd")
const Library = preload("res://scripts/library.gd")
const SaveGame = preload("res://scripts/save_game.gd")
const Boons = preload("res://scripts/boons.gd")
const LibraryWindow = preload("res://scripts/library_window.gd")

const TEST_SAVE := "user://test_save.dat"
const TEST_LIB := "user://test_library.dat"

var fails := 0
var checks := 0


## A UI that remembers the choices it was asked for (and answers with the first one) and the order of things.
class RecUI extends "res://scripts/null_ui.gd":
	var screens: Array = []
	var order: Array = []

	func pick(title: String, _sub: String, list: Array, _skip: String = "") -> int:
		screens.append({"title": title, "list": list.duplicate()})
		return 0

	func pause(sec: float) -> void:
		order.append("pause %.1f" % sec)

	func victory(_g, _summary: Dictionary) -> void:
		order.append("victory")


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


func _initialize() -> void:
	SaveGame.path = TEST_SAVE
	Library.path = TEST_LIB
	SaveGame.delete()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_LIB))
	Library.reset_memory()
	test_library()
	test_save()
	await test_boons()
	await test_intro()
	await test_new_dominoes()
	await test_pause()
	await test_title_ui()
	SaveGame.delete()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_LIB))
	print("CHECKS: ", checks, "  FAILURES: ", fails)
	quit(fails)


func test_library() -> void:
	Library.reset_memory()
	Library.offer("domino", "Slash", "reward")
	Library.offer("domino", "Slash", "reward")
	Library.skip("domino", "Slash", "reward")
	Library.offer("artifact", "iron_cloak", "shop")
	Library.skip("artifact", "iron_cloak", "shop")
	Library.use("Slash", 2)
	Library.use("Slash", 0)
	var s := Library.get_stats("domino", "Slash")
	expect(s.offered_reward == 2 and s.skipped_reward == 1 and s.used == 2 and s.wait == 2, "the library counts offers, skips and plays")
	expect(Library.average_wait("domino", "Slash") == 1.0, "and the average wait in hand before a domino is played")
	expect(Library.get_stats("domino", "Never seen").offered_reward == 0, "an item never seen has all zeros")
	Library.flush()
	expect(FileAccess.file_exists(TEST_LIB), "flush writes the numbers to disk")
	Library.stats = {}
	Library._loaded = false
	expect(Library.get_stats("domino", "Slash").used == 2 and Library.get_stats("artifact", "iron_cloak").skipped_shop == 1, "and they come back after a restart")
	# rewards in a game
	Library.reset_memory()
	var g := Game.new()
	g.battle_no = 1
	var opts: Array = g._begin_reward()
	for d in opts:
		expect_silent(Library.get_stats("domino", d.data.title).offered_reward == 1)
	g._take_domino(1, opts)
	expect(Library.get_stats("domino", opts[0].data.title).skipped_reward == 1 and Library.get_stats("domino", opts[1].data.title).skipped_reward == 0
			and Library.get_stats("domino", opts[2].data.title).skipped_reward == 1, "a reward screen: the domino you took is not skipped, the others are")
	var g2 := Game.new()
	g2.battle_no = 1
	var opts2: Array = g2._begin_reward()
	g2._take_domino(-1, opts2)
	var all_skipped := true
	for d in opts2:
		all_skipped = all_skipped and Library.get_stats("domino", d.data.title).skipped_reward >= 1
	expect(all_skipped, "skipping the screen skips all three")
	# shops
	Library.reset_memory()
	var h := fresh()
	h.shop = h.generate_shop()
	var offered := 0
	for it in h.shop:
		if it.kind != "upgrade":
			var kind: String = h._library_kind(it.kind)
			offered += Library.get_stats(kind, h._library_id(it)).offered_shop
	expect(offered >= 8, "every item of a new shop counts as offered (%d)" % offered)
	h.gems = 0
	h.leave_shop()
	var skipped := 0
	for it in h.shop:
		if it.kind != "upgrade":
			skipped += Library.get_stats(h._library_kind(it.kind), h._library_id(it)).skipped_shop
	expect(skipped == 0, "leaving a shop with no gems skips nothing: you could not buy anything")
	var h2 := fresh()
	h2.shop = h2.generate_shop()
	h2.gems = 100
	h2.buy(0)
	h2.leave_shop()
	h2.leave_shop()
	var sk := 0
	var bought_ok := true
	for i in h2.shop.size():
		var it = h2.shop[i]
		if it.kind == "upgrade":
			continue
		var st := Library.get_stats(h2._library_kind(it.kind), h2._library_id(it))
		sk += st.skipped_shop
		if it.sold:
			bought_ok = bought_ok and st.skipped_shop == 0
	expect(sk >= 6 and bought_ok, "with the gems to buy everything, the things you left count as skipped (once each): %d" % sk)
	# use and wait
	Library.reset_memory()
	var p := fresh()
	var d = make(p, "Slash")
	d.roll_all(p.rng)
	p.history.turn = 1
	p._enter_hand(d, "stack")
	p.history.turn = 3
	p.hand = [d]
	p.energy = 99
	var sp = find_spot(p, d.a, d.b)
	var wait_ok := sp != null
	if sp != null:
		p.play_domino({"x": sp.x, "y": sp.y, "rot": sp.rot, "a": d.a, "b": d.b, "i": 0})
	var us := Library.get_stats("domino", "Slash")
	expect(wait_ok and us.used == 1 and us.wait == 2, "playing a domino notes that it waited 2 turns in your hand")


func expect_silent(cond: bool) -> void:
	if not cond:
		fails += 1
		checks += 1
		print("FAIL  (silent check)")


func find_spot(g: Game, a: int, b: int):
	for r in 4:
		var dm := Game.dims(r)
		for x in range(0, Game.N - int(dm.x) + 1):
			for y in range(0, Game.N - int(dm.y) + 1):
				if g.check({"x": x, "y": y, "rot": r, "a": a, "b": b}).ok:
					return {"x": x, "y": y, "rot": r}
	return null


func test_save() -> void:
	expect(not SaveGame.exists(), "there is no save at first")
	var g := Game.new()
	g.collection[2].upgrade()
	g.collection[2].upgrade()
	g.gems = 17
	g.weapon.upgrade()
	g.add_relic(Relics.by_id("spiked_buckler"))
	g.add_relic(Relics.by_id("fragile_gauntlet"))
	g.relics[g.relics.size() - 1].counter = 2
	g.stored_weapons.append(Relics.by_id("machete"))
	g.max_hp_bonus = 20
	var risky = make(g, "Risky Manoeuvre")
	risky.roll_all(g.rng)
	g.hand.append(risky)
	g.energy = 99
	var sp = find_spot(g, g.hand[0].a, g.hand[0].b)
	g.play_domino({"x": sp.x, "y": sp.y, "rot": sp.rot, "a": g.hand[0].a, "b": g.hand[0].b, "i": 0})
	g.snapshot_turn()
	expect(SaveGame.write(g) and SaveGame.exists(), "write saves the run")
	var h := Game.new()
	expect(SaveGame.read_into(h), "and read_into loads it")
	expect(h.collection.size() == g.collection.size() and h.collection[2].level() == 3 and h.collection[2].data.title == g.collection[2].data.title,
			"the collection and the levels of its dominoes come back")
	expect(h.weapon.title == g.weapon.title and h.weapon.level == 2 and h.stored_weapons.size() == 1 and h.stored_weapons[0].title == "Machete", "so do the weapons and their levels")
	var counters := []
	for r in h.relics:
		counters.append("%s:%d" % [r.id, r.counter])
	expect(counters.has("fragile_gauntlet:2") and counters.has("spiked_buckler:0"), "artifacts keep their counters %s" % str(counters))
	expect(h.gems == 17 and h.battle_no == g.battle_no and h.seed_value == g.seed_value and h.max_hp_bonus == 20 and h.lives == g.lives, "gems, battle, seed, lives and max HP bonus")
	expect(h.hand.size() == g.turn_snap.hand.size() and h.stack.size() == g.turn_snap.stack.size() and h.discard.size() == g.turn_snap.discard.size(),
			"the piles are as they were at the start of the turn")
	var same_hand := true
	for i in h.hand.size():
		same_hand = same_hand and h.hand[i].data.title == g.turn_snap.hand[i].d.data.title and h.hand[i].a == g.turn_snap.hand[i].a and h.hand[i].b == g.turn_snap.hand[i].b
	expect(same_hand, "with the same dominoes and pips in the same places")
	expect(h.foe.hp == g.turn_snap.foe.hp and h.foe.lv == g.foe.lv and h.pl.hp == g.turn_snap.pl.hp and h.energy == g.turn_snap.energy, "both fighters and the energy")
	expect(h.rng.state == g.turn_snap.rng and h.history.turn == g.history.turn, "the random numbers and the turn")
	expect(not h.turn_snap.is_empty() and h.busy == 0 and not h.ended, "and the turn can be restarted again")
	# board and rolled pips
	var board := Game.new()
	var r2 = make(board, "Risky Manoeuvre")
	r2.roll_all(board.rng)
	board.hand = [r2]
	board.energy = 99
	var spot = find_spot(board, r2.a, r2.b)
	board.play_domino({"x": spot.x, "y": spot.y, "rot": spot.rot, "a": r2.a, "b": r2.b, "i": 0})
	board.stack.append(r2)
	board.snapshot_turn()
	SaveGame.write(board)
	var b2 := Game.new()
	SaveGame.read_into(b2)
	expect(b2.placed.size() == board.placed.size() and b2.occ.size() == board.occ.size() and b2.occ.size() > 0, "dominoes on the board come back (%d cells)" % b2.occ.size())
	var found = null
	for d in b2.stack:
		if d.data.title == "Risky Manoeuvre":
			found = d
	expect(found != null and found.rolled and found.specs[0].text() == "3-6" and found.a == r2.a and found.specs[0].is_volatile(), "ranges, rolled values and volatile pips are kept")
	# a save with no battle
	SaveGame.delete()
	var empty := Game.new(); empty.turn_snap = {}
	expect(not SaveGame.write(empty) and not SaveGame.exists() and not SaveGame.read_into(Game.new()), "nothing to save before the first turn, and nothing to load")
	SaveGame.delete()


func test_boons() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var picked := Boons.pick(rng, 3)
	var ids := {}
	for b in picked:
		ids[b.id] = true
	expect(picked.size() == 3 and ids.size() == 3 and Boons.LIST.size() == 9, "3 different boons out of the 9")
	var g := Game.new()
	g.new_game(-1, false)
	var ui := RecUI.new()
	g.ui = ui
	var before := 0
	for d in g.collection:
		before += d.level()
	await Boons.apply(g, {"id": "upgrade3"})
	var after := 0
	for d in g.collection:
		after += d.level()
	expect(after == before + 3, "Upgrade 3 dominoes: three go up a level")
	var n: int = g.collection.size()
	await Boons.apply(g, {"id": "remove2"})
	expect(g.collection.size() == n - 2 and ui.screens.size() == 2, "Remove 2 dominoes: you choose two (and they are gone)")
	await Boons.apply(g, {"id": "maxhp"})
	expect(g.base_max_hp() == 70 and g.pl.max_hp == 70 and g.pl.hp == 70, "+20 max HP")
	ui.screens.clear()
	var coll0: int = g.collection.size()
	await Boons.apply(g, {"id": "rare3"})
	var rare_ok: bool = ui.screens.size() == 1 and ui.screens[0].list.size() == 3
	for d in ui.screens[0].list:
		rare_ok = rare_ok and d.data.rarity == "r"
	expect(rare_ok and g.collection.size() == coll0 + 1 and g.collection.back().data.rarity == "r", "a reward screen with 3 rare dominoes (one is taken)")
	ui.screens.clear()
	await Boons.apply(g, {"id": "weapon2"})
	var wlist: Array = ui.screens[0].list
	var common_ok := wlist.size() == 2
	for w in wlist:
		common_ok = common_ok and w.rarity == "c" and w.weapon and w.title != "Short Sword"
	expect(common_ok and g.weapon.title == wlist[0].title and g.stored_weapons.size() == 1 and g.stored_weapons[0].title == "Short Sword",
			"a reward screen with 2 common weapons (not the Short Sword): the chosen one is equipped and the old one stored")
	ui.screens.clear()
	await Boons.apply(g, {"id": "artifact2"})
	var alist: Array = ui.screens[0].list
	var a_ok := alist.size() == 2
	for a in alist:
		a_ok = a_ok and a.rarity == "c" and not a.weapon
	expect(a_ok and g.has_relic(alist[0].id), "a reward screen with 2 common artifacts")
	await Boons.apply(g, {"id": "weapon_u"})
	expect(g.weapon.rarity == "u", "a random uncommon weapon is equipped")
	var relics0: int = g.relics.size() + g.stored_relics.size()
	await Boons.apply(g, {"id": "artifact_u"})
	var got_u := false
	for r in g.relics + g.stored_relics:
		got_u = got_u or r.rarity == "u"
	expect(g.relics.size() + g.stored_relics.size() == relics0 + 1 and got_u, "a random uncommon artifact")
	await Boons.apply(g, {"id": "luck"})
	var luck = g.collection.back()
	expect(luck.data.title == "Beginner's Luck" and luck.data.rarity == "l", "Beginner's Luck joins the collection")
	expect(Library.get_stats("weapon", wlist[0].id).offered_reward >= 1 and Library.get_stats("weapon", wlist[1].id).skipped_reward >= 1, "the library counts the weapon reward screen (offered, and the other one skipped)")
	# Beginner's Luck
	var l = make(g, "Beginner's Luck")
	expect(l.total() == 0 and l.data.ephemeral and l.type() == "skill" and not l.can_upgrade() and l.can_downgrade() and l.max_level() == 1, "Beginner's Luck: 0|0, ephemeral, legendary: it cannot be upgraded but it can be downgraded")
	g.energy = 3
	l.roll_all(g.rng)
	await g.run_fx(l)
	expect(g.energy == 9 and g.fx_lines(l)[0] == "Gain 6 energy", "it gains 6 energy")
	l.downgrade()
	g.energy = 3
	await g.run_fx(l)
	expect(g.energy == 6 and l.level() == 0 and l.data.ephemeral and l.display_name() == "Beginner's Luck-", "downgraded it gains 3 energy and stays ephemeral")
	expect(not l.downgrade() and l.upgrade() and l.level() == 1 and not l.upgrade(), "(a legendary domino has just the two levels: upgrading a downgraded one only brings it back)")


func test_intro() -> void:
	var g := Game.new()
	g.new_game(-1, false)
	var ui := RecUI.new()
	g.ui = ui
	expect(g.turn_snap.is_empty(), "with begin = false the first battle waits")
	await g.run_intro()
	expect(ui.screens.size() >= 4 and ui.screens[0].title == "Choose a boon" and ui.screens[0].list.size() == 3, "a run starts with a choice of 3 boons")
	var starts := ui.screens.filter(func(s): return s.title.begins_with("Starting reward"))
	expect(starts.size() == 3, "then 3 starting reward screens")
	var all_common := true
	var seen := {}
	var distinct := true
	for s in starts:
		expect_silent(s.list.size() == 3)
		for d in s.list:
			all_common = all_common and d.data.rarity == "c"
			distinct = distinct and not seen.has(d.data.id)
			seen[d.data.id] = true
	expect(all_common and distinct, "all common dominoes, and no domino twice across them")
	expect(not g.turn_snap.is_empty() and g.hand.size() > 0 and g.history.turn == 1, "and then the first battle starts")
	var taken := 0
	for d in g.collection:
		if d.origin == "collection":
			taken += 1
	expect(taken >= 20, "the dominoes you took are in your collection (%d)" % taken)


func test_new_dominoes() -> void:
	# weapons
	var all := Relics.build_weapons()
	var by := {}
	for w in all:
		by[w.rarity] = by.get(w.rarity, []) + [w.id]
	expect(by.c.size() == 4 and by.u.size() == 3 and by.r.size() == 1, "weapons: 4 common (Short Sword, Rapier, Machete, Swift Sword), 3 uncommon, 1 rare")
	expect(by.c.has("rapier") and by.c.has("machete") and by.c.has("swift_sword") and by.u.has("duelists_blade"), "the old uncommon Rapier is now the Duelist's Blade")
	# Rapier Thrust
	var g := fresh()
	var thrust = make(g, "Rapier Thrust")
	thrust.roll_all(g.rng)
	g.foe.shield = 10
	var hp0: int = g.foe.hp
	await g.run_fx(thrust)
	expect(g.foe.shield == 0 and hp0 - g.foe.hp == 7, "Rapier Thrust removes all the enemy's shield, then deals its 7 damage (all of it gets through)")
	# Machete Chop
	var chop = make(g, "Machete Chop")
	chop.roll_all(g.rng)
	g.foe.shield = 3
	hp0 = g.foe.hp
	await g.run_fx(chop)
	expect(hp0 - g.foe.hp == 2 and g.foe.shield == 0, "Machete Chop: normal damage against a shield (5 - 3)")
	hp0 = g.foe.hp
	await g.run_fx(chop)
	expect(hp0 - g.foe.hp == 10, "and double damage when the enemy has no shield (10)")
	expect(g.fx_lines(chop)[0].contains("double if the enemy has no shield") and g.fx_lines(chop)[0].contains("10 now"), "its text says so: %s" % g.fx_lines(chop)[0])
	var sim_ok := true
	g.hand = [chop]
	g.foe.shield = 0
	sim_ok = g.preview_player_attack(0).hp == 10
	expect(sim_ok, "and the preview agrees")
	# Swift Strike
	var h := fresh()
	var swift = make(h, "Swift Strike")
	swift.roll_all(h.rng)
	h.hand = [swift, make(h, "Slash"), make(h, "Slash"), make(h, "Slash"), make(h, "Parry")]
	h.stack = [make(h, "Slash"), make(h, "Slash"), make(h, "Slash"), make(h, "Slash")]
	h.history.turn = 1
	expect(h.cond_ok(0), "Swift Strike can be played on turn 1")
	h.history.turn = 2
	expect(not h.cond_ok(0), "but not later")
	h.hand.remove_at(0)
	hp0 = h.foe.hp
	var discards0: int = h.discard.size()
	await h.run_fx(swift)
	expect(hp0 - h.foe.hp == 10 and h.discard.size() == discards0 + 3, "it hits for 10, draws 3 and discards 3 random dominoes")
	# weapon placement
	var w := Game.new()
	w.weapon = Relics.by_id("swift_sword")
	w.collection = []
	w.start_battle()
	var ss := 0
	var in_hand := false
	for d in w.hand + w.stack:
		if d.data.title == "Swift Strike":
			ss += 1
			in_hand = w.hand.has(d)
	expect(ss == 1 and in_hand and w.hand.size() > 0, "the Swift Sword puts its Swift Strike on top of the stack: it is in your first hand")
	var r := Game.new()
	r.weapon = Relics.by_id("rapier")
	r.weapon.upgrade()
	r.collection = []
	r.start_battle()
	var level_ok := true
	var thr := 0
	for d in r.hand + r.stack:
		if d.data.title == "Rapier Thrust":
			thr += 1
			level_ok = level_ok and d.level() == 2 and d.origin == "equipment"
	expect(thr == 3 and level_ok, "a level 2 Rapier adds 3 level 2 Rapier Thrusts, tagged as equipment")


func test_pause() -> void:
	var g := fresh()
	var ui := RecUI.new()
	g.ui = ui
	g.foe.hp = 0
	await g.battle_won()
	var at_pause: int = ui.order.find("pause 1.0")
	var at_victory: int = ui.order.find("victory")
	expect(at_pause >= 0 and at_victory > at_pause, "a 1 second pause comes before the victory screen %s" % str(ui.order))


func test_title_ui() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(1.5).timeout
	var g = main.game
	var hud = main.hud
	expect(hud.title_screen.visible and not main.run_active, "the game starts at the title screen")
	expect(hud.title_screen.load_b.disabled, "Load game is greyed out without a save")
	expect(hud.title_screen.achievements_b.disabled, "Achievements come later")
	hud.show_title(true)
	expect(not hud.title_screen.load_b.disabled, "Load game works when there is a save")
	# settings and library from the title screen
	hud.title_screen.settings_pressed.emit()
	expect(hud.settings_window.visible, "Settings opens from the title screen")
	hud.settings_window.close_b.pressed.emit()
	hud.title_screen.library_pressed.emit()
	var lib = hud.library_window
	var kinds := 0
	for base in g.data:
		if ["c", "u", "r", "l"].has(base.rarity):
			kinds += 1
	expect(lib.visible and lib.kind == "domino" and lib.entries() == kinds, "the Library opens on the dominoes tab with every domino (%d)" % lib.entries())
	lib.tab_buttons["artifact"].pressed.emit()
	expect(lib.kind == "artifact" and lib.entries() == Relics.build().size(), "the Artifacts tab lists every artifact (%d)" % lib.entries())
	lib.tab_buttons["weapon"].pressed.emit()
	expect(lib.kind == "weapon" and lib.entries() == Relics.build_weapons().size(), "the Weapons tab lists every weapon (%d)" % lib.entries())
	Library.reset_memory()
	Library.offer("domino", "Slash", "reward")
	Library.skip("domino", "Slash", "reward")
	Library.use("Slash", 3)
	var text := LibraryWindow.stats_text("domino", "Slash")
	expect(text.contains("Offered in rewards: 1") and text.contains("skipped: 1 (100%)") and text.contains("Played: 1 times") and text.contains("3.0 turns"), "an entry shows the numbers: %s" % text.replace("\n", " | "))
	var aw := LibraryWindow.stats_text("artifact", "iron_cloak")
	expect(aw.contains("Offered in shops: 0") and not aw.contains("Played"), "artifacts and weapons show no play numbers")
	lib.close_b.pressed.emit()
	# a new run: drive the pick windows by choosing the first card each time
	Library.reset_memory()
	SaveGame.delete()
	hud.title_screen.new_game_pressed.emit()
	var guard := 0
	while not main.run_active and guard < 400:
		await process_frame
		guard += 1
		if hud.pick_window.visible:
			hud.pick_window._choose(0)
	expect(main.run_active and not hud.title_screen.visible, "New game: the boon and the starting rewards, then the battle (%d frames)" % guard)
	await create_timer(0.3).timeout
	expect(g.history.turn == 1 and g.hand.size() > 0 and not g.turn_snap.is_empty(), "the first battle has started")
	expect(SaveGame.exists(), "the run is saved at the start of the first turn")
	var seen := 0
	for k in Library.stats:
		if k.begins_with("domino:") and Library.stats[k].offered_reward > 0:
			seen += 1
	expect(seen >= 9, "the starting rewards were counted in the library (%d dominoes offered)" % seen)
	# menu -> title -> load
	var hand_titles := []
	for d in g.hand:
		hand_titles.append(d.data.title)
	g.busy = 0
	hud.menu_b.pressed.emit()
	expect(hud.title_screen.visible and not hud.title_screen.load_b.disabled, "the Menu button goes back to the title screen with a save to load")
	g.hand = []
	hud.title_screen.load_game_pressed.emit()
	await process_frame
	var loaded := []
	for d in g.hand:
		loaded.append(d.data.title)
	expect(not hud.title_screen.visible and loaded == hand_titles, "Load game puts the saved hand back %s" % str(loaded))
	main.queue_free()
	await process_frame
