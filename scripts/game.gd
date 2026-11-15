extends RefCounted
## Game state, rules and turn flow. No nodes in here, so it can run headless (see tests/test_rules.gd).
## Everything the player would see or wait for goes through the ui object (main.gd, or NullUI in tests).
## Ported from the web build (index.html).

const Dominoes = preload("res://scripts/dominoes.gd")
const NullUI = preload("res://scripts/null_ui.gd")

const N := 20
const MAXE := 10            # energy per turn
const MAXH := 12            # most dominoes your hand can hold
const START_LIVES := 3
const START_HAND := 6
const DRAW_PER_TURN := 4
const DIRS := [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]
## Top-left cell of each 3x3 character footprint. They mirror each other through the board centre.
const CH := {"p": Vector2(14, 8), "c": Vector2(3, 9)}
const FOE_NAMES := ["Gruff Hare", "Bone Rabbit", "Iron Hare", "Void Rabbit", "Warlord Hare"]

var ui = NullUI.new()

# board
var occ := {}          # Vector2 cell -> {id, owner, pip}
var chars := {}        # Vector2 cell -> "p" | "c"
var placed := []       # every domino on the board: {x, y, rot, a, b, owner}
# dominoes. Played dominoes stay on the board and discarded ones stay in the discard pile:
# neither comes back during a battle. Each battle the stack is rebuilt from your collection.
var collection := []   # every domino you own: {a, b, t}
var stack := []        # draw pile (top = last)
var discard := []
var hand := []         # {a, b, t, ang}
# battle
var pl := {}
var foe := {}
var bat := {}
var energy := MAXE
var lives := START_LIVES
var battle_no := 1
var played_this_turn := false
var uid := 0
var stats := {}
# flow
var busy := 0          # 0 free, 1 computer turn, 2 resolving effects, 3 reward screen
var ended := false
var reason := ""
var _cache := {}


func _init() -> void:
	new_game()


func new_game() -> void:
	collection = starter_collection()
	battle_no = 1
	stats = new_stats()
	lives = START_LIVES
	ended = false
	reason = ""
	pl = new_pl()
	foe = make_foe(1)
	start_battle()


static func new_pl() -> Dictionary:
	return {"hp": 50, "max": 50, "sh": 0, "max_sh": 9, "pow": 0, "boost": 0, "fury": 0}


static func make_foe(n: int) -> Dictionary:
	var hp := 70 + (n - 1) * 10 + (n - 1) * (n - 1) * 5
	var nm: String = FOE_NAMES[n - 1] if n <= FOE_NAMES.size() else "Hare Lord %d" % n
	return {"hp": hp, "max": hp, "sh": 0, "fury": 0, "intent": [], "lv": n, "name": nm}


static func new_stats() -> Dictionary:
	return {"played": 0, "wasted": 0, "turn": 1, "spent": 0, "pips": 0, "doubles": 0, "free": 0,
			"max_cost": 0, "cpu": 0, "lost": 0, "battles": 0, "selfdmg": 0, "dealt": 0, "taken": 0,
			"absorbed": 0, "shield": 0, "healed": 0, "drawn": 0, "rerolls": 0,
			"t0": Time.get_ticks_msec(), "t1": 0}


## The starting deck is the first 20 dominoes of the catalogue with random pips.
static func starter_collection() -> Array:
	var out := []
	for i in 20:
		out.append({"a": randi() % 7, "b": randi() % 7, "t": i})
	return out


static func new_domino() -> Dictionary:
	return {"a": randi() % 7, "b": randi() % 7, "t": Dominoes.rand_type(), "ang": 0}


static func garbage() -> Dictionary:
	return {"a": 0, "b": 0, "t": Dominoes.GARBAGE, "ang": 0}


func start_battle() -> void:
	occ.clear()
	chars.clear()
	placed.clear()
	_cache.clear()
	for who in CH:
		for i in 3:
			for j in 3:
				chars[CH[who] + Vector2(i, j)] = who
	energy = MAXE
	played_this_turn = false
	bat = {"played": 0, "hp_lost": false, "turn": 1}
	stack.clear()
	for d in collection:
		stack.append({"a": d.a, "b": d.b, "t": d.t, "ang": 0})
	stack.shuffle()
	discard.clear()
	hand.clear()
	draw(START_HAND)
	new_intent()
	busy = 0


# ---- drawing dominoes -----------------------------------------------------

