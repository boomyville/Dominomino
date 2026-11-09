extends Node2D
## Dominomino: bare bones Godot 4 port of domino-board.html.
## Board, dominoes, characters and the hand tray are drawn in _draw(); the HUD is plain Controls.
## Images (all optional, placeholders are drawn if missing):
##   res://images/isometric_tile.png  32x16, 2:1 isometric diamond
##   res://images/player.png, enemy.png
##   res://images/domino_dot.png      2x2 black pixel

const Game = preload("res://scripts/game.gd")
const Skills = preload("res://scripts/skills.gd")

const VIEW := Vector2(960, 540)
const ORIGIN := Vector2(480, 56)   # top vertex of the board diamond
const HW := 16.0                   # half tile width  (tile is 32x16)
const HH := 8.0                    # half tile height
const TRAY_TOP := 404.0
const TRAY_Y := 466.0
const SLOT := 60.0
const THICK := 5.0                 # thickness of the domino being placed
const PLACED_THICK := 3.0
const LIFT := 8.0                  # height while dragging
const PEND_LIFT := 4.0             # height while waiting for OK
const FINGER := 28.0               # aim this many px above the pointer so a finger does not hide the domino
const SWING_MS := 320.0
const IDLE_RESET_MS := 10000
const FONT_SIZE := 14
const PIPS := [[], [4], [0, 8], [0, 4, 8], [0, 2, 6, 8], [0, 2, 4, 6, 8], [0, 2, 3, 5, 6, 8]]

var game
var tile_tex: Texture2D
var player_tex: Texture2D
var enemy_tex: Texture2D
var dot_tex: Texture2D
var font: Font

var sel := -1              # selected hand index
var drag = null            # {i, x, y, rot, a, b, on}
var pending = null         # dropped on the board, waiting for OK / Cancel
var press = null           # pointer is down on a hand domino
var pdrag = null           # pointer is down on the pending domino
var busy := false          # computer turn / draw in progress
var ended := false
var reason := ""
var swing = null           # {who, t0}
var flash_t0 := -100000
var last_play := 0
var finish_ms := 0
var toast_until := 0

var ui: CanvasLayer
var hint_l: Label
var energy_l: Label
var stats_l: Label
var pv_panel: Panel
var pv_l: Label
var end_b: Button
var ok_b: Button
var cancel_b: Button
var reset_b: Button
var over_panel: Panel
var over_l: Label
var toast_l: Label


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
	_build_ui()
	last_play = Time.get_ticks_msec()
	_refresh_ui()


func _tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var t = load(path)
		if t is Texture2D:
			return t
	return null


# ---- UI -------------------------------------------------------------------

func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(2)
	return s


