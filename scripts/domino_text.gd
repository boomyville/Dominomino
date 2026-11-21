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


## Add a line: an icon, then text.
static func icon_line(rt: RichTextLabel, kind: String, text: String) -> void:
	rt.add_image(Icons.texture(kind))
	rt.append_text(" " + text + "\n")


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