## Draws one domino from the stack. Nothing is drawn if the hand is full (max 12) or the stack is empty.
func draw_one() -> bool:
	if hand.size() >= MAXH:
		ui.hand_full()
		return false
	if stack.is_empty():
		return false
	var d: Dictionary = stack.pop_back()
	d.ang = 0
	hand.append(d)
	stats.drawn += 1
	_cache.clear()
	return true


func draw(n: int) -> int:
	var k := 0
	for i in n:
		if draw_one():
			k += 1
	return k


# ---- geometry -------------------------------------------------------------

## rot even -> 2 wide x 1 tall, rot odd -> 1 wide x 2 tall (x, y is the min corner)
static func dims(rot: int) -> Vector2:
	return Vector2(2, 1) if rot % 2 == 0 else Vector2(1, 2)


## Returns [cell of pip a, cell of pip b]
static func cells_of(m: Dictionary) -> Array:
	var x: int = m.x
	var y: int = m.y
	match m.rot & 3:
		0:
			return [Vector2(x, y), Vector2(x + 1, y)]
		1:
			return [Vector2(x, y), Vector2(x, y + 1)]
		2:
			return [Vector2(x + 1, y), Vector2(x, y)]
		_:
			return [Vector2(x, y + 1), Vector2(x, y)]


static func clamp_m(m: Dictionary) -> void:
	var d := dims(m.rot)
	m.x = clampi(m.x, 0, N - int(d.x))
	m.y = clampi(m.y, 0, N - int(d.y))


# ---- board rules ----------------------------------------------------------

## Returns {ok, cost, why}. who is "p" or "c". free ignores the energy limit (CPU).
func check(m: Dictionary, free := false, who := "p") -> Dictionary:
	var cs := cells_of(m)
	var pips := [m.a, m.b]
	var touches := {}
	var cost := 0
	var stem := false
	for c in cs:
		if occ.has(c) or chars.has(c):
			return {"ok": false, "why": "Space taken"}
	for k in 2:
		var touched := false
		for d in DIRS:
			var nb: Vector2 = cs[k] + d
			if chars.has(nb):
				if chars[nb] == who:
					stem = true
				continue
			if not occ.has(nb):
				continue
			var o: Dictionary = occ[nb]
			if o.owner == who:
				stem = true
			if o.pip != pips[k]:
				return {"ok": false, "why": "Pips must match"}
			touched = true
			touches[o.id] = touches.get(o.id, 0) + 1
			if touches[o.id] > 1:
				return {"ok": false, "why": "Touches same domino twice"}
		if not touched:
			cost += pips[k]
	if not stem:
		return {"ok": false, "why": "Connect to your character"}
	if cost > energy and not free:
		return {"ok": false, "why": "Needs %d energy" % cost, "cost": cost}
	return {"ok": true, "cost": cost}


## Board check plus the domino's own play condition. m.i is the index of the domino in hand.
func check_p(m: Dictionary) -> Dictionary:
	if m.has("i") and m.i >= 0 and m.i < hand.size():
		var def: Dictionary = Dominoes.TY[hand[m.i].t]
		if not cond_ok(m.i):
			if def.c == "never":
				return {"ok": false, "why": "Garbage cannot be played"}
			return {"ok": false, "why": "Needs: " + Dominoes.COND_TEXT[def.c]}
	return check(m)


## Does the hand domino at index i meet its play condition right now?
func cond_ok(i: int) -> bool:
	var c: String = Dominoes.TY[hand[i].t].c
	if c == "":
		return true
	match c:
		"noSix":
			for j in hand.size():
				if j != i and (hand[j].a == 6 or hand[j].b == 6):
					return false
			return true
		"hand6":
			return hand.size() >= 6
		"handLe3":
			return hand.size() <= 3
		"noShield":
			return pl.sh == 0
		"noAtk":
			for j in hand.size():
				if j != i and Dominoes.has_atk(Dominoes.TY[hand[j].t]):
					return false
			return true
		"noHpLost":
			return not bat.hp_lost
		"first":
			return not played_this_turn
		"played9":
			return bat.played >= 9
		"lowHp":
			return pl.hp * 2 <= pl.max
		"enShield":
			return foe.sh > 0
	return false    # "never" (Garbage)


