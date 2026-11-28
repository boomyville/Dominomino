extends RefCounted
## The saved run (user://save.dat). It is written at the start of every turn (Game.snapshot_turn), and when you die, and
## it holds everything needed to carry on from the start of that turn: your collection, artifacts and weapons (with their
## levels and counters), and the battle as it was when the turn began (piles, board, both fighters, the random numbers).
## Saving mid-turn is not needed: Load game puts you back at the start of the turn you were in.
## Tests set `path` to another file so they never touch the player's save.

const PipSpec = preload("res://scripts/pip_spec.gd")
const Relics = preload("res://scripts/relics/relics.gd")
const Foe = preload("res://scripts/foe.gd")

static var path := "user://save.dat"
const VERSION := 1


static func exists() -> bool:
	return FileAccess.file_exists(path)


static func delete() -> void:
	if exists():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Save the run. False if there is nothing to save (no battle turn has started).
static func write(g) -> bool:
	if g.turn_snap.is_empty():
		return false
	var t: Dictionary = g.turn_snap
	var objs := []
	var index := {}
	var reg := func(d) -> int:
		if not index.has(d):
			index[d] = objs.size()
			objs.append(d)
		return index[d]
	var coll := []
	for d in g.collection:
		coll.append(reg.call(d))
	var deck := []
	for d in t.deck:
		deck.append(reg.call(d))
	var piles := {}
	for name in ["hand", "stack", "discard"]:
		var out := []
		for st in t[name]:
			if st == null:
				out.append(null)
			else:
				out.append({"i": reg.call(st.d), "a": st.a, "b": st.b, "rolled": st.rolled, "ang": st.ang})
		piles[name] = out
	var doms := []
	for d in objs:
		doms.append(_dom(d))
	var data := {
		"version": VERSION, "seed": g.seed_value, "battle_no": g.battle_no, "gems": g.gems, "uid": g.uid,
		"max_hp_bonus": g.max_hp_bonus, "relic_chance": g.relic_chance, "foe_lv": g.foe.lv,
		"doms": doms, "collection": coll,
		"weapon": _relic(g.weapon) if g.weapon != null else null,
		"stored_weapons": g.stored_weapons.map(func(r): return _relic(r)),
		"relics": g.relics.map(func(r): return _relic(r)),
		"stored_relics": g.stored_relics.map(func(r): return _relic(r)),
		"battle_snap": g.battle_snap,
		"snap": {
			"deck": deck, "hand": piles.hand, "stack": piles.stack, "discard": piles.discard,
			"occ": t.occ, "placed": t.placed, "pl": t.pl, "foe": t.foe, "energy": t.energy, "lives": t.lives,
			"played": t.played, "bat": t.bat, "history": t.history, "stats": t.stats, "rng": t.rng,
		},
	}
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(var_to_str(data))
	f.close()
	return true


## Put the saved run into g (a Game) and start from the beginning of the saved turn. False if there is no usable save.
static func read_into(g) -> bool:
	if not exists():
		return false
	var data = str_to_var(FileAccess.get_file_as_string(path))
	if not (data is Dictionary) or data.get("version", 0) != VERSION:
		return false
	g.seed_value = data.seed
	g.battle_no = data.battle_no
	g.gems = data.gems
	g.uid = data.uid
	g.max_hp_bonus = data.max_hp_bonus
	g.relic_chance = data.relic_chance
	var objs := []
	for d in data.doms:
		objs.append(_make_dom(g, d))
	g.collection = []
	for i in data.collection:
		g.collection.append(objs[i])
	g.weapon = _make_relic(data.weapon) if data.weapon != null else null
	g.stored_weapons = data.stored_weapons.map(func(r): return _make_relic(r))
	g.relics = data.relics.map(func(r): return _make_relic(r))
	g.stored_relics = data.stored_relics.map(func(r): return _make_relic(r))
	g.battle_snap = data.battle_snap
	var s: Dictionary = data.snap
	g.battle_deck = []
	for i in s.deck:
		g.battle_deck.append(objs[i])
	g.hand = _pile(objs, s.hand)
	g.stack = _pile(objs, s.stack)
	g.discard = _pile(objs, s.discard)
	g.occ = s.occ.duplicate(true)
	g.placed = s.placed.duplicate(true)
	g.chars.clear()
	for who in g.CH:
		for i in 3:
			for j in 3:
				g.chars[g.CH[who] + Vector2(i, j)] = who
	g.pl = g.fresh_player()
	g.pl.set_state(s.pl)
	g.foe = Foe.new(data.foe_lv)
	g.foe.set_state(s.foe)
	g.energy = s.energy
	g.lives = s.lives
	g.played_this_turn = s.played
	g.bat = s.bat.duplicate(true)
	g.history.load_saved(s.history)
	g.stats = s.stats.duplicate(true)
	g.rng.seed = hash("battle:%d:%d" % [g.seed_value, g.battle_no])
	g.rng.state = s.rng
	g.shop = []
	g.shop_pending = false
	g.shop_note = ""
	g.artifact_offered = false
	g.victory_summary = {}
	g.ended = false
	g.reason = ""
	g.busy = 0
	g.end_turn_after_play = false
	g._cache.clear()
	g._reset_counters()          # you are at the start of a turn: counters that count a turn start from 0
	g.snapshot_turn()
	return true


static func _pile(objs: Array, saved: Array) -> Array:
	var out := []
	for st in saved:
		if st == null:
			out.append(null)
			continue
		var d = objs[st.i]
		d.a = st.a
		d.b = st.b
		d.rolled = st.rolled
		d.ang = st.ang
		out.append(d)
	return out


static func _dom(d) -> Dictionary:
	var specs := []
	for sp in d.specs:
		specs.append([sp.lo, sp.hi, sp.stability])
	return {"id": d.data.id, "lv": d.level(), "specs": specs, "a": d.a, "b": d.b, "rolled": d.rolled,
			"ang": d.ang, "origin": d.origin, "ht": d.hand_turn}


static func _make_dom(g, st: Dictionary):
	var d = g.make_domino(st.id)
	d.set_level(st.lv)
	for i in 2:
		d.specs[i] = PipSpec.new(st.specs[i][0], st.specs[i][1], st.specs[i][2])
	d.a = st.a
	d.b = st.b
	d.rolled = st.rolled
	d.ang = st.ang
	d.origin = st.origin
	d.hand_turn = st.ht
	return d


static func _relic(r) -> Dictionary:
	return {"id": r.id, "level": r.level, "counter": r.counter}


static func _make_relic(st: Dictionary):
	var r = Relics.by_id(st.id)
	r.level = st.level
	r.counter = st.counter
	return r
