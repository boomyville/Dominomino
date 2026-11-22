extends RefCounted
## Fills a RichTextLabel with what a domino is: name, rarity, one line per effect (with its icon),
## the play condition and the statuses that are changing its damage.

const Icons = preload("res://scripts/icons.gd")


## Set a RichTextLabel up the way every domino text uses it.
static func setup(rt: RichTextLabel) -> void:
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


static var _token_re: RegEx = null


## Add one icon (a kind like "dmg" or a name like "fire") at the current position.
static func add_icon(rt: RichTextLabel, kind: String) -> void:
	rt.add_image(Icons.texture(kind), Icons.SIZE, Icons.SIZE)


## Append text in which :name: is replaced by that icon ("Gain 2 :fury:"). A :word: that is not an
## icon name stays as text.
static func append_rich(rt: RichTextLabel, text: String) -> void:
	if _token_re == null:
		_token_re = RegEx.new()
		_token_re.compile(":([a-z_]+):")
	var pos := 0
	for m in _token_re.search_all(text):
		if not Icons.exists(m.get_string(1)):
			continue
		rt.append_text(text.substr(pos, m.get_start() - pos))
		add_icon(rt, m.get_string(1))
		pos = m.get_end()
	rt.append_text(text.substr(pos))


## Add a line: an icon, then text (the text may hold :name: icons too).
static func icon_line(rt: RichTextLabel, kind: String, text: String) -> void:
	add_icon(rt, kind)
	append_rich(rt, " " + text + "\n")


## index is the position in the hand (so "not met" can be shown), or -1 when the domino is not in hand.
static func fill(rt: RichTextLabel, game, d, index: int = -1) -> void:
	var def = d.data
	rt.clear()
	rt.push_bold()
	rt.append_text("%s  [%d|%d]" % [def.title, d.a, d.b])
	rt.pop()
	rt.append_text("\n%s, pip total %d\n" % [def.rarity_name(), d.total()])
	for entry in game.fx_entries(d):
		icon_line(rt, entry.k, entry.text + ".")
	if def.condition != null:
		if def.condition.id == "never":
			rt.append_text("[i]Cannot be played.[/i]\n")
		else:
			var met: bool = index < 0 or game.cond_ok(index)
			rt.append_text("[i]Only if %s%s.[/i]\n" % [def.condition.text, "" if met else " (not met)"])
	var mods: Array = game.pl.status_lines()
	if index >= 0 and def.has_attack() and mods.size() > 0:
		rt.append_text("Includes " + ", ".join(mods))


## A relic: its picture and name, rarity, then what it does.
static func fill_relic(rt: RichTextLabel, relic) -> void:
	rt.clear()
	rt.add_image(Icons.relic_texture(relic), Icons.RELIC_SIZE, Icons.RELIC_SIZE)
	rt.push_bold()
	rt.append_text("  " + relic.title)
	rt.pop()
	rt.append_text("\n%s relic\n" % relic.rarity_name())
	append_rich(rt, relic.text)