## Is there a legal spot on the board for these pips? Cached until the board or energy changes.
func _board_can(a: int, b: int) -> bool:
	var key := "%d,%d" % [a, b]
	if _cache.has(key):
		return _cache[key]
	var result := false
	for r in 4:
		var dm := dims(r)
		for x in range(0, N - int(dm.x) + 1):
			for y in range(0, N - int(dm.y) + 1):
				if check({"x": x, "y": y, "rot": r, "a": a, "b": b}).ok:
					result = true
					break
			if result:
				break
		if result:
			break
	_cache[key] = result
	return result


## Can the hand domino at index i be played at all right now?
func can_play(i: int) -> bool:
	return cond_ok(i) and _board_can(hand[i].a, hand[i].b)


func playable_any() -> bool:
	for i in hand.size():
		if can_play(i):
			return true
	return false


func place(m: Dictionary, who: String) -> void:
	uid += 1
	var cs := cells_of(m)
	var pips := [m.a, m.b]
	for k in 2:
		occ[cs[k]] = {"id": uid, "owner": who, "pip": pips[k]}
	placed.append({"x": m.x, "y": m.y, "rot": m.rot, "a": m.a, "b": m.b, "owner": who})
	_cache.clear()


# ---- status / text --------------------------------------------------------

# Godot 4.1 to 4.4 pass the wrong arguments to a script's own static functions when they are called
# from a coroutine after an await. Code that awaits (play_domino, run_fx, end_turn, stuck_check,
# battle_won) therefore uses these small instance wrappers instead of calling the static helpers directly.
func _foe(n: int) -> Dictionary:
	return make_foe(n)


func _pl() -> Dictionary:
	return new_pl()


func _garb() -> Dictionary:
	return garbage()


func _dom() -> Dictionary:
	return new_domino()


func _tick(o: Dictionary) -> void:
	tick(o)


func _status(o: Dictionary) -> String:
	return status_text(o)


## Announce the card that was just added to the hand. Kept as its own function because arithmetic
## written inline right after an await hit a Godot 4.1 to 4.4 bug (it read a stale temporary).
func _announce_new_card() -> void:
	ui.fresh(hand.size() - 1)


## Start-of-turn bookkeeping, in a normal function for the same reason.
func _new_turn_state() -> void:
	stats.turn += 1
	bat.turn += 1
	energy = MAXE
	played_this_turn = false
	if pl.sh > pl.max_sh:
		pl.sh = pl.max_sh
		ui.float_text("p", "Excess shield lost")
	new_intent()
	_cache.clear()


static func status_text(o: Dictionary) -> String:
	if o.fury > 0:
		return "Fury %d" % o.fury
	if o.fury < 0:
		return "Impair %d" % (-o.fury)
	return ""


## Fury and Impair tick one step toward 0 after every attack.
static func tick(o: Dictionary) -> void:
	if o.fury > 0:
		o.fury -= 1
	elif o.fury < 0:
		o.fury += 1


## One line of text per effect, with your current Power / Boost / Fury already added to damage.
func fx_lines(d: Dictionary) -> Array:
	var def: Dictionary = Dominoes.TY[d.t]
	var s: int = d.a + d.b
	var bo: int = pl.boost if Dominoes.has_atk(def) else 0
	var out := []
	for e in def.fx:
		var v := Dominoes.val(e, s)
		var n := maxi(0, v + pl.pow + bo + pl.fury)
		match e.k:
			"dmg":
				out.append("Deal %d damage" % n)
			"hit":
				out.append("Deal %d damage x%d" % [n, e.t])
			"shield":
				out.append("Gain %d shield" % v)
			"maxs":
				out.append("Max shield +%d" % v)
			"draw":
				out.append("Draw %d" % v)
			"discR":
				out.append("Discard %d at random" % v)
			"discP":
				out.append("Discard %d of your choice" % v)
			"tutor":
				out.append("Find a domino in your stack and add it to your hand")
			"power":
				out.append("Gain %d Power" % v)
			"boost":
				out.append("Gain %d Boost" % v)
			"heal":
				out.append("Heal %d" % v)
			"rerollA":
				out.append("Reroll all dominoes in hand")
			"rerollP":
				out.append("Reroll a domino of your choice")
			"fury":
				out.append("Gain %d Fury" % v)
			"impS":
				out.append("Apply %d Impair to yourself" % v)
			"impE":
				out.append("Apply %d Impair to the enemy" % v)
			"selfdmg":
				out.append("Lose %d HP" % v)
			"gen":
				out.append("Add %d random domino%s to your stack" % [v, "es" if v > 1 else ""])
			"life":
				out.append("Gain %d lives" % v)
	return out


