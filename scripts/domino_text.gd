extends RefCounted
## Fills a RichTextLabel with what a domino is: name, rarity, one line per effect (with its icon),
## the play condition and the statuses that are changing its damage.

const Icons = preload("res://scripts/icons.gd")
const Glossary = preload("res://scripts/glossary.gd")


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
	rt.append_text("%s  [%s]" % [d.display_name(), d.pips_text()])
	rt.pop()
	var span: Vector2i = d.total_span()
	var level_text := ", level %d/%d" % [d.level(), d.max_level()] if d.max_level() > 1 else ""
	rt.append_text("\n%s, pip total %s%s\n" % [def.rarity_name(), str(span.x) if span.x == span.y else "%d-%d" % [span.x, span.y], level_text])
	if d.specs[0].is_volatile() or d.specs[1].is_volatile():
		rt.append_text("[i]Volatile pips: rolled again at the start of every turn until played.[/i]\n")
	elif d.has_ranged():
		rt.append_text("[i]Unstable pips: rolled at the start of each battle.[/i]\n")
	for entry in game.fx_entries(d):
		icon_line(rt, entry.k, entry.text + ".")
	if def.condition != null:
		if def.condition.id == "never":
			rt.append_text("[i]Cannot be played.[/i]\n")
		else:
			var met: bool = index < 0 or game.cond_ok(index)
			rt.append_text("[i]Only if %s%s.[/i]\n" % [def.condition.text, "" if met else " (not met)"])
	if def.ephemeral:
		rt.append_text("[i]Ephemeral: discarded at the end of the turn if you do not play it.[/i]\n")
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
	rt.append_text("\n%s %s\n" % [relic.rarity_name(), relic.kind_name()])
	append_rich(rt, relic.text)


## A glossary card: the status icon and name, then what it does.
static func fill_status(rt: RichTextLabel, id: String) -> void:
	var e: Dictionary = Glossary.ENTRIES[id]
	rt.clear()
	add_icon(rt, e.icon)
	rt.push_bold()
	rt.append_text(" " + e.name)
	rt.pop()
	rt.append_text("\n" + e.text)


## A relic as a list row: bold name, rarity, then what it does (the picture is drawn separately).
static func fill_relic_line(rt: RichTextLabel, relic) -> void:
	rt.clear()
	rt.push_bold()
	rt.append_text(relic.title)
	rt.pop()
	rt.append_text("  (%s %s)\n" % [relic.rarity_name(), relic.kind_name()])
	append_rich(rt, relic.text)
