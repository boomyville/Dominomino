extends RefCounted
## Game state and rules. No nodes in here, so it can be unit tested (see tests/test_rules.gd).
## Ported from domino-board.html.

const N := 20
const MAXE := 10
const START_LIVES := 3
const START_HAND := 6
const DRAW_PER_TURN := 4
const HAND_LIMIT := 12
const DIRS := [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]
## Top-left cell of each 3x3 character footprint. They mirror each other through the board centre.
const CH := {"p": Vector2(14, 8), "c": Vector2(3, 9)}

var occ := {}       # Vector2 cell -> {id, owner, pip}
var chars := {}     # Vector2 cell -> "p" | "c"
var placed := []    # every placed domino: {x, y, rot, a, b, owner}
var hand := []      # {a, b, ang}
var energy := MAXE
var lives := START_LIVES
var turn := 1
var played_this_turn := false
var uid := 0
var stats := {}
var _cache := {}


func _init() -> void:
	reset()


func reset() -> void:
	occ.clear()
	chars.clear()
	placed.clear()
	hand.clear()
	_cache.clear()
	for who in CH:
		for i in 3:
			for j in 3:
				chars[CH[who] + Vector2(i, j)] = who
	energy = MAXE
	lives = START_LIVES
	turn = 1
	played_this_turn = false
	uid = 0
	stats = {"played": 0, "wasted": 0, "spent": 0, "pips": 0, "doubles": 0,
			"free": 0, "max_cost": 0, "cpu": 0, "lost": 0, "t0": Time.get_ticks_msec()}
	draw_dominoes(START_HAND)


func draw_dominoes(n: int) -> void:
	for i in n:
		hand.append({"a": randi() % 7, "b": randi() % 7, "ang": 0})
	_cache.clear()


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


# ---- rules ----------------------------------------------------------------

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


## True if the player has any legal spot for this domino. Cached until the board or energy changes.
func can_play(d: Dictionary) -> bool:
	var key := "%d,%d" % [d.a, d.b]
	if _cache.has(key):
		return _cache[key]
	var result := false
	for r in 4:
		var dm := dims(r)
		for x in range(0, N - int(dm.x) + 1):
			for y in range(0, N - int(dm.y) + 1):
				if check({"x": x, "y": y, "rot": r, "a": d.a, "b": d.b}).ok:
					result = true
					break
			if result:
				break
		if result:
			break
	_cache[key] = result
	return result


func playable_any() -> bool:
	for d in hand:
		if can_play(d):
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


## m.i is the hand index. Returns false if the move is not legal.
func commit_player(m: Dictionary) -> bool:
	var res := check(m)
	if not res.ok:
		return false
	place(m, "p")
	energy -= res.cost
	stats.played += 1
	stats.spent += res.cost
	stats.pips += m.a + m.b
	if m.a == m.b:
		stats.doubles += 1
	if res.cost == 0:
		stats.free += 1
	stats.max_cost = maxi(stats.max_cost, res.cost)
	played_this_turn = true
	hand.remove_at(m.i)
	_cache.clear()
	return true


# ---- turn flow ------------------------------------------------------------

## Banks leftover energy as wasted. Returns true if a life was lost (no domino played this turn).
func begin_end_turn() -> bool:
	stats.wasted += energy
	energy = 0
	_cache.clear()
	if not played_this_turn:
		lives -= 1
		stats.lost += 1
		return true
	return false


func start_new_turn() -> void:
	turn += 1
	energy = MAXE
	played_this_turn = false
	_cache.clear()


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
		return true
	return false
