extends Node2D
## Dominomino: Godot 4 port of the web game (index.html).
## This script draws the isometric board (dominoes, characters, highlights) and handles the board
## side of the input. Everything else on screen lives in scenes/hud.tscn (scripts/hud.gd).
## The rules and turn flow live in game.gd, which calls the hooks below (refresh, pause, pick, ...).
## Images (all optional, placeholders are drawn if missing):
##   res://images/isometric_tile.png  32x16, 2:1 isometric diamond
##   res://images/player.png, enemy.png
##   res://images/domino_dot.png      2x2 black pixel

const Game = preload("res://scripts/game.gd")
const DominoArt = preload("res://scripts/domino_art.gd")
const HudScene = preload("res://scenes/hud.tscn")

const VIEW := Vector2(960, 540)
const ORIGIN := Vector2(480, 56)   # top vertex of the board diamond
const HW := 16.0                   # half tile width  (tile is 32x16)
const HH := 8.0                    # half tile height
const THICK := 5.0                 # thickness of the domino being placed
const PLACED_THICK := 3.0
const LIFT := 8.0                  # height while dragging
const PEND_LIFT := 4.0             # height while waiting for OK
const FINGER := 28.0               # aim this many px above the pointer so a finger does not hide the domino
const SWING_MS := 320.0
const FONT_SIZE := 14

var game
var hud
var tile_tex: Texture2D
var player_tex: Texture2D
var enemy_tex: Texture2D
var dot_tex: Texture2D
var font: Font
var time_scale := 1.0      # tests speed the waits up

var sel := -1              # selected hand index
var drag = null            # {i, x, y, rot, a, b, on}
var pending = null         # dropped on the board, waiting for OK / Cancel
var pdrag = null           # pointer is down on the pending domino
var swing_fx = null        # {who, t0}
var last_full := -100000


func _ready() -> void:
	randomize()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	RenderingServer.set_default_clear_color(Color.WHITE)
	tile_tex = _tex("res://images/isometric_tile.png")
	player_tex = _tex("res://images/player.png")
	enemy_tex = _tex("res://images/enemy.png")
	dot_tex = _tex("res://images/domino_dot.png")
	font = ThemeDB.fallback_font
	game = Game.new()
	game.ui = self
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = HudScene.instantiate()
	hud.dot_tex = dot_tex
	layer.add_child(hud)
	hud.ok_pressed.connect(_commit_pending)
	hud.cancel_pressed.connect(_on_cancel_pressed)
	hud.end_turn_pressed.connect(_on_end_pressed)
	hud.new_game_pressed.connect(_on_new_game)
	hud.domino_tapped.connect(_on_domino_tapped)
	hud.domino_drag_started.connect(_on_drag_started)
	hud.domino_drag_moved.connect(_on_drag_moved)
	hud.domino_drag_released.connect(_on_drag_released)
	hud.domino_rotate_requested.connect(_on_rotate_requested)
	_refresh_ui()
	game.stuck_check()


func _tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var t = load(path)
		if t is Texture2D:
			return t
	return null


# ---- hooks called by game.gd ----------------------------------------------

func refresh() -> void:
	_refresh_ui()


func pause(sec: float) -> void:
	await get_tree().create_timer(sec * time_scale).timeout


## Show the dominoes in list and wait until one is chosen. Returns its index, or -1 for skip.
func pick(title: String, sub: String, list: Array, skip: String = "") -> int:
	var r: int = await hud.pick(game, title, sub, list, skip)
	return r


func float_text(who: String, text: String) -> void:
	var top: Vector2 = hud.tag_top(who)
	hud.spawn_float(text, Vector2(top.x + randf_range(-25.0, 25.0), top.y - 14.0))


func toast(text: String) -> void:
	hud.toast(text)


## The hand holds at most 12: extra draws are skipped and this message flashes briefly.
func hand_full() -> void:
	var now := Time.get_ticks_msec()
	if now - last_full < 900:
		return
	last_full = now
	hud.toast("Hand size is maxed", true)


func flash() -> void:
	hud.flash()


