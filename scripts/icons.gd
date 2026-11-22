extends RefCounted
## Icons for captions, info text, status tags and intents.
##
## Every icon has a NAME (lowercase, spaces become underscores: "Max Shield" -> "max_shield").
## To use your own art, drop a PNG called  res://img/icons/<name>.png  in the project.
## If that file exists it is used; if not, the tiny built-in 8x8 pixel icon below is drawn instead.
## The full list of names is in img/icons/README.md.
##
## Effects, statuses and intents ask for an icon by KIND ("dmg", "maxs", "impE" ...).
## NAME turns a kind into a name, and a name that is not in NAME is used as it is, so
## icon("fire") works too. Icons can also be written inside any text shown in a RichTextLabel as
## :name: (for example "Gain 2 :fury:"), see DominoText.append_rich().
##
## SIZE is the one knob for how big icons are drawn (in game pixels). Custom PNGs of any size are
## scaled to SIZE x SIZE, so a 16x16 or 32x32 PNG works fine (set SIZE to 16 to draw them bigger).

const SIZE := 8
const RELIC_SIZE := 16
const DIR := "res://img/icons/"

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
const CRACKED := [".##..##.", "##.##.##", "###..###", "##.##.##", ".##..##.", "..#.##..", "...#....", "........"]
const ENERGY := ["..####..", "########", "#......#", "#.####.#", "#.####.#", "#......#", "########", "........"]
const SUN := ["#..##..#", ".#.##.#.", "..####..", "########", "########", "..####..", ".#.##.#.", "#..##..#"]
const MOUNTAIN := ["........", "...##...", "..####..", "..####.#", ".######.", ".#######", "########", "........"]
const MOON := ["..####..", ".###....", "####....", "####....", "####....", ".###....", "..####..", "........"]
const GEM := ["........", "...##...", "..####..", ".######.", "..####..", "...##...", "........", "........"]
const GEM_OUTLINE := ["........", "...##...", "..#..#..", ".#....#.", "..#..#..", "...##...", "........", "........"]
const GEM_RARE := ["...##...", "..####..", ".######.", "########", ".######.", "..####..", "...##...", "........"]

## icon name -> built-in bitmap (used when there is no PNG for that name)
const PIXEL := {
	"damage": SWORD, "multi_hit": SWORD, "shield": SHIELD, "max_shield": MAX_SHIELD, "draw": CARD,
	"discard_random": TRASH, "discard": TRASH, "tutor": LENS, "power": POWER, "boost": BOLT, "heal": HEART,
	"reroll_all": DIE, "reroll": DIE, "fury": FLAME, "impair": DOWN, "self_damage": DROP, "generate": PLUS,
	"life": HEART_LINE, "lose_life": CRACKED, "energy": ENERGY,
	# enemy intents
	"attack": SWORD, "attack_life": SWORD, "block": SHIELD, "mill": CARD, "garbage": TRASH,
	# pip elements
	"light": SUN, "earth": MOUNTAIN, "water": DROP, "fire": FLAME, "lightning": BOLT, "darkness": MOON,
}

## kind (the id used by effects, statuses and intents) -> icon name. A kind that is missing here
## simply uses its own id as the name.
const NAME := {
	"dmg": "damage", "hit": "multi_hit", "shield": "shield", "maxs": "max_shield", "draw": "draw",
	"discR": "discard_random", "discP": "discard", "tutor": "tutor", "power": "power", "boost": "boost",
	"heal": "heal", "rerollA": "reroll_all", "rerollP": "reroll", "fury": "fury", "impS": "impair",
	"impE": "impair", "selfdmg": "self_damage", "gen": "generate", "life": "life", "paylife": "lose_life",
	"atk": "attack", "lifeatk": "attack_life", "blk": "block", "discH": "discard", "junk": "garbage",
}

static var _cache := {}
static var _custom := {}


## "Max Shield" -> "max_shield", "Veteran's Edge" -> "veterans_edge".
static func slug(s: String) -> String:
	var out := ""
	for ch in s.to_lower().replace(" ", "_"):
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "_":
			out += ch
	return out


## The icon name for a kind (or for a name, which stays as it is).
static func name_of(kind: String) -> String:
	return slug(NAME.get(kind, kind))


## Every icon name the game knows about (the files img/icons/<name>.png can replace).
static func all_names() -> Array:
	var out := PIXEL.keys()
	out.sort()
	return out


## Forget which PNGs were found (call after adding files while the game is running).
static func clear_cache() -> void:
	_cache.clear()
	_custom.clear()


## The PNG for this name, or null when there is none.
static func custom_texture(icon_name: String) -> Texture2D:
	if _custom.has(icon_name):
		return _custom[icon_name]
	var path := "%s%s.png" % [DIR, icon_name]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			tex = res
	elif FileAccess.file_exists(path):
		# not imported yet (running from the project folder): read the file directly
		var img := Image.load_from_file(path)
		if img != null and not img.is_empty():
			tex = ImageTexture.create_from_image(img)
	_custom[icon_name] = tex
	return tex


## Is there any icon (PNG or built-in) for this kind or name?
static func exists(kind: String) -> bool:
	if kind == "x":
		return true
	var n := name_of(kind)
	return PIXEL.has(n) or custom_texture(n) != null


## The icon as a texture for Controls and RichTextLabel. A PNG wins over the built-in 8x8 icon
## (the built-in one is black unless color says otherwise). Kind "x" is the red X.
static func texture(kind: String, color: Color = Color.BLACK) -> Texture2D:
	if kind == "x":
		return _pixel_texture("x", [], color)
	var n := name_of(kind)
	var tex := custom_texture(n)
	if tex != null:
		return tex
	return _pixel_texture(n, PIXEL.get(n, []), color)


static func _pixel_texture(key_name: String, rows: Array, color: Color) -> Texture2D:
	var key := "%s%s" % [key_name, color.to_html()]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	if key_name == "x":
		var red := Color(0.85, 0.0, 0.0)
		for i in range(1, 7):
			for t in [0, 1]:
				img.set_pixel(i, mini(i + t, 7), red)
				img.set_pixel(7 - i, mini(i + t, 7), red)
	else:
		for y in rows.size():
			var row: String = rows[y]
			for x in row.length():
				if row[x] == "#":
					img.set_pixel(x, y, color)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## A relic's picture: img/icons/<relic name>.png, or a little gem whose shape shows its rarity.
static func relic_texture(relic) -> Texture2D:
	var n := slug(relic.title)
	var tex := custom_texture(n)
	if tex != null:
		return tex
	var rows: Array = GEM_OUTLINE
	if relic.rarity == "u":
		rows = GEM
	elif relic.rarity == "r":
		rows = GEM_RARE
	return _pixel_texture("gem_" + relic.rarity, rows, Color.BLACK)


## Draw the icon for a kind at pos (top-left), SIZE x SIZE.
static func draw(ci: CanvasItem, kind: String, pos: Vector2, color: Color = Color.BLACK) -> void:
	ci.draw_texture_rect(texture(kind, color), Rect2(pos, Vector2(SIZE, SIZE)), false)