func _label(parent: Node, pos: Vector2, sz: Vector2, align = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = sz
	l.horizontal_alignment = align
	l.add_theme_color_override("font_color", Color.BLACK)
	parent.add_child(l)
	return l


func _button(text: String, pos: Vector2, sz: Vector2, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = sz
	b.pressed.connect(callback)
	ui.add_child(b)
	return b


func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	hint_l = _label(ui, Vector2(8, 6), Vector2(500, 20))
	energy_l = _label(ui, Vector2(768, 6), Vector2(184, 40), HORIZONTAL_ALIGNMENT_RIGHT)

	pv_panel = Panel.new()
	pv_panel.position = Vector2(8, 34)
	pv_panel.size = Vector2(220, 104)
	pv_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pv_panel.add_theme_stylebox_override("panel", _box(Color.WHITE, Color.BLACK))
	ui.add_child(pv_panel)
	pv_l = _label(pv_panel, Vector2(8, 6), Vector2(204, 92))
	pv_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	stats_l = _label(ui, Vector2(8, 490), Vector2(300, 48))
	end_b = _button("End turn", Vector2(836, 488), Vector2(116, 40), _on_end_pressed)
	cancel_b = _button("Cancel", Vector2(380, 372), Vector2(96, 28), _on_cancel_pressed)
	ok_b = _button("OK", Vector2(484, 372), Vector2(96, 28), _on_ok_pressed)
	reset_b = _button("Reset game", Vector2(8, 406), Vector2(110, 28), _on_new_game)

	toast_l = _label(ui, Vector2(330, 34), Vector2(300, 20), HORIZONTAL_ALIGNMENT_CENTER)

	over_panel = Panel.new()
	over_panel.position = Vector2(300, 60)
	over_panel.size = Vector2(360, 380)
	over_panel.add_theme_stylebox_override("panel", _box(Color.WHITE, Color.BLACK))
	ui.add_child(over_panel)
	var title := _label(over_panel, Vector2(0, 8), Vector2(360, 24), HORIZONTAL_ALIGNMENT_CENTER)
	title.text = "GAME OVER"
	over_l = _label(over_panel, Vector2(40, 36), Vector2(300, 290))
	var again := Button.new()
	again.text = "New game"
	again.position = Vector2(120, 336)
	again.size = Vector2(120, 32)
	again.pressed.connect(_on_new_game)
	over_panel.add_child(again)


func _toast(txt: String) -> void:
	toast_l.text = txt
	toast_until = Time.get_ticks_msec() + 1400


func _refresh_ui() -> void:
	energy_l.text = "Energy %d\nLives %d" % [game.energy, game.lives]
	var s: Dictionary = game.stats
	stats_l.text = "Played %d\nEnergy wasted %d\nTurn %d" % [s.played, s.wasted, game.turn]
	if busy:
		hint_l.text = "Computer turn"
	elif pending != null:
		hint_l.text = "Tap the domino or press OK to place it"
	elif drag != null:
		hint_l.text = "Right-click or second finger to rotate"
	elif sel >= 0:
		hint_l.text = "Tap to rotate. Drag onto the board."
	else:
		hint_l.text = "Select a domino"
	pv_panel.visible = sel >= 0 and sel < game.hand.size() and not ended
	if pv_panel.visible:
		var d: Dictionary = game.hand[sel]
		var sk := Skills.skill(d.a, d.b)
		pv_l.text = "%s  [%d|%d]\n%s\nPower %d%s" % [sk.name, d.a, d.b, sk.desc, sk.power,
				(", double bonus +25%" if sk.dbl else "")]
	ok_b.visible = pending != null
	cancel_b.visible = pending != null
	end_b.disabled = busy or ended or pending != null
	over_panel.visible = ended
	if ended:
		over_l.text = _stats_text()


func _stats_text() -> String:
	var s: Dictionary = game.stats
	var board_pips := 0
	for p in game.placed:
		board_pips += p.a + p.b
	var hand_pips := 0
	for d in game.hand:
		hand_pips += d.a + d.b
	var sec := int((finish_ms - s.t0) / 1000.0)
	var eff := int(round(100.0 * s.spent / maxi(1, s.spent + s.wasted)))
	var rows := [
		["Result", reason], ["Turns", str(game.turn)], ["Time", "%d:%02d" % [sec / 60, sec % 60]],
		["Lives lost", str(s.lost)], ["Your dominoes", str(s.played)], ["Computer dominoes", str(s.cpu)],
		["Pips you played", str(s.pips)], ["Pips left in hand", str(hand_pips)], ["Pips on board", str(board_pips)],
		["Energy spent", str(s.spent)], ["Energy wasted", str(s.wasted)], ["Energy efficiency", "%d%%" % eff],
		["Free plays", str(s.free)], ["Doubles played", str(s.doubles)], ["Costliest play", str(s.max_cost)],
		["Board covered", "%d%%" % int(round(game.placed.size() / 2.0))],
	]
	var out := ""
	for r in rows:
		out += "%s: %s\n" % [r[0], r[1]]
	return out


# ---- buttons and turn flow ------------------------------------------------

func _on_ok_pressed() -> void:
	_commit_pending()


func _on_cancel_pressed() -> void:
	pending = null
	_refresh_ui()


func _commit_pending() -> void:
	if pending == null:
		return
	var m: Dictionary = pending
	var res: Dictionary = game.check(m)
	if not res.ok:
		_toast(res.why)
		return
	game.commit_player(m)
	swing = {"who": "p", "t0": Time.get_ticks_msec()}
	pending = null
	sel = -1
	last_play = Time.get_ticks_msec()
	_refresh_ui()


func _on_end_pressed() -> void:
	if busy or ended or pending != null:
		return
	busy = true
	sel = -1
	drag = null
	var lost: bool = game.begin_end_turn()
	_refresh_ui()
	if lost:
		flash_t0 = Time.get_ticks_msec()
		await get_tree().create_timer(1.1).timeout
		if game.lives <= 0:
			_finish("You ran out of lives")
			return
	var n := 2 + randi() % 5
	for i in n:
		await get_tree().create_timer(0.45).timeout
		if game.cpu_play():
			swing = {"who": "c", "t0": Time.get_ticks_msec()}
		_refresh_ui()
	await get_tree().create_timer(0.45).timeout
	game.start_new_turn()
	for i in Game.DRAW_PER_TURN:
		game.draw_dominoes(1)
		_refresh_ui()
		await get_tree().create_timer(0.38).timeout
	busy = false
	last_play = Time.get_ticks_msec()
	if game.hand.size() >= Game.HAND_LIMIT:
		_finish("Your hand reached %d dominoes" % Game.HAND_LIMIT)
		return
	_refresh_ui()


func _finish(r: String) -> void:
	reason = r
	ended = true
	busy = false
	finish_ms = Time.get_ticks_msec()
	_refresh_ui()


func _on_new_game() -> void:
	game.reset()
	sel = -1
	drag = null
	pending = null
	press = null
	pdrag = null
	busy = false
	ended = false
	swing = null
	last_play = Time.get_ticks_msec()
	_refresh_ui()


# ---- input ----------------------------------------------------------------
# Mouse and touch both arrive as mouse events (touch emulation is on by default).

func _unhandled_input(event: InputEvent) -> void:
	if ended or busy:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_press(get_global_mouse_position())
			else:
				_release()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and drag != null:
			_rotate_drag()
	elif event is InputEventMouseMotion:
		_motion(get_global_mouse_position())
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


func _tray_center(i: int, n: int) -> Vector2:
	return Vector2(VIEW.x / 2.0 - n * SLOT / 2.0 + SLOT / 2.0 + i * SLOT, TRAY_Y)


func _tray_at(pos: Vector2) -> int:
	var n: int = game.hand.size()
	for i in n:
		var c := _tray_center(i, n)
		if Rect2(c - Vector2(SLOT / 2.0, SLOT / 2.0), Vector2(SLOT, SLOT)).has_point(pos):
			return i
	return -1


func _hit_pending(pos: Vector2) -> bool:
	var d := Game.dims(pending.rot)
	for z in [0.0, PEND_LIFT + THICK]:
		var g := _to_grid(pos + Vector2(0, z))
		if g.x >= pending.x and g.x < pending.x + d.x and g.y >= pending.y and g.y < pending.y + d.y:
			return true
	return false


func _press(pos: Vector2) -> void:
	if pending != null:
		if _hit_pending(pos):
			pdrag = {"start": pos, "g0": _to_grid(pos), "x": pending.x, "y": pending.y, "moved": false}
		return
	var i := _tray_at(pos)
	if i >= 0:
		press = {"i": i, "start": pos}


func _motion(pos: Vector2) -> void:
	if pdrag != null:
		if pos.distance_to(pdrag.start) > 6:
			pdrag.moved = true
		if pdrag.moved:
			var g := _to_grid(pos)
			pending.x = pdrag.x + int(round(g.x - pdrag.g0.x))
			pending.y = pdrag.y + int(round(g.y - pdrag.g0.y))
			Game.clamp_m(pending)
		return
	if press != null and drag == null and pos.distance_to(press.start) > 8:
		sel = press.i
		var d: Dictionary = game.hand[sel]
		drag = {"i": sel, "x": 0, "y": 0, "rot": posmod(int(d.ang / 90.0), 4), "a": d.a, "b": d.b, "on": false}
		_refresh_ui()
	if drag != null:
		_update_drag(pos)


func _update_drag(pos: Vector2) -> void:
	drag.on = pos.y < TRAY_TOP
	if drag.on:
		var g := _to_grid(Vector2(pos.x, pos.y - FINGER))
		var d := Game.dims(drag.rot)
		drag.x = int(round(g.x - d.x / 2.0))
		drag.y = int(round(g.y - d.y / 2.0))
		Game.clamp_m(drag)


func _rotate_drag() -> void:
	drag.rot = (drag.rot + 1) % 4
	game.hand[drag.i].ang += 90
	_update_drag(get_global_mouse_position())


func _release() -> void:
	if pdrag != null:
		var tap: bool = not pdrag.moved
		pdrag = null
		if tap:
			_commit_pending()
		press = null
		return
	if drag != null:
		_drop()
	elif press != null:
		var i: int = press.i
		if sel == i:
			game.hand[i].ang += 90      # tap the selected domino to rotate it
		else:
			sel = i
		_refresh_ui()
	press = null


func _drop() -> void:
	var d: Dictionary = drag
	drag = null
	if d.on:
		var res: Dictionary = game.check(d)
		if res.ok:
			pending = {"x": d.x, "y": d.y, "rot": d.rot, "a": d.a, "b": d.b, "i": d.i}
		else:
			_toast(res.why)
	_refresh_ui()


# ---- per frame ------------------------------------------------------------

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	var stuck: bool = not busy and not ended and pending == null and not game.playable_any()
	end_b.modulate = Color(0.35, 0.35, 0.35) if (stuck and int(now / 350.0) % 2 == 0) else Color.WHITE
	reset_b.visible = not ended and not busy and now - last_play > IDLE_RESET_MS
	toast_l.visible = now < toast_until
	queue_redraw()


# ---- drawing --------------------------------------------------------------

func _draw() -> void:
	_draw_board()
	_draw_tray()


func _draw_board() -> void:
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
		res = game.check(act)
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

	var fa := Time.get_ticks_msec() - flash_t0
	if fa < 1050 and int(fa / 175.0) % 2 == 0:
		draw_colored_polygon(PackedVector2Array([_P(0, 0), _P(n, 0), _P(n, n), _P(0, n)]), Color(0, 0, 0, 0.5))


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
		for idx in PIPS[pips[k]]:
			var gx: float = cs[k].x + 0.27 + (idx % 3) * 0.23
			var gy: float = cs[k].y + 0.27 + int(idx / 3.0) * 0.23
			_dot(_P(gx, gy, z1) - Vector2(1, 1), pip_white)


func _poly(pts: Array, fill: Color) -> void:
	draw_colored_polygon(PackedVector2Array(pts), fill)
	var o := pts.duplicate()
	o.append(pts[0])
	draw_polyline(PackedVector2Array(o), Color.BLACK, 1.0)


func _dot(pos: Vector2, white: bool) -> void:
	if white or dot_tex == null:
		draw_rect(Rect2(pos, Vector2(2, 2)), Color.WHITE if white else Color.BLACK)
	else:
		draw_texture(dot_tex, pos)


func _draw_char(who: String) -> void:
	var o: Vector2 = Game.CH[who]
	var other: Vector2 = Game.CH["c" if who == "p" else "p"]
	var center := _P(o.x + 1.5, o.y + 1.5)
	var to := (_P(other.x + 1.5, other.y + 1.5) - center).normalized()
	# characters fade while a domino is being played so they do not hide the board
	var alpha := 0.2 if (sel >= 0 or pending != null or drag != null) else 1.0
	var off := Vector2.ZERO
	if swing != null and swing.who == who:
		var p: float = (Time.get_ticks_msec() - swing.t0) / SWING_MS
		if p >= 1.0:
			swing = null
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


func _draw_tray() -> void:
	draw_line(Vector2(0, TRAY_TOP), Vector2(VIEW.x, TRAY_TOP), Color.BLACK, 2.0)
	var n: int = game.hand.size()
	var blink := int(Time.get_ticks_msec() / 250.0) % 2 == 0
	for i in n:
		if (drag != null and drag.i == i) or (pending != null and pending.i == i):
			continue
		var d: Dictionary = game.hand[i]
		var c := _tray_center(i, n)
		_draw_flat(c, d.ang, d.a, d.b, i == sel)
		if not busy and not ended and pending == null and game.can_play(d):
			var half := Vector2(28, 16) if posmod(int(d.ang / 90.0), 2) == 0 else Vector2(16, 28)
			draw_rect(Rect2(c - half, half * 2), Color.BLACK if blink else Color(0.5, 0.5, 0.5), false, 2.0)
	if drag != null and not drag.on:
		_draw_flat(get_global_mouse_position(), game.hand[drag.i].ang, drag.a, drag.b, true)


## Flat 48x24 domino for the hand. inverted = black body (selected / being dragged).
func _draw_flat(c: Vector2, ang: float, a: int, b: int, inverted: bool) -> void:
	draw_set_transform(c, deg_to_rad(ang), Vector2.ONE)
	var body := Color.BLACK if inverted else Color.WHITE
	draw_rect(Rect2(-24, -12, 48, 24), body)
	draw_rect(Rect2(-24, -12, 48, 24), Color.BLACK, false, 1.0)
	draw_line(Vector2(0, -12), Vector2(0, 12), Color.WHITE if inverted else Color.BLACK, 1.0)
	_flat_pips(-24, a, inverted)
	_flat_pips(0, b, inverted)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _flat_pips(x0: float, n: int, inverted: bool) -> void:
	for idx in PIPS[n]:
		_dot(Vector2(x0 + 4 + (idx % 3) * 7, -12 + 4 + int(idx / 3.0) * 7), inverted)


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