func swing(who: String) -> void:
	swing_fx = {"who": who, "t0": Time.get_ticks_msec()}


func fresh(_index: int) -> void:
	pass


func note_play() -> void:
	hud.note_play()


func finished() -> void:
	_refresh_ui()


# ---- showing the game in the HUD ------------------------------------------

func _refresh_ui() -> void:
	if sel >= game.hand.size():
		sel = -1
	hud.refresh(game, {
		"sel": sel,
		"pending": pending != null,
		"drag_index": drag.i if drag != null else -1,
		"pending_index": pending.i if pending != null else -1,
	})
	if game.ended:
		hud.show_game_over(_stats_rows())
	else:
		hud.hide_game_over()


func _stats_rows() -> Array:
	var s: Dictionary = game.stats
	var board_pips := 0
	for p in game.placed:
		board_pips += p.a + p.b
	var hand_pips := 0
	for d in game.hand:
		hand_pips += d.total()
	var sec := int((s.t1 - s.t0) / 1000.0)
	var eff := int(round(100.0 * s.spent / maxi(1, s.spent + s.wasted)))
	return [
		["Result", game.reason], ["Battles won", s.battles], ["Turns", s.turn],
		["Time", "%d:%02d" % [sec / 60, sec % 60]], ["Lives lost", s.lost],
		["Your dominoes", s.played], ["Computer dominoes", s.cpu],
		["Damage dealt", s.dealt], ["Damage taken", s.taken], ["Damage blocked", s.absorbed],
		["Shield gained", s.shield], ["HP healed", s.healed], ["Dominoes drawn", s.drawn],
		["Dominoes rerolled", s.rerolls], ["Self damage", s.selfdmg], ["Dominoes owned", game.collection.size()], ["Relics", game.relics.size()],
		["Pips you played", s.pips], ["Pips left in hand", hand_pips], ["Pips on board", board_pips],
		["Energy spent", s.spent], ["Energy wasted", s.wasted], ["Energy efficiency", "%d%%" % eff],
		["Free plays", s.free], ["Doubles played", s.doubles], ["Costliest play", s.max_cost],
	]


# ---- buttons and the hand -------------------------------------------------

func _on_cancel_pressed() -> void:
	pending = null
	_refresh_ui()


func _commit_pending() -> void:
	if pending == null:
		return
	var m: Dictionary = pending
	var res: Dictionary = game.check_p(m)
	if not res.ok:
		toast(res.why)
		return
	pending = null
	sel = -1
	game.play_domino(m)


func _on_end_pressed() -> void:
	if pending != null:
		return
	sel = -1
	drag = null
	game.end_turn()


func _on_new_game() -> void:
	game.new_game()
	sel = -1
	drag = null
	pending = null
	pdrag = null
	swing_fx = null
	hud.set_ghost(false, null, Vector2.ZERO)
	_refresh_ui()
	game.stuck_check()


func _can_play_now() -> bool:
	return not game.ended and game.busy == 0 and pending == null


## Tap a domino in the hand: the first tap selects it, tapping the selected one turns it.
func _on_domino_tapped(view) -> void:
	if not _can_play_now():
		return
	if sel == view.index:
		game.hand[view.index].ang += 90
	else:
		sel = view.index
	_refresh_ui()


func _on_drag_started(view) -> void:
	if not _can_play_now():
		return
	sel = view.index
	var d = game.hand[sel]
	drag = {"i": sel, "x": 0, "y": 0, "rot": posmod(int(d.ang / 90.0), 4), "a": d.a, "b": d.b, "on": false}
	_refresh_ui()


func _on_drag_moved(_view, pos: Vector2) -> void:
	if drag != null:
		_update_drag(pos)


func _on_drag_released(_view, pos: Vector2) -> void:
	if drag != null:
		_update_drag(pos)
		_drop()


func _on_rotate_requested(_view) -> void:
	if drag != null:
		_rotate_drag()