## Icon + number chips shown under a hand domino. A red X ("x") replaces the icon when the
## play condition is not met, and for Garbage.
func caps(i: int) -> Array:
	var d: Dictionary = hand[i]
	var def: Dictionary = Dominoes.TY[d.t]
	if def.r == "g":
		return [{"k": "x", "num": ""}]
	var s: int = d.a + d.b
	var bo: int = pl.boost if Dominoes.has_atk(def) else 0
	var chips := []
	for e in def.fx:
		var v := Dominoes.val(e, s)
		var n := maxi(0, v + pl.pow + bo + pl.fury)
		var num := ""
		if e.has("m"):
			if e.k == "hit":
				num = "%dx%d" % [n, e.t]
			elif e.k == "dmg":
				num = str(n)
			else:
				num = str(v)
		chips.append({"k": e.k, "num": num})
	if not cond_ok(i):
		return [{"k": "x", "num": chips[0].num if chips.size() > 0 else ""}]
	return chips


func intent_text(it: Dictionary) -> String:
	match it.k:
		"atk":
			return "Attack %d" % maxi(0, it.v + foe.fury)
		"lifeatk":
			return "Attack %d (lose a life if unblocked)" % maxi(0, it.v + foe.fury)
		"blk":
			return "Block %d" % it.v
		"discH":
			return "Discard a domino from your hand"
		"mill":
			return "Discard your top stack domino, add Garbage"
	return "Shuffle 3 Garbage into your stack"


# ---- combat ---------------------------------------------------------------

func hit_foe(n: int) -> void:
	n = maxi(0, n)
	var ab := mini(foe.sh, n)
	var dm := n - ab
	foe.sh -= ab
	foe.hp = maxi(0, foe.hp - dm)
	stats.dealt += dm
	ui.float_text("c", "-%d" % dm if dm > 0 else "Blocked")


## Returns the damage that got through the shield.
func hit_pl(n: int) -> int:
	n = maxi(0, n)
	var ab := mini(pl.sh, n)
	var dm := n - ab
	pl.sh -= ab
	pl.hp = maxi(0, pl.hp - dm)
	stats.taken += dm
	stats.absorbed += ab
	if dm > 0:
		bat.hp_lost = true
	ui.float_text("p", "-%d HP" % dm if dm > 0 else "Blocked")
	return dm


func lose_life() -> void:
	lives -= 1
	stats.lost += 1
	ui.flash()
	ui.float_text("p", "Lost a life")


## The enemy plans 1 or 2 dominoes per turn and shows each one as its intent.
## Attacks and blocks are common; the other intents are uncommon.
func new_intent() -> void:
	var n := 1 if randf() < 0.5 else 2
	var lv := battle_no - 1
	var out := []
	for i in n:
		var r := randf()
		if r < 0.62:
			out.append({"k": "atk", "v": 4 + lv + randi() % (8 + lv)})
		elif r < 0.75:
			out.append({"k": "blk", "v": 4 + lv + randi() % 5})
		elif r < 0.82:
			out.append({"k": "lifeatk", "v": 5 + lv + randi() % (6 + lv)})
		elif r < 0.88:
			out.append({"k": "discH"})
		elif r < 0.94:
			out.append({"k": "mill"})
		else:
			out.append({"k": "junk"})
	foe.intent = out


## The computer plays one domino built to match the board. Returns true on success.
func cpu_play() -> bool:
	var rare := randf() < 0.12      # rarely plays a domino that touches no other domino
	var own := false
	for p in placed:
		if p.owner == "c":
			own = true
			break
	for _attempt in 500:
		var m := {"x": randi() % N, "y": randi() % N, "rot": randi() % 4, "a": 0, "b": 0}
		clamp_m(m)
		var cs := cells_of(m)
		var req := [-1, -1]
		var touch := false
		var bad := false
		var stem := false
		for k in 2:
			for d in DIRS:
				var nb: Vector2 = cs[k] + d
				if chars.has(nb):
					if chars[nb] == "c":
						stem = true
					continue
				if occ.has(nb):
					var o: Dictionary = occ[nb]
					touch = true
					if o.owner == "c":
						stem = true
					if req[k] != -1 and req[k] != o.pip:
						bad = true
					req[k] = o.pip
		if bad or not stem:
			continue
		if own and not rare and not touch:
			continue
		if rare and touch:
			continue
		m.a = req[0] if req[0] != -1 else randi() % 7
		m.b = req[1] if req[1] != -1 else randi() % 7
		if not check(m, true, "c").ok:
			continue
		place(m, "c")
		stats.cpu += 1
		ui.swing("c")
		return true
	return false


