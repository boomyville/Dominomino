extends RefCounted
## Base class for what a domino does when it is played. There is one child class per kind in this
## folder. Make a new effect by adding a child and registering it in effect_factory.gd.
##
## The size of an effect comes from a number s taken from the domino's pips (by default their total, 0 to 12):
## bigger pips, bigger effect. "src" in the catalogue row picks the number: sum, max, min, diff or prod (see
## pip_metric.gd), so a domino can deal damage equal to the product of its pips.
##   S = s*a + b      C = ceil(s/a) + b      F = floor(s/a) + b
##   K = b (constant) L = max(1, round(a*s + b))      N = the effect has no number

const PipMetric = preload("res://scripts/pip_metric.gd")
const DamageCmd = preload("res://scripts/cmd/damage_cmd.gd")
const PowerCmd = preload("res://scripts/cmd/power_cmd.gd")
const CreatureCmd = preload("res://scripts/cmd/creature_cmd.gd")

var kind := ""       # data id, also the icon id in icons.gd
var mode := "N"
var a := 0.0
var b := 0.0
var hits := 1
var src := "sum"     # which pip number s is: sum, max, min, diff or prod


func setup(row: Dictionary) -> void:
	kind = row.k
	mode = row.get("m", "N")
	a = float(row.get("a", 0))
	b = float(row.get("b", 0))
	hits = int(row.get("t", 1))
	src = row.get("src", "sum")


func has_number() -> bool:
	return mode != "N"


func value(s: int) -> int:
	match mode:
		"S":
			return int(s * a + b)
		"C":
			return int(ceil(s / a)) + int(b)
		"F":
			return int(floor(s / a)) + int(b)
		"K":
			return int(b)
		"L":
			return maxi(1, int(round(a * s + b)))
	return 0


## The number s for this domino's current pips.
func size_for(domino) -> int:
	return PipMetric.of(src, domino.a, domino.b)


## The lowest and highest s the domino's pips can give while a half has no value yet (before the battle).
func size_span(domino) -> Vector2i:
	var lo := 1000
	var hi := -1
	for x in range(domino.specs[0].lo, domino.specs[0].hi + 1):
		for y in range(domino.specs[1].lo, domino.specs[1].hi + 1):
			var v := PipMetric.of(src, x, y)
			lo = mini(lo, v)
			hi = maxi(hi, v)
	return Vector2i(lo, hi)


## The line shown to the player. While the domino's pips are still a range ("1-6") the numbers in the line
## are ranges too ("Deal 12-36 damage"). A note says where the number comes from when it is not the total.
func shown_text(game, domino) -> String:
	var t: String
	if domino.unsettled():
		var span := size_span(domino)
		t = merge_range(text_for(game, domino, span.x), text_for(game, domino, span.y))
	else:
		t = text_for(game, domino, size_for(domino))
	return t + PipMetric.note(src)


## The number under a hand domino (a range while the pips are a range).
func shown_caption(game, domino) -> String:
	if domino.unsettled():
		var span := size_span(domino)
		return merge_range(caption_for(game, domino, span.x), caption_for(game, domino, span.y))
	return caption_for(game, domino, size_for(domino))


## Two versions of the same text with different numbers become one text with ranges: "Deal 5 damage" and
## "Deal 9 damage" give "Deal 5-9 damage".
static func merge_range(t_lo: String, t_hi: String) -> String:
	if t_lo == t_hi:
		return t_lo
	var re := RegEx.new()
	re.compile("\\d+")
	var lo := re.search_all(t_lo)
	var hi := re.search_all(t_hi)
	if lo.size() != hi.size():
		return "%s to %s" % [t_lo, t_hi]
	var out := ""
	var pos := 0
	for i in lo.size():
		out += t_lo.substr(pos, lo[i].get_start() - pos)
		var x := lo[i].get_string()
		var y := hi[i].get_string()
		out += x if x == y else "%s-%s" % [x, y]
		pos = lo[i].get_end()
	return out + t_lo.substr(pos)


## Does this effect count as an attack? (Attacks tick Fury / Impair and use up Boost.)
func is_attack() -> bool:
	return false


## One line for the info window.
func text(_game, _s: int) -> String:
	return ""


## The number shown next to the icon under a hand domino ("" = none).
func caption(_game, s: int) -> String:
	return str(value(s)) if has_number() else ""


## The icon shown for this effect: a kind or an icon name (see icons.gd). Defaults to the kind.
func icon() -> String:
	return kind


## text() / caption() for an effect that depends on the domino itself (for example one that counts
## its own pips). Most effects do not, so these just call text() and caption().
func text_for(game, _domino, s: int) -> String:
	return text(game, s)


func caption_for(game, _domino, s: int) -> String:
	return caption(game, s)


## The damage an attack of this base size would deal right now (for text, captions, previews).
func attack_value(game, base: int) -> int:
	return DamageCmd.attack_value(game, game.pl, game.foe, base)


## Deal damage from you to the enemy through DamageCmd (modifiers, log, stats and UI included).
func attack(game, base: int) -> void:
	DamageCmd.attack(game, game.pl, game.foe, base)


## The same hit on the copies in sim ({pl, foe}). Nothing is logged or shown.
func sim_attack(game, sim: Dictionary, base: int) -> void:
	DamageCmd.attack(game, sim.pl, sim.foe, base, true)


## Work out what this effect would do to the damage preview, without changing the game. sim holds
## copies of the two combatants, {pl, foe}, and the effects of one domino run in order on them.
## Only effects that change attack damage need to override this (damage, Fury, Power, Boost ...).
## Change the copies only through the commands with silent = true (DamageCmd, PowerCmd).
func preview(_game, _domino, _s: int, _sim: Dictionary) -> void:
	pass


## Do the effect. It may wait (await game.ui.pause) or ask the player (await game.ui.pick).
## Keep anything that comes after an await simple: call a helper on game instead of doing
## arithmetic inline (Godot 4.1 to 4.4 read stale values there).
func apply(_game, _domino, _s: int) -> void:
	pass