func _update_drag(pos: Vector2) -> void:
	drag.on = pos.y < hud.tray_top()
	if drag.on:
		var g := _to_grid(Vector2(pos.x, pos.y - FINGER))
		var d := Game.dims(drag.rot)
		drag.x = int(round(g.x - d.x / 2.0))
		drag.y = int(round(g.y - d.y / 2.0))
		Game.clamp_m(drag)
	# off the board the domino follows the pointer over the tray
	hud.set_ghost(not drag.on, game.hand[drag.i], pos)


func _rotate_drag() -> void:
	drag.rot = (drag.rot + 1) % 4
	game.hand[drag.i].ang += 90
	_update_drag(get_viewport().get_mouse_position())


func _drop() -> void:
	var d: Dictionary = drag
	drag = null
	hud.set_ghost(false, null, Vector2.ZERO)
	if d.on:
		var res: Dictionary = game.check_p(d)
		if res.ok:
			pending = {"x": d.x, "y": d.y, "rot": d.rot, "a": d.a, "b": d.b, "i": d.i}
		else:
			toast(res.why)
	_refresh_ui()


# ---- input on the board ---------------------------------------------------
# The pending domino can be tapped (to place it) or dragged to another spot.
# Mouse and touch both arrive as mouse events (touch emulation is on by default).

