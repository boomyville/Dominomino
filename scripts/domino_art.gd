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


## A flat 48 x 24 domino centred on c and turned by ang degrees.
## inverted = black body with white pips (selected / being dragged).
static func draw_flat(ci: CanvasItem, c: Vector2, ang: float, a: int, b: int, inverted: bool, dot_tex: Texture2D = null) -> void:
	ci.draw_set_transform(c, deg_to_rad(ang), Vector2.ONE)
	var body := Color.BLACK if inverted else Color.WHITE
	ci.draw_rect(Rect2(-24, -12, 48, 24), body)
	ci.draw_rect(Rect2(-24, -12, 48, 24), Color.BLACK, false, 1.0)
	ci.draw_line(Vector2(0, -12), Vector2(0, 12), Color.WHITE if inverted else Color.BLACK, 1.0)
	_pips(ci, -24, a, inverted, dot_tex)
	_pips(ci, 0, b, inverted, dot_tex)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _pips(ci: CanvasItem, x0: float, n: int, inverted: bool, dot_tex: Texture2D) -> void:
	for idx in PIPS[n]:
		dot(ci, Vector2(x0 + 4 + (idx % 3) * 7, -12 + 4 + int(idx / 3.0) * 7), inverted, dot_tex)
