extends RefCounted
## Tiny 8x8 pixel icons for the effect captions under each hand domino (no emoji font needed).
## Swap these for real sprites whenever you like: draw() is the only place that uses them.

const SIZE := 8

const SWORD := ["......##", ".....###", "....###.", ".#.###..", "..###...", "..##....", ".#.#....", "#......."]
const SHIELD := ["########", "########", "########", "########", ".######.", "..####..", "...##...", "........"]
const MAX_SHIELD := ["...##...", "..####..", ".######.", "########", "########", ".######.", "..####..", "...##..."]
const CARD := [".######.", ".#....#.", ".#.##.#.", ".#.##.#.", ".#....#.", ".#....#.", ".######.", "........"]
const TRASH := ["..####..", "########", ".#.##.#.", ".#.##.#.", ".#.##.#.", ".#.##.#.", ".######.", "........"]
const LENS := ["..####..", ".##..##.", ".#....#.", ".#....#.", ".##..##.", "..####..", "......#.", ".......#"]
const POWER := ["...##...", "..####..", ".##..##.", "........", "...##...", "..####..", ".##..##.", "........"]
const BOLT := ["....###.", "...###..", "..###...", ".######.", "...###..", "..##....", ".##.....", "#......."]
const HEART := [".##..##.", "########", "########", "########", ".######.", "..####..", "...##...", "........"]
const DIE := ["########", "#......#", "#.#..#.#", "#......#", "#......#", "#.#..#.#", "#......#", "########"]
const FLAME := ["...#....", "..##..#.", "..###.#.", ".#######", ".#######", ".#######", "..#####.", "...###.."]
const DOWN := ["........", "##....##", ".##..##.", "..####..", "...##...", "........", "########", "........"]
const DROP := ["...##...", "...##...", "..####..", "..####..", ".######.", ".######.", ".######.", "..####.."]
const PLUS := ["...##...", "...##...", "...##...", "########", "########", "...##...", "...##...", "...##..."]
const HEART_LINE := [".##..##.", "#..##..#", "#......#", "#......#", ".#....#.", "..#..#..", "...##...", "........"]

## effect kind -> icon bitmap
const BY_KIND := {
	"dmg": SWORD, "hit": SWORD, "shield": SHIELD, "maxs": MAX_SHIELD, "draw": CARD, "discR": TRASH,
	"discP": TRASH, "tutor": LENS, "power": POWER, "boost": BOLT, "heal": HEART, "rerollA": DIE,
	"rerollP": DIE, "fury": FLAME, "impS": DOWN, "impE": DOWN, "selfdmg": DROP, "gen": PLUS, "life": HEART_LINE,
}


## Draw the icon for an effect kind at pos (top-left), one pixel per bitmap cell.
## kind "x" draws a red X (condition not met, or Garbage).
static func draw(ci: CanvasItem, kind: String, pos: Vector2, color: Color = Color.BLACK) -> void:
	if kind == "x":
		var red := Color(0.85, 0.0, 0.0)
		ci.draw_line(pos + Vector2(1, 1), pos + Vector2(7, 7), red, 2.0)
		ci.draw_line(pos + Vector2(7, 1), pos + Vector2(1, 7), red, 2.0)
		return
	if not BY_KIND.has(kind):
		return
	var rows: Array = BY_KIND[kind]
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if row[x] == "#":
				ci.draw_rect(Rect2(pos + Vector2(x, y), Vector2(1, 1)), color)