func _unhandled_input(event: InputEvent) -> void:
	if game.ended or game.busy != 0:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press(event.position)
		else:
			_release()
	elif event is InputEventMouseMotion:
		_motion(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed and event.index >= 1 and drag != null:
			_rotate_drag()      # second finger rotates the domino being dragged
	elif event is InputEventKey:
		if event.pressed and event.keycode == KEY_R and drag != null:
			_rotate_drag()


func _to_grid(p: Vector2) -> Vector2:
	var u := (p.x - ORIGIN.x) / HW
	var v := (p.y - ORIGIN.y) / HH
	return Vector2((u + v) / 2.0, (v - u) / 2.0)


func _P(gx: float, gy: float, z := 0.0) -> Vector2:
	return Vector2(round(ORIGIN.x + (gx - gy) * HW), round(ORIGIN.y + (gx + gy) * HH - z))


func _hit_pending(pos: Vector2) -> bool:
	var d := Game.dims(pending.rot)
	for z in [0.0, PEND_LIFT + THICK]:
		var g := _to_grid(pos + Vector2(0, z))
		if g.x >= pending.x and g.x < pending.x + d.x and g.y >= pending.y and g.y < pending.y + d.y:
			return true
	return false


func _press(pos: Vector2) -> void:
	if pending != null and _hit_pending(pos):
		pdrag = {"start": pos, "g0": _to_grid(pos), "x": pending.x, "y": pending.y, "moved": false}


func _motion(pos: Vector2) -> void:
	if pdrag != null:
		if pos.distance_to(pdrag.start) > 6:
			pdrag.moved = true
		if pdrag.moved:
			var g := _to_grid(pos)
			pending.x = pdrag.x + int(round(g.x - pdrag.g0.x))
			pending.y = pdrag.y + int(round(g.y - pdrag.g0.y))
			Game.clamp_m(pending)


func _release() -> void:
	if pdrag != null:
		var tap: bool = not pdrag.moved
		pdrag = null
		if tap:
			_commit_pending()


# ---- per frame ------------------------------------------------------------

func _process(_delta: float) -> void:
	# the tags follow the characters
	var anchors := {}
	for who in ["c", "p"]:
		var c := _char_center(who)
		anchors[who] = Vector2(c.x, c.y - _char_height(who) - 6)
	hud.place_tags(anchors.c, anchors.p)
	queue_redraw()


func _char_center(who: String) -> Vector2:
	var o: Vector2 = Game.CH[who]
	return _P(o.x + 1.5, o.y + 1.5)


func _char_height(who: String) -> float:
	var tex := player_tex if who == "p" else enemy_tex
	return float(tex.get_height()) if tex else 40.0


# ---- drawing --------------------------------------------------------------

func _draw() -> void:
	var n := Game.N
	for j in n:
		for i in n:
			var p := _P(i, j)
			if tile_tex:
				draw_texture(tile_tex, p + Vector2(-HW, 0))
			else:
				var q := PackedVector2Array([p, _P(i + 1, j), _P(i + 1, j + 1), _P(i, j + 1), p])
				draw_polyline(q, Color(0.8, 0.8, 0.8), 1.0)
	var edge := PackedVector2Array([_P(0, 0), _P(n, 0), _P(n, n), _P(0, n), _P(0, 0)])
	draw_polyline(edge, Color.BLACK, 2.0)

	for who in Game.CH:
		var o: Vector2 = Game.CH[who]
		var fp := PackedVector2Array([_P(o.x, o.y), _P(o.x + 3, o.y), _P(o.x + 3, o.y + 3), _P(o.x, o.y + 3)])
		draw_colored_polygon(fp, Color(0, 0, 0, 0.1))
		draw_polyline(PackedVector2Array([fp[0], fp[1], fp[2], fp[3], fp[0]]), Color.BLACK, 1.0)

	var act = null
	if drag != null and drag.on:
		act = drag
	elif pending != null:
		act = pending
	var res: Dictionary = {}
	if act != null:
		res = game.check_p(act)
		_draw_highlight(act, res.ok)

	var items: Array = game.placed.duplicate()
	items.append({"ch": "c"})
	items.append({"ch": "p"})
	for it in depth_sorted(items):
		if it.has("ch"):
			_draw_char(it.ch)
		else:
			_draw_iso(it, 0.0, PLACED_THICK, "player" if it.owner == "p" else "cpu")

	if act != null:
		var lift := LIFT if act == drag else PEND_LIFT
		_draw_iso(act, lift, THICK, "active")
		var d := Game.dims(act.rot)
		var c := _P(act.x + d.x / 2.0, act.y + d.y / 2.0, LIFT + THICK + 6)
		_label_box(c + Vector2(0, -16), ("-%d" % res.cost) if res.ok else res.why, res.ok)


func _draw_highlight(m: Dictionary, ok: bool) -> void:
	var d := Game.dims(m.rot)
	var poly := [_P(m.x, m.y), _P(m.x + d.x, m.y), _P(m.x + d.x, m.y + d.y), _P(m.x, m.y + d.y)]
	draw_colored_polygon(PackedVector2Array(poly), Color(0, 0, 0, 0.25 if ok else 0.1))
	poly.append(poly[0])
	draw_polyline(PackedVector2Array(poly), Color.BLACK, 2.0)
	if not ok:
		draw_line(poly[0], poly[2], Color.BLACK, 2.0)
		draw_line(poly[1], poly[3], Color.BLACK, 2.0)


## style: "active" (black), "player" (white), "cpu" (grey)
func _draw_iso(m: Dictionary, z: float, t: float, style: String) -> void:
	var d := Game.dims(m.rot)
	var x: int = m.x
	var y: int = m.y
	var z1 := z + t
	var top_c := Color.WHITE
	var left_c := Color(0.8, 0.8, 0.8)
	var right_c := Color(0.6, 0.6, 0.6)
	var pip_white := false
	if style == "active":
		top_c = Color(0.05, 0.05, 0.05)
		left_c = Color(0.25, 0.25, 0.25)
		right_c = Color(0.4, 0.4, 0.4)
		pip_white = true
	elif style == "cpu":
		top_c = Color(0.72, 0.72, 0.72)
		left_c = Color(0.5, 0.5, 0.5)
		right_c = Color(0.38, 0.38, 0.38)
	var left := [_P(x, y + d.y, z1), _P(x + d.x, y + d.y, z1), _P(x + d.x, y + d.y, z), _P(x, y + d.y, z)]
	var right := [_P(x + d.x, y, z1), _P(x + d.x, y + d.y, z1), _P(x + d.x, y + d.y, z), _P(x + d.x, y, z)]
	var top := [_P(x, y, z1), _P(x + d.x, y, z1), _P(x + d.x, y + d.y, z1), _P(x, y + d.y, z1)]
	_poly(left, left_c)
	_poly(right, right_c)
	_poly(top, top_c)
	# divider and pips on the top face
	var line_c := Color.WHITE if pip_white else Color.BLACK
	if d.x == 2:
		draw_line(_P(x + 1, y + 0.12, z1), _P(x + 1, y + 0.88, z1), line_c, 1.0)
	else:
		draw_line(_P(x + 0.12, y + 1, z1), _P(x + 0.88, y + 1, z1), line_c, 1.0)
	var cs := Game.cells_of(m)
	var pips := [m.a, m.b]
	for k in 2:
		for idx in DominoArt.PIPS[pips[k]]:
			var gx: float = cs[k].x + 0.27 + (idx % 3) * 0.23
			var gy: float = cs[k].y + 0.27 + int(idx / 3.0) * 0.23
			DominoArt.dot(self, _P(gx, gy, z1) - Vector2(1, 1), pip_white, dot_tex)


func _poly(pts: Array, fill: Color) -> void:
	draw_colored_polygon(PackedVector2Array(pts), fill)
	var o := pts.duplicate()
	o.append(pts[0])
	draw_polyline(PackedVector2Array(o), Color.BLACK, 1.0)


func _draw_char(who: String) -> void:
	var o: Vector2 = Game.CH[who]
	var other: Vector2 = Game.CH["c" if who == "p" else "p"]
	var center := _P(o.x + 1.5, o.y + 1.5)
	var to := (_P(other.x + 1.5, other.y + 1.5) - center).normalized()
	# characters fade while a domino is being played so they do not hide the board
	var alpha := 0.2 if (sel >= 0 or pending != null or drag != null) else 1.0
	var off := Vector2.ZERO
	if swing_fx != null and swing_fx.who == who:
		var p: float = (Time.get_ticks_msec() - swing_fx.t0) / SWING_MS
		if p >= 1.0:
			swing_fx = null
		else:
			var e := sin(PI * p)
			off = to * 10.0 * e
			alpha = maxf(alpha, 0.65 * e)
	var tex := player_tex if who == "p" else enemy_tex
	if tex:
		var pos := center + off - Vector2(tex.get_width() / 2.0, tex.get_height() - 4)
		draw_texture(tex, pos.round(), Color(1, 1, 1, alpha))
	else:
		var r := Rect2(center + off - Vector2(12, 36), Vector2(24, 40))
		draw_rect(r, Color(1, 1, 1, alpha))
		draw_rect(r, Color(0, 0, 0, alpha), false, 1.0)


func _label_box(center: Vector2, txt: String, ok: bool) -> void:
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x + 8
	var r := Rect2((center - Vector2(w / 2.0, 9)).round(), Vector2(w, 18))
	draw_rect(r, Color.WHITE if ok else Color.BLACK)
	draw_rect(r, Color.BLACK, false, 1.0)
	draw_string(font, Vector2(r.position.x + 4, r.position.y + 13), txt,
			HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color.BLACK if ok else Color.WHITE)


# ---- depth sorting --------------------------------------------------------
# A is drawn before B if A sits fully behind B along either board axis.
# If both axes disagree the two cannot overlap on screen, so their order does not matter.

func _rect(it: Dictionary) -> Array:
	if it.has("ch"):
		var o: Vector2 = Game.CH[it.ch]
		return [o.x, o.x + 3, o.y, o.y + 3]
	var d := Game.dims(it.rot)
	return [it.x, it.x + d.x, it.y, it.y + d.y]


func _behind(r: Array, i: int, j: int) -> bool:
	return r[i][1] <= r[j][0] or r[i][3] <= r[j][2]


func _visit(j: int, items: Array, r: Array, vis: Array, out: Array) -> void:
	if vis[j]:
		return
	vis[j] = true
	for i in items.size():
		if i != j and _behind(r, i, j) and not _behind(r, j, i):
			_visit(i, items, r, vis, out)
	out.append(items[j])


func depth_sorted(items: Array) -> Array:
	var r := []
	var vis := []
	var out := []
	for it in items:
		r.append(_rect(it))
		vis.append(false)
	for j in items.size():
		_visit(j, items, r, vis, out)
	return out