# ---- playing a domino -----------------------------------------------------

## Plays the pending domino m (m.i is its index in hand): place it, pay energy, resolve its effects.
func play_domino(m: Dictionary) -> void:
	if busy != 0 or ended:
		return
	var ck := check_p(m)
	if not ck.ok:
		ui.toast(ck.why)
		return
	place(m, "p")
	energy -= ck.cost
	stats.played += 1
	stats.spent += ck.cost
	stats.pips += m.a + m.b
	if m.a == m.b:
		stats.doubles += 1
	if ck.cost == 0:
		stats.free += 1
	stats.max_cost = maxi(stats.max_cost, ck.cost)
	played_this_turn = true
	ui.swing("p")
	# the played domino stays on the board: it does not go to the discard pile
	var d: Dictionary = hand[m.i]
	hand.remove_at(m.i)
	bat.played += 1
	busy = 2
	_cache.clear()
	ui.note_play()
	ui.refresh()
	await ui.pause(0.25)
	await run_fx(d)
	busy = 0
	ui.note_play()
	if pl.hp <= 0:
		finish("You were defeated")
		return
	if lives <= 0:
		finish("You ran out of lives")
		return
	if foe.hp <= 0:
		await battle_won()
		return
	ui.refresh()


func run_fx(d: Dictionary) -> void:
	var s: int = d.a + d.b
	var def: Dictionary = Dominoes.TY[d.t]
	var atk := Dominoes.has_atk(def)
	var bo: int = pl.boost if atk else 0
	for e in def.fx:
		if foe.hp <= 0 or pl.hp <= 0:
			break
		var v := Dominoes.val(e, s)
		var dm := maxi(0, v + pl.pow + bo + pl.fury)
		match e.k:
			"dmg":
				hit_foe(dm)
			"hit":
				var i := 0
				while i < e.t and foe.hp > 0:
					hit_foe(dm)
					ui.refresh()
					await ui.pause(0.26)
					i += 1
			"shield":
				pl.sh += v
				stats.shield += v
				ui.float_text("p", "+%d shield" % v)
			"maxs":
				pl.max_sh += v
				ui.float_text("p", "Max shield +%d" % v)
			"draw":
				for i in v:
					if draw_one():
						_announce_new_card()
					ui.refresh()
					await ui.pause(0.22)
				ui.fresh(-1)
			"discR":
				for i in v:
					if hand.size() > 0:
						discard.append(hand.pop_at(randi() % hand.size()))
			"discP":
				for i in v:
					if hand.size() > 0:
						var c: int = await ui.pick("Discard a domino", "Choose a domino from your hand to discard.", hand.duplicate())
						discard.append(hand.pop_at(maxi(c, 0)))
						ui.refresh()
			"tutor":
				if stack.is_empty():
					ui.toast("Your stack is empty")
				elif hand.size() >= MAXH:
					ui.hand_full()
				else:
					var idx := range(stack.size())
					idx.sort_custom(func(p, q): return Dominoes.TY[stack[p].t].n < Dominoes.TY[stack[q].t].n)
					var list := []
					for k in idx:
						list.append(stack[k])
					var c: int = await ui.pick("Find a domino", "Choose a domino from your stack to add to your hand.", list)
					var got: Dictionary = stack.pop_at(idx[maxi(c, 0)])
					got.ang = 0
					hand.append(got)
					_announce_new_card()
					ui.refresh()
					await ui.pause(0.3)
					ui.fresh(-1)
			"power":
				pl.pow += v
				ui.float_text("p", "Power +%d" % v)
			"boost":
				pl.boost += v
				ui.float_text("p", "Boost +%d" % v)
			"heal":
				var h := mini(v, pl.max - pl.hp)
				pl.hp += h
				stats.healed += h
				ui.float_text("p", "+%d HP" % h)
			"rerollA":
				for h in hand:
					h.a = randi() % 7
					h.b = randi() % 7
				stats.rerolls += hand.size()
				ui.float_text("p", "Rerolled hand")
			"rerollP":
				if hand.size() > 0:
					var c: int = await ui.pick("Reroll a domino", "Choose a domino from your hand to reroll.", hand.duplicate())
					c = maxi(c, 0)
					hand[c].a = randi() % 7
					hand[c].b = randi() % 7
					stats.rerolls += 1
			"fury":
				pl.fury += v
				ui.float_text("p", _status(pl) if pl.fury != 0 else "Fury 0")
			"impS":
				pl.fury -= v
				ui.float_text("p", _status(pl) if pl.fury != 0 else "Fury 0")
			"impE":
				foe.fury -= v
				ui.float_text("c", _status(foe) if foe.fury != 0 else "Fury 0")
			"selfdmg":
				pl.hp = maxi(0, pl.hp - v)
				stats.selfdmg += v
				bat.hp_lost = true
				ui.float_text("p", "-%d HP" % v)
			"gen":
				for i in v:
					stack.insert(randi() % (stack.size() + 1), _dom())
				ui.float_text("p", "+%d in stack" % v)
			"life":
				lives += v
				ui.float_text("p", "+%d lives" % v)
		_cache.clear()
		ui.refresh()
		await ui.pause(0.16)
	if atk:
		_tick(pl)
		pl.boost = 0     # Boost is used up by the next attack (Power stays until the battle ends)
	_cache.clear()


