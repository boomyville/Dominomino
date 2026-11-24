extends RefCounted
## How a domino looks when it is lying flat (in the hand, in the pick window).
## The isometric board dominoes are drawn by main.gd.

## Pip layout of each number, as positions in a 3 x 3 grid (0 to 8, row by row).
const PIPS := [[], [4], [0, 8], [0, 4, 8], [0, 2, 6, 8], [0, 2, 4, 6, 8], [0, 2, 3, 5, 6, 8]]


## One pip: a 2x2 texture (the black pixel image) or a plain rectangle if there is no texture.
static func dot(ci: CanvasItem, pos: Vector2, white: bool, dot_tex: Texture2D = null) -> void:
	if white or dot_tex == null:
		ci.draw_rect(Rect2(pos, Vector2(2, 2)), Color.WHITE if white else Color.BLACK)
	else:
		ci.draw_texture(dot_tex, pos)


## How a domino should be marked, for draw_flat: {halves: [{label, mark}, {label, mark}], tag}.
##   label  "1-6": the half has a range and no value yet (shop, rewards, your collection): the range is
##          written instead of pips. "" when the half shows pips.
##   mark   "u" for an unstable half (a small square in its corner) and "v" for a volatile half (a small
##          lightning bolt), "" for a stable half.
##   tag    the upgrade level above the top-right corner: "+", "++", "+++" (upgraded) or "-" (downgraded)
static func sides(d) -> Dictionary:
	var out := []
	for i in 2:
		var spec = d.specs[i]
		var label := ""
		var mark := ""
		if spec.ranged():
			mark = "v" if spec.is_volatile() else "u"
			if d.unsettled():
				label = spec.text()
		out.append({"label": label, "mark": mark})
	return {"halves": out, "tag": d.level_tag()}


## A flat 48 x 24 domino centred on c and turned by ang degrees.
## inverted = black body with white pips (selected / being dragged).
## look comes from sides(): a range written instead of pips, the unstable / volatile marks and the level tag.
static func draw_flat(ci: CanvasItem, c: Vector2, ang: float, a: int, b: int, inverted: bool, dot_tex: Texture2D = null, look: Dictionary = {}) -> void:
	var halves: Array = look.get("halves", [])
	ci.draw_set_transform(c, deg_to_rad(ang), Vector2.ONE)
	var body := Color.BLACK if inverted else Color.WHITE
	var ink := Color.WHITE if inverted else Color.BLACK
	ci.draw_rect(Rect2(-24, -12, 48, 24), body)
	ci.draw_rect(Rect2(-24, -12, 48, 24), Color.BLACK, false, 1.0)
	ci.draw_line(Vector2(0, -12), Vector2(0, 12), ink, 1.0)
	for i in 2:
		var x0 := -24.0 + 24.0 * i
		var n := a if i == 0 else b
		var half: Dictionary = halves[i] if halves.size() == 2 else {"label": "", "mark": ""}
		if half.label != "":
			var font := ThemeDB.fallback_font
			ci.draw_string(font, Vector2(x0, 4), half.label, HORIZONTAL_ALIGNMENT_CENTER, 24, 11, ink)
		else:
			_pips(ci, x0, n, inverted, dot_tex)
		_mark(ci, x0, half.mark, ink)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var tag: String = look.get("tag", "")
	if tag != "":
		var font := ThemeDB.fallback_font
		var half_size := Vector2(12, 24) if posmod(roundi(ang / 90.0), 2) == 1 else Vector2(24, 12)
		var w := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		ci.draw_string(font, Vector2(c.x + half_size.x - w, c.y - half_size.y - 5), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
				Color(0.7, 0.0, 0.0) if tag == "-" else Color.BLACK)


## The corner mark of an unstable (square) or volatile (lightning bolt) half.
static func _mark(ci: CanvasItem, x0: float, mark: String, ink: Color) -> void:
	if mark == "u":
		ci.draw_rect(Rect2(x0 + 19, -11, 3, 3), ink, false, 1.0)
	elif mark == "v":
		ci.draw_polyline(PackedVector2Array([Vector2(x0 + 22, -11), Vector2(x0 + 19, -8), Vector2(x0 + 22, -8), Vector2(x0 + 19, -5)]), ink, 1.0)


static func _pips(ci: CanvasItem, x0: float, n: int, inverted: bool, dot_tex: Texture2D) -> void:
	for idx in PIPS[n]:
		dot(ci, Vector2(x0 + 4 + (idx % 3) * 7, -12 + 4 + int(idx / 3.0) * 7), inverted, dot_tex)
