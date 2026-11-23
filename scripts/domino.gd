extends "res://scripts/model.gd"
## One domino you own or hold: its kind (data) and its own pips.
## Where it is on the board is a separate placement ({x, y, rot, a, b}), see game.gd.

var data = null      # DominoData
var a := 0           # pips on the first half
var b := 0           # pips on the second half
var ang := 0         # how far it is turned in the hand (degrees, adds up so it never spins backwards)


func _init(domino_data = null, pips_a: int = 0, pips_b: int = 0) -> void:
	data = domino_data
	a = pips_a
	b = pips_b


## Both halves added together: the number every effect size is worked out from.
func total() -> int:
	return a + b


## A fresh copy (same kind and pips, not turned).
func copy():
	return get_script().new(data, a, b)