# ---- turn flow ------------------------------------------------------------

func end_turn() -> void:
	if busy != 0 or ended:
		return
	busy = 1
	stats.wasted += energy
	energy = 0
	_cache.clear()
	ui.refresh()
	if not played_this_turn:
		# skipped the turn: lose a life
		ui.flash()
		lives -= 1
		stats.lost += 1
		ui.refresh()
		await ui.pause(1.1)
		if lives <= 0:
			finish("You ran out of lives")
			return
	foe.sh = 0
	for it in foe.intent.duplicate():
		await ui.pause(0.5)
		cpu_play()
		match it.k:
			"atk", "lifeatk":
				var dm := hit_pl(maxi(0, it.v + foe.fury))
				_tick(foe)
				if it.k == "lifeatk" and dm > 0:
					await ui.pause(0.25)
					lose_life()
			"blk":
				foe.sh += it.v
				ui.float_text("c", "+%d shield" % it.v)
			"discH":
				if hand.size() > 0:
					discard.append(hand.pop_at(randi() % hand.size()))
					ui.float_text("p", "Domino discarded")
			"mill":
				if stack.size() > 0:
					discard.append(stack.pop_back())
				stack.append(_garb())
				ui.float_text("p", "Garbage on your stack")
			"junk":
				for i in 3:
					stack.append(_garb())
				stack.shuffle()
				ui.float_text("p", "3 Garbage shuffled in")
		_cache.clear()
		ui.refresh()
		if pl.hp <= 0:
			finish("You were defeated")
			return
		if lives <= 0:
			finish("You ran out of lives")
			return
	await ui.pause(0.45)
	_new_turn_state()
	ui.refresh()
	for i in DRAW_PER_TURN:
		if draw_one():
			_announce_new_card()
		ui.refresh()
		await ui.pause(0.38)
	ui.fresh(-1)
	busy = 0
	ui.note_play()
	ui.refresh()
	await stuck_check()


## At the start of a battle or a turn, if nothing in hand can be played you lose a life and the turn passes.
func stuck_check() -> void:
	if ended or busy != 0 or playable_any():
		return
	busy = 1
	ui.toast("No playable dominoes: you lose a life")
	ui.refresh()
	await ui.pause(1.3)
	busy = 0
	await end_turn()


## Heal fully, clear every status, offer 3 dominoes (take one or skip), then start the next battle.
## The work after the wait is kept in normal (non-coroutine) helpers on purpose: a longer version of
## this function hit a Godot 4.1 to 4.4 compiler bug that corrupted battle_no after the await.
func battle_won() -> void:
	busy = 3
	var opts := _begin_reward()
	var c: int = await ui.pick("Victory!", "You healed to full HP and every status was cleared. Choose a domino to add to your stack, or skip.", opts, "Skip")
	_start_next_battle(c, opts)
	await stuck_check()


func _begin_reward() -> Array:
	stats.battles += 1
	pl = new_pl()
	ui.refresh()
	var opts := []
	for i in 3:
		opts.append(new_domino())
	return opts


func _start_next_battle(c: int, opts: Array) -> void:
	if c >= 0:
		collection.append({"a": opts[c].a, "b": opts[c].b, "t": opts[c].t})
	battle_no += 1
	foe = make_foe(battle_no)
	start_battle()
	ui.refresh()


func finish(r: String) -> void:
	reason = r
	ended = true
	busy = 0
	stats.t1 = Time.get_ticks_msec()
	ui.finished()
