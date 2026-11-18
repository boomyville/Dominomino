extends RefCounted
## Base class for what a domino does when it is played. There is one child class per kind in this
## folder. Make a new effect by adding a child and registering it in effect_factory.gd.
##
## The size of an effect comes from the domino's pip total s (0 to 12): bigger pips, bigger effect.
##   S = s*a + b      C = ceil(s/a) + b      F = floor(s/a) + b
##   K = b (constant) L = max(1, round(a*s + b))      N = the effect has no number

var kind := ""       # data id, also the icon id in icons.gd
var mode := "N"
var a := 0.0
var b := 0.0
var hits := 1


func setup(row: Dictionary) -> void:
	kind = row.k
	mode = row.get("m", "N")
	a = float(row.get("a", 0))
	b = float(row.get("b", 0))
	hits = int(row.get("t", 1))


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


## Does this effect count as an attack? (Attacks tick Fury / Impair and use up Boost.)
func is_attack() -> bool:
	return false


## One line for the info window.
func text(_game, _s: int) -> String:
	return ""


## The number shown next to the icon under a hand domino ("" = none).
func caption(_game, s: int) -> String:
	return str(value(s)) if has_number() else ""


## Do the effect. It may wait (await game.ui.pause) or ask the player (await game.ui.pick).
## Keep anything that comes after an await simple: call a helper on game instead of doing
## arithmetic inline (Godot 4.1 to 4.4 read stale values there).
func apply(_game, _domino, _s: int) -> void:
	pass
